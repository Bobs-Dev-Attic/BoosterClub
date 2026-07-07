import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single "on this day" event pulled from an external feed.
class OnThisDayEvent {
  final int? year;
  final String description;
  final String? wikipediaUrl;
  const OnThisDayEvent({this.year, required this.description, this.wikipediaUrl});
}

/// Fetches "On This Day" history suggestions from a free, CORS-enabled public
/// feed (byabbe.se, which is derived from Wikipedia).
///
/// NOTE on *local* history: there is no dedicated public API for hyperlocal
/// Bethesda / Walter Johnson HS history. This feed is general world/US history;
/// [marylandOnly] narrows it to entries mentioning Maryland / Montgomery County
/// so a Contributor can spot locally relevant items and adapt them. For true
/// local facts, use the built-in local pack (see LocalHistory) or add your own.
class HistorySuggestionsService {
  HistorySuggestionsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Keywords that flag a general event as locally relevant.
  static const localKeywords = [
    'maryland',
    'montgomery county',
    'bethesda',
    'rockville',
    'silver spring',
    'walter johnson',
    'washington, d.c.',
    'potomac',
    'chesapeake',
  ];

  /// Parses a byabbe.se events payload. Exposed for testing.
  static List<OnThisDayEvent> parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final events = (json['events'] as List?) ?? const [];
    return [
      for (final e in events)
        OnThisDayEvent(
          year: int.tryParse('${(e as Map)['year']}'),
          description: (e['description'] ?? '').toString(),
          wikipediaUrl: (e['wikipedia'] is List &&
                  (e['wikipedia'] as List).isNotEmpty)
              ? ((e['wikipedia'] as List).first as Map)['wikipedia']?.toString()
              : null,
        ),
    ];
  }

  static bool isLocal(OnThisDayEvent e) {
    final d = e.description.toLowerCase();
    return localKeywords.any(d.contains);
  }

  /// Fetches events for [month]/[day]. When [marylandOnly] is true, only
  /// locally relevant entries are returned. Returns an empty list on failure
  /// (offline, blocked, etc.) so callers can fall back to manual entry.
  Future<List<OnThisDayEvent>> fetch(int month, int day,
      {bool marylandOnly = false}) async {
    try {
      final uri =
          Uri.parse('https://byabbe.se/on-this-day/$month/$day/events.json');
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];
      final all = parse(res.body);
      return marylandOnly ? all.where(isLocal).toList() : all;
    } catch (_) {
      return const [];
    }
  }
}
