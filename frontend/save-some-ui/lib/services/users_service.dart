import '../models/models.dart';

import 'api_client.dart';

class UsersService {
  final ApiClient _client;
  UsersService(this._client);

  /// GET /v1/user/{id}/profile
  /// NOTE: this route doesn't exist on the backend yet — db.py already
  /// has retrieve_user_profile, it just isn't wired to a route in
  /// api/routers/users.py. Add it before this will actually work.
  /*
  Future<User> fetchProfile(String userId) async {
    final json = await _client.get('/v1/user/$userId/profile');
    return User.fromJson(json as Map<String, dynamic>);
  }
  */

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
}