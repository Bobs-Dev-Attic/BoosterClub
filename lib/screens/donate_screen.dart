import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user.dart';
import '../models/donation.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/paypal_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  static const _presets = [25, 50, 100, 250, 500];
  int? _selected = 50;
  final _custom = TextEditingController();
  String _frequency = 'One-time';
  String? _designation = 'Greatest Need';

  static const _designations = [
    'Greatest Need',
    'Athletics',
    'Performing Arts',
    'Scholarships',
    'Facilities',
  ];

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  int get _amount =>
      _selected ?? int.tryParse(_custom.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return PageBody(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Make a Donation',
            icon: Icons.favorite,
            subtitle:
                'Your tax-deductible gift directly supports our students.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose an amount',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final p in _presets)
                        ChoiceChip(
                          label: Text('\$$p'),
                          selected: _selected == p,
                          onSelected: (_) => setState(() {
                            _selected = p;
                            _custom.clear();
                          }),
                        ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _custom,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            prefixText: '\$ ',
                            hintText: 'Custom',
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() => _selected = null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Frequency',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'One-time', label: Text('One-time')),
                      ButtonSegment(value: 'Monthly', label: Text('Monthly')),
                    ],
                    selected: {_frequency},
                    onSelectionChanged: (s) =>
                        setState(() => _frequency = s.first),
                  ),
                  const SizedBox(height: 20),
                  Text('Designation',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _designation,
                    items: [
                      for (final d in _designations)
                        DropdownMenuItem(value: d, child: Text(d)),
                    ],
                    onChanged: (v) => setState(() => _designation = v),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _amount > 0 ? _donate : null,
                      icon: const Icon(Icons.lock_outline),
                      label: Text(_amount > 0
                          ? 'Donate \$$_amount ${_frequency == 'Monthly' ? '/mo' : ''}'
                          : 'Enter an amount'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.verified_user_outlined,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Secure checkout. The Booster Club is a registered 501(c)(3) nonprofit; donations may be tax-deductible.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const _PoweringStudentSuccess(),
        ],
      ),
    );
  }

  void _donate() {
    final fs = context.read<FirestoreService>();
    final user = context.read<AuthProvider>().user;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CheckoutDialog(
        fs: fs,
        user: user,
        amount: _amount.toDouble(),
        frequency: _frequency == 'Monthly' ? 'monthly' : 'one-time',
        designation: _designation ?? 'Greatest Need',
      ),
    );
  }
}

/// Drives a single donation: writes the pending Firestore record, sends the
/// donor to PayPal, then waits for the backend (capture + webhook) to confirm.
/// In demo mode it simulates the whole handshake so the flow is previewable.
class _CheckoutDialog extends StatefulWidget {
  final FirestoreService fs;
  final AppUser? user;
  final double amount;
  final String frequency;
  final String designation;
  const _CheckoutDialog({
    required this.fs,
    required this.user,
    required this.amount,
    required this.frequency,
    required this.designation,
  });

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

enum _Phase { form, waiting, done, error }

class _CheckoutDialogState extends State<_CheckoutDialog> {
  late final PayPalService _paypal = PayPalService();
  late final TextEditingController _name =
      TextEditingController(text: widget.user?.displayName ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.user?.email ?? '');

  _Phase _phase = _Phase.form;
  String? _error;
  String? _donationId;
  StreamSubscription<Donation?>? _sub;
  bool _capturing = false;

  bool get _signedIn => widget.user != null;

  @override
  void dispose() {
    _sub?.cancel();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your name and a valid email.');
      return;
    }
    setState(() {
      _error = null;
      _phase = _Phase.waiting;
    });

