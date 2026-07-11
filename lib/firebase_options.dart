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
//
// SECURITY NOTE: the apiKey/appId values in this file are PUBLIC identifiers,
// not secrets — every Firebase web app ships them to the browser, and they are
// safe to commit. What actually protects the data is firestore.rules and
// storage.rules. Real secrets (the CI deploy key, PayPal secret) live in
// GitHub Actions secrets and Cloud Functions secrets — never in this repo.
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

  // Project: boosterclub-bda (project number / sender id: 595475479160).
  // apiKey and appId still need to be filled from the Firebase console after
  // registering each app (or run `flutterfire configure` to generate all of it).
  static const String _projectId = 'boosterclub-bda';
  static const String _senderId = '595475479160';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC4ZCtn2k9aausoQUlfwsnvxH77ySD7E6E',
    appId: '1:595475479160:web:ca64684dc289a489394b8d',
    messagingSenderId: _senderId,
    projectId: _projectId,
    authDomain: '$_projectId.firebaseapp.com',
    storageBucket: '$_projectId.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: '$_projectId.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: '$_projectId.firebasestorage.app',
    iosBundleId: 'com.boosterclub.boosterClub',
  );
}
