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
  final String? imageUrl;

  const SchoolEvent({
    required this.id,
    required this.title,
    required this.description,
    this.startsAt,
    this.endsAt,
    this.location = '',
    this.imageUrl,
  });

  @override
  String get summary => description;

  factory SchoolEvent.fromDoc(String id, Map<String, dynamic> d) => SchoolEvent(
        id: id,
        title: d['title'] ?? '',
        description: d['description'] ?? '',
        startsAt: _ts(d['startsAt']),
        endsAt: _ts(d['endsAt']),
        location: d['location'] ?? '',
        imageUrl: d['imageUrl'],
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'startsAt': startsAt != null ? Timestamp.fromDate(startsAt!) : null,
        'endsAt': endsAt != null ? Timestamp.fromDate(endsAt!) : null,
        'location': location,
        'imageUrl': imageUrl,
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
