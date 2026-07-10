import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Public "Leadership & Committees" directory. Shows the club's leadership
/// groups (Executive Committee, Class Chairs, …) and its working committees,
/// each with its positions and how to get involved.
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
            title: 'Leadership & Committees',
            icon: Icons.groups_2,
            subtitle:
                'Our leadership team and standing committees — and where '
                'you\'d like to pitch in.',
          ),
          StreamListView<Committee>(
            stream: fs.committees(),
            emptyIcon: Icons.groups_2_outlined,
            emptyMessage: 'No committees listed yet. Check back soon!',
            builder: (context, committees) {
              final leadership =
                  committees.where((c) => c.isLeadership).toList();
              final working =
                  committees.where((c) => !c.isLeadership).toList();
              final open = [
                for (final c in committees)
                  for (final p in c.openPositions) (group: c.title, pos: p),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leadership.isNotEmpty) ...[
                    _subheader(context, 'Leadership'),
                    const SizedBox(height: 12),
                    _grid(leadership, minWidth: 300, maxColumns: 3),
                    const SizedBox(height: 28),
                  ],
                  if (open.isNotEmpty) ...[
                    _OpenPositions(open: open),
                    const SizedBox(height: 28),
                  ],
                  if (working.isNotEmpty) ...[
                    _subheader(context, 'Committees'),
                    const SizedBox(height: 12),
                    _grid(working, minWidth: 340, maxColumns: 2),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _subheader(BuildContext context, String text) => Text(
        text,
        style: displayFont(context, size: 22)
            .copyWith(color: Theme.of(context).colorScheme.primary),
      );

  Widget _grid(List<Committee> items,
      {required double minWidth, required int maxColumns}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            (constraints.maxWidth / minWidth).floor().clamp(1, maxColumns);
        final cardWidth =
            (constraints.maxWidth - (columns - 1) * 20) / columns;
        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            for (final c in items)
              SizedBox(width: cardWidth, child: _CommitteeCard(committee: c)),
          ],
        );
      },
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
    final body =
        Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4);
    final bold = body?.copyWith(fontWeight: FontWeight.w700);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(c.title,
                textAlign: TextAlign.center,
                style: displayFont(context, size: 24)
                    .copyWith(color: scheme.primary)),
            if (c.schedule.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(c.schedule, textAlign: TextAlign.center, style: bold),
            ],
            if (c.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(c.description, textAlign: TextAlign.center, style: body),
            ],
            // Named positions (Chair — Dawn Harris, President — …).
            if (c.positions.isNotEmpty) ...[
              const SizedBox(height: 18),
              for (final p in c.positions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _positionLine(context, p, body, bold),
                ),
            ],
            // Generic role titles (no assigned person) — the flyer "TEAM".
            if (c.teamRoles.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('TEAM', textAlign: TextAlign.center, style: bold),
              const SizedBox(height: 6),
              for (final role in c.teamRoles)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child:
                      Text(role, textAlign: TextAlign.center, style: body),
                ),
            ],
            for (final s in c.sections) ...[
              const SizedBox(height: 18),
              Text(s.heading, textAlign: TextAlign.center, style: bold),
              if (s.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(s.body, textAlign: TextAlign.center, style: body),
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
                child: Text(c.highlight,
                    textAlign: TextAlign.center,
                    style: body?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700)),
              ),
            ],
            if (c.contactEmail.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Questions?',
                  textAlign: TextAlign.center,
                  style: body?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              InkWell(
                onTap: _email,
                child: Text(c.contactEmail,
                    textAlign: TextAlign.center,
                    style: body?.copyWith(
                      color: scheme.primary,
                      decoration: TextDecoration.underline,
                      fontStyle: FontStyle.italic,
                    )),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _positionLine(BuildContext context, CommitteePosition p,
      TextStyle? body, TextStyle? bold) {
    final scheme = Theme.of(context).colorScheme;
    if (p.isOpen) {
      return Text.rich(
        TextSpan(children: [
          TextSpan(text: '${p.title} — ', style: bold),
          TextSpan(
              text: 'OPEN', style: bold?.copyWith(color: scheme.tertiary)),
        ]),
        textAlign: TextAlign.center,
      );
    }
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '${p.title} — ', style: bold),
        TextSpan(text: p.holder, style: body),
      ]),
      textAlign: TextAlign.center,
    );
  }
}

/// A compact call-out listing every unfilled position across all groups.
class _OpenPositions extends StatelessWidget {
  final List<({String group, CommitteePosition pos})> open;
  const _OpenPositions({required this.open});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volunteer_activism, color: scheme.tertiary),
              const SizedBox(width: 8),
              Text('Open positions — we\'d love your help!',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final o in open)
                Chip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text('${o.pos.title} · ${o.group}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
