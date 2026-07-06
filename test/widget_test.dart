import 'package:booster_club/config/app_config.dart';
import 'package:booster_club/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots in demo mode and shows the hero', (tester) async {
    AppConfig.demoMode = true;

    await tester.pumpWidget(const BoosterClubApp());
    await tester.pump(const Duration(milliseconds: 500));

    // The home hero greets with the school spirit line.
    expect(find.textContaining('Go ${AppConfig.mascot}'), findsOneWidget);
    // Navigation is present.
    expect(find.text('Events'), findsWidgets);
  });
}
