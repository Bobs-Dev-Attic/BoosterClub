import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
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
          const _Hero(),
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 40 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppTheme.navy, Color(0xFF1E4A8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pill('${AppConfig.schoolName} Booster Club',
              color: AppTheme.gold, icon: Icons.star),
          const SizedBox(height: 16),
          Text(
            'Go Lions! 🦁',
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
                  color: Colors.white.withOpacity(0.9),
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
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.navy,
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
              if (!auth.isSignedIn)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.5)),
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
                color: Colors.white.withOpacity(0.12),
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
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
