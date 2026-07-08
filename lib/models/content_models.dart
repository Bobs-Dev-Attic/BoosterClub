import 'package:cloud_firestore/cloud_firestore.dart';

/// Base interface all content documents implement so generic list / card
/// widgets can render them uniformly.
abstract class ContentItem {
  String get id;
  String get title;
  String get summary;
  Map<String, dynamic> toMap();
}

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

/// A school event supporters can browse and RSVP to.
class SchoolEvent implements ContentItem {
  @override
  final String id;
  @override
  final String title;
  final String description;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String location;

  /// Optional map coordinates for [location]. When both are set the event
  /// links out to a map / directions.
  final double? latitude;
  final double? longitude;

  /// The structured address parts entered via the address-lookup dialog. Saved
  /// so they can be re-edited later; [location] holds the display string.
  final String street;
  final String city;
  final String state;
  final String zip;

  /// When true the event has a date but no specific time-of-day (the Time
  /// field was left blank), so times are hidden throughout the UI.
  final bool allDay;

  final String? imageUrl;
  final String category; // see kEventCategories

  const SchoolEvent({
    required this.id,
    required this.title,
    required this.description,
    this.startsAt,
    this.endsAt,
    this.location = '',
    this.latitude,
    this.longitude,
    this.street = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.allDay = false,
    this.imageUrl,
    this.category = 'General',
  });

  @override
  String get summary => description;

  /// Whether the event carries usable map coordinates.
  bool get hasGeo => latitude != null && longitude != null;

  factory SchoolEvent.fromDoc(String id, Map<String, dynamic> d) => SchoolEvent(
        id: id,
        title: d['title'] ?? '',
        description: d['description'] ?? '',
        startsAt: _ts(d['startsAt']),
        endsAt: _ts(d['endsAt']),
        location: d['location'] ?? '',
        latitude: (d['latitude'] as num?)?.toDouble(),
        longitude: (d['longitude'] as num?)?.toDouble(),
        street: d['street'] ?? '',
        city: d['city'] ?? '',
        state: d['state'] ?? '',
        zip: d['zip'] ?? '',
        allDay: d['allDay'] as bool? ?? false,
        imageUrl: d['imageUrl'],
        category: d['category'] ?? 'General',
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'startsAt': startsAt != null ? Timestamp.fromDate(startsAt!) : null,
        'endsAt': endsAt != null ? Timestamp.fromDate(endsAt!) : null,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'street': street,
        'city': city,
        'state': state,
        'zip': zip,
        'allDay': allDay,
        'imageUrl': imageUrl,
        'category': category,
      };
}

/// A volunteering opportunity members can sign up for.
class VolunteerOpportunity implements ContentItem {
  @override
  final String id;
  @override
  final String title;
  final String description;
  final DateTime? date;
  final int spotsNeeded;
  final int spotsFilled;

  const VolunteerOpportunity({
    required this.id,
    required this.title,
    required this.description,
    this.date,
    this.spotsNeeded = 0,
    this.spotsFilled = 0,
  });

  int get spotsRemaining =>
      (spotsNeeded - spotsFilled).clamp(0, spotsNeeded);

  @override
  String get summary => description;

  factory VolunteerOpportunity.fromDoc(String id, Map<String, dynamic> d) =>
      VolunteerOpportunity(
        id: id,
        title: d['title'] ?? '',
        description: d['description'] ?? '',
        date: _ts(d['date']),
        spotsNeeded: (d['spotsNeeded'] ?? 0) as int,
        spotsFilled: (d['spotsFilled'] ?? 0) as int,
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'date': date != null ? Timestamp.fromDate(date!) : null,
        'spotsNeeded': spotsNeeded,
        'spotsFilled': spotsFilled,
      };
}

/// A corporate sponsorship tier / opportunity.
class Sponsorship implements ContentItem {
  @override
  final String id;
  @override
  final String title;
  final String description;
  final double amount;
  final String tier; // Bronze / Silver / Gold / Platinum
  final List<String> benefits;

  const Sponsorship({
    required this.id,
    required this.title,
    required this.description,
    this.amount = 0,
    this.tier = '',
    this.benefits = const [],
  });

  @override
  String get summary => description;

  factory Sponsorship.fromDoc(String id, Map<String, dynamic> d) => Sponsorship(
        id: id,
        title: d['title'] ?? '',
        description: d['description'] ?? '',
        amount: (d['amount'] ?? 0).toDouble(),
        tier: d['tier'] ?? '',
        benefits: List<String>.from(d['benefits'] ?? const []),
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'amount': amount,
        'tier': tier,
        'benefits': benefits,
      };
}

