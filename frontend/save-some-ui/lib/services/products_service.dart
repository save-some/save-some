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
  Future<List<Product>> search(String query, {int limit = 25, int offset = 0}) async {
    final json = await _client.post('/v1/products/search', body: {
      'query': query,
      'limit': limit,
      'offset': offset,
    });
    final products = (json as Map<String, dynamic>)['products'] as List;
    return products.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
  }
}
