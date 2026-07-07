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
  static const String appVersion = '1.4.1';

  /// When true, the app runs against seeded in-memory data instead of Firebase.
  /// This is automatically enabled when [DefaultFirebaseOptions] still contains
  /// placeholder credentials, or when Firebase initialization fails, so the app
  /// remains fully previewable before a backend is wired up.
  static bool demoMode = !DefaultFirebaseOptions.isConfigured;
}
