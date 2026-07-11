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
/// The public/members-visible summary of a funding request. Contact PII (coach
/// & parent emails, parent name, application history) is intentionally NOT here
/// — it lives in a separate [FundingApplicationDetail] document readable only by
/// funding managers. See firestore.rules (`funding_requests/{id}/private`).
class FundingRequest implements ContentItem {
  @override
  final String id;
  @override
  final String title; // Sport team or club name
  final String description; // How the funds will be used
  final double amountRequested;
  final String requestedBy; // Coach/sponsor name (shown on the card)
  final String status; // pending / approved / declined / funded
  final DateTime? submittedAt;
  final String? imageUrl;

  // Non-sensitive summary fields.
  final String groupType; // 'sport' | 'club' | ''
  final int studentCount;
  final bool metWithLeadership; // met with AD (sports) / Asst. Principal (clubs)
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
    this.studentCount = 0,
    this.metWithLeadership = false,
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
        studentCount: (d['studentCount'] ?? 0) as int,
        metWithLeadership: d['metWithLeadership'] ?? false,
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
        'studentCount': studentCount,
        'metWithLeadership': metWithLeadership,
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
        studentCount: studentCount,
        metWithLeadership: metWithLeadership,
        fundraisingContributions: fundraisingContributions,
      );
}

/// The private half of a funding request — contact PII and internal application
/// context. Stored at `funding_requests/{id}/private/detail`, readable only by
/// funding managers (`manage_funding`). Kept out of the public summary doc so a
/// signed-in member (or the public) can never read applicants' emails.
class FundingApplicationDetail {
  final String coachEmail;
  final String parentName;
  final String parentEmail;
  final String previousRequests;
  final String boosterMembersInfo;

  const FundingApplicationDetail({
    this.coachEmail = '',
    this.parentName = '',
    this.parentEmail = '',
    this.previousRequests = '',
    this.boosterMembersInfo = '',
  });

  bool get isEmpty =>
      coachEmail.isEmpty &&
      parentName.isEmpty &&
      parentEmail.isEmpty &&
      previousRequests.isEmpty &&
      boosterMembersInfo.isEmpty;