/// A funding request submitted by a team / club seeking Booster Club support.
class FundingRequest implements ContentItem {
  @override
  final String id;
  @override
  final String title; // Sport team or club name
  final String description; // How the funds will be used
  final double amountRequested;
  final String requestedBy; // Coach/sponsor name (kept for card display)
  final String status; // pending / approved / declined / funded
  final DateTime? submittedAt;
  final String? imageUrl;

  // Expanded application fields.
  final String groupType; // 'sport' | 'club' | ''
  final String coachName;
  final String coachEmail;
  final String parentName;
  final String parentEmail;
  final int studentCount;
  final bool metWithLeadership; // met with AD (sports) / Asst. Principal (clubs)
  final String previousRequests;
  final String boosterMembersInfo;
  final List<String> fundraisingContributions;

  const FundingRequest({
    required this.id,
    required this.title,
    required this.description,
    this.amountRequested = 0,
    this.requestedBy = '',
    this.status = 'pending',
    this.submittedAt,
    this.imageUrl,
    this.groupType = '',
    this.coachName = '',
    this.coachEmail = '',
    this.parentName = '',
    this.parentEmail = '',
    this.studentCount = 0,
    this.metWithLeadership = false,
    this.previousRequests = '',
    this.boosterMembersInfo = '',
    this.fundraisingContributions = const [],
  });

  @override
  String get summary => description;

  factory FundingRequest.fromDoc(String id, Map<String, dynamic> d) =>
      FundingRequest(
        id: id,
        title: d['title'] ?? '',
        description: d['description'] ?? '',
        amountRequested: (d['amountRequested'] ?? 0).toDouble(),
        requestedBy: d['requestedBy'] ?? '',
        status: d['status'] ?? 'pending',
        submittedAt: _ts(d['submittedAt']),
        imageUrl: d['imageUrl'],
        groupType: d['groupType'] ?? '',
        coachName: d['coachName'] ?? '',
        coachEmail: d['coachEmail'] ?? '',
        parentName: d['parentName'] ?? '',
        parentEmail: d['parentEmail'] ?? '',
        studentCount: (d['studentCount'] ?? 0) as int,
        metWithLeadership: d['metWithLeadership'] ?? false,
        previousRequests: d['previousRequests'] ?? '',
        boosterMembersInfo: d['boosterMembersInfo'] ?? '',
        fundraisingContributions:
            List<String>.from(d['fundraisingContributions'] ?? const []),
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'amountRequested': amountRequested,
        'requestedBy': requestedBy,
        'status': status,
        'imageUrl': imageUrl,
        'groupType': groupType,
        'coachName': coachName,
        'coachEmail': coachEmail,
        'parentName': parentName,
        'parentEmail': parentEmail,
        'studentCount': studentCount,
        'metWithLeadership': metWithLeadership,
        'previousRequests': previousRequests,
        'boosterMembersInfo': boosterMembersInfo,
        'fundraisingContributions': fundraisingContributions,
        'submittedAt':
            submittedAt != null ? Timestamp.fromDate(submittedAt!) : FieldValue.serverTimestamp(),
      };

  FundingRequest copyWith({
    String? title,
    String? description,
    double? amountRequested,
    String? requestedBy,
    String? status,
  }) =>
      FundingRequest(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        amountRequested: amountRequested ?? this.amountRequested,
        requestedBy: requestedBy ?? this.requestedBy,
        status: status ?? this.status,
        submittedAt: submittedAt,
        imageUrl: imageUrl,
        groupType: groupType,
        coachName: coachName,
        coachEmail: coachEmail,
        parentName: parentName,
        parentEmail: parentEmail,
        studentCount: studentCount,
        metWithLeadership: metWithLeadership,
        previousRequests: previousRequests,
        boosterMembersInfo: boosterMembersInfo,
        fundraisingContributions: fundraisingContributions,
      );
}

/// A fundraising event / campaign with a goal and running total.
class FundraisingEvent implements ContentItem {
  @override
  final String id;
  @override
  final String title;
  final String description;
  final double goalAmount;
  final double raisedAmount;
  final DateTime? endsAt;

  const FundraisingEvent({
    required this.id,
    required this.title,
    required this.description,
    this.goalAmount = 0,
    this.raisedAmount = 0,
    this.endsAt,
  });

  double get progress =>
      goalAmount <= 0 ? 0 : (raisedAmount / goalAmount).clamp(0, 1);

  @override
  String get summary => description;

  factory FundraisingEvent.fromDoc(String id, Map<String, dynamic> d) =>
      FundraisingEvent(
        id: id,
        title: d['title'] ?? '',
        description: d['description'] ?? '',
        goalAmount: (d['goalAmount'] ?? 0).toDouble(),
        raisedAmount: (d['raisedAmount'] ?? 0).toDouble(),
        endsAt: _ts(d['endsAt']),
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'goalAmount': goalAmount,
        'raisedAmount': raisedAmount,
        'endsAt': endsAt != null ? Timestamp.fromDate(endsAt!) : null,
      };
}

