import 'json.dart';

// ---- Product ----
// GET /v1/products/trending, GET /v1/products, POST /v1/products/search,
// GET /v1/user/{id}/watchlist.
//
// One model covers all four because the backend returns the same product row
// with different optional context attached: browse and trending add the
// retailer and current price, watchlist adds target_price/notes/tracked_at.
// ProductCard keys its layout off which of those are present.

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

  /// Which retailer [price] came from, when it was picked as the cheapest across
  /// several. Distinct from [retailerName] so a watchlist row still leads with
  /// the product name rather than a shop name.
  final String? priceRetailerName;
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
    this.priceRetailerName,
    this.price,
    this.originalPrice,
    this.targetPrice,
    this.notes,
    this.trackedAt,
  });

  /// True when the current price is below the recorded original — drives the
  /// struck-through original price in the UI.
  bool get isDiscounted => originalPrice != null && price != null && originalPrice! > price!;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        upc: json['upc'] as String?,
        brand: json['brand'] as String?,
        createdAt: parseDate(json['created_at']),
        retailerId: json['retailer_id'] as String?,
        retailerName: json['retailer_name'] as String?,
        priceRetailerName: json['price_retailer_name'] as String?,
        price: parseDoubleOrNull(json['price']),
        originalPrice: parseDoubleOrNull(json['original_price']),
        targetPrice: parseDoubleOrNull(json['target_price']),
        notes: json['notes'] as String?,
        trackedAt:
            json['tracked_at'] == null ? null : parseDate(json['tracked_at']),
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
        'price_retailer_name': priceRetailerName,
        'price': price,
        'original_price': originalPrice,
        'target_price': targetPrice,
        'notes': notes,
        'tracked_at': trackedAt?.toIso8601String(),
      };
}
