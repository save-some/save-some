import 'json.dart';

// ---- Category ----
// GET /v1/categories — canonical, retailer-agnostic categories used
// for a user's "interests".

class Category {
  final String id;
  final String name;
  final DateTime createdAt;

  Category({required this.id, required this.name, required this.createdAt});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: parseDate(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
      };
}
