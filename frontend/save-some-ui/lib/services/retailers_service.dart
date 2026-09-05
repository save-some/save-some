import 'package:save_some_ui/models/models.dart';
import 'api_client.dart';

class RetailersService {
  final ApiClient _client;
  RetailersService(this._client);

  /// GET /v1/retailers — populates the retailer chip group.
  Future<List<Retailer>> fetchAll() async {
    final json = await _client.get('/v1/retailers');
    return (json as List).map((r) => Retailer.fromJson(r as Map<String, dynamic>)).toList();
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
    return (json as List).map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// GET /v1/retailers/locations — store pins and the nearby-stores list on the
  /// maps screen. Results come back nearest-first with distance_miles computed
  /// per request.
  Future<List<Store>> fetchNearbyStores({
    required double lat,
    required double lng,
    double radiusMiles = 25,
    Set<String>? retailerIds,
  }) async {
    // Same repeated-key problem as fetchProducts.
    final buffer = StringBuffer(
      '/v1/retailers/locations?lat=$lat&lng=$lng&radius_miles=$radiusMiles',
    );
    if (retailerIds != null) {
      for (final id in retailerIds) {
        buffer.write('&retailer_ids=$id');
      }
    }
    final json = await _client.getRaw(buffer.toString());
    return (json as List).map((s) => Store.fromJson(s as Map<String, dynamic>)).toList();
  }
}
