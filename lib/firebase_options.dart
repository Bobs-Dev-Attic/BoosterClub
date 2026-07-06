// GENERATED-STYLE PLACEHOLDER.
//
// Replace the values below with your real Firebase project configuration.
// The recommended way to generate this file is the FlutterFire CLI:
//
//     dart pub global activate flutterfire_cli
//     flutterfire configure
//
// Until real values are supplied, `DefaultFirebaseOptions.isConfigured` returns
// false and the app boots into an in-memory DEMO MODE so it can be previewed
// without a backend. See lib/config/app_config.dart.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String _placeholder = 'REPLACE_ME';

  /// True once real Firebase credentials have been filled in below.
  static bool get isConfigured => web.apiKey != _placeholder;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: _placeholder,
    authDomain: _placeholder,
    storageBucket: _placeholder,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: _placeholder,
    storageBucket: _placeholder,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: _placeholder,
    storageBucket: _placeholder,
    iosBundleId: 'com.boosterclub.boosterClub',
  );
}
