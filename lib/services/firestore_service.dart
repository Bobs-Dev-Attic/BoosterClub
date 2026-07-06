import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../data/demo_data.dart';
import '../models/content_models.dart';

/// Abstracts reads/writes for all content collections. Backed by Cloud
/// Firestore in production, or an in-memory store when [AppConfig.demoMode].
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
      return _controllerFor(collection).stream.map(
            (items) => items.cast<T>(),
          );
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
  Future<void> submitFundingRequest(FundingRequest req) =>
      upsert('funding_requests', req);

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
  }
}
