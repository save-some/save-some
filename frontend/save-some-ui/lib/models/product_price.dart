import 'json.dart';

// ---- ProductPrice ----
// GET /v1/products/{id}/price-history
//
// product_prices is append-only, so this is one observation rather than a
// current state: a series of these is what the price chart draws.

class ProductPrice {
  final double price;
  final double? originalPrice;
  final bool inStock;
  final DateTime scrapedAt;
  final String? retailerId;
  final String? retailerProductId;

  ProductPrice({
    required this.price,
    this.originalPrice,
    this.inStock = true,
    required this.scrapedAt,
    this.retailerId,
    this.retailerProductId,
  });

  factory ProductPrice.fromJson(Map<String, dynamic> json) => ProductPrice(
        price: parseDoubleOrNull(json['price'])!,
        originalPrice: parseDoubleOrNull(json['original_price']),
        inStock: json['in_stock'] as bool? ?? true,
        scrapedAt: parseDate(json['scraped_at']),
        retailerId: json['retailer_id'] as String?,
        retailerProductId: json['retailer_product_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'price': price,
        'original_price': originalPrice,
        'in_stock': inStock,
        'scraped_at': scrapedAt.toIso8601String(),
        'retailer_id': retailerId,
        'retailer_product_id': retailerProductId,
      };
}
