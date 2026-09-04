import 'package:save_some_ui/models/models.dart';
import 'api_client.dart';

class CategoriesService {
  final ApiClient _client;
  CategoriesService(this._client);

  /// GET /v1/categories — the canonical, retailer-agnostic list used for a
  /// user's interests. Previously reached by a raw client.get() inline in
  /// submit_product.dart, which left no place to put caching or error handling.
  Future<List<Category>> fetchAll() async {
    final json = await _client.get('/v1/categories');
    return (json as List)
        .map((c) => Category.fromJson(c as Map<String, dynamic>))
        .toList();
  }
}
