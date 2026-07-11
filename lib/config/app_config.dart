import '../firebase_options.dart';

/// Global runtime configuration.
class AppConfig {
  AppConfig._();

  /// The name shown throughout the app. Change to your school's booster club.
  static const String appName = 'WJ Booster Club';
  static const String schoolName = 'Walter Johnson High School';
  static const String mascot = 'Wildcats';

  /// App version, shown in the nav footer. Bump this on each iteration (kept in
  /// step with the version in pubspec.yaml and CHANGELOG.md).
  static const String appVersion = '1.18.4';

  /// When true, the app runs against seeded in-memory data instead of Firebase.
  /// This is automatically enabled when [DefaultFirebaseOptions] still contains
  /// placeholder credentials, or when Firebase initialization fails, so the app
  /// remains fully previewable before a backend is wired up.
  static bool demoMode = !DefaultFirebaseOptions.isConfigured;

  /// PayPal REST **client id** (public — safe to ship in the app). Leave empty
  /// until a PayPal business/REST app is set up; when empty the Donate page
  /// runs a simulated checkout so it stays previewable. The matching **secret**
  /// is NEVER stored here — it lives only in Cloud Functions config.
  static const String paypalClientId = String.fromEnvironment(
    'PAYPAL_CLIENT_ID',
    defaultValue: '',
  );

  /// Whether a real PayPal integration is available (client id configured and
  /// not running against the in-memory demo backend).
  static bool get paypalConfigured => paypalClientId.isNotEmpty && !demoMode;
}
