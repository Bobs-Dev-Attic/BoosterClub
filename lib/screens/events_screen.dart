import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../data/event_categories.dart';
import '../models/content_models.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  // Selected category filters (empty = show all).
  final Set<String> _filters = {};
  // Anchor month for the 3-month calendar.
  DateTime _anchor = DateTime(2026, 7, 1);

  bool _matches(SchoolEvent e) =>
      _filters.isEmpty || _filters.contains(e.category);

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return PageBody(
      maxWidth: 1100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'School Events',
            icon: Icons.event,
            subtitle: 'Games, performances, deadlines, holidays and more.',
          ),
          StreamListView<SchoolEvent>(
            stream: fs.events(),
            emptyIcon: Icons.event_busy,
            emptyMessage: 'No events scheduled yet. Check back soon!',
            builder: (context, allEvents) {
              final events = allEvents.where(_matches).toList()
                ..sort((a, b) => (a.startsAt ?? DateTime(2100))
                    .compareTo(b.startsAt ?? DateTime(2100)));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterBar(
                    selected: _filters,
                    onToggle: (key) => setState(() {
                      if (_filters.contains(key)) {
                        _filters.remove(key);
                      } else {
                        _filters.add(key);
                      }
                    }),
                    onClear: () => setState(_filters.clear),
                  ),
                  const SizedBox(height: 20),
                  _ThreeMonthCalendar(
                    anchor: _anchor,
                    events: events,
                    onPrev: () => setState(() => _anchor =
                        DateTime(_anchor.year, _anchor.month - 1, 1)),
                    onNext: () => setState(() => _anchor =
                        DateTime(_anchor.year, _anchor.month + 1, 1)),
                    onDayTap: (day, dayEvents) =>
                        _showDayEvents(context, day, dayEvents),
                  ),
                  const SizedBox(height: 24),
                  Text('Upcoming',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (events.isEmpty)
                    const EmptyState(
                        icon: Icons.filter_alt_off,
                        message: 'No events match the selected filters.')
                  else
                    for (final e in events)
                      _EventTile(
                          event: e, onTap: () => showEventDetail(context, e)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDayEvents(
      BuildContext context, DateTime day, List<SchoolEvent> dayEvents) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DateFormat('EEEE, MMM d').format(day)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in dayEvents)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(categoryFor(e.category).icon,
                      color: categoryFor(e.category).color),
                  title: Text(e.title),
                  subtitle: (e.startsAt != null && !e.allDay)
                      ? Text(DateFormat('h:mm a').format(e.startsAt!))
                      : (e.allDay ? const Text('All day') : null),
                  onTap: () {
                    Navigator.pop(context);
                    showEventDetail(context, e);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }
}

// ---- Filter bar ----------------------------------------------------------
class _FilterBar extends StatelessWidget {
  final Set<String> selected;
  final void Function(String) onToggle;
  final VoidCallback onClear;
  const _FilterBar(
      {required this.selected, required this.onToggle, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final c in kEventCategories)
          FilterChip(
            avatar: Icon(c.icon,
                size: 18,
                color: selected.contains(c.key) ? Colors.white : c.color),
            label: Text(c.key),
            selected: selected.contains(c.key),
            selectedColor: c.color,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
                color: selected.contains(c.key) ? Colors.white : null),
            onSelected: (_) => onToggle(c.key),
          ),
        if (selected.isNotEmpty)
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear'),
          ),
      ],
    );
  }
}

