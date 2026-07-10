import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Public directory of the club's standing volunteer committees (Concessions,
/// School Store, Mulch Sale, …). Each committee lists its team roles, details
/// and a contact so parents can find where to get involved.
class CommitteesScreen extends StatelessWidget {
  const CommitteesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Committees',
            icon: Icons.groups_2,
            subtitle:
                'Our standing committees and the teams that run them — find '
                'where you\'d like to pitch in.',
          ),
          StreamListView<Committee>(
            stream: fs.committees(),
            emptyIcon: Icons.groups_2_outlined,
            emptyMessage: 'No committees listed yet. Check back soon!',
            builder: (context, committees) => LayoutBuilder(
              builder: (context, constraints) {
                // Two columns on wide screens, one on narrow.
                final twoUp = constraints.maxWidth >= 720;
                final cardWidth = twoUp
                    ? (constraints.maxWidth - 20) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    for (final c in committees)
                      SizedBox(
                          width: cardWidth, child: _CommitteeCard(committee: c)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CommitteeCard extends StatelessWidget {
  final Committee committee;
  const _CommitteeCard({required this.committee});

  Future<void> _email() async {
    final uri = Uri(scheme: 'mailto', path: committee.contactEmail);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = committee;
    final centered = Theme.of(context)
        .textTheme
        .bodyLarge
        ?.copyWith(height: 1.4);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              c.title,
              textAlign: TextAlign.center,
              style: displayFont(context, size: 26)
                  .copyWith(color: scheme.primary),
            ),
            if (c.schedule.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                c.schedule,
                textAlign: TextAlign.center,
                style: centered?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
            if (c.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(c.description, textAlign: TextAlign.center, style: centered),
            ],
            if (c.teamRoles.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('TEAM',
                  textAlign: TextAlign.center,
                  style: centered?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final role in c.teamRoles)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child:
                      Text(role, textAlign: TextAlign.center, style: centered),
                ),
            ],
            for (final s in c.sections) ...[
              const SizedBox(height: 18),
              Text(s.heading,
                  textAlign: TextAlign.center,
                  style: centered?.copyWith(fontWeight: FontWeight.w700)),
              if (s.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(s.body, textAlign: TextAlign.center, style: centered),
              ],
            ],
            if (c.highlight.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  c.highlight,
                  textAlign: TextAlign.center,
                  style: centered?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
            if (c.contactEmail.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Questions?',
                  textAlign: TextAlign.center,
                  style: centered?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              InkWell(
                onTap: _email,
                child: Text(
                  c.contactEmail,
                  textAlign: TextAlign.center,
                  style: centered?.copyWith(
                    color: scheme.primary,
                    decoration: TextDecoration.underline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
