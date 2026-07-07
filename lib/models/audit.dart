import 'package:cloud_firestore/cloud_firestore.dart';

/// An immutable audit record written whenever a Web Admin changes a user's
/// role or delegated permissions.
class AuditEntry {
  final String id;
  final String actorUid;
  final String actorName;
  final String targetUid;
  final String targetName;
  final String action; // role_change | grant | revoke
  final String details;
  final DateTime? at;

  const AuditEntry({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.targetUid,
    required this.targetName,
    required this.action,
    required this.details,
    this.at,
  });

  factory AuditEntry.fromDoc(String id, Map<String, dynamic> d) => AuditEntry(
        id: id,
        actorUid: d['actorUid'] ?? '',
        actorName: d['actorName'] ?? '',
        targetUid: d['targetUid'] ?? '',
        targetName: d['targetName'] ?? '',
        action: d['action'] ?? '',
        details: d['details'] ?? '',
        at: (d['at'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'actorUid': actorUid,
        'actorName': actorName,
        'targetUid': targetUid,
        'targetName': targetName,
        'action': action,
        'details': details,
        'at': at != null ? Timestamp.fromDate(at!) : FieldValue.serverTimestamp(),
      };
}
