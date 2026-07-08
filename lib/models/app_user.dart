import 'package:cloud_firestore/cloud_firestore.dart';

import 'permissions.dart';

/// The permissions granted by a base role (before any delegated grants).
Set<String> rolePermissions(UserRole role) {
  switch (role) {
    case UserRole.webAdmin:
      return kPermissions.toSet();
    case UserRole.administrator:
      return kPermissions.where((p) => p != 'manage_users').toSet();
    case UserRole.contributor:
      return {'manage_meetings', 'manage_history', 'manage_gallery'};
    case UserRole.policyAdmin:
      return {'manage_legal'};
    default:
      return {};
  }
}

/// Roles supported by the Booster Club app, ordered from least to most
/// privileged. Higher-index roles inherit the abilities of lower ones.
enum UserRole {
  guest,
  supporter,
  member,
  contributor,
  sponsor,
  policyAdmin,
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
      case UserRole.contributor:
        return 'Contributor';
      case UserRole.sponsor:
        return 'Sponsor';
      case UserRole.policyAdmin:
        return 'Policy Admin';
      case UserRole.administrator:
        return 'Administrator';
      case UserRole.webAdmin:
        return 'Web Admin';
    }
  }

  /// Can create / edit / delete app content.
  bool get canManageContent =>
      index >= UserRole.administrator.index;

  /// Can upload meeting minutes (Contributors and content managers).
  bool get canPostMinutes =>
      this == UserRole.contributor || canManageContent;

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

  /// Delegated permission grants: permission key -> expiry (a far-future date
  /// means "no expiry"). Only active (non-expired) grants take effect.
  final Map<String, DateTime> grants;

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
    this.grants = const {},
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    final rawGrants = (data['grants'] as Map?) ?? const {};
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
      grants: {
        for (final e in rawGrants.entries)
          if (e.value is Timestamp)
            e.key as String: (e.value as Timestamp).toDate(),
      },
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
      'grants': {
        for (final e in grants.entries) e.key: Timestamp.fromDate(e.value),
      },
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// A far-future sentinel used for permanent (no-expiry) grants.
  static final DateTime never = DateTime.utc(9999, 1, 1);

  /// Active delegated permissions (grants that have not expired).
  Set<String> activeGrants([DateTime? now]) {
    final t = now ?? DateTime.now();
    return {
      for (final e in grants.entries)
        if (e.value.isAfter(t)) e.key,
    };
  }

  /// The user's full effective permission set (role defaults + active grants).
  Set<String> effectivePermissions([DateTime? now]) =>
      rolePermissions(role).union(activeGrants(now));

  /// Whether the user currently holds [permission].
  bool can(String permission) => effectivePermissions().contains(permission);

  /// True if the user can manage any part of the site (shows the admin area).
  bool get canManageAny => effectivePermissions().isNotEmpty;

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    UserRole? role,
    String? phone,
    String? organization,
    String? address,
    bool? emailOptIn,
    List<String>? interests,
    Map<String, DateTime>? grants,
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
      grants: grants ?? this.grants,
      createdAt: createdAt,
    );
  }
}
