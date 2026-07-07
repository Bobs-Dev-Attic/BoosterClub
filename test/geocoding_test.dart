import 'package:booster_club/services/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeocodingService.parse', () {
    test('extracts coordinates and matched address from a Census match', () {
      const body = '''
{
  "result": {
    "addressMatches": [
      {
        "matchedAddress": "6400 ROCK SPRING DR, BETHESDA, MD, 20814",
        "coordinates": { "x": -77.1136, "y": 39.0349 }
      }
    ]
  }
}
''';
      final r = GeocodingService.parse(body);
      expect(r, isNotNull);
      expect(r!.latitude, 39.0349);
      expect(r.longitude, -77.1136);
      expect(r.matchedAddress, contains('BETHESDA'));
    });

    test('returns null when there are no matches', () {
      const body = '{ "result": { "addressMatches": [] } }';
      expect(GeocodingService.parse(body), isNull);
    });

    test('returns null when the payload is missing coordinates', () {
      const body = '''
{ "result": { "addressMatches": [ { "matchedAddress": "X" } ] } }''';
      expect(GeocodingService.parse(body), isNull);
    });
  });
}
