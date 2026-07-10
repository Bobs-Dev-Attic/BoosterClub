import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/content_models.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class VolunteeringScreen extends StatelessWidget {
  const VolunteeringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Volunteering',
            icon: Icons.volunteer_activism,
            subtitle: 'Lend a hand — every shift makes a difference.',
          ),
          const _VolunteerIntro(),
          const SizedBox(height: 24),
          StreamListView<VolunteerOpportunity>(
            stream: fs.volunteering(),
            emptyIcon: Icons.handshake_outlined,
            emptyMessage: 'No open opportunities right now.',
            builder: (context, items) => ResponsiveGrid(
              children: [for (final o in items) _OppCard(o)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Welcoming call-to-action shown above the list of open opportunities.
class _VolunteerIntro extends StatelessWidget {
  const _VolunteerIntro();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45);
    final bold = body?.copyWith(fontWeight: FontWeight.w700);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.12),
            scheme.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_people, color: scheme.primary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Show Your Walter Johnson Pride! VOLUNTEER for Boosters!',
                  style: displayFont(context, size: 22)
                      .copyWith(color: scheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: body,
              children: [
                const TextSpan(
                    text:
                        'We need great parents '),
                TextSpan(text: 'LIKE YOU', style: bold),
                const TextSpan(
                    text:
                        ' to help raise money, show school spirit and '),
                TextSpan(text: 'HAVE FUN!', style: bold),
                const TextSpan(
                    text:
                        '  We have jobs that can fit any schedule (daytime/nighttime, '
                        'weekdays/weekends, fall/winter/spring/summer), location (at '
                        'home or in-person), and skill set/interest.  We do everything '
                        'in teams, so it’s manageable…we can make it work, we '
                        'promise!'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: body,
              children: [
                TextSpan(text: 'BONUS: ', style: bold),
                const TextSpan(
                    text:
                        'You get to meet other great parents and find out what is '
                        'happening at WJ!'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'If you don’t know which job is right for you, just reach out. '
            'We’d be happy to discuss our committees and ways you can get '
            'involved!',
            style: body,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.celebration, color: scheme.onPrimary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'EVERYONE IS WELCOME TO JOIN US!',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
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

class _OppCard extends StatelessWidget {
  final VolunteerOpportunity opp;
  const _OppCard(this.opp);

  @override
  Widget build(BuildContext context) {
    final full = opp.spotsRemaining == 0 && opp.spotsNeeded > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (opp.date != null)
                  Pill(DateFormat('MMM d').format(opp.date!),
                      icon: Icons.calendar_today),
                const Spacer(),
                Pill(
                  full ? 'Full' : '${opp.spotsRemaining} spots left',
                  color: full ? Colors.grey : Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(opp.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                opp.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: full ? null : () => _signUp(context),
                child: Text(full ? 'Full' : 'Sign up'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _signUp(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (!auth.isSignedIn) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Please sign in to volunteer.')));
      return;
    }
    messenger.showSnackBar(SnackBar(
        content: Text('Thanks for signing up for "${opp.title}"!')));
  }
}