  factory FundingApplicationDetail.fromMap(Map<String, dynamic> d) =>
      FundingApplicationDetail(
        coachEmail: d['coachEmail'] ?? '',
        parentName: d['parentName'] ?? '',
        parentEmail: d['parentEmail'] ?? '',
        previousRequests: d['previousRequests'] ?? '',
        boosterMembersInfo: d['boosterMembersInfo'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'coachEmail': coachEmail,
        'parentName': parentName,
        'parentEmail': parentEmail,
        'previousRequests': previousRequests,
        'boosterMembersInfo': boosterMembersInfo,
      };
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

  /// Original file metadata, captured at upload time (may be absent for images
  /// added before this was tracked).
  final String fileName;
  final int? width;
  final int? height;
  final int? sizeBytes;

  /// Whether the image is shown on the public Gallery page. Contributors can
  /// hide an image (e.g. a work-in-progress or a photo kept only for internal
  /// reuse) without deleting it. Defaults to true, so images created before
  /// this flag existed stay visible.
  final bool public;

  const GalleryImage({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.caption = '',
    this.tags = const [],
    this.uploadedAt,
    this.fileName = '',
    this.width,
    this.height,
    this.sizeBytes,
    this.public = true,
  });

  @override
  String get summary => caption;

  /// `"1600 × 1200"` when known, else null.
  String? get dimensionsLabel =>
      (width != null && height != null) ? '$width × $height' : null;

  /// Human-readable file size (e.g. `2.3 MB`, `840 KB`) when known, else null.
  String? get sizeLabel {
    final b = sizeBytes;
    if (b == null || b <= 0) return null;
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }

  factory GalleryImage.fromDoc(String id, Map<String, dynamic> d) =>
      GalleryImage(
        id: id,
        title: d['title'] ?? '',
        imageUrl: d['imageUrl'] ?? '',
        caption: d['caption'] ?? '',
        tags: List<String>.from(d['tags'] ?? const []),
        uploadedAt: _ts(d['uploadedAt']),
        fileName: d['fileName'] ?? '',
        width: (d['width'] as num?)?.toInt(),
        height: (d['height'] as num?)?.toInt(),
        sizeBytes: (d['sizeBytes'] as num?)?.toInt(),
        public: d['public'] ?? true,
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'imageUrl': imageUrl,
        'caption': caption,
        'tags': tags,
        'fileName': fileName,
        'width': width,
        'height': height,
        'sizeBytes': sizeBytes,
        'public': public,
        'uploadedAt':
            uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : FieldValue.serverTimestamp(),
      };

  GalleryImage copyWith({
    String? title,
    String? imageUrl,
    String? caption,
    List<String>? tags,
    DateTime? uploadedAt,
    String? fileName,
    int? width,
    int? height,
    int? sizeBytes,
    bool? public,
  }) =>
      GalleryImage(
        id: id,
        title: title ?? this.title,
        imageUrl: imageUrl ?? this.imageUrl,
        caption: caption ?? this.caption,
        tags: tags ?? this.tags,
        uploadedAt: uploadedAt ?? this.uploadedAt,
        fileName: fileName ?? this.fileName,
        width: width ?? this.width,
        height: height ?? this.height,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        public: public ?? this.public,
      );
}

// ===========================================================================
// Fundraising campaigns & orders
//
// A richer, logistics-focused model than [FundraisingEvent] (which is just a
// donation progress bar). A campaign has a catalogue of products, moves through
// workflow stages, and collects customer orders that are tracked from payment
// through delivery.
// ===========================================================================

/// The kind of campaign. Used for light labelling only.
enum CampaignType { product, raffle, generic }

extension CampaignTypeX on CampaignType {
  String get label => switch (this) {
        CampaignType.product => 'Product sale',
        CampaignType.raffle => 'Raffle',
        CampaignType.generic => 'General',
      };
  static CampaignType parse(String? v) => CampaignType.values.firstWhere(
      (e) => e.name == v,
      orElse: () => CampaignType.product);
}

/// Where a campaign is in its lifecycle. Ordered planning → closed.
enum CampaignStage { planning, selling, ordering, delivery, closed }

extension CampaignStageX on CampaignStage {
  String get label => switch (this) {
        CampaignStage.planning => 'Planning',
        CampaignStage.selling => 'Selling',
        CampaignStage.ordering => 'Ordering',
        CampaignStage.delivery => 'Delivery',
        CampaignStage.closed => 'Closed',
      };
  static CampaignStage parse(String? v) => CampaignStage.values.firstWhere(
      (e) => e.name == v,
      orElse: () => CampaignStage.planning);
}

/// A sellable item within a campaign, e.g. "3 cu ft Hardwood Mulch" or a
/// t-shirt with size [options].
class CampaignProduct {
  final String id;
  final String name;
  final double price;

  /// Optional variant choices a buyer picks from (sizes, colours). Empty when
  /// the product has no variants.
  final List<String> options;

  /// Optional target number of units to sell (for progress display).
  final int? goalQty;

  /// Ids of the [Vendor]s that supply this item (may be more than one).
  final List<String> vendorIds;

  const CampaignProduct({
    required this.id,
    required this.name,
    this.price = 0,
    this.options = const [],
    this.goalQty,
    this.vendorIds = const [],
  });

  factory CampaignProduct.fromMap(Map<String, dynamic> d) => CampaignProduct(
        id: (d['id'] ?? '').toString(),
        name: d['name'] ?? '',
        price: (d['price'] ?? 0).toDouble(),
        options: List<String>.from(d['options'] ?? const []),
        goalQty: (d['goalQty'] as num?)?.toInt(),
        vendorIds: List<String>.from(d['vendorIds'] ?? const []),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'options': options,
        'goalQty': goalQty,
        'vendorIds': vendorIds,
      };

  CampaignProduct copyWith({
    String? name,
    double? price,
    List<String>? options,
    int? goalQty,
    List<String>? vendorIds,
  }) =>
      CampaignProduct(
        id: id,
        name: name ?? this.name,
        price: price ?? this.price,
        options: options ?? this.options,
        goalQty: goalQty ?? this.goalQty,
        vendorIds: vendorIds ?? this.vendorIds,
      );
}

/// A supplier/vendor that can be assigned to one or more campaign products
/// (e.g. a mulch supplier or a screen printer). Reusable across campaigns.
class Vendor implements ContentItem {
  @override
  final String id;
  @override
  final String title; // vendor / company name
  final String contact; // phone / email / point of contact
  final String notes;
  final DateTime? createdAt;

  const Vendor({
    required this.id,
    required this.title,
    this.contact = '',
    this.notes = '',
    this.createdAt,
  });

