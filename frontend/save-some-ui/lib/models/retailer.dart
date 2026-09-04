import 'json.dart';

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
        createdAt: parseDate(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'website': website,
        'created_at': createdAt.toIso8601String(),
      };
}
