import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/common/avatar_badge.dart';

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

  /// Tapping the card, e.g. to open price history.
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final hasRetailer = (product.retailerName?.isNotEmpty ?? false);
    final headline = hasRetailer ? product.retailerName! : product.name;
    final subtitle = hasRetailer ? product.name : product.brand;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                AvatarBadge(source: headline),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                      if (product.price != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        PriceRow(
                          price: product.price!,
                          originalPrice: product.originalPrice,
                        ),
                      ] else if (product.targetPrice != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Alert below \$${product.targetPrice!.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.primary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Always present, matching the design's neutral block. Renders
                // the real image when a product has one.
                ThumbPlaceholder(imageUrl: product.imageUrl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Current price, with the pre-discount price struck through beside it.
class PriceRow extends StatelessWidget {
  final double price;
  final double? originalPrice;

  const PriceRow({super.key, required this.price, this.originalPrice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDiscounted = originalPrice != null && originalPrice! > price;

    return Row(
      children: [
        Text(
          '\$${price.toStringAsFixed(2)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isDiscounted) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            '\$${originalPrice!.toStringAsFixed(2)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
              decorationColor: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
