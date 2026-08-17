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

  /// GET /v1/user/{id}/watchlist
  Future<List<Product>> fetchWatchlist(String userId) async {
    final json = await _client.get('/v1/user/$userId/watchlist');
    return (json as List)
        .map((p) => Product.fromJson(p as Map<String, dynamic>))
        .toList();
  }
}