import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:booster_club/config/app_config.dart';
import 'package:booster_club/models/app_user.dart';
import 'package:booster_club/models/content_models.dart';
import 'package:booster_club/services/firestore_service.dart';
import 'package:booster_club/screens/committees_screen.dart';

void main() {
  test('Committee round-trips roles, sections, category and positions', () {
    final c = Committee.fromDoc('c', {
      'title': 'Concessions',
      'teamRoles': ['A', 'B'],
      'sections': [
        {'heading': 'Outdoor', 'body': '2 adults'}
      ],
      'category': 'leadership',
      'positions': [
        {'title': 'Chair', 'holder': 'Dawn Harris'},
        {'title': 'Commissioner', 'holder': 'OPEN'},
        {'title': 'Empty', 'holder': ''},
      ],
      'order': 1,
    });
    expect(c.teamRoles, ['A', 'B']);
    expect(c.sections.single.heading, 'Outdoor');
    expect(c.isLeadership, isTrue);
    expect(c.positions.length, 3);
    // open = blank holder or literal "OPEN"
    expect(c.openPositions.map((p) => p.title), ['Commissioner', 'Empty']);
    final map = c.toMap();
    expect(map['category'], 'leadership');
    expect((map['positions'] as List).first['holder'], 'Dawn Harris');
  });

  test('AppUser round-trips committee memberships', () {
    final u = AppUser.fromMap('u', {
      'email': 'x@y.z',
      'displayName': 'X',
      'role': 'member',
      'committees': ['lead_exec', 'com_concessions'],
    });
    expect(u.committees, ['lead_exec', 'com_concessions']);
    expect(u.toMap()['committees'], ['lead_exec', 'com_concessions']);
    expect(u.copyWith(committees: ['a']).committees, ['a']);
  });

  testWidgets('Leadership & Committees page renders groups, holders and open',
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
    // Leadership group + a holder name (rendered in a rich-text position line).
    expect(find.text('Executive Committee'), findsOneWidget);
    expect(find.textContaining('Mary Bittle Koenick'), findsWidgets);
    // Working committee still renders with its contact email.
    expect(find.text('Concessions'), findsOneWidget);
    expect(find.text('wjmulchsale@gmail.com'), findsOneWidget);
    // The open-positions call-out appears (there are OPEN chairs in the seed).
    expect(find.textContaining('Open positions'), findsOneWidget);
  });
}
