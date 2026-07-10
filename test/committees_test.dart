import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:booster_club/config/app_config.dart';
import 'package:booster_club/models/content_models.dart';
import 'package:booster_club/services/firestore_service.dart';
import 'package:booster_club/screens/committees_screen.dart';

void main() {
  test('Committee round-trips teamRoles and sections through fromDoc/toMap', () {
    final c = Committee.fromDoc('c', {
      'title': 'Concessions',
      'teamRoles': ['A', 'B'],
      'sections': [
        {'heading': 'Outdoor', 'body': '2 adults'}
      ],
      'order': 1,
    });
    expect(c.teamRoles, ['A', 'B']);
    expect(c.sections.single.heading, 'Outdoor');
    expect(c.sections.single.body, '2 adults');
    final map = c.toMap();
    expect(map['teamRoles'], ['A', 'B']);
    expect((map['sections'] as List).single['heading'], 'Outdoor');
  });

  testWidgets('Committees page renders the committees', (tester) async {
    AppConfig.demoMode = true;
    tester.view.physicalSize = const Size(1200, 3000);
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
    expect(find.text('Concessions'), findsOneWidget);
    expect(find.text('Mulch Sale Fundraiser'), findsOneWidget);
    expect(find.text('wjmulchsale@gmail.com'), findsOneWidget);
  });
}
