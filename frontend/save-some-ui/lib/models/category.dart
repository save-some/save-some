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
        createdAt: _parseDate(json['created_at']),
      );
 
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
      };
}
 
