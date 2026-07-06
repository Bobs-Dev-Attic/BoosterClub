import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

enum _Mode { signIn, register, emailLink }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _Mode _mode = _Mode.signIn;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<AuthResult> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final result = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!result.success) {
        _error = result.message ?? 'Something went wrong.';
      } else if (result.message != null) {
        _info = result.message;
      }
    });
    if (result.success && result.message == null && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return PageBody(
      maxWidth: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Text('Welcome', style: displayFont(context, size: 30)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _mode == _Mode.register
                  ? 'Create your ${AppConfig.appName} account'
                  : 'Sign in to ${AppConfig.appName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) _banner(_error!, isError: true),
                    if (_info != null) _banner(_info!, isError: false),
                    if (_mode == _Mode.register) ...[
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    if (_mode != _Mode.emailLink) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'At least 6 characters'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : () => _submit(auth),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_primaryLabel),
                    ),
                    if (_mode == _Mode.signIn) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                if (!_email.text.contains('@')) {
                                  setState(() =>
                                      _error = 'Enter your email first.');
                                  return;
                                }
                                _run(() =>
                                    auth.sendPasswordReset(_email.text.trim()));
                              },
                        child: const Text('Forgot password?'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _modeSwitcher(),
                    const _OrDivider(),
                    _SocialButtons(onRun: _run, auth: auth),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed:
                          _busy ? null : () => context.go('/login/qr'),
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Sign in with QR code'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Continue as guest'),
            ),
          ),
        ],
      ),
    );
  }

  String get _primaryLabel {
    switch (_mode) {
      case _Mode.signIn:
        return 'Sign in';
      case _Mode.register:
        return 'Create account';
      case _Mode.emailLink:
        return 'Email me a one-time link';
    }
  }

  void _submit(AuthProvider auth) {
    if (_mode == _Mode.emailLink) {
      if (!_email.text.contains('@')) {
        setState(() => _error = 'Enter a valid email');
        return;
      }
      final continueUrl = Uri.base.origin.isEmpty
          ? 'https://example.com'
          : '${Uri.base.origin}/login';
      _run(() => auth.sendSignInLink(_email.text.trim(), continueUrl));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_mode == _Mode.signIn) {
      _run(() =>
          auth.signInWithEmail(_email.text.trim(), _password.text));
    } else {
      _run(() => auth.register(
          _email.text.trim(), _password.text, _name.text.trim()));
    }
  }

  Widget _modeSwitcher() {
    return Column(
      children: [
        if (_mode != _Mode.emailLink)
          TextButton.icon(
            onPressed: () => setState(() {
              _mode = _Mode.emailLink;
              _error = null;
              _info = null;
            }),
            icon: const Icon(Icons.pin_outlined, size: 18),
            label: const Text('Use a one-time email code instead'),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_mode == _Mode.register
                ? 'Already have an account?'
                : "New here?"),
            TextButton(
              onPressed: () => setState(() {
                _mode = _mode == _Mode.register ? _Mode.signIn : _Mode.register;
                _error = null;
                _info = null;
              }),
              child:
                  Text(_mode == _Mode.register ? 'Sign in' : 'Create account'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _banner(String text, {required bool isError}) {
    final color = isError ? Colors.red : Colors.green;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('or'),
            ),
            Expanded(child: Divider()),
          ],
        ),
      );
}

class _SocialButtons extends StatelessWidget {
  final Future<void> Function(Future<AuthResult> Function()) onRun;
  final AuthProvider auth;
  const _SocialButtons({required this.onRun, required this.auth});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () => onRun(auth.signInWithGoogle),
          icon: const Text('G',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4285F4),
                  fontSize: 18)),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => onRun(auth.signInWithFacebook),
          icon: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
          label: const Text('Continue with Facebook'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }
}
