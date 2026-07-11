import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Public "Leadership & Committees" directory. Shows the club's leadership
/// groups (Executive Committee, Class Chairs, …) and its working committees,
/// each with its roles and the members assigned to them.
///
/// Roles come from the committee document; who fills each role comes from the
/// separate `committee_members` join collection — so this screen combines both
/// streams and groups members under the role(s) they hold.
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
          StreamBuilder<List<Committee>>(
            stream: fs.committees(),
            builder: (context, cSnap) {
              final committees = cSnap.data;
              if (committees == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (committees.isEmpty) {
                return const EmptyState(
                  icon: Icons.groups_2_outlined,
                  message: 'No committees listed yet. Check back soon!',
                );
              }
              // Members arrive on their own stream; render committees as soon as
              // they load and fill members in when that stream emits.
              return StreamBuilder<List<CommitteeMember>>(
                stream: fs.committeeMembers(),
                builder: (context, mSnap) {
                  final members = mSnap.data ?? const <CommitteeMember>[];
                  // committeeId -> that committee's members.
                  final byCommittee = <String, List<CommitteeMember>>{};
                  for (final m in members) {
                    byCommittee.putIfAbsent(m.committeeId, () => []).add(m);
                  }
                  return _buildBody(context, committees, byCommittee);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Committee> committees,
      Map<String, List<CommitteeMember>> byCommittee) {
    final leadership = committees.where((c) => c.isLeadership).toList();
    final working = committees.where((c) => !c.isLeadership).toList();

    // Every role with nobody assigned, across all groups → the "open" call-out.
    final open = <({String group, String role})>[];
    for (final c in committees) {
      final assigned = _roleIdsWithMembers(byCommittee[c.id]);
      for (final r in c.roles) {
        if (!assigned.contains(r.id)) {
          open.add((group: c.title, role: r.title));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leadership.isNotEmpty) ...[
          _subheader(context, 'Leadership'),
          const SizedBox(height: 12),
          _grid(leadership, byCommittee, minWidth: 300, maxColumns: 3),
          const SizedBox(height: 28),
        ],
        if (open.isNotEmpty) ...[
          _OpenPositions(open: open),
          const SizedBox(height: 28),
        ],
        if (working.isNotEmpty) ...[
          _subheader(context, 'Committees'),
          const SizedBox(height: 12),
          _grid(working, byCommittee, minWidth: 340, maxColumns: 2),
        ],
      ],
    );
  }

  /// The set of role ids that have at least one member in [members].
  static Set<String> _roleIdsWithMembers(List<CommitteeMember>? members) {
    final ids = <String>{};
    for (final m in (members ?? const <CommitteeMember>[])) {
      ids.addAll(m.roleIds);
    }
    return ids;
  }

  Widget _subheader(BuildContext context, String text) => Text(
        text,
        style: displayFont(context, size: 22)
            .copyWith(color: Theme.of(context).colorScheme.primary),
      );

  Widget _grid(List<Committee> items,
      Map<String, List<CommitteeMember>> byCommittee,
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
              SizedBox(
                width: cardWidth,
                child: _CommitteeCard(
                    committee: c,
                    members: byCommittee[c.id] ?? const []),
              ),
          ],
        );
      },
    );
  }
}

class _CommitteeCard extends StatelessWidget {
  final Committee committee;
  final List<CommitteeMember> members;
  const _CommitteeCard({required this.committee, required this.members});

  Future<void> _email() async {
    final uri = Uri(scheme: 'mailto', path: committee.contactEmail);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// role id -> the names of members holding that role.
  Map<String, List<String>> _membersByRole() {
    final map = <String, List<String>>{};
    for (final m in members) {
      for (final id in m.roleIds) {
        map.putIfAbsent(id, () => []).add(m.userName);
      }
    }
    return map;
  }

  /// Members who belong to the committee but hold no specific role.
  List<String> _roleless() =>
      [for (final m in members) if (m.roleIds.isEmpty) m.userName];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = committee;
    final body = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4);
    final bold = body?.copyWith(fontWeight: FontWeight.w700);
    final byRole = _membersByRole();
    final roleless = _roleless();

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
            // Each role with the member(s) who hold it (or OPEN when unfilled).
            if (c.roles.isNotEmpty) ...[
              const SizedBox(height: 18),
              for (final role in c.roles)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _roleLine(context, role.title,
                      byRole[role.id] ?? const [], body, bold, scheme),
                ),
            ],
            // Members with no specific role.
            if (roleless.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Members', textAlign: TextAlign.center, style: bold),
              const SizedBox(height: 4),
              Text(roleless.join(', '),
                  textAlign: TextAlign.center, style: body),
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

  Widget _roleLine(BuildContext context, String roleTitle, List<String> holders,
      TextStyle? body, TextStyle? bold, ColorScheme scheme) {
    if (holders.isEmpty) {
      return Text.rich(
        TextSpan(children: [
          TextSpan(text: '$roleTitle — ', style: bold),
          TextSpan(text: 'OPEN', style: bold?.copyWith(color: scheme.tertiary)),
        ]),
        textAlign: TextAlign.center,
      );
    }
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '$roleTitle — ', style: bold),
        TextSpan(text: holders.join(', '), style: body),
      ]),
      textAlign: TextAlign.center,
    );
  }
}

/// A compact call-out listing every unfilled role across all groups.
class _OpenPositions extends StatelessWidget {
  final List<({String group, String role})> open;
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
              Text('Open roles — we\'d love your help!',
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
                  label: Text('${o.role} · ${o.group}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
