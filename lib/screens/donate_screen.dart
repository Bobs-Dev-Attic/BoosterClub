import 'package:flutter/material.dart';

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
        ],
      ),
    );
  }

  void _donate() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.favorite, color: Colors.pink),
        title: const Text('Thank you!'),
        content: Text(
          'This is a demo checkout. In production this would open a secure '
          'payment provider (e.g. Stripe) for your \$$_amount '
          '${_frequency.toLowerCase()} gift to "$_designation".',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