  @override
  String get summary => contact;

  factory Vendor.fromDoc(String id, Map<String, dynamic> d) => Vendor(
        id: id,
        title: d['title'] ?? '',
        contact: d['contact'] ?? '',
        notes: d['notes'] ?? '',
        createdAt: _ts(d['createdAt']),
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'contact': contact,
        'notes': notes,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  Vendor copyWith({String? title, String? contact, String? notes}) => Vendor(
        id: id,
        title: title ?? this.title,
        contact: contact ?? this.contact,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}

class FundraisingCampaign implements ContentItem {
  @override
  final String id;
  @override
  final String title;
  final String description;
  final CampaignType type;
  final CampaignStage stage;
  final double goalAmount;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final List<CampaignProduct> products;

  /// Supplier for the goods (mulch supplier, screen printer, …).
  final String vendorName;
  final String vendorContact;
  final String notes;
  final DateTime? createdAt;

  const FundraisingCampaign({
    required this.id,
    required this.title,
    this.description = '',
    this.type = CampaignType.product,
    this.stage = CampaignStage.planning,
    this.goalAmount = 0,
    this.startsAt,
    this.endsAt,
    this.products = const [],
    this.vendorName = '',
    this.vendorContact = '',
    this.notes = '',
    this.createdAt,
  });

  @override
  String get summary => description;

  factory FundraisingCampaign.fromDoc(String id, Map<String, dynamic> d) =>
      FundraisingCampaign(
        id: id,
        title: d['title'] ?? '',
        description: d['description'] ?? '',
        type: CampaignTypeX.parse(d['type']),
        stage: CampaignStageX.parse(d['stage']),
        goalAmount: (d['goalAmount'] ?? 0).toDouble(),
        startsAt: _ts(d['startsAt']),
        endsAt: _ts(d['endsAt']),
        products: [
          for (final p in (d['products'] as List? ?? const []))
            CampaignProduct.fromMap(Map<String, dynamic>.from(p as Map)),
        ],
        vendorName: d['vendorName'] ?? '',
        vendorContact: d['vendorContact'] ?? '',
        notes: d['notes'] ?? '',
        createdAt: _ts(d['createdAt']),
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'type': type.name,
        'stage': stage.name,
        'goalAmount': goalAmount,
        'startsAt': startsAt != null ? Timestamp.fromDate(startsAt!) : null,
        'endsAt': endsAt != null ? Timestamp.fromDate(endsAt!) : null,
        'products': [for (final p in products) p.toMap()],
        'vendorName': vendorName,
        'vendorContact': vendorContact,
        'notes': notes,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  FundraisingCampaign copyWith({
    String? title,
    String? description,
    CampaignType? type,
    CampaignStage? stage,
    double? goalAmount,
    DateTime? startsAt,
    DateTime? endsAt,
    List<CampaignProduct>? products,
    String? vendorName,
    String? vendorContact,
    String? notes,
  }) =>
      FundraisingCampaign(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        type: type ?? this.type,
        stage: stage ?? this.stage,
        goalAmount: goalAmount ?? this.goalAmount,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt ?? this.endsAt,
        products: products ?? this.products,
        vendorName: vendorName ?? this.vendorName,
        vendorContact: vendorContact ?? this.vendorContact,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}

/// A single line on an order — a product (and chosen variant) with a quantity.
class OrderItem {
  final String productName;
  final String option; // '' when the product has no variants
  final int quantity;
  final double unitPrice;

  const OrderItem({
    required this.productName,
    this.option = '',
    this.quantity = 1,
    this.unitPrice = 0,
  });

  double get lineTotal => quantity * unitPrice;

  String get label =>
      option.isEmpty ? productName : '$productName ($option)';

  factory OrderItem.fromMap(Map<String, dynamic> d) => OrderItem(
        productName: d['productName'] ?? '',
        option: d['option'] ?? '',
        quantity: (d['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (d['unitPrice'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'productName': productName,
        'option': option,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  OrderItem copyWith(
          {String? productName, String? option, int? quantity, double? unitPrice}) =>
      OrderItem(
        productName: productName ?? this.productName,
        option: option ?? this.option,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
      );
}

enum PaymentStatus { unpaid, paid, refunded }

extension PaymentStatusX on PaymentStatus {
  String get label => switch (this) {
        PaymentStatus.unpaid => 'Unpaid',
        PaymentStatus.paid => 'Paid',
        PaymentStatus.refunded => 'Refunded',
      };
  static PaymentStatus parse(String? v) => PaymentStatus.values.firstWhere(
      (e) => e.name == v,
      orElse: () => PaymentStatus.unpaid);
}

enum FulfillmentStatus { pending, packed, delivered, canceled }

extension FulfillmentStatusX on FulfillmentStatus {
  String get label => switch (this) {
        FulfillmentStatus.pending => 'Pending',
        FulfillmentStatus.packed => 'Packed',
        FulfillmentStatus.delivered => 'Delivered',
        FulfillmentStatus.canceled => 'Canceled',
      };
  static FulfillmentStatus parse(String? v) =>
      FulfillmentStatus.values.firstWhere((e) => e.name == v,
          orElse: () => FulfillmentStatus.pending);
}

/// A customer order placed against a campaign, tracked from payment through
/// delivery.
class FundraisingOrder implements ContentItem {
  @override
  final String id;
  final String campaignId;

  /// Buyer name — also serves as the [title] for generic content helpers.
  final String customerName;
  final String customerContact;
  final String deliveryAddress;
  final List<OrderItem> items;
  final PaymentStatus paymentStatus;
  final String paymentMethod; // e.g. Cash, Check #123, Online
  final FulfillmentStatus fulfillmentStatus;

  /// Name of the volunteer responsible for packing/delivering this order.
  final String assignedTo;
  final String notes;
  final DateTime? createdAt;

  const FundraisingOrder({
    required this.id,
    required this.campaignId,
    required this.customerName,
    this.customerContact = '',
    this.deliveryAddress = '',
    this.items = const [],
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentMethod = '',
    this.fulfillmentStatus = FulfillmentStatus.pending,
    this.assignedTo = '',
    this.notes = '',
    this.createdAt,
  });

  @override
  String get title => customerName;

  @override
  String get summary => items.map((i) => '${i.quantity}× ${i.label}').join(', ');

  double get total => items.fold(0.0, (s, i) => s + i.lineTotal);
  int get unitCount => items.fold(0, (s, i) => s + i.quantity);

  factory FundraisingOrder.fromDoc(String id, Map<String, dynamic> d) =>
      FundraisingOrder(
        id: id,
        campaignId: d['campaignId'] ?? '',
        customerName: d['customerName'] ?? '',
        customerContact: d['customerContact'] ?? '',
        deliveryAddress: d['deliveryAddress'] ?? '',
        items: [
          for (final i in (d['items'] as List? ?? const []))
            OrderItem.fromMap(Map<String, dynamic>.from(i as Map)),
        ],
        paymentStatus: PaymentStatusX.parse(d['paymentStatus']),
        paymentMethod: d['paymentMethod'] ?? '',
        fulfillmentStatus: FulfillmentStatusX.parse(d['fulfillmentStatus']),
        assignedTo: d['assignedTo'] ?? '',
        notes: d['notes'] ?? '',
        createdAt: _ts(d['createdAt']),
      );

  @override
  Map<String, dynamic> toMap() => {
        'campaignId': campaignId,
        'customerName': customerName,
        'customerContact': customerContact,
        'deliveryAddress': deliveryAddress,
        'items': [for (final i in items) i.toMap()],
        'paymentStatus': paymentStatus.name,
        'paymentMethod': paymentMethod,
        'fulfillmentStatus': fulfillmentStatus.name,
        'assignedTo': assignedTo,
        'notes': notes,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  FundraisingOrder copyWith({
    String? customerName,
    String? customerContact,
    String? deliveryAddress,
    List<OrderItem>? items,
    PaymentStatus? paymentStatus,
    String? paymentMethod,
    FulfillmentStatus? fulfillmentStatus,
    String? assignedTo,
    String? notes,
  }) =>
      FundraisingOrder(
        id: id,
        campaignId: campaignId,
        customerName: customerName ?? this.customerName,
        customerContact: customerContact ?? this.customerContact,
        deliveryAddress: deliveryAddress ?? this.deliveryAddress,
        items: items ?? this.items,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        fulfillmentStatus: fulfillmentStatus ?? this.fulfillmentStatus,
        assignedTo: assignedTo ?? this.assignedTo,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}

// ===========================================================================
// Committees
//
// Standing volunteer committees (Concessions, School Store, Mulch Sale, …).
// Each lists the roles on its team plus optional detail sections and a contact.
// ===========================================================================

/// A labelled sub-block within a committee (e.g. "Outdoor Concessions" →
/// "2 adults + 6 students (required)").
class CommitteeSection {
  final String heading;
  final String body;
  const CommitteeSection({required this.heading, this.body = ''});

  factory CommitteeSection.fromMap(Map<String, dynamic> d) => CommitteeSection(
        heading: d['heading'] ?? '',
        body: d['body'] ?? '',
      );

  Map<String, dynamic> toMap() => {'heading': heading, 'body': body};
}

/// Whether a group is a working committee or an organisation leadership group
/// (e.g. Executive Committee, Class Chairs).
enum CommitteeCategory { committee, leadership }

extension CommitteeCategoryX on CommitteeCategory {
  String get label => switch (this) {
        CommitteeCategory.committee => 'Committee',
        CommitteeCategory.leadership => 'Leadership',
      };
  static CommitteeCategory parse(String? v) =>
      CommitteeCategory.values.firstWhere((e) => e.name == v,
          orElse: () => CommitteeCategory.committee);
}

/// A named position within a committee/leadership group and who holds it — e.g.
/// "President → Mary Bittle Koenick" or "Commissioner (Sports) → OPEN".
class CommitteePosition {
  final String title;
  final String holder; // person's name; empty or "OPEN" means unfilled
  const CommitteePosition({required this.title, this.holder = ''});

  /// True when the position has no assigned person.
  bool get isOpen =>
      holder.trim().isEmpty || holder.trim().toUpperCase() == 'OPEN';

  factory CommitteePosition.fromMap(Map<String, dynamic> d) =>
      CommitteePosition(
        title: d['title'] ?? '',
        holder: d['holder'] ?? '',
      );

  Map<String, dynamic> toMap() => {'title': title, 'holder': holder};
}

class Committee implements ContentItem {
  @override
  final String id;
  @override
  final String title;

  /// When/where it runs (e.g. "Held annually in mid-to-late March").
  final String schedule;

  /// Intro paragraph.
  final String description;

  /// The roles that make up the committee's team.
  final List<String> teamRoles;

  /// Optional detail sub-blocks.
  final List<CommitteeSection> sections;

  /// An emphasised call-out (e.g. "ADULT DRIVERS REQUIRED…").
  final String highlight;

  /// Contact email for questions.
  final String contactEmail;

  /// Sort order within the Committees page.
  final int order;

  /// Working committee vs. an organisation leadership group.
  final CommitteeCategory category;

  /// Named positions and who holds them (Chair, President, class chair, …).
  final List<CommitteePosition> positions;

  const Committee({
    required this.id,
    required this.title,
    this.schedule = '',
    this.description = '',
    this.teamRoles = const [],
    this.sections = const [],
    this.highlight = '',
    this.contactEmail = '',
    this.order = 0,
    this.category = CommitteeCategory.committee,
    this.positions = const [],
  });

  @override
  String get summary => description.isNotEmpty ? description : schedule;

  bool get isLeadership => category == CommitteeCategory.leadership;

  /// Positions still needing someone.
  List<CommitteePosition> get openPositions =>
      positions.where((p) => p.isOpen).toList();

  factory Committee.fromDoc(String id, Map<String, dynamic> d) => Committee(
        id: id,
        title: d['title'] ?? '',
        schedule: d['schedule'] ?? '',
        description: d['description'] ?? '',
        teamRoles: List<String>.from(d['teamRoles'] ?? const []),
        sections: [
          for (final s in (d['sections'] as List? ?? const []))
            CommitteeSection.fromMap(Map<String, dynamic>.from(s as Map)),
        ],
        highlight: d['highlight'] ?? '',
        contactEmail: d['contactEmail'] ?? '',
        order: (d['order'] as num?)?.toInt() ?? 0,
        category: CommitteeCategoryX.parse(d['category']),
        positions: [
          for (final p in (d['positions'] as List? ?? const []))
            CommitteePosition.fromMap(Map<String, dynamic>.from(p as Map)),
        ],
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'schedule': schedule,
        'description': description,
        'teamRoles': teamRoles,
        'sections': [for (final s in sections) s.toMap()],
        'highlight': highlight,
        'contactEmail': contactEmail,
        'order': order,
        'category': category.name,
        'positions': [for (final p in positions) p.toMap()],
      };
}
