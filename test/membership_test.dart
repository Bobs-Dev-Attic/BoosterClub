import 'package:flutter_test/flutter_test.dart';
import 'package:booster_club/config/app_config.dart';
import 'package:booster_club/models/app_user.dart';
import 'package:booster_club/models/content_models.dart';
import 'package:booster_club/services/firestore_service.dart';

/// Exercises the committee/team membership join tables through
/// [FirestoreService] in demo mode (add → assign roles → remove).
void main() {
  const committee = Committee(
    id: 'com_test',
    title: 'Test Committee',
    roles: [
      CommitteeRole(id: 'chair', title: 'Chair'),
      CommitteeRole(id: 'vol', title: 'Volunteer'),
    ],
  );
  const team = Team(id: 'team_test', title: 'Test Team');
  const user = AppUser(
    uid: 'u1',
    email: 'u1@example.com',
    displayName: 'Test User',
    role: UserRole.member,
  );

  setUp(() => AppConfig.demoMode = true);

  test('committee membership: add, assign roles, remove', () async {
    final fs = FirestoreService();

    await fs.addCommitteeMember(committee, user, roleIds: ['chair']);
    var members = (await fs.committeeMembers().first)
        .where((m) => m.committeeId == 'com_test')
        .toList();
    expect(members, hasLength(1));
    expect(members.single.userId, 'u1');
    expect(members.single.roleIds, ['chair']);
    // Deterministic id keeps re-adds idempotent.
    expect(members.single.id, CommitteeMember.idFor('com_test', 'u1'));

    await fs.setCommitteeMemberRoles(members.single, ['chair', 'vol']);
    members = (await fs.committeeMembers().first)
        .where((m) => m.committeeId == 'com_test')
        .toList();
    expect(members, hasLength(1)); // still one record, not a duplicate
    expect(members.single.roleIds, ['chair', 'vol']);

    await fs.removeCommitteeMember(members.single);
    members = (await fs.committeeMembers().first)
        .where((m) => m.committeeId == 'com_test')
        .toList();
    expect(members, isEmpty);
  });

  test('team membership: add and remove', () async {
    final fs = FirestoreService();

    await fs.addTeamMember(team, user);
    var members = (await fs.teamMembers().first)
        .where((m) => m.teamId == 'team_test')
        .toList();
    expect(members, hasLength(1));
    expect(members.single.userName, 'Test User');

    await fs.removeTeamMember(members.single);
    members = (await fs.teamMembers().first)
        .where((m) => m.teamId == 'team_test')
        .toList();
    expect(members, isEmpty);
  });

  test('AppUser no longer carries committee ids', () {
    final u = AppUser.fromMap('u', {
      'email': 'x@y.z',
      'displayName': 'X',
      'role': 'member',
      // A legacy committees field is simply ignored now.
      'committees': ['old'],
    });
    expect(u.toMap().containsKey('committees'), isFalse);
  });
}