    try {
      final id = await widget.fs.createPendingDonation(Donation(
        id: 'new',
        uid: widget.user?.uid,
        donorName: name,
        donorEmail: email,
        amount: widget.amount,
        frequency: widget.frequency,
        designation: widget.designation,
      ));
      _donationId = id;

      // Watch for the backend to confirm the payment.
      _sub = widget.fs.donationDoc(id).listen((d) {
        if (d != null && d.status == DonationStatus.completed && mounted) {
          setState(() => _phase = _Phase.done);
        }
      });

      if (_paypal.isLive) {
        final order = await _paypal.createOrder(id);
        final uri = Uri.tryParse(order.approveUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        // Stay in `waiting`; the doc listener flips to `done` once the webhook
        // (or the manual "I've paid" capture below) confirms.
      } else {
        // Demo: simulate PayPal approving + the webhook confirming.
        await Future.delayed(const Duration(milliseconds: 900));
        await widget.fs.simulateDonationCompleted(id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _capture() async {
    if (_donationId == null) return;
    setState(() => _capturing = true);
    try {
      final ok = await _paypal.captureOrder(_donationId!);
      if (ok && mounted) setState(() => _phase = _Phase.done);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not confirm yet: $e');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.done:
        return AlertDialog(
          icon: const Icon(Icons.favorite, color: Colors.pink),
          title: const Text('Thank you!'),
          content: Text(
            'Your \$${widget.amount.toStringAsFixed(0)} '
            '${widget.frequency == 'monthly' ? 'monthly ' : ''}gift to '
            '"${widget.designation}" is confirmed. A receipt will be emailed '
            'to ${_email.text.trim()}.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      case _Phase.waiting:
        return AlertDialog(
          title: const Text('Completing your donation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _paypal.isLive
                    ? 'Finish your payment in the PayPal window. This page will '
                        'update automatically once it’s confirmed.'
                    : 'Processing your demo donation…',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            if (_paypal.isLive) ...[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _capturing ? null : _capture,
                child: _capturing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('I’ve completed payment'),
              ),
            ],
          ],
        );
      case _Phase.error:
        return AlertDialog(
          icon: const Icon(Icons.error_outline, color: Colors.red),
          title: const Text('Something went wrong'),
          content: Text(_error ?? 'Please try again.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      case _Phase.form:
        return AlertDialog(
          title: const Text('Confirm your donation'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _summaryRow('Amount',
                    '\$${widget.amount.toStringAsFixed(0)}'
                    '${widget.frequency == 'monthly' ? ' / month' : ''}'),
                _summaryRow('Designation', widget.designation),
                const Divider(height: 24),
                if (!_signedIn) ...[
                  const Text('Where should we send your receipt?',
                      style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                ] else
                  Text('Receipt will go to ${_email.text.trim()}.',
                      style: Theme.of(context).textTheme.bodySmall),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),
                Text(
                  _paypal.isLive
                      ? 'You’ll be taken to PayPal to complete payment securely.'
                      : 'Demo mode: no live PayPal account is configured, so '
                          'this records a simulated donation.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.lock_outline, size: 18),
              label: Text(_paypal.isLive ? 'Continue to PayPal' : 'Donate'),
            ),
          ],
        );
    }
  }

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

/// Shows where donations go — the Booster Club's 2026–2027 investments across
/// clubs, athletics, school-wide support and events.
class _PoweringStudentSuccess extends StatelessWidget {
  const _PoweringStudentSuccess();

  static const _groups = <_InvestGroup>[
    _InvestGroup('Clubs & Activities', Icons.groups, [
      'DECA competition fees',
      'Fashion Club equipment',
      'Girls Learn International — care kits',
      'Mock Trial fees',
      'Robotics Club — equipment & fees',
      'Science Olympiad equipment',
      'Youth in Government fees',
    ]),
    _InvestGroup('Athletics', Icons.sports, [
      'Baseball — state champ t-shirts',
      'Boys Lacrosse — helmets',
      'Football — community night supplies',
      'Swim — state champ t-shirts',
      'Volleyball — nets',
      'Wrestling — warmups & singlets',
    ]),
    _InvestGroup('School-Wide Support', Icons.school, [
      'Gym area — TV / Firestick',
      'Main office — chairs',
      'The Pitch / Spectator — equipment & printing',
      'WJ Production / Stage — wireless headphones',
      'Weight room — dehumidifiers & vinyl wraps',
    ]),
    _InvestGroup('Events & Appreciation', Icons.celebration, [
      'Building Services luncheon',
      'Kennedy HS Booster Club donation',
      'Key Club / COHE — senior citizens Thanksgiving luncheon',
      'Staff ice cream social',
      'Stem4all — science fair',
      'Sue Amos Scholarship',
      'WJ After-Prom party',
      'WJ TEDx Club — event support',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [AppTheme.green, AppTheme.greenDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Powering Student Success',
                  style: displayFont(context, size: 26, color: Colors.white)),
              const SizedBox(height: 4),
              Text('2026–2027 Booster Club investments',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 15)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final two = c.maxWidth >= 640;
          final width = two ? (c.maxWidth - 16) / 2 : c.maxWidth;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final g in _groups)
                SizedBox(width: width, child: _InvestCard(group: g)),
            ],
          );
        }),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Thank you for your generous support — building our future together.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      ],
    );
  }
}

class _InvestGroup {
  final String title;
  final IconData icon;
  final List<String> items;
  const _InvestGroup(this.title, this.icon, this.items);
}

class _InvestCard extends StatelessWidget {
  final _InvestGroup group;
  const _InvestCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(group.icon, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(group.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in group.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
