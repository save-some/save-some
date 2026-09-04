import 'package:flutter/material.dart';
import 'package:save_some_ui/models/models.dart';

/// One horizontal product card, used everywhere a Product is shown —
/// Home's trending list, the Products page's browse list and "Your
/// Products" section, and search results. It adapts based on which
/// optional fields are populated, so callers don't need a different
/// widget per context:
///   - retailerName present  -> headline is the retailer, subtitle is the
///     product name (trending / browse)
///   - retailerName absent   -> headline is the product name, subtitle is
///     the brand if present (search results / bare products)
///   - price present         -> shows price, with the original struck
///     through if it's a discount
///   - targetPrice present (and no price) -> shows the watchlist alert
///     threshold instead
class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final hasRetailer = (product.retailerName?.isNotEmpty ?? false);
    final headline = hasRetailer ? product.retailerName! : product.name;
    final subtitle = hasRetailer ? product.name : product.brand;
    final avatarLetter = headline.isNotEmpty ? headline[0] : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.deepPurple[100],
              child: Text(avatarLetter, style: const TextStyle(color: Colors.deepPurple)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                  if (product.price != null) ...[
                    const SizedBox(height: 4),
                    _PriceRow(price: product.price!, originalPrice: product.originalPrice),
                  ] else if (product.targetPrice != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Alert below \$${product.targetPrice!.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.deepPurple, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (product.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  product.imageUrl!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final double price;
  final double? originalPrice;
  const _PriceRow({required this.price, this.originalPrice});

  @override
  Widget build(BuildContext context) {
    final isDiscounted = originalPrice != null && originalPrice! > price;
    return Row(
      children: [
        Text(
          '\$${price.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        if (isDiscounted) ...[
          const SizedBox(width: 6),
          Text(
            '\$${originalPrice!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );
  }
}