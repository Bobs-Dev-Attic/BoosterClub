import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../config/app_config.dart';
import '../data/demo_data.dart';
import '../models/app_user.dart';
import '../models/audit.dart';
import '../models/content_models.dart';
import '../models/donation.dart';

/// Abstracts reads/writes for all content collections. Backed by Cloud
/// Firestore in production, or an in-memory store when [AppConfig.demoMode].
///
/// ## Recipe: adding a new content type
///
/// Most features follow the same five steps — grep for `committees` to see a
/// complete, recent example of each one:
///
///  1. **Model** (lib/models/content_models.dart): a class implementing
///     [ContentItem] with `fromDoc` (Firestore map → object) and `toMap`
///     (object → Firestore map).
///  2. **Stream** (this file): a one-liner like
///     `Stream<List<Foo>> foos() => _stream('foos', Foo.fromDoc);`
///     plus a `_demo['foos'] = …` line in [_seedDemo] and a loop in
///     [seedSampleData] so demo mode and "Load sample content" work.
///  3. **Security rule** (firestore.rules): a `match /foos/{doc}` block saying
///     who may read/write. Nothing is accessible until a rule allows it.
///  4. **Permission** (lib/models/permissions.dart) if admins manage it, and a
///     tab in lib/screens/admin/admin_screen.dart gated by that permission.
///  5. **Screen/editor**: a public screen reading the stream via
///     `StreamListView`, and an editor dialog in
///     lib/screens/admin/content_forms.dart returning the edited model.
///
/// Writes go through [upsert]/[delete], which handle both demo mode and
/// Firestore, so screens never need to branch on [AppConfig.demoMode].
class FirestoreService {
  FirestoreService() {
    if (AppConfig.demoMode) _seedDemo();
  }

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ---- In-memory demo stores -------------------------------------------
  final Map<String, List<ContentItem>> _demo = {};
  final Map<String, StreamController<List<ContentItem>>> _controllers = {};

  void _seedDemo() {
    _demo['events'] = List.of(DemoData.events());
    _demo['volunteering'] = List.of(DemoData.volunteering());
    _demo['sponsorships'] = List.of(DemoData.sponsorships());
    _demo['funding_requests'] = List.of(DemoData.fundingRequests());
    _demo['fundraisers'] = List.of(DemoData.fundraisers());
    _demo['meetings'] = List.of(DemoData.meetings());
    _demo['faqs'] = List.of(DemoData.faqs());
    _demo['committees'] = List.of(DemoData.committees());
    _demo['committee_members'] = List.of(DemoData.committeeMembers());
    _demo['teams'] = List.of(DemoData.teams());
    _demo['team_members'] = List.of(DemoData.teamMembers());
    _demo['history_facts'] = List.of(DemoData.historyFacts());
    _demo['gallery'] = List.of(DemoData.gallery());
    _demo['legal_documents'] = List.of(DemoData.legalDocuments());
    _demo['fundraising_campaigns'] = List.of(DemoData.fundraisingCampaigns());
    _demo['fundraising_orders'] = List.of(DemoData.fundraisingOrders());
    _demo['fundraising_vendors'] = List.of(DemoData.fundraisingVendors());
  }

  StreamController<List<ContentItem>> _controllerFor(String c) {
    return _controllers.putIfAbsent(
      c,
      () => StreamController<List<ContentItem>>.broadcast(
        onListen: () => _emit(c),
      ),
    );
  }

  void _emit(String c) => _controllerFor(c).add(List.of(_demo[c] ?? const []));

  Stream<List<T>> _stream<T extends ContentItem>(
    String collection,
    T Function(String id, Map<String, dynamic> data) parse, {
    String? orderBy,
    bool descending = false,
  }) {
    if (AppConfig.demoMode) {
      final controller = _controllerFor(collection);
      // Emit the current snapshot to EVERY new subscriber immediately (like
      // Firestore's snapshots()), then forward live updates. The shared
      // broadcast controller only runs onListen for its first listener, so a
      // second concurrent view (e.g. a detail screen) would otherwise wait
      // forever for its first event.
      return Stream<List<ContentItem>>.multi((sink) {
        sink.add(List.of(_demo[collection] ?? const []));
        final sub =
            controller.stream.listen(sink.add, onError: sink.addError);
        sink.onCancel = () => sub.cancel();
      }).map((items) => items.cast<T>());
    }
    Query<Map<String, dynamic>> q = _db.collection(collection);
    if (orderBy != null) q = q.orderBy(orderBy, descending: descending);
    return q.snapshots().map(
          (snap) => snap.docs.map((d) => parse(d.id, d.data())).toList(),
        );
  }

