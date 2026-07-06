import 'package:cloud_firestore/cloud_firestore.dart';

/// Roles supported by the Booster Club app, ordered from least to most
/// privileged. Higher-index roles inherit the abilities of lower ones.
enum UserRole {
  guest,
  supporter,
  member,
  sponsor,
  administrator,
  webAdmin;

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.supporter,
    );
  }

  String get label {
    switch (this) {
      case UserRole.guest:
        return 'Guest';
      case UserRole.supporter:
        return 'Supporter';
      case UserRole.member:
        return 'Member';
      case UserRole.sponsor:
        return 'Sponsor';
      case UserRole.administrator:
        return 'Administrator';
      case UserRole.webAdmin:
        return 'Web Admin';
    }
  }

  /// Can create / edit / delete app content.
  bool get canManageContent =>
      index >= UserRole.administrator.index;

  /// Can manage other users, roles and app configuration.
  bool get canAdministerSite => this == UserRole.webAdmin;
}

/// A user profile stored in the `users` collection, keyed by the Firebase Auth
/// UID. This augments the Firebase Auth account with role and profile data.
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final UserRole role;
  final String? phone;
  final String? organization; // used for sponsors
  final String? address; // optional mailing/contact address
  final DateTime? createdAt;

  /// Email-update opt-in flag.
  final bool emailOptIn;

  /// Selected interest keys (see lib/data/interests.dart), e.g.
  /// `sports.football`, `clubs.science`, `fundraising`, `volunteering`.
  final List<String> interests;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.photoUrl,
    this.phone,
    this.organization,
    this.address,
    this.createdAt,
    this.emailOptIn = true,
    this.interests = const [],
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      role: UserRole.fromString(data['role'] as String?),
      phone: data['phone'] as String?,
      organization: data['organization'] as String?,
      address: data['address'] as String?,
      emailOptIn: data['emailOptIn'] as bool? ?? true,
      interests: List<String>.from(data['interests'] as List? ?? const []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role.name,
      'phone': phone,
      'organization': organization,
      'address': address,
      'emailOptIn': emailOptIn,
      'interests': interests,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    UserRole? role,
    String? phone,
    String? organization,
    String? address,
    bool? emailOptIn,
    List<String>? interests,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      organization: organization ?? this.organization,
      address: address ?? this.address,
      emailOptIn: emailOptIn ?? this.emailOptIn,
      interests: interests ?? this.interests,
      createdAt: createdAt,
    );
  }
}
