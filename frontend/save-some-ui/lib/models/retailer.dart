

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


// ---- Retailer ----
// GET /v1/retailers
 
class Retailer {
  final String id;
  final String name;
  final String? website;
  final DateTime createdAt;
 
  Retailer({
    required this.id,
    required this.name,
    this.website,
    required this.createdAt,
  });
 
  factory Retailer.fromJson(Map<String, dynamic> json) => Retailer(
        id: json['id'] as String,
        name: json['name'] as String,
        website: json['website'] as String?,
        createdAt: _parseDate(json['created_at']),
      );
 
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'website': website,
        'created_at': createdAt.toIso8601String(),
      };
}
 

