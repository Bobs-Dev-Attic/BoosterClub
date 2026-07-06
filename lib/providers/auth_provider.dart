import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

/// Exposes authentication state to the widget tree.
class AuthProvider extends ChangeNotifier {
  final AuthService _service;
  StreamSubscription<AppUser?>? _sub;

  AppUser? _user;
  bool _initializing = true;

  AuthProvider(this._service) {
    _sub = _service.userChanges().listen((u) {
      _user = u;
      _initializing = false;
      notifyListeners();
    });
  }

  AppUser? get user => _user;
  bool get isInitializing => _initializing;
  bool get isSignedIn => _user != null;
  UserRole get role => _user?.role ?? UserRole.guest;

  AuthService get service => _service;

  Future<AuthResult> signInWithEmail(String email, String password) =>
      _service.signInWithEmail(email, password);

  Future<AuthResult> register(String email, String password, String name) =>
      _service.registerWithEmail(email, password, name);

  Future<AuthResult> sendSignInLink(String email, String continueUrl) =>
      _service.sendSignInLink(email, continueUrl);

  bool isSignInLink(String link) => _service.isSignInLink(link);

  Future<String?> savedEmailForSignIn() => _service.savedEmailForSignIn();

  Future<AuthResult> completeSignInWithLink(String email, String link) =>
      _service.completeSignInWithLink(email, link);

  // QR pairing
  Future<String> createQrSession() => _service.createQrSession();

  Stream<Map<String, dynamic>?> watchQrSession(String id) =>
      _service.watchQrSession(id);

  Future<AuthResult> approveQrSession(String id) =>
      _service.approveQrSession(id);

  Future<AuthResult> sendPasswordReset(String email) =>
      _service.sendPasswordReset(email);

  Future<AuthResult> signInWithGoogle() => _service.signInWithGoogle();

  Future<AuthResult> signInWithFacebook() => _service.signInWithFacebook();

  Future<AuthResult> signInWithQrToken(String token, {String? sessionId}) =>
      _service.signInWithQrToken(token, sessionId: sessionId);

  Future<void> updateProfile(AppUser user) async {
    await _service.updateProfile(user);
  }

  Future<void> signOut() => _service.signOut();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
