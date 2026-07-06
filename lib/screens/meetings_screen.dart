import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_models.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';

class MeetingsScreen extends StatelessWidget {
  const MeetingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Meetings & Minutes',
            icon: Icons.groups,
            subtitle: 'Upcoming meetings and archived minutes.',
          ),
          StreamListView<Meeting>(
            stream: fs.meetings(),
            emptyIcon: Icons.groups_outlined,
            emptyMessage: 'No meetings posted yet.',
            builder: (context, items) => Column(
              children: [for (final m in items) _MeetingTile(m)],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingTile extends StatelessWidget {
  final Meeting m;
  const _MeetingTile(this.m);

  @override
  Widget build(BuildContext context) {
    final hasMinutes = m.minutesUrl != null && m.minutesUrl!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_note,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(m.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (hasMinutes)
                  const Pill('Minutes', icon: Icons.description, color: Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                if (m.meetingDate != null)
                  _meta(context, Icons.calendar_today,
                      DateFormat('EEE, MMM d, yyyy').format(m.meetingDate!)),
                if (m.location.isNotEmpty)
                  _meta(context, Icons.place, m.location),
              ],
            ),
            const SizedBox(height: 8),
            Text(m.description,
                style: Theme.of(context).textTheme.bodyMedium),
            if (hasMinutes) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _open(m.minutesUrl!),
                icon: const Icon(Icons.download),
                label: const Text('View minutes'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _meta(BuildContext context, IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
        ],
      );
}
