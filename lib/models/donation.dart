import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle of a donation. A record starts as [pending] (created by the app
/// before checkout) and is only moved to [completed] by a trusted Cloud
/// Function after PayPal confirms the payment — the client can never mark a
/// donation paid.
enum DonationStatus {
  pending,
  completed,
  failed,
  refunded;

  static DonationStatus fromString(String? v) => DonationStatus.values.firstWhere(
        (s) => s.name == v,
        orElse: () => DonationStatus.pending,
      );

  String get label {
    switch (this) {
      case DonationStatus.pending:
        return 'Pending';
      case DonationStatus.completed:
        return 'Completed';
      case DonationStatus.failed:
        return 'Failed';
      case DonationStatus.refunded:
        return 'Refunded';
    }
  }
}

/// A donation recorded in the `donations` collection. The app writes the
/// pending record and initiates PayPal; a Cloud Function (driven by PayPal
/// capture + webhook) is what fills in [paypalCaptureId] and flips [status] to
/// completed. Amounts/status are therefore authoritative only once confirmed.
class Donation {
  final String id;
  final String? uid; // Firebase Auth UID, if signed in
  final String donorName;
  final String donorEmail;
  final double amount;
  final String currency;
  final String frequency; // 'one-time'
  final String designation;
  final DonationStatus status;
  final String? paypalOrderId;
  final String? paypalCaptureId;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const Donation({
    required this.id,
    this.uid,
    required this.donorName,
    required this.donorEmail,
    required this.amount,
    this.currency = 'USD',
    this.frequency = 'one-time',
    required this.designation,
    this.status = DonationStatus.pending,
    this.paypalOrderId,
    this.paypalCaptureId,
    this.createdAt,
    this.completedAt,
  });

  factory Donation.fromDoc(String id, Map<String, dynamic> d) => Donation(
        id: id,
        uid: d['uid'] as String?,
        donorName: d['donorName'] as String? ?? '',
        donorEmail: d['donorEmail'] as String? ?? '',
        amount: (d['amount'] ?? 0).toDouble(),
        currency: d['currency'] as String? ?? 'USD',
        frequency: d['frequency'] as String? ?? 'one-time',
        designation: d['designation'] as String? ?? 'Greatest Need',
        status: DonationStatus.fromString(d['status'] as String?),
        paypalOrderId: d['paypalOrderId'] as String?,
        paypalCaptureId: d['paypalCaptureId'] as String?,
        createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
        completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
      );

  /// The fields the *client* is allowed to write when creating a pending
  /// donation. Server-controlled fields (status transitions, capture id,
  /// completedAt) are intentionally omitted here.
  Map<String, dynamic> toPendingMap() => {
        'uid': uid,
        'donorName': donorName,
        'donorEmail': donorEmail,
        'amount': amount,
        'currency': currency,
        'frequency': frequency,
        'designation': designation,
        'status': DonationStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
      };

  Donation copyWith({
    DonationStatus? status,
    String? paypalOrderId,
    String? paypalCaptureId,
    DateTime? completedAt,
  }) =>
      Donation(
        id: id,
        uid: uid,
        donorName: donorName,
        donorEmail: donorEmail,
        amount: amount,
        currency: currency,
        frequency: frequency,
        designation: designation,
        status: status ?? this.status,
        paypalOrderId: paypalOrderId ?? this.paypalOrderId,
        paypalCaptureId: paypalCaptureId ?? this.paypalCaptureId,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
      );
}
