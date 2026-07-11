import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:booster_club/config/app_config.dart';
import 'package:booster_club/providers/auth_provider.dart';
import 'package:booster_club/screens/admin/admin_screen.dart';
import 'package:booster_club/services/auth_service.dart';
import 'package:booster_club/services/firestore_service.dart';

/// Pumps the Admin Dashboard signed in as a demo web-admin (any email with
/// "admin" gets full privileges in demo mode) inside the providers it reads.
Future<void> _pumpAdmin(WidgetTester tester) async {
  AppConfig.demoMode = true;
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fs = FirestoreService();
  final auth = AuthProvider(AuthService());
  await auth.signInWithEmail('admin@wj.org', 'x'); // → webAdmin

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        Provider<FirestoreService>.value(value: fs),
      ],
      child: const MaterialApp(home: Scaffold(body: AdminScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Admin Dashboard groups sections into category flyout menus',
      (tester) async {
    await _pumpAdmin(tester);
    expect(tester.takeException(), isNull);

    // The three category buttons replace the old flat tab strip.
    expect(find.text('Content & Engagement'), findsOneWidget);
    expect(find.text('Fundraising & Finance'), findsOneWidget);
    expect(find.text('Organization'), findsOneWidget);

    // Sections aren't shown until their category flyout is opened. The default
    // open section (first content one) is Events — its breadcrumb is present.
    expect(find.text('Events'), findsWidgets);
    expect(find.text('Donations'), findsNothing);
  });

  testWidgets('Opening a category flyout switches the visible section',
      (tester) async {
    await _pumpAdmin(tester);

    // Open the Fundraising & Finance flyout and pick Donations.
    await tester.tap(find.text('Fundraising & Finance'));
    await tester.pumpAndSettle();
    expect(find.text('Donations'), findsWidgets); // now listed in the menu

    await tester.tap(find.text('Donations').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The breadcrumb now reads Donations and the Donations admin panel is shown.
    expect(find.text('Donations'), findsWidgets);
    // Events panel is torn down when we switch away.
    expect(find.byType(AdminScreen), findsOneWidget);
  });

  testWidgets('Organization category exposes Committees and a Teams section',
      (tester) async {
    await _pumpAdmin(tester);

    // Committees section has a per-row "Manage members" action.
    await tester.tap(find.text('Organization'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Committees').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Concessions'), findsWidgets);
    expect(find.text('Members'), findsWidgets); // manage-members buttons

    // Opening the members manager lists a seeded committee member.
    await tester.tap(find.text('Members').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Members — '), findsOneWidget);
    expect(find.text('Add member'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Teams is its own section under Organization and lists seeded teams.
    await tester.tap(find.text('Organization'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teams').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Events Crew'), findsOneWidget);
  });
}
