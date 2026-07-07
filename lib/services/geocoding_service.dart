import 'dart:convert';

import 'package:http/http.dart' as http;

/// The latitude/longitude and canonical address returned by a geocode lookup.
class GeocodeResult {
  final double latitude;
  final double longitude;
  final String matchedAddress;
  const GeocodeResult({
    required this.latitude,
    required this.longitude,
    required this.matchedAddress,
  });
}

/// Turns a US street address into map coordinates using the free U.S. Census
/// Bureau geocoder (no API key required, CORS-enabled).
///
/// The Census geocoder only covers **US** addresses. Returns null on no match,
/// network failure or a non-US address so callers can fall back to manual entry.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Parses a Census `/geocoder/locations/*` JSON payload (the `address` and
  /// `onelineaddress` endpoints share this shape), returning the first match
  /// (or null when there are none). Exposed for testing.
  static GeocodeResult? parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final matches =
        (json['result'] as Map<String, dynamic>?)?['addressMatches'] as List?;
    if (matches == null || matches.isEmpty) return null;
    final m = matches.first as Map<String, dynamic>;
    final coords = m['coordinates'] as Map<String, dynamic>?;
    if (coords == null) return null;
    final x = coords['x']; // longitude
    final y = coords['y']; // latitude
    if (x is! num || y is! num) return null;
    return GeocodeResult(
      latitude: y.toDouble(),
      longitude: x.toDouble(),
      matchedAddress: (m['matchedAddress'] ?? '').toString(),
    );
  }

  /// Joins address parts into a single one-line address string, skipping any
  /// blank parts (e.g. "6400 Rock Spring Dr, Bethesda, MD 20814").
  static String oneLine({
    String street = '',
    String city = '',
    String state = '',
    String zip = '',
  }) {
    final stateZip =
        [state.trim(), zip.trim()].where((s) => s.isNotEmpty).join(' ');
    return [street.trim(), city.trim(), stateZip]
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  /// Geocodes the given address parts. Uses the Census *one-line* endpoint,
  /// which parses a full address from a single field — so it works whether the
  /// user fills separate city/state/zip fields or types the whole address into
  /// one. Returns null on no match or failure.
  Future<GeocodeResult?> geocode({
    required String street,
    String city = '',
    String state = '',
    String zip = '',
  }) async {
    final address = oneLine(street: street, city: city, state: state, zip: zip);
    if (address.isEmpty) return null;
    try {
      final uri = Uri.https(
        'geocoding.geo.census.gov',
        '/geocoder/locations/onelineaddress',
        {
          'address': address,
          'benchmark': 'Public_AR_Current',
          'format': 'json',
        },
      );
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      return parse(res.body);
    } catch (_) {
      return null;
    }
  }
}
