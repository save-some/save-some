import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// ZIP → coordinates, resolved live instead of from a lookup table baked into
/// the app.
///
/// Zippopotam US is keyless and sends CORS headers, so the app can resolve any
/// US ZIP the same way seed/import_osm_stores.py does — which closes the loop
/// the store importer opened: a user entering a ZIP nobody has imported for
/// still at least gets an HONEST empty state naming their own area, and once
/// `--zip <their ZIP>` is run, the same coordinates resolve to real stores
/// with no app change. (Before this, every ZIP outside a four-entry table was
/// silently served Hoboken results behind its own heading.)
class ZipService {
  ZipService({http.Client? client}) : _http = client ?? http.Client();

  static const _endpoint = 'https://api.zippopotam.us/us/';
  static const _timeout = Duration(seconds: 8);

  final http.Client _http;

  /// Null for anything unresolvable: bad ZIP, offline, timeout. Callers treat
  /// null as "no geocode", never as an error.
  Future<ZipLocation?> locate(String zipcode) async {
    final trimmed = zipcode.trim();
    if (!_zipPattern.hasMatch(trimmed)) return null;
    try {
      final response = await _http
          .get(Uri.parse('$_endpoint$trimmed'))
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final places = (data as Map<String, dynamic>)['places'] as List?;
      if (places == null || places.isEmpty) return null;
      final place = places.first as Map<String, dynamic>;
      final lat = double.tryParse('${place['latitude']}');
      final lng = double.tryParse('${place['longitude']}');
      if (lat == null || lng == null) return null;
      final name = place['place name'];
      final state = place['state abbreviation'];
      return ZipLocation(
        lat: lat,
        lng: lng,
        label: (name is String && state is String) ? '$name, $state' : null,
      );
    } on TimeoutException {
      return null;
    } on FormatException {
      return null;
    } catch (_) {
      // A dead/unreachable geocoder must not break the Maps tab — the caller
      // still has its fallback anchor.
      return null;
    }
  }

  static final RegExp _zipPattern = RegExp(r'^\d{5}(-\d{4})?$');
}

class ZipLocation {
  final double lat;
  final double lng;

  /// "Seattle, WA" when the geocoder told us, else null.
  final String? label;

  const ZipLocation({required this.lat, required this.lng, this.label});
}
