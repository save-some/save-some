import 'package:save_some_ui/models/models.dart';
import 'api_client.dart';

class RetailersService {
  final ApiClient _client;
  RetailersService(this._client);

  /// GET /v1/retailers — populates the retailer chip group.
  Future<List<Retailer>> fetchAll() async {
    final json = await _client.get('/v1/retailers');
    return (json as List)
        .map((r) => Retailer.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// GET /v1/products?retailer_ids=... — the Products page browse list.
  /// Pass an empty/null set of ids for "no chips selected" (all retailers).
  Future<List<Product>> fetchProducts({
    Set<String>? retailerIds,
    int limit = 50,
    int offset = 0,
  }) async {
    // ApiClient's query map only supports single values per key — a
    // multi-select filter needs retailer_ids repeated, so build the query
    // string by hand and go through getRaw instead of get's query map.
    final buffer = StringBuffer('/v1/products?limit=$limit&offset=$offset');
    if (retailerIds != null) {
      for (final id in retailerIds) {
        buffer.write('&retailer_ids=$id');
      }
    }
    final json = await _client.getRaw(buffer.toString());
    return (json as List)
        .map((p) => Product.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// The ZIP the Maps page anchors on, resolved SERVER-SIDE.
  ///
  /// GET /v1/zipcodes/{zip} — the backend owns the zipcodes table (write-
  /// through cached), so the app no longer geocodes anything itself and the
  /// heading can name the place ("Seattle, WA") from the same lookup the
  /// nearby-stores query uses. Throws ApiException(404) for unknown ZIPs.
  Future<ZipInfo> fetchZip(String zipcode) async {
    final json =
        await _client.get('/v1/zipcodes/$zipcode') as Map<String, dynamic>;
    return ZipInfo(
      zip: json['zip'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      label: json['label'] as String?,
    );
  }

  /// GET /v1/retailers/locations — store pins and the nearby-stores list on
  /// the maps screen. Results come back nearest-first with distance_miles
  /// computed per request. Give either [zipcode] or a lat/lng pair; the
  /// server resolves the ZIP, so distance always matches the same lookup
  /// fetchZip reports.
  Future<List<Store>> fetchNearbyStores({
    String? zipcode,
    double? lat,
    double? lng,
    double radiusMiles = 25,
    Set<String>? retailerIds,
  }) async {
    assert(zipcode != null || (lat != null && lng != null));
    // Same repeated-key problem as fetchProducts.
    final buffer = StringBuffer(
      '/v1/retailers/locations?radius_miles=$radiusMiles',
    );
    if (zipcode != null) {
      buffer.write('&zipcode=${Uri.encodeComponent(zipcode)}');
    } else {
      buffer.write('&lat=$lat&lng=$lng');
    }
    if (retailerIds != null) {
      for (final id in retailerIds) {
        buffer.write('&retailer_ids=$id');
      }
    }
    final json = await _client.getRaw(buffer.toString());
    return (json as List)
        .map((s) => Store.fromJson(s as Map<String, dynamic>))
        .toList();
  }
}

/// One resolved US ZIP: centroid plus a display label when the backend had
/// one ("Seattle, WA").
class ZipInfo {
  final String zip;
  final double lat;
  final double lng;
  final String? label;

  const ZipInfo({
    required this.zip,
    required this.lat,
    required this.lng,
    this.label,
  });
}