/// A Booster Club meeting with optional minutes attachment.
class Meeting implements ContentItem {
  @override
  final String id;
  @override
  final String title;
  final String description;
  final DateTime? meetingDate;
  final String? minutesUrl;
  final String location;

  const Meeting({
    required this.id,
    required this.title,
    required this.description,
    this.meetingDate,
    this.minutesUrl,
    this.location = '',
  });

  @override
  String get summary => description;

  factory Meeting.fromDoc(String id, Map<String, dynamic> d) => Meeting(
        id: id,
        title: d['title'] ?? '',
        description: d['description'] ?? '',
        meetingDate: _ts(d['meetingDate']),
        minutesUrl: d['minutesUrl'],
        location: d['location'] ?? '',
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'meetingDate':
            meetingDate != null ? Timestamp.fromDate(meetingDate!) : null,
        'minutesUrl': minutesUrl,
        'location': location,
      };
}

/// A frequently-asked question.
class FaqItem implements ContentItem {
  @override
  final String id;
  final String question;
  final String answer;
  final int order;

  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    this.order = 0,
  });

  @override
  String get title => question;
  @override
  String get summary => answer;

  factory FaqItem.fromDoc(String id, Map<String, dynamic> d) => FaqItem(
        id: id,
        question: d['question'] ?? '',
        answer: d['answer'] ?? '',
        order: (d['order'] ?? 0) as int,
      );

  @override
  Map<String, dynamic> toMap() => {
        'question': question,
        'answer': answer,
        'order': order,
      };
}

/// A "This Day in Wildcat History" fact, keyed by calendar month/day so the
/// home page can surface today's item. Managed by contributors.
class HistoryFact implements ContentItem {
  @override
  final String id;
  @override
  final String title;
  final String fact;
  final int month; // 1-12
  final int day; // 1-31
  final int? year;

  /// Optional link to the source or more information.
  final String? sourceUrl;

  const HistoryFact({
    required this.id,
    required this.title,
    required this.fact,
    this.month = 1,
    this.day = 1,
    this.year,
    this.sourceUrl,
  });

  @override
  String get summary => fact;

  factory HistoryFact.fromDoc(String id, Map<String, dynamic> d) => HistoryFact(
        id: id,
        title: d['title'] ?? '',
        fact: d['fact'] ?? '',
        month: (d['month'] ?? 1) as int,
        day: (d['day'] ?? 1) as int,
        year: d['year'] as int?,
        sourceUrl: (d['sourceUrl'] as String?)?.trim().isNotEmpty == true
            ? (d['sourceUrl'] as String).trim()
            : null,
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'fact': fact,
        'month': month,
        'day': day,
        'year': year,
        'sourceUrl': sourceUrl,
      };
}

/// A site legal/policy document (e.g. Terms of Use, Privacy Policy), managed by
/// a Policy Admin. Keyed by a stable id such as `terms` or `privacy`. The body
/// is plain text with a light markup convention: lines starting with `# ` or
/// `## ` are headings and lines starting with `- ` are bullets.
class LegalDocument implements ContentItem {
  @override
  final String id;
  @override
  final String title;
  final String body;
  final DateTime? updatedAt;

  const LegalDocument({
    required this.id,
    required this.title,
    required this.body,
    this.updatedAt,
  });

  @override
  String get summary => body;

  factory LegalDocument.fromDoc(String id, Map<String, dynamic> d) =>
      LegalDocument(
        id: id,
        title: d['title'] ?? '',
        body: d['body'] ?? '',
        updatedAt: _ts(d['updatedAt']),
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

/// A reusable image in the shared media library. Contributors upload and manage
/// these; other parts of the site can reference them by [imageUrl].
class GalleryImage implements ContentItem {
  @override
  final String id;
  @override
  final String title;
  final String imageUrl;
  final String caption;

  /// Free-form tags to help find and group images (e.g. `athletics`, `2026`).
  final List<String> tags;
  final DateTime? uploadedAt;

  const GalleryImage({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.caption = '',
    this.tags = const [],
    this.uploadedAt,
  });

  @override
  String get summary => caption;

  factory GalleryImage.fromDoc(String id, Map<String, dynamic> d) =>
      GalleryImage(
        id: id,
        title: d['title'] ?? '',
        imageUrl: d['imageUrl'] ?? '',
        caption: d['caption'] ?? '',
        tags: List<String>.from(d['tags'] ?? const []),
        uploadedAt: _ts(d['uploadedAt']),
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'imageUrl': imageUrl,
        'caption': caption,
        'tags': tags,
        'uploadedAt':
            uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : FieldValue.serverTimestamp(),
      };
}
