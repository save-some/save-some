import 'package:save_some_ui/models/models.dart';
import 'api_client.dart';

class ProductsService {
  final ApiClient _client;
  ProductsService(this._client);

  /// GET /v1/products/trending
  Future<List<Product>> fetchTrending({int limit = 20}) async {
    final json = await _client.get('/v1/products/trending', query: {'limit': limit});
    return (json as List).map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// POST /v1/products/search — cross-retailer canonical product search,
  /// backs the search modal on the Products page.
  ///
  /// Passing [userId] also records the search server-side, which is what
  /// populates the history screen's recent-searches list.
  Future<List<Product>> search(
    String query, {
    int limit = 25,
    int offset = 0,
    String? userId,
  }) async {
    final path = userId == null
        ? '/v1/products/search'
        : '/v1/products/search?user_id=$userId';
    final json = await _client.post(path, body: {
      'query': query,
      'limit': limit,
      'offset': offset,
    });
    final products = (json as Map<String, dynamic>)['products'] as List;
    return products.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// GET /v1/products/{id}/price-history — the series behind the price chart.
  ///
  /// The API returns newest-first; this reverses it so callers get chronological
  /// order, which is what a chart wants.
  Future<List<ProductPrice>> fetchPriceHistory(
    String productId, {
    String? retailerId,
    int limit = 100,
  }) async {
    final json = await _client.get(
      '/v1/products/$productId/price-history',
      query: {
        'limit': limit,
        'retailer_id': ?retailerId,
      },
    );
    final prices = (json as List)
        .map((p) => ProductPrice.fromJson(p as Map<String, dynamic>))
        .toList();
    return prices.reversed.toList();
  }
}
