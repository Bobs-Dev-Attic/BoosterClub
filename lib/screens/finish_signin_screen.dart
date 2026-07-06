import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/common.dart';

/// Landing page for the passwordless email link. Completes the one-time sign-in.
/// If the email that requested the link was saved on this device it completes
/// automatically; otherwise it asks the user to confirm their email (e.g. when
/// the link is opened on a different device).
class FinishSignInScreen extends StatefulWidget {
  const FinishSignInScreen({super.key});

  @override
  State<FinishSignInScreen> createState() => _FinishSignInScreenState();
}

class _FinishSignInScreenState extends State<FinishSignInScreen> {
  final _email = TextEditingController();
  bool _working = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _attempt();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String get _link => Uri.base.toString();

  Future<void> _attempt() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isSignInLink(_link)) {
      // Not an email link — nothing to do here.
      if (mounted) context.go('/login');
      return;
    }
    final saved = await auth.savedEmailForSignIn();
    if (saved != null && saved.isNotEmpty) {
      final res = await auth.completeSignInWithLink(saved, _link);
      if (!mounted) return;
      if (res.success) {
        context.go('/');
        return;
      }
      setState(() {
        _error = res.message;
        _working = false;
      });
    } else {
      setState(() => _working = false);
    }
  }

  Future<void> _submitEmail() async {
    final auth = context.read<AuthProvider>();
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Enter the email you requested the link with.');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    final res = await auth.completeSignInWithLink(_email.text.trim(), _link);
    if (!mounted) return;
    if (res.success) {
      context.go('/');
    } else {
      setState(() {
        _error = res.message ?? 'Could not complete sign-in.';
        _working = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      maxWidth: 440,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const SectionHeader(
              title: 'Finishing sign-in', icon: Icons.mark_email_read_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _working
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Confirm the email address you used to request the '
                          'one-time sign-in link.',
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _submitEmail,
                          child: const Text('Complete sign-in'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Back to sign in'),
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
