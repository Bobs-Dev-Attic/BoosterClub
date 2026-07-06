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
    final end = event.endsAt;
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
                    runSpacing: 4,
                    children: [
                      if (d != null)
                        _meta(context, Icons.schedule, _timeRange(d, end)),
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

  /// Formats a start–end range: same day → "6:00 PM – 8:00 PM";
  /// different days → "Jul 26, 6:00 PM – Jul 27, 9:00 AM".
  String _timeRange(DateTime start, DateTime? end) {
    final t = DateFormat('h:mm a');
    if (end == null) return t.format(start);
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (sameDay) return '${t.format(start)} – ${t.format(end)}';
    final dt = DateFormat('MMM d, h:mm a');
    return '${t.format(start)} – ${dt.format(end)}';
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
        color: scheme.primary.withValues(alpha: 0.1),
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
