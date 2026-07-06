import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/common.dart';

/// Phone side of QR sign-in. Opened by scanning the QR shown on another device
/// (URL: /pair?s=<sessionId>). The already-signed-in user reviews and approves,
/// which mints a token onto the session so the other device can sign in.
class PairScreen extends StatefulWidget {
  final String sessionId;
  const PairScreen({super.key, required this.sessionId});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  bool _busy = false;
  bool _approved = false;
  String? _error;

  Future<void> _approve() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await auth.approveQrSession(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res.success) {
        _approved = true;
      } else {
        _error = res.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return PageBody(
      maxWidth: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const SectionHeader(
              title: 'Approve sign-in', icon: Icons.qr_code_scanner),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: !auth.isSignedIn
                  ? Column(
                      children: [
                        const EmptyState(
                          icon: Icons.lock_outline,
                          message:
                              'Sign in on this device first, then reopen the QR '
                              'link to approve.',
                        ),
                        FilledButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Sign in'),
                        ),
                      ],
                    )
                  : _approved
                      ? Column(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 56),
                            const SizedBox(height: 12),
                            Text('Approved!',
                                style:
                                    Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 6),
                            const Text(
                              'Your other device will be signed in momentarily. '
                              'You can close this page.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: () => context.go('/'),
                              child: const Text('Done'),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            const Icon(Icons.devices_other, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Sign in as ${user!.displayName} on the other '
                              'device?',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Only approve if you just scanned this code on a '
                              'device you trust.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: const TextStyle(color: Colors.red)),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => context.go('/'),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _busy ? null : _approve,
                                    child: _busy
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Text('Approve'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