  // ---- Public read streams ---------------------------------------------
  Stream<List<SchoolEvent>> events() =>
      _stream('events', SchoolEvent.fromDoc, orderBy: 'startsAt');

  Stream<List<VolunteerOpportunity>> volunteering() =>
      _stream('volunteering', VolunteerOpportunity.fromDoc, orderBy: 'date');

  Stream<List<Sponsorship>> sponsorships() => _stream(
      'sponsorships', Sponsorship.fromDoc,
      orderBy: 'amount', descending: true);

  Stream<List<FundingRequest>> fundingRequests() => _stream(
      'funding_requests', FundingRequest.fromDoc,
      orderBy: 'submittedAt', descending: true);

  Stream<List<FundraisingEvent>> fundraisers() =>
      _stream('fundraisers', FundraisingEvent.fromDoc, orderBy: 'endsAt');

  Stream<List<Meeting>> meetings() => _stream(
      'meetings', Meeting.fromDoc,
      orderBy: 'meetingDate', descending: true);

  Stream<List<FaqItem>> faqs() =>
      _stream('faqs', FaqItem.fromDoc, orderBy: 'order');

  Stream<List<Committee>> committees() =>
      _stream('committees', Committee.fromDoc, orderBy: 'order');

  /// Every committee membership (join records). Callers filter by `committeeId`
  /// (or `userId`) client-side — the set is small and this avoids per-committee
  /// composite indexes.
  Stream<List<CommitteeMember>> committeeMembers() =>
      _stream('committee_members', CommitteeMember.fromDoc);

  /// All teams, ordered for display.
  Stream<List<Team>> teams() => _stream('teams', Team.fromDoc, orderBy: 'order');

  /// Every team membership (join records). Callers filter by `teamId`.
  Stream<List<TeamMember>> teamMembers() =>
      _stream('team_members', TeamMember.fromDoc);

  /// Adds a user to a committee (idempotent — the membership id is a
  /// deterministic composite of committee + user, so re-adding just updates).
  Future<void> addCommitteeMember(
    Committee committee,
    AppUser user, {
    List<String> roleIds = const [],
  }) =>
      upsert(
        'committee_members',
        CommitteeMember(
          id: CommitteeMember.idFor(committee.id, user.uid),
          committeeId: committee.id,
          userId: user.uid,
          userName: user.displayName,
          roleIds: roleIds,
          createdAt: DateTime.now(),
        ),
      );

  /// Replaces the set of roles a committee member holds.
  Future<void> setCommitteeMemberRoles(
          CommitteeMember member, List<String> roleIds) =>
      upsert('committee_members', member.copyWith(roleIds: roleIds));

  Future<void> removeCommitteeMember(CommitteeMember member) =>
      delete('committee_members', member.id);

  /// Adds a user to a team (idempotent — see [addCommitteeMember]).
  Future<void> addTeamMember(Team team, AppUser user) => upsert(
        'team_members',
        TeamMember(
          id: TeamMember.idFor(team.id, user.uid),
          teamId: team.id,
          userId: user.uid,
          userName: user.displayName,
          createdAt: DateTime.now(),
        ),
      );

  Future<void> removeTeamMember(TeamMember member) =>
      delete('team_members', member.id);

  Stream<List<HistoryFact>> historyFacts() =>
      _stream('history_facts', HistoryFact.fromDoc, orderBy: 'month');

  /// All gallery images (public + hidden). Only gallery managers may read this
  /// unfiltered — the security rules deny an unconstrained read to others.
  Stream<List<GalleryImage>> gallery() => _stream(
      'gallery', GalleryImage.fromDoc,
      orderBy: 'uploadedAt', descending: true);

