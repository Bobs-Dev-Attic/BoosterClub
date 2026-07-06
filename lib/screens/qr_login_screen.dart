import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';

/// QR-code sign-in (device side that wants to sign in — e.g. a laptop).
///
/// Creates a pending pairing session and displays a QR code encoding a
/// `/pair?s=<id>` link. A phone that is already signed in scans it and approves;
/// a Cloud Function mints a custom token onto the session, which this screen
/// then exchanges to sign in. In demo mode a "Simulate scan" button completes
/// the flow instantly.
class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen> {
  String? _sessionId;
  StreamSubscription<Map<String, dynamic>?>? _sub;
  bool _signingIn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final auth = context.read<AuthProvider>();
    if (AppConfig.demoMode) {
      setState(() => _sessionId = 'demo-session');
      return;
    }
    try {
      final id = await auth.createQrSession();
      if (!mounted) return;
      setState(() => _sessionId = id);
      _sub = auth.watchQrSession(id).listen((data) async {
        final token = data?['token'] as String?;
        if (token != null && !_signingIn) {
          setState(() => _signingIn = true);
          final res = await auth.signInWithQrToken(token, sessionId: id);
          if (!mounted) return;
          if (res.success) {
            context.go('/');
          } else {
            setState(() {
              _error = res.message;
              _signingIn = false;
            });
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String get _payload {
    final base = Uri.base.origin.isEmpty ? 'https://example.com' : Uri.base.origin;
    return '$base/#/pair?s=$_sessionId';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return PageBody(
      maxWidth: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              const Text('QR Sign-in',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Text(
                    'Open the ${AppConfig.appName} app on your phone (while '
                    'signed in) and scan this code to sign in here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    _errorBox(_error!)
                  else if (_sessionId == null)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: QrImageView(
                        data: _payload,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_sessionId != null && _error == null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(_signingIn ? 'Signing you in…' : 'Waiting for approval…',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  const SizedBox(height: 20),
                  if (AppConfig.demoMode)
                    FilledButton.icon(
                      onPressed: _signingIn
                          ? null
                          : () async {
                              setState(() => _signingIn = true);
                              await auth.signInWithQrToken('demo');
                              if (context.mounted) context.go('/');
                            },
                      icon: const Icon(Icons.check),
                      label: const Text('Simulate scan (demo)'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.password),
              label: const Text('Use another method'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(color: Colors.red))),
          ],
        ),
      );
}
