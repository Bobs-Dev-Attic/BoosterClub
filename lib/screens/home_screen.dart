import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/history_section.dart';
import '../widgets/nav_destinations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return PageBody(
      maxWidth: 1200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              // On wide screens, put "This Day in Wildcat History" beside the
              // hero to fill the space to its right; stack them when narrow.
              if (c.maxWidth >= 900) {
                return const IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _Hero()),
                      SizedBox(width: 20),
                      Expanded(flex: 2, child: HistorySection(fill: true)),
                    ],
                  ),
                );
              }
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Hero(),
                  SizedBox(height: 24),
                  HistorySection(),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          _QuickLinks(),
          const SizedBox(height: 32),
          SectionHeader(
            title: 'Upcoming Events',
            icon: Icons.event,
            action: TextButton(
              onPressed: () => context.go('/events'),
              child: const Text('See all'),
            ),
          ),
          StreamListView(
            stream: fs.events(),
            emptyMessage: 'No upcoming events yet.',
            builder: (context, events) {
              final upcoming = events.take(3).toList();
              return ResponsiveGrid(
                children: [
                  for (final e in upcoming)
                    _MiniCard(
                      title: e.title,
                      subtitle: e.startsAt != null
                          ? DateFormat('EEE, MMM d · h:mm a').format(e.startsAt!)
                          : 'Date TBD',
                      body: e.description,
                      icon: Icons.event,
                      onTap: () => context.go('/events'),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Fundraising Progress',
            icon: Icons.savings,
            action: TextButton(
              onPressed: () => context.go('/fundraisers'),
              child: const Text('See all'),
            ),
          ),
          StreamListView(
            stream: fs.fundraisers(),
            emptyMessage: 'No active fundraisers.',
            builder: (context, list) => Column(
              children: [
                for (final f in list.take(2))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.title,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: f.progress,
                              minHeight: 10,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '\$${f.raisedAmount.toStringAsFixed(0)} of \$${f.goalAmount.toStringAsFixed(0)} '
                            '(${(f.progress * 100).toStringAsFixed(0)}%)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          // Base fill so the tinted overlay always sits on green.
          const Positioned.fill(child: ColoredBox(color: AppTheme.green)),
          // Optional school photo behind the hero. Drop a JPG at
          // assets/images/wj-frontb.jpg to show the building faded/tinted;
          // absent, it silently falls back to the plain green gradient.
          Positioned.fill(
            child: Image.asset(
              'assets/images/wj-frontb.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          // Green tint over the photo (semi-transparent so it shows through).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.green.withValues(alpha: 0.86),
                    const Color(0xFF0AA64F).withValues(alpha: 0.78),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(wide ? 40 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          const Pill('${AppConfig.schoolName} Booster Club',
              color: Colors.white, icon: Icons.star),
          const SizedBox(height: 16),
          Text(
            'Go ${AppConfig.mascot}! 🐾',
            style: displayFont(context, size: wide ? 44 : 32, color: Colors.white),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 620,
            child: Text(
              'Supporting our student athletes, performers and clubs through '
              'volunteering, sponsorships and community fundraising. Browse '
              'events, lend a hand, or chip in — every bit helps.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.green,
                ),
                onPressed: () => context.go('/donate'),
                icon: const Icon(Icons.favorite),
                label: const Text('Donate'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.go('/volunteering'),
                icon: const Icon(Icons.volunteer_activism),
                label: const Text('Volunteer'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                ),
                onPressed: () => context.go('/funding'),
                icon: const Icon(Icons.request_quote),
                label: const Text('Funding Request'),
              ),
              if (!auth.isSignedIn)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Become a member'),
                ),
            ],
          ),
          if (AppConfig.demoMode) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Demo mode — sample data. Configure Firebase to go live. '
                      'Tip: sign in with any "admin@…" email to explore admin tools.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final links = kSections.where((s) => s.route != '/').toList();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final s in links)
          ActionChip(
            avatar: Icon(s.icon, size: 18),
            label: Text(s.label),
            onPressed: () => context.go(s.route),
          ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String body;
  final IconData icon;
  final VoidCallback onTap;
  const _MiniCard({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(subtitle,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            )),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
