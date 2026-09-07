import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:save_some_ui/services/zip_service.dart';

/// Pins the parse contract against Zippopotam's real payload shape — the field
/// names ('place name' with a space, 'state abbreviation') are exactly what
/// the live response carries and what a first pass got wrong, silently losing
/// the "Seattle, WA" heading. Null paths matter just as much: the Maps tab
/// falls back to its offline table/demo anchor, and must keep doing that for
/// bad ZIPs, 404s, and garbage bodies rather than erroring.
void main() {
  const seattle = '''
    {"post code": "98105", "places": [
      {"place name": "Seattle", "longitude": "-122.3022",
       "latitude": "47.6633", "state": "Washington",
       "state abbreviation": "WA"}]}''';

  ZipService withBody(int status, String body) =>
      ZipService(client: MockClient((_) async => http.Response(body, status)));

  test('parses a real ZIP into coordinates and a place label', () async {
    final loc = await withBody(200, seattle).locate('98105');
    expect(loc, isNotNull);
    expect(loc!.lat, closeTo(47.6633, 1e-9));
    expect(loc.lng, closeTo(-122.3022, 1e-9));
    expect(loc.label, 'Seattle, WA');
  });

  test('ZIP+4 is accepted by the local gate', () async {
    expect(await withBody(200, seattle).locate('98105-1234'), isNotNull);
  });

  test('malformed ZIP never hits the network', () async {
    var requested = false;
    final svc = ZipService(
      client: MockClient((_) async {
        requested = true;
        return http.Response('{}', 200);
      }),
    );
    for (final bad in ['', '  ', 'abc', '9810', '98105x']) {
      expect(await svc.locate(bad), isNull, reason: bad);
    }
    expect(requested, isFalse);
  });

  test('404 and garbage bodies resolve to null, not an exception', () async {
    expect(await withBody(404, 'Not Found').locate('00000'), isNull);
    expect(
      await withBody(200, '<html>not json</html>').locate('98105'),
      isNull,
    );
    expect(
      await withBody(200, jsonEncode({'post code': '98105'})).locate('98105'),
      isNull,
    );
    expect(
      await withBody(200, '{"places":[{"latitude":"x"}]}').locate('98105'),
      isNull,
    );
  });

  test('label degrades to null when place fields are missing', () async {
    final loc = await withBody(
      200,
      '{"places":[{"latitude":"47.6","longitude":"-122.3"}]}',
    ).locate('98105');
    expect(loc, isNotNull);
    expect(loc!.label, isNull);
  });
}
