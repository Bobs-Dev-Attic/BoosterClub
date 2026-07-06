import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';

/// QR-code sign-in.
///
/// The desktop/web app displays a QR code encoding a short-lived pairing token.
/// A user who is already signed in on their phone scans it (from their phone's
/// authenticated session) to approve the login; a Cloud Function then mints a
/// Firebase custom token which this screen exchanges via
/// [AuthProvider.signInWithQrToken]. In demo mode the "Simulate scan" button
/// completes the flow instantly.
class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen> {
  // A stable pseudo-token for this pairing session. Derived deterministically
  // so we don't need Date.now()/random at build time.
  late final String _pairingToken =
      'bc-pair-${identityHashCode(this).toRadixString(16)}';

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final payload =
        '${Uri.base.origin}/pair?token=$_pairingToken';
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
                    'Scan this code with the ${AppConfig.appName} app on your '
                    'phone (while signed in) to sign in here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: QrImageView(
                      data: payload,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text('Waiting for approval…',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (AppConfig.demoMode)
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              await auth.signInWithQrToken(_pairingToken);
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
}
