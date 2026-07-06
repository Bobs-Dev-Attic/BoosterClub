import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/content_models.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'School Events',
            icon: Icons.event,
            subtitle: 'Games, performances and community gatherings.',
          ),
          StreamListView<SchoolEvent>(
            stream: fs.events(),
            emptyIcon: Icons.event_busy,
            emptyMessage: 'No events scheduled yet. Check back soon!',
            builder: (context, events) => Column(
              children: [for (final e in events) _EventTile(e)],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final SchoolEvent event;
  const _EventTile(this.event);

  @override
  Widget build(BuildContext context) {
    final d = event.startsAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateBadge(date: d),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (d != null)
                        _meta(context, Icons.schedule,
                            DateFormat('h:mm a').format(d)),
                      if (event.location.isNotEmpty)
                        _meta(context, Icons.place, event.location),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(event.description,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

class _DateBadge extends StatelessWidget {
  final DateTime? date;
  const _DateBadge({this.date});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            date != null ? DateFormat('MMM').format(date!).toUpperCase() : '—',
            style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12),
          ),
          Text(
            date != null ? DateFormat('d').format(date!) : '',
            style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 22),
          ),
        ],
      ),
    );
  }
}
