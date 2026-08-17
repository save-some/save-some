import 'category.dart';
import 'retailer.dart';


DateTime _parseDate(dynamic value) => DateTime.parse(value as String);
 
double? _parseDoubleOrNull(dynamic value) =>
    value == null ? null : (value as num).toDouble();
 
List<T> _parseList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value == null) return [];
  return (value as List)
      .map((item) => fromJson(item as Map<String, dynamic>))
      .toList();
}
 

// ---- User ----
// Returned by POST /v1/onboarding/{user_id}.
// Note: this intentionally doesn't carry a `products` list like the
// earlier draft did — there's no endpoint that embeds a user's watchlist
// in the User payload. If/when a watchlist endpoint gets added on the
// backend (db.py already has the helpers for it, just not wired to a
// route yet), fetch it separately and keep it out of this model.
 
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
        interests: _parseList(json['interests'], Category.fromJson),
        retailers: _parseList(json['retailers'], Retailer.fromJson),
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
 
