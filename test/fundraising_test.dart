import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booster_club/config/app_config.dart';
import 'package:booster_club/models/app_user.dart';
import 'package:booster_club/models/content_models.dart';
import 'package:booster_club/services/firestore_service.dart';
import 'package:booster_club/screens/admin/fundraising_admin.dart';

void main() {
  test('order total, unit count and summary compute from items', () {
    const order = FundraisingOrder(
      id: 'o',
      campaignId: 'c',
      customerName: 'Jane',
      items: [
        OrderItem(productName: 'Mulch', quantity: 20, unitPrice: 6),
        OrderItem(productName: 'Tee', option: 'L', quantity: 2, unitPrice: 18),
      ],
    );
    expect(order.total, 156.0);
    expect(order.unitCount, 22);
    expect(order.summary, '20× Mulch, 2× Tee (L)');
  });

  test('enums round-trip through fromDoc/toMap with sensible defaults', () {
    final c = FundraisingCampaign.fromDoc('c', {
      'title': 'Sale',
      'type': 'raffle',
      'stage': 'delivery',
      'products': [
        {'id': 'p', 'name': 'Ticket', 'price': 5, 'options': ['A', 'B']}
      ],
    });
    expect(c.type, CampaignType.raffle);
    expect(c.stage, CampaignStage.delivery);
    expect(c.products.single.options, ['A', 'B']);
    expect(c.toMap()['stage'], 'delivery');

    // Unknown/missing values fall back to defaults.
    final d = FundraisingCampaign.fromDoc('d', {'title': 'x'});
    expect(d.type, CampaignType.product);
    expect(d.stage, CampaignStage.planning);
  });

  test('fundraising role permissions are scoped correctly', () {
    expect(rolePermissions(UserRole.fundraisingAdmin),
        contains('manage_fundraising'));
    expect(rolePermissions(UserRole.fundraisingVolunteer),
        {'fulfill_fundraising'});
    expect(rolePermissions(UserRole.fundraisingVendor), {'supply_fundraising'});
    expect(rolePermissions(UserRole.fundraisingSponsor),
        {'sponsor_fundraising'});
  });

  testWidgets('Fundraising module renders list + detail without crashing',
      (tester) async {
    AppConfig.demoMode = true;
    // Tall viewport so the whole detail (incl. the Orders section) lays out and
    // its lazily-built widgets exist for the test to interact with.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FirestoreService();
    const user = AppUser(
        uid: 'u',
        email: 'a@b.c',
        displayName: 'Admin',
        role: UserRole.fundraisingAdmin);

    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: FundraisingAdmin(fs: fs, user: user))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Spring Mulch Sale'), findsOneWidget);

    // Open the detail screen (exercises workflow bar, dashboard, orders).
    await tester.tap(find.text('Spring Mulch Sale'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Dashboard'), findsOneWidget);

    // Open the order editor (line-item rows, product/option dropdowns, totals).
    await tester.tap(find.text('Add order'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('New Order'), findsOneWidget);
    expect(find.text('Total: \$6'), findsOneWidget); // default 1 × Mulch @ $6
  });
}
