import '../models/trending_product.dart';
import 'api_client.dart';

class ProductsService {
  final ApiClient _client;
  ProductsService(this._client);

  /// GET /v1/products/trending
  /// Returns TrendingProduct (product + retailer + price), not the bare
  /// Product model — see the note in trending_product.dart for why.
  Future<List<TrendingProduct>> fetchTrending({int limit = 20}) async {
    final json = await _client.get(
      '/v1/products/trending',
      query: {'limit': limit},
    );
    return (json as List)
        .map((p) => TrendingProduct.fromJson(p as Map<String, dynamic>))
        .toList();
  }
}