import 'json.dart';

// ---- ProductOffer ----
// GET /v1/products/{id}/offers
//
// One retailer's current offer for a product. A list of these is the
// cross-retailer comparison the app exists for.

class ProductOffer {
  final String retailerId;
  final String retailerName;
  final String? website;
  final String retailerProductId;
  final String? productUrl;

  /// Null when this retailer stocks the product but no price has been observed
  /// yet — shown as "price unknown" rather than hidden.
  final double? price;
  final double? originalPrice;
  final bool? inStock;
  final DateTime? scrapedAt;

  ProductOffer({
    required this.retailerId,
    required this.retailerName,
    this.website,
    required this.retailerProductId,
    this.productUrl,
    this.price,
    this.originalPrice,
    this.inStock,
    this.scrapedAt,
  });

  bool get isDiscounted =>
      originalPrice != null && price != null && originalPrice! > price!;

  factory ProductOffer.fromJson(Map<String, dynamic> json) => ProductOffer(
        retailerId: json['retailer_id'] as String,
        retailerName: json['retailer_name'] as String,
        website: json['website'] as String?,
        retailerProductId: json['retailer_product_id'] as String,
        productUrl: json['product_url'] as String?,
        price: parseDoubleOrNull(json['price']),
        originalPrice: parseDoubleOrNull(json['original_price']),
        inStock: json['in_stock'] as bool?,
        scrapedAt: json['scraped_at'] == null
            ? null
            : parseDate(json['scraped_at']),
      );
}

/// Convenience over a list of offers, so screens don't recompute the same
/// summary. The API already returns them cheapest first, unpriced last.
extension ProductOfferList on List<ProductOffer> {
  Iterable<ProductOffer> get priced => where((o) => o.price != null);

  ProductOffer? get cheapest {
    for (final offer in this) {
      if (offer.price != null) return offer;
    }
    return null;
  }

  /// What you save by buying from the cheapest rather than the dearest retailer.
  /// Null unless at least two retailers have a price, since "compare" needs two.
  double? get spread {
    final prices = priced.map((o) => o.price!).toList();
    if (prices.length < 2) return null;
    prices.sort();
    return prices.last - prices.first;
  }
}
