import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:booster_club/config/app_config.dart';
import 'package:booster_club/models/content_models.dart';
import 'package:booster_club/services/firestore_service.dart';
import 'package:booster_club/screens/committees_screen.dart';

void main() {
  test('Committee round-trips roles, sections and category', () {
    final c = Committee.fromDoc('c', {
      'title': 'Concessions',
      'roles': [
        {'id': 'chair', 'title': 'Chair'},
        {'id': 'vol', 'title': 'Volunteer Coordinator'},
      ],
      'sections': [
        {'heading': 'Outdoor', 'body': '2 adults'}
      ],
      'category': 'leadership',
      'order': 1,
    });
    expect(c.roles.map((r) => r.title), ['Chair', 'Volunteer Coordinator']);
    expect(c.roleById('vol')?.title, 'Volunteer Coordinator');
    expect(c.roleById('missing'), isNull);
    expect(c.sections.single.heading, 'Outdoor');
    expect(c.isLeadership, isTrue);
    final map = c.toMap();
    expect(map['category'], 'leadership');
    expect((map['roles'] as List).first['id'], 'chair');
  });

  test('CommitteeMember round-trips and builds a deterministic id', () {
    expect(CommitteeMember.idFor('com_x', 'user_y'), 'com_x__user_y');
    final m = CommitteeMember.fromDoc('com_x__user_y', {
      'committeeId': 'com_x',
      'userId': 'user_y',
      'userName': 'Jane Doe',
      'roleIds': ['chair', 'vol'],
    });
    expect(m.committeeId, 'com_x');
    expect(m.roleIds, ['chair', 'vol']);
    expect(m.copyWith(roleIds: ['chair']).roleIds, ['chair']);
    expect(m.toMap()['userName'], 'Jane Doe');
  });

  test('Team and TeamMember round-trip', () {
    final t = Team.fromDoc('t', {
      'title': 'Events Crew',
      'description': 'Runs events',
      'order': 2,
    });
    expect(t.title, 'Events Crew');
    expect(t.toMap()['order'], 2);

    expect(TeamMember.idFor('t', 'u'), 't__u');
    final tm = TeamMember.fromDoc('t__u', {
      'teamId': 't',
      'userId': 'u',
      'userName': 'Sam',
    });
    expect(tm.teamId, 't');
    expect(tm.userName, 'Sam');
  });

  testWidgets('Leadership & Committees page renders groups, members and open',
      (tester) async {
    AppConfig.demoMode = true;
    tester.view.physicalSize = const Size(1400, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FirestoreService();

    await tester.pumpWidget(Provider<FirestoreService>.value(
      value: fs,
      child: const MaterialApp(home: Scaffold(body: CommitteesScreen())),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Leadership group + an assigned member (Alex Admin is seeded as President).
    expect(find.text('Executive Committee'), findsOneWidget);
    expect(find.textContaining('Alex Admin'), findsWidgets);
    // Working committee still renders with its contact email.
    expect(find.text('Concessions'), findsOneWidget);
    expect(find.text('wjmulchsale@gmail.com'), findsOneWidget);
    // The open-roles call-out appears (there are unassigned roles in the seed).
    expect(find.textContaining('Open roles'), findsOneWidget);
  });
}
