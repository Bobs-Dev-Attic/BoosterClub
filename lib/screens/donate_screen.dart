import 'package:flutter/material.dart';

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