  /// Public-only gallery images, for the public Gallery page. Filters on the
  /// server (`public == true`) so hidden images are never sent to guests, and
  /// so the query is permitted by the gallery read rule. Sorted client-side to
  /// avoid needing a composite index.
  Stream<List<GalleryImage>> galleryPublic() {
    if (AppConfig.demoMode) {
      return gallery().map(
          (list) => list.where((g) => g.public).toList());
    }
    return _db
        .collection('gallery')
        .where('public', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => GalleryImage.fromDoc(d.id, d.data())).toList();
      list.sort((a, b) => (b.uploadedAt ?? DateTime(1970))
          .compareTo(a.uploadedAt ?? DateTime(1970)));
      return list;
    });
  }

  /// One-time backfill: older gallery documents created before the `public`
  /// flag existed have no such field, so `where('public', == true)` would hide
  /// them from the public page. Set the flag to true (their prior behavior) on
  /// any that are missing it. Safe to call repeatedly; only managers can run it.
  Future<void> ensureGalleryPublicFlags() async {
    if (AppConfig.demoMode) return;
    final snap = await _db.collection('gallery').get();
    for (final doc in snap.docs) {
      if (doc.data()['public'] == null) {
        await doc.reference.set({'public': true}, SetOptions(merge: true));
      }
    }
  }

  /// Legal/policy documents (Terms of Use, Privacy Policy). Small, unordered
  /// set keyed by a stable id (`terms`, `privacy`).
  Stream<List<LegalDocument>> legalDocuments() =>
      _stream('legal_documents', LegalDocument.fromDoc);

  /// Logistics-focused fundraising campaigns (product sales, raffles, …).
  Stream<List<FundraisingCampaign>> fundraisingCampaigns() => _stream(
      'fundraising_campaigns', FundraisingCampaign.fromDoc,
      orderBy: 'createdAt', descending: true);

  /// Customer orders across all campaigns. Callers filter by `campaignId`.
  Stream<List<FundraisingOrder>> fundraisingOrders() => _stream(
      'fundraising_orders', FundraisingOrder.fromDoc,
      orderBy: 'createdAt', descending: true);

  /// Reusable vendors/suppliers that can be assigned to campaign products.
  Stream<List<Vendor>> fundraisingVendors() =>
      _stream('fundraising_vendors', Vendor.fromDoc, orderBy: 'title');

  // ---- Writes (used by admins) -----------------------------------------
  Future<void> upsert(String collection, ContentItem item) async {
    if (AppConfig.demoMode) {
      final list = _demo.putIfAbsent(collection, () => []);
      final idx = list.indexWhere((e) => e.id == item.id);
      if (idx >= 0) {
        list[idx] = item;
      } else {
        list.add(item);
      }
      _emit(collection);
      return;
    }
    final data = item.toMap();
    if (item.id.isEmpty || item.id.startsWith('new')) {
      await _db.collection(collection).add(data);
    } else {
      await _db.collection(collection).doc(item.id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> delete(String collection, String id) async {
    if (AppConfig.demoMode) {
      _demo[collection]?.removeWhere((e) => e.id == id);
      _emit(collection);
      return;
    }
    await _db.collection(collection).doc(id).delete();
  }

  /// Records a submitted funding request (available to members).
  /// Submits a funding request as two documents: the members-visible summary
  /// and a manager-only private detail (contact PII) at
  /// `funding_requests/{id}/private/detail`.
  Future<void> submitFundingRequest(
      FundingRequest req, FundingApplicationDetail detail) async {
    if (AppConfig.demoMode) {
      final list = _demo.putIfAbsent('funding_requests', () => []);
      list.add(req);
      _emit('funding_requests');
      return;
    }
    final ref = await _db.collection('funding_requests').add(req.toMap());
    if (!detail.isEmpty) {
      await ref.collection('private').doc('detail').set(detail.toMap());
    }
  }

  /// Manager-only read of a funding request's private applicant detail.
  Future<FundingApplicationDetail?> fundingApplicationDetail(String id) async {
    if (AppConfig.demoMode) return null;
    final snap = await _db
        .collection('funding_requests')
        .doc(id)
        .collection('private')
        .doc('detail')
        .get();
    if (!snap.exists) return null;
    return FundingApplicationDetail.fromMap(snap.data()!);
  }

  /// Uploads a meeting-minutes PDF to Firebase Storage and returns its public
  /// download URL. In demo mode returns a placeholder URL.
  Future<String> uploadMinutesPdf(
      Uint8List bytes, String filename, int stamp) async {
    final safe = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (AppConfig.demoMode) {
      return 'https://example.com/minutes/$safe';
    }
    final ref = FirebaseStorage.instance.ref('minutes/${stamp}_$safe');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/pdf'),
    );
    return task.ref.getDownloadURL();
  }

  /// Uploads an image (e.g. a photo attached to a funding request) under
  /// [folder] and returns its download URL. In demo mode returns a placeholder.
  Future<String> uploadImage(
      Uint8List bytes, String filename, String folder, int stamp,
      {String contentType = 'image/jpeg'}) async {
    final safe = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (AppConfig.demoMode) {
      return 'https://example.com/$folder/$safe';
    }
    final ref = FirebaseStorage.instance.ref('$folder/${stamp}_$safe');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return task.ref.getDownloadURL();
  }

  /// Writes the bundled sample content into every collection. Used by admins
  /// to populate a fresh database. Idempotent: documents keep their demo IDs so
  /// re-running overwrites rather than duplicating.
  Future<void> seedSampleData() async {
    for (final e in DemoData.events()) {
      await upsert('events', e);
    }
    for (final o in DemoData.volunteering()) {
      await upsert('volunteering', o);
    }
    for (final s in DemoData.sponsorships()) {
      await upsert('sponsorships', s);
    }
    for (final r in DemoData.fundingRequests()) {
      await upsert('funding_requests', r);
    }
    for (final f in DemoData.fundraisers()) {
      await upsert('fundraisers', f);
    }
    for (final m in DemoData.meetings()) {
      await upsert('meetings', m);
    }
    for (final q in DemoData.faqs()) {
      await upsert('faqs', q);
    }
    for (final c in DemoData.committees()) {
      await upsert('committees', c);
    }
    for (final m in DemoData.committeeMembers()) {
      await upsert('committee_members', m);
    }
    for (final t in DemoData.teams()) {
      await upsert('teams', t);
    }
    for (final m in DemoData.teamMembers()) {
      await upsert('team_members', m);
    }
    for (final h in DemoData.historyFacts()) {
      await upsert('history_facts', h);
    }
    for (final g in DemoData.gallery()) {
      await upsert('gallery', g);
    }
    for (final l in DemoData.legalDocuments()) {
      await upsert('legal_documents', l);
    }
    for (final c in DemoData.fundraisingCampaigns()) {
      await upsert('fundraising_campaigns', c);
    }
    for (final o in DemoData.fundraisingOrders()) {
      await upsert('fundraising_orders', o);
    }
    for (final v in DemoData.fundraisingVendors()) {
      await upsert('fundraising_vendors', v);
    }
  }

  // ---- User administration & audit (Web Admin) --------------------------
  final List<AppUser> _demoUsers = [
    const AppUser(
        uid: 'demo-admin',
        email: 'admin@example.com',
        displayName: 'Alex Admin',
        role: UserRole.webAdmin),
    const AppUser(
        uid: 'demo-contrib',
        email: 'casey@example.com',
        displayName: 'Casey Contributor',
        role: UserRole.contributor),
    const AppUser(
        uid: 'demo-member',
        email: 'morgan@example.com',
        displayName: 'Morgan Member',
        role: UserRole.member),
  ];
  final List<AuditEntry> _demoAudit = [];
  final _demoUsersCtl = StreamController<List<AppUser>>.broadcast();
  final _demoAuditCtl = StreamController<List<AuditEntry>>.broadcast();

  Stream<List<AppUser>> users() {
    if (AppConfig.demoMode) {
      Future.microtask(() => _demoUsersCtl.add(List.of(_demoUsers)));
      return _demoUsersCtl.stream;
    }
    return _db
        .collection('users')
        .snapshots()
        .map((s) => s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.displayName
              .toLowerCase()
              .compareTo(b.displayName.toLowerCase())));
  }

  Stream<List<AuditEntry>> auditLog() {
    if (AppConfig.demoMode) {
      Future.microtask(() => _demoAuditCtl.add(List.of(_demoAudit)));
      return _demoAuditCtl.stream;
    }
    return _db
        .collection('audit_log')
        .orderBy('at', descending: true)
        .limit(200)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AuditEntry.fromDoc(d.id, d.data())).toList());
  }

  /// Persists a user's role/grants (Web Admin only) and records audit entries.
  Future<void> saveUserAdmin(
    AppUser updated, {
    required AppUser actor,
    required List<String> actions, // human-readable change descriptions
  }) async {
    if (AppConfig.demoMode) {
      final idx = _demoUsers.indexWhere((u) => u.uid == updated.uid);
      if (idx >= 0) _demoUsers[idx] = updated;
      for (final a in actions) {
        _demoAudit.insert(
          0,
          AuditEntry(
            id: 'a${_demoAudit.length}',
            actorUid: actor.uid,
            actorName: actor.displayName,
            targetUid: updated.uid,
            targetName: updated.displayName,
            action: 'change',
            details: a,
            at: DateTime.now(),
          ),
        );
      }
      _demoUsersCtl.add(List.of(_demoUsers));
      _demoAuditCtl.add(List.of(_demoAudit));
      return;
    }
    await _db.collection('users').doc(updated.uid).set({
      'role': updated.role.name,
      'grants': {
        for (final e in updated.grants.entries)
          e.key: Timestamp.fromDate(e.value),
      },
    }, SetOptions(merge: true));
    for (final a in actions) {
      await _db.collection('audit_log').add(AuditEntry(
            id: 'new',
            actorUid: actor.uid,
            actorName: actor.displayName,
            targetUid: updated.uid,
            targetName: updated.displayName,
            action: 'change',
            details: a,
          ).toMap());
    }
  }

  // ---- Donations ledger -------------------------------------------------
  final List<Donation> _demoDonations = [
    Donation(
      id: 'd-demo1',
      donorName: 'Jamie Booster',
      donorEmail: 'jamie@example.com',
      amount: 100,
      designation: 'Athletics',
      status: DonationStatus.completed,
      paypalCaptureId: 'DEMOCAP1',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      completedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Donation(
      id: 'd-demo2',
      donorName: 'Riley Parent',
      donorEmail: 'riley@example.com',
      amount: 50,
      designation: 'Greatest Need',
      status: DonationStatus.completed,
      paypalCaptureId: 'DEMOCAP2',
      createdAt: DateTime.now().subtract(const Duration(days: 9)),
      completedAt: DateTime.now().subtract(const Duration(days: 9)),
    ),
  ];
  final _demoDonationsCtl = StreamController<List<Donation>>.broadcast();
  final Map<String, StreamController<Donation?>> _demoDonationDocCtls = {};

  void _emitDonations() {
    _demoDonationsCtl.add(List.of(_demoDonations));
  }

  /// Full donations ledger, newest first (for the Donations admin view).
  Stream<List<Donation>> donations() {
    if (AppConfig.demoMode) {
      Future.microtask(_emitDonations);
      return _demoDonationsCtl.stream;
    }
    return _db
        .collection('donations')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .map((s) => s.docs.map((d) => Donation.fromDoc(d.id, d.data())).toList());
  }

  /// Watches a single donation so the Donate page can react when a Cloud
  /// Function flips its status to completed.
  Stream<Donation?> donationDoc(String id) {
    if (AppConfig.demoMode) {
      final ctl = _demoDonationDocCtls.putIfAbsent(
          id, () => StreamController<Donation?>.broadcast());
      Future.microtask(() {
        final match = _demoDonations.where((d) => d.id == id);
        ctl.add(match.isEmpty ? null : match.first);
      });
      return ctl.stream;
    }
    return _db.collection('donations').doc(id).snapshots().map(
        (d) => d.exists ? Donation.fromDoc(d.id, d.data()!) : null);
  }

  /// Creates the pending donation record and returns its id. The client may
  /// only ever write a *pending* record (enforced by security rules); the
  /// completed status is set server-side once PayPal confirms payment.
  Future<String> createPendingDonation(Donation donation) async {
    if (AppConfig.demoMode) {
      final id = 'd-${DateTime.now().microsecondsSinceEpoch}';
      _demoDonations.insert(
        0,
        Donation(
          id: id,
          uid: donation.uid,
          donorName: donation.donorName,
          donorEmail: donation.donorEmail,
          amount: donation.amount,
          currency: donation.currency,
          frequency: donation.frequency,
          designation: donation.designation,
          status: DonationStatus.pending,
          createdAt: DateTime.now(),
        ),
      );
      _emitDonations();
      return id;
    }
    final ref = await _db.collection('donations').add(donation.toPendingMap());
    return ref.id;
  }

  /// Demo-only: simulates the Cloud Function + PayPal webhook confirming a
  /// donation, so the preview build can show the full success flow.
  Future<void> simulateDonationCompleted(String id) async {
    final idx = _demoDonations.indexWhere((d) => d.id == id);
    if (idx < 0) return;
    _demoDonations[idx] = _demoDonations[idx].copyWith(
      status: DonationStatus.completed,
      paypalCaptureId: 'DEMOCAP',
      completedAt: DateTime.now(),
    );
    _emitDonations();
    _demoDonationDocCtls[id]?.add(_demoDonations[idx]);
  }
}