// ---- 3-month calendar ----------------------------------------------------
class _ThreeMonthCalendar extends StatelessWidget {
  final DateTime anchor;
  final List<SchoolEvent> events;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(DateTime day, List<SchoolEvent> dayEvents) onDayTap;
  const _ThreeMonthCalendar({
    required this.anchor,
    required this.events,
    required this.onPrev,
    required this.onNext,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final months = [
      anchor,
      DateTime(anchor.year, anchor.month + 1, 1),
      DateTime(anchor.year, anchor.month + 2, 1),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                    onPressed: onPrev,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous month'),
                Expanded(
                  child: Text(
                    '${DateFormat('MMM yyyy').format(months.first)} – '
                    '${DateFormat('MMM yyyy').format(months.last)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                    onPressed: onNext,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next month'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 20,
              children: [
                for (final m in months)
                  SizedBox(
                    width: 280,
                    child: _MonthGrid(
                        month: m, events: events, onDayTap: onDayTap),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final List<SchoolEvent> events;
  final void Function(DateTime day, List<SchoolEvent> dayEvents) onDayTap;
  const _MonthGrid(
      {required this.month, required this.events, required this.onDayTap});

  List<SchoolEvent> _eventsOn(DateTime day) => events.where((e) {
        final s = e.startsAt;
        return s != null &&
            s.year == day.year &&
            s.month == day.month &&
            s.day == day.day;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadBlanks = first.weekday % 7; // Sunday-first
    const dow = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final scheme = Theme.of(context).colorScheme;

    final cells = <Widget>[];
    for (var i = 0; i < leadBlanks; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(month.year, month.month, d);
      final dayEvents = _eventsOn(day);
      final has = dayEvents.isNotEmpty;
      cells.add(
        InkWell(
          onTap: has ? () => onDayTap(day, dayEvents) : null,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$d',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: has ? FontWeight.bold : FontWeight.normal,
                      color: has ? scheme.onSurface : scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              if (has)
                Wrap(
                  spacing: 2,
                  children: [
                    for (final e in dayEvents.take(3))
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            color: categoryFor(e.category).color,
                            shape: BoxShape.circle),
                      ),
                  ],
                )
              else
                const SizedBox(height: 5),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Text(DateFormat('MMMM yyyy').format(month),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final d in dow)
              Expanded(
                child: Center(
                  child: Text(d,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurfaceVariant)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: cells,
        ),
      ],
    );
  }
}

// ---- Event tile ----------------------------------------------------------
class _EventTile extends StatelessWidget {
  final SchoolEvent event;
  final VoidCallback onTap;
  const _EventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = categoryFor(event.category);
    final d = event.startsAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBadge(date: d, color: cat.color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(event.title,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        Pill(event.category, color: cat.color, icon: cat.icon),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (d != null)
                          _meta(
                              context,
                              Icons.schedule,
                              event.allDay
                                  ? 'All day'
                                  : _timeRange(d, event.endsAt)),
                        if (event.location.isNotEmpty)
                          _meta(context, Icons.place, event.location),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(event.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
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
  final Color color;
  const _DateBadge({this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            date != null ? DateFormat('MMM').format(date!).toUpperCase() : '—',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
          Text(
            date != null ? DateFormat('d').format(date!) : '',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ],
      ),
    );
  }
}

String _timeRange(DateTime start, DateTime? end) {
  final t = DateFormat('h:mm a');
  if (end == null) return t.format(start);
  final sameDay = start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (sameDay) return '${t.format(start)} – ${t.format(end)}';
  return '${t.format(start)} – ${DateFormat('MMM d, h:mm a').format(end)}';
}

// ---- Event detail dialog (share / social / reminder) ---------------------
void showEventDetail(BuildContext context, SchoolEvent e) {
  showDialog(context: context, builder: (context) => _EventDetailDialog(e));
}

class _EventDetailDialog extends StatelessWidget {
  final SchoolEvent e;
  const _EventDetailDialog(this.e);

  String get _shareText {
    final when = e.startsAt == null
        ? ''
        : e.allDay
            ? DateFormat('EEE, MMM d, y').format(e.startsAt!)
            : DateFormat('EEE, MMM d, y · h:mm a').format(e.startsAt!);
    return '${e.title}\n$when\n${e.location}\n\n${e.description}';
  }

  String get _mapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=${e.latitude},${e.longitude}';

  String get _shareUrl {
    final origin = Uri.base.origin.isEmpty ? 'https://boosterclub-bda.web.app' : Uri.base.origin;
    return '$origin/#/events';
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _fmtCal(DateTime d) =>
      '${d.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';

  String get _googleCalUrl {
    final start = e.startsAt ?? DateTime(2026, 7, 6, 9);
    final end = e.endsAt ?? start.add(const Duration(hours: 1));
    final params = {
      'action': 'TEMPLATE',
      'text': e.title,
      'dates': '${_fmtCal(start)}/${_fmtCal(end)}',
      'details': e.description,
      'location': e.location,
    };
    final q = params.entries
        .map((kv) => '${kv.key}=${Uri.encodeComponent(kv.value)}')
        .join('&');
    return 'https://calendar.google.com/calendar/render?$q';
  }

  @override
  Widget build(BuildContext context) {
    final cat = categoryFor(e.category);
    final d = e.startsAt;
    return AlertDialog(
      title: Row(
        children: [
          Icon(cat.icon, color: cat.color),
          const SizedBox(width: 8),
          Expanded(child: Text(e.title)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Pill(e.category, color: cat.color, icon: cat.icon),
              const SizedBox(height: 12),
              if (d != null)
                _row(context, Icons.calendar_today,
                    DateFormat('EEEE, MMMM d, y').format(d)),
              if (d != null && !e.allDay)
                _row(context, Icons.schedule, _timeRange(d, e.endsAt)),
              if (d != null && e.allDay)
                _row(context, Icons.schedule, 'All day'),
              if (e.location.isNotEmpty)
                _row(context, Icons.place, e.location),
              const SizedBox(height: 12),
              Text(e.description,
                  style: Theme.of(context).textTheme.bodyMedium),
              const Divider(height: 28),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Share.share('$_shareText\n$_shareUrl',
                        subject: e.title),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _open(_googleCalUrl),
                    icon: const Icon(Icons.event_available, size: 18),
                    label: const Text('Add reminder'),
                  ),
                  if (e.hasGeo)
                    OutlinedButton.icon(
                      onPressed: () => _open(_mapsUrl),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('View on map'),
                    ),
                  IconButton(
                    tooltip: 'Share on Facebook',
                    onPressed: () => _open(
                        'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_shareUrl)}'),
                    icon: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
                  ),
                  IconButton(
                    tooltip: 'Share on X',
                    onPressed: () => _open(
                        'https://twitter.com/intent/tweet?text=${Uri.encodeComponent('${e.title} — ${AppConfig.appName}')}&url=${Uri.encodeComponent(_shareUrl)}'),
                    icon: const Text('𝕏',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
