import 'package:booster_club/services/history_suggestions_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sample = '''
{
  "date": "September 6",
  "events": [
    {"year": "1776", "description": "Montgomery County, Maryland is established.",
     "wikipedia": [{"title": "Montgomery County", "wikipedia": "https://en.wikipedia.org/wiki/Montgomery_County"}]},
    {"year": "1901", "description": "US President William McKinley is shot.",
     "wikipedia": [{"title": "McKinley", "wikipedia": "https://en.wikipedia.org/wiki/McKinley"}]}
  ]
}
''';

  test('parses events with year, description and wikipedia url', () {
    final events = HistorySuggestionsService.parse(sample);
    expect(events.length, 2);
    expect(events.first.year, 1776);
    expect(events.first.description, contains('Montgomery County'));
    expect(events.first.wikipediaUrl, contains('wikipedia.org'));
  });

  test('isLocal flags Maryland/Montgomery County entries', () {
    final events = HistorySuggestionsService.parse(sample);
    final local = events.where(HistorySuggestionsService.isLocal).toList();
    expect(local.length, 1);
    expect(local.first.description, contains('Montgomery County'));
  });
}
