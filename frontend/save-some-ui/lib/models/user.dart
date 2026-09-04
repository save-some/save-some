import 'category.dart';
import 'json.dart';
import 'retailer.dart';

// ---- User ----
// GET /v1/user/{id}/profile
// Note: this intentionally doesn't carry a `products` list — there's no
// endpoint that embeds a user's watchlist in the User payload, so fetch it
// separately via GET /v1/user/{id}/watchlist and keep it out of this model.
//
// `interests` and `retailers` are also fetched separately in practice; the
// profile endpoint leaves them null, which parseList turns into empty lists.

class User {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? zipcode;
  final List<Category> interests;
  final List<Retailer> retailers;

  User({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.zipcode,
    this.interests = const [],
    this.retailers = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        zipcode: json['zipcode'] as String?,
        interests: parseList(json['interests'], Category.fromJson),
        retailers: parseList(json['retailers'], Retailer.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'zipcode': zipcode,
        'interests': interests.map((c) => c.toJson()).toList(),
        'retailers': retailers.map((r) => r.toJson()).toList(),
      };
}
