import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';

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
      return const AuthResult(
          true, 'A one-time sign-in link has been emailed to you.');
    } on FirebaseAuthException catch (e) {
      return AuthResult(false, e.message);
    }
  }

  /// Completes sign-in from an email link (call with the full incoming URL).
  Future<AuthResult> completeSignInWithLink(String email, String link) async {
    try {
      if (!_auth.isSignInWithEmailLink(link)) {
        return const AuthResult(false, 'Not a valid sign-in link.');
      }
      await _auth.signInWithEmailLink(email: email, emailLink: link);
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
  /// Signs in using a token embedded in a scanned QR code. In production the
  /// token is a Firebase custom token minted by a Cloud Function after an
  /// already-authenticated device approves the QR session; here we complete the
  /// exchange. In demo mode any token signs in a demo account.
  Future<AuthResult> signInWithQrToken(String token) async {
    if (AppConfig.demoMode) {
      return _demoSignIn('qr.user@example.com', name: 'QR User');
    }
    try {
      await _auth.signInWithCustomToken(token);
      return const AuthResult(true);
    } on FirebaseAuthException catch (e) {
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
