import 'package:save_some_ui/models/models.dart';
import 'api_client.dart';

class UsersService {
  final ApiClient _client;
  UsersService(this._client);

  /// GET /v1/user/{id}/profile
  /// Returns null if the user hasn't onboarded yet (no profiles row) —
  /// callers need to handle that as a real state, e.g. routing to
  /// onboarding, not a crash.
  Future<User?> fetchProfile(String userId) async {
    try {
      final json = await _client.get('/v1/user/$userId/profile');
      return User.fromJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// GET /v1/user/{id}/interests
  Future<List<Category>> fetchInterests(String userId) async {
    final json = await _client.get('/v1/user/$userId/interests');
    return (json as List)
        .map((c) => Category.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// GET /v1/user/{id}/retailers — the chains a user opted into during
  /// onboarding, used to scope the maps screen's chip row.
  Future<List<Retailer>> fetchRetailers(String userId) async {
    final json = await _client.get('/v1/user/$userId/retailers');
    return (json as List)
        .map((r) => Retailer.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// GET /v1/user/{id}/zipcode — the geo anchor for nearby-store lookups when
  /// device location isn't available or permitted.
  Future<String?> fetchZipcode(String userId) async {
    try {
      final json = await _client.get('/v1/user/$userId/zipcode');
      return (json as Map<String, dynamic>)['zipcode'] as String?;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// GET /v1/user/{id}/watchlist
  Future<List<Product>> fetchWatchlist(String userId) async {
    final json = await _client.get('/v1/user/$userId/watchlist');
    return (json as List)
        .map((p) => Product.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// POST /v1/user/{id}/watchlist — track a product, or update the target price
  /// if it's already tracked. Backs the "Save Product" button.
  Future<void> addToWatchlist(
    String userId,
    String productId, {
    double? targetPrice,
    String? notes,
  }) async {
    await _client.post('/v1/user/$userId/watchlist', body: {
      'product_id': productId,
      'target_price': ?targetPrice,
      'notes': ?notes,
    });
  }

  /// DELETE /v1/user/{id}/watchlist/{productId}
  Future<void> removeFromWatchlist(String userId, String productId) async {
    await _client.delete('/v1/user/$userId/watchlist/$productId');
  }

  /// GET /v1/user/{id}/history — past searches, newest first.
  Future<List<SearchHistoryEntry>> fetchSearchHistory(
    String userId, {
    int limit = 50,
  }) async {
    final json =
        await _client.get('/v1/user/$userId/history', query: {'limit': limit});
    return (json as List)
        .map((e) => SearchHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
