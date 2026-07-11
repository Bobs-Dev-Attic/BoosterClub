import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';

/// A pending QR pairing session: its public [id] (encoded in the QR) plus the
/// private [secret] the creating device keeps to itself. The secret is what
/// lets this device — and only this device — later claim the sign-in token.
class QrSession {
  final String id;
  final String secret;
  const QrSession(this.id, this.secret);
}

/// Result of an attempted sign-in.
class AuthResult {
  final bool success;
  final String? message;
  const AuthResult(this.success, [this.message]);
}

/// Wraps Firebase Auth and the user-profile document. Supports Email/Password,
/// passwordless Email link (one-time-code style), QR sign-in, Google and
/// Facebook. Falls back to an in-memory simulation in [AppConfig.demoMode].
class AuthService {
  final _demoController = StreamController<AppUser?>.broadcast();
  AppUser? _demoUser;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Emits the current [AppUser] (or null when signed out).
  Stream<AppUser?> userChanges() {
    if (AppConfig.demoMode) {
      return _demoController.stream;
    }
    return _auth.authStateChanges().asyncMap(_toAppUser);
  }

  Future<AppUser?> _toAppUser(User? user) async {
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return AppUser.fromMap(user.uid, doc.data()!);
    }
    // First login: create a default profile.
    final profile = AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? (user.email?.split('@').first ?? 'Member'),
      photoUrl: user.photoURL,
      role: UserRole.supporter,
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(user.uid).set(profile.toMap());
    return profile;
  }

  // ---- Email / Password -------------------------------------------------
  Future<AuthResult> signInWithEmail(String email, String password) async {
    if (AppConfig.demoMode) return _demoSignIn(email);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return const AuthResult(true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(false, e.message);
    }
  }

  Future<AuthResult> registerWithEmail(
      String email, String password, String displayName) async {
    if (AppConfig.demoMode) return _demoSignIn(email, name: displayName);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await cred.user?.updateDisplayName(displayName);
      await _toAppUser(cred.user); // ensure profile doc exists
      return const AuthResult(true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(false, e.message);
    }
  }

  Future<AuthResult> sendPasswordReset(String email) async {
    if (AppConfig.demoMode) {
      return const AuthResult(true, 'Demo mode: reset email would be sent.');
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return const AuthResult(true, 'Password reset email sent.');
    } on FirebaseAuthException catch (e) {
      return AuthResult(false, e.message);
    }
  }

  // ---- Email One-Time-Code (passwordless link) --------------------------
  /// Sends a one-time sign-in link to [email]. The link, when opened, completes
  /// sign-in with no password. This is the "Email / One-Time-Code" method.
  Future<AuthResult> sendSignInLink(String email, String continueUrl) async {
    if (AppConfig.demoMode) {
      return const AuthResult(
          true, 'Demo mode: a one-time sign-in link would be emailed.');
    }
    try {
      final settings = ActionCodeSettings(
        url: continueUrl,
        handleCodeInApp: true,
      );
      await _auth.sendSignInLinkToEmail(
          email: email, actionCodeSettings: settings);
      // Remember the address so we can complete sign-in when the user returns
      // via the link on this same device without re-typing it.
      await _saveEmailForSignIn(email);
      return const AuthResult(
          true, 'A one-time sign-in link has been emailed to you.');
    } on FirebaseAuthException catch (e) {
      return AuthResult(false, e.message);
    }
  }

  /// True if [link] (typically the current page URL) is a passwordless sign-in
  /// link that should be completed.
  bool isSignInLink(String link) {
    if (AppConfig.demoMode) return false;
    try {
      return _auth.isSignInWithEmailLink(link);
    } catch (_) {
      return false;
    }
  }

  /// The email saved when the one-time link was requested (same device).
  Future<String?> savedEmailForSignIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('emailForSignIn');
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveEmailForSignIn(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emailForSignIn', email);
    } catch (_) {/* best effort */}
  }

  /// Completes sign-in from an email link (call with the full incoming URL).
  Future<AuthResult> completeSignInWithLink(String email, String link) async {
    try {
      if (!_auth.isSignInWithEmailLink(link)) {
        return const AuthResult(false, 'Not a valid sign-in link.');
      }
      await _auth.signInWithEmailLink(email: email, emailLink: link);
      // Clear the stored email once used.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('emailForSignIn');
      } catch (_) {}
      return const AuthResult(true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(false, e.message);
    }
  }

  // ---- Social providers -------------------------------------------------
  Future<AuthResult> signInWithGoogle() => _signInWithProvider(
        GoogleAuthProvider(),
        demoName: 'Google User',
        demoEmail: 'google.user@example.com',
      );

  Future<AuthResult> signInWithFacebook() => _signInWithProvider(
        FacebookAuthProvider(),
        demoName: 'Facebook User',
        demoEmail: 'facebook.user@example.com',
      );

  Future<AuthResult> _signInWithProvider(
    AuthProvider provider, {
    required String demoName,
    required String demoEmail,
  }) async {
    if (AppConfig.demoMode) return _demoSignIn(demoEmail, name: demoName);
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(provider);
      } else {
        await _auth.signInWithProvider(provider);
      }
      return const AuthResult(true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(false, e.message);
    }
  }

  // ---- QR sign-in -------------------------------------------------------
  //
  // Cross-device flow (see functions/index.js for the matching server logic):
  //   1. The web app creates a `qr_sessions/{id}` doc (status: pending) that
  //      stores only the SHA-256 HASH of a locally-generated secret. It shows a
  //      QR encoding a /pair?s={id} URL. The secret is NEVER in the QR or the
  //      document — it stays in this device's memory.
  //   2. A phone that is already signed in opens that URL and approves it,
  //      calling `approveQrSignIn`. That records the approving uid only; no
  //      token is minted or stored (a stored token could be read by anyone,
  //      since the session doc is publicly readable).
  //   3. The web app, watching the doc, sees `status == approved` and calls
  //      `claimQrSignIn` with the secret. The function verifies the secret,
  //      mints the token, returns it directly (never persisting it), and
  //      deletes the single-use session. The web app signs in with the token.

  CollectionReference<Map<String, dynamic>> get _qrSessions =>
      _db.collection('qr_sessions');

  /// Generates a high-entropy URL-safe secret (32 random bytes).
  String _randomSecret() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Creates a pending QR pairing session. Stores only the secret's hash; the
  /// returned [QrSession] carries the raw secret for this device to keep.
  Future<QrSession> createQrSession() async {
    final secret = _randomSecret();
    final hash = sha256.convert(utf8.encode(secret)).toString();
    final doc = _qrSessions.doc();
    await doc.set({
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'secretHash': hash,
    });
    return QrSession(doc.id, secret);
  }

  /// Streams the status of a QR session so the web app can react to approval.
  Stream<Map<String, dynamic>?> watchQrSession(String sessionId) =>
      _qrSessions.doc(sessionId).snapshots().map((s) => s.data());

  /// Web side: once a phone has approved the session, prove knowledge of the
  /// [secret] to obtain and consume the custom token, then sign in.
  Future<AuthResult> claimQrSignIn(String sessionId, String secret) async {
    if (AppConfig.demoMode) {
      return _demoSignIn('qr.user@example.com', name: 'QR User');
    }
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('claimQrSignIn');
      final res = await callable
          .call<dynamic>({'sessionId': sessionId, 'secret': secret});
      final token = (res.data as Map?)?['token'] as String?;
      if (token == null || token.isEmpty) {
        return const AuthResult(false, 'No sign-in token was returned.');
      }
      await _auth.signInWithCustomToken(token);
      return const AuthResult(true);
    } on FirebaseFunctionsException catch (e) {
      return AuthResult(false, e.message ?? 'Sign-in failed.');
    } on FirebaseAuthException catch (e) {
      return AuthResult(false, e.message);
    } catch (e) {
      return AuthResult(false, '$e');
    }
  }

  /// Demo-mode QR sign-in (no backend) used by the "Simulate scan" button.
  Future<AuthResult> demoQrSignIn() async =>
      _demoSignIn('qr.user@example.com', name: 'QR User');

  /// Phone side: approve a scanned QR session. Calls the Cloud Function which
  /// records the approval for the current (already signed-in) user.
  Future<AuthResult> approveQrSession(String sessionId) async {
    if (AppConfig.demoMode) return const AuthResult(true);
    if (_auth.currentUser == null) {
      return const AuthResult(false, 'Please sign in first, then approve.');
    }
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('approveQrSignIn');
      await callable.call<dynamic>({'sessionId': sessionId});
      return const AuthResult(true);
    } on FirebaseFunctionsException catch (e) {
      return AuthResult(false, e.message ?? 'Approval failed.');
    } catch (e) {
      return AuthResult(false, '$e');
    }
  }

  /// Starts an email-address change. Firebase sends a verification link to the
  /// new address; the change takes effect once the user clicks it.
  Future<AuthResult> updateEmail(String newEmail) async {
    if (AppConfig.demoMode) {
      return const AuthResult(
          true, 'Demo mode: a verification link would be sent to the new email.');
    }
    final user = _auth.currentUser;
    if (user == null) return const AuthResult(false, 'Not signed in.');
    try {
      await user.verifyBeforeUpdateEmail(newEmail);
      return const AuthResult(true,
          'Verification sent — check the new address to finish the change.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return const AuthResult(false,
            'For security, please sign out and back in, then try again.');
      }
      return AuthResult(false, e.message);
    }
  }

  // ---- Profile / sign out ----------------------------------------------
  Future<void> updateProfile(AppUser user) async {
    if (AppConfig.demoMode) {
      _demoUser = user;
      _demoController.add(_demoUser);
      return;
    }
    await _db.collection('users').doc(user.uid).set(
          user.toMap(),
          SetOptions(merge: true),
        );
    if (_auth.currentUser?.displayName != user.displayName) {
      await _auth.currentUser?.updateDisplayName(user.displayName);
    }
  }

  Future<void> signOut() async {
    if (AppConfig.demoMode) {
      _demoUser = null;
      _demoController.add(null);
      return;
    }
    await _auth.signOut();
  }

  // ---- Demo helpers -----------------------------------------------------
  AuthResult _demoSignIn(String email, {String? name}) {
    // Give the built-in admin demo email elevated privileges so admin features
    // can be explored without a backend.
    final isAdmin = email.toLowerCase().contains('admin');
    _demoUser = AppUser(
      uid: 'demo-${email.hashCode}',
      email: email,
      displayName: name ?? email.split('@').first,
      role: isAdmin ? UserRole.webAdmin : UserRole.member,
      createdAt: DateTime.now(),
    );
    _demoController.add(_demoUser);
    return const AuthResult(true);
  }
}
