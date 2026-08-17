import 'product.dart';

/// The Home page's "Trending this week" cards need to show which
/// retailer a product is trending at (and its price) — the canonical
/// [Product] model deliberately doesn't carry that, since a product is
/// retailer-agnostic. This wraps a [Product] with the retailer/price
/// context that's specific to a *trending* listing, not the product
/// itself.
///
/// NOTE: this assumes `GET /v1/products/trending` is updated to return
/// `retailer_id`, `retailer_name`, `price`, and `original_price`
/// alongside the product fields, instead of being filtered down to bare
/// Product fields like it currently is. See the note in
/// home_service.dart / the accompanying explanation.
class TrendingProduct {
  final Product product;
  final String? retailerId;
  final String? retailerName;
  final double? price;
  final double? originalPrice;

  TrendingProduct({
    required this.product,
    this.retailerId,
    this.retailerName,
    this.price,
    this.originalPrice,
  });

  String? get imageUrl => product.imageUrl;

  factory TrendingProduct.fromJson(Map<String, dynamic> json) {
    return TrendingProduct(
      product: Product.fromJson(json),
      retailerId: json['retailer_id'] as String?,
      retailerName: json['retailer_name'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      originalPrice: (json['original_price'] as num?)?.toDouble(),
    );
  }
}