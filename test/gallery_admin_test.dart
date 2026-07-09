import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booster_club/config/app_config.dart';
import 'package:booster_club/services/firestore_service.dart';
import 'package:booster_club/screens/admin/gallery_admin.dart';

void main() {
  testWidgets('GalleryAdmin renders grid + toolbar without layout crash',
      (tester) async {
    AppConfig.demoMode = true; // use in-memory demo gallery
    final fs = FirestoreService();

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: GalleryAdmin(fs: fs))));
    await tester.pump(); // let the demo stream emit

    // No thrown exception (the old Spacer-in-Wrap bug rendered a grey
    // ErrorWidget instead of the grid).
    expect(tester.takeException(), isNull);

    // Toolbar controls and the grid are present.
    expect(find.text('Add new'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
  });
}
