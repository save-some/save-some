 
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
 
 
// ---- Product ----
// GET /v1/products/trending, POST /v1/products/search, etc.
 
class Product {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? upc;
  final String? brand;
  final DateTime createdAt;
 
  final String? retailerId;
  final String? retailerName;
  final double? price;
  final double? originalPrice;
  final double? targetPrice;
  final String? notes;
  final DateTime? trackedAt;
 
  Product({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.upc,
    this.brand,
    required this.createdAt,
    this.retailerId,
    this.retailerName,
    this.price,
    this.originalPrice,
    this.targetPrice,
    this.notes,
    this.trackedAt,
  });
 
  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        upc: json['upc'] as String?,
        brand: json['brand'] as String?,
        createdAt: _parseDate(json['created_at']),
        retailerId: json['retailer_id'] as String?,
        retailerName: json['retailer_name'] as String?,
        price: _parseDoubleOrNull(json['price']),
        originalPrice: _parseDoubleOrNull(json['original_price']),
        targetPrice: _parseDoubleOrNull(json['target_price']),
        notes: json['notes'] as String?,
        trackedAt: json['tracked_at'] == null
            ? null
            : _parseDate(json['tracked_at']),
      );
 
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'upc': upc,
        'brand': brand,
        'created_at': createdAt.toIso8601String(),
        'retailer_id': retailerId,
        'retailer_name': retailerName,
        'price': price,
        'original_price': originalPrice,
        'target_price': targetPrice,
        'notes': notes,
        'tracked_at': trackedAt?.toIso8601String(),
      };
}

