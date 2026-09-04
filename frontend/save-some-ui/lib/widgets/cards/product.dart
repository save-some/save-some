import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/util/format.dart';
import 'package:save_some_ui/widgets/common/app_card.dart';
import 'package:save_some_ui/widgets/common/avatar_badge.dart';
import 'package:save_some_ui/widgets/common/product_thumb.dart';
import 'package:save_some_ui/widgets/common/save_button.dart';

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
///   - targetPrice present   -> also shows the watchlist alert threshold
class ProductCard extends StatelessWidget {
  final Product product;

  /// Tapping the card, e.g. to open price history and retailer comparison.
  final VoidCallback? onTap;

  /// Set to show a bookmark control. Off for lists where saving makes no sense.
  final bool showSaveButton;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.showSaveButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final hasRetailer = (product.retailerName?.isNotEmpty ?? false);
    final headline = hasRetailer ? product.retailerName! : product.name;
    final subtitle = hasRetailer ? product.name : product.brand;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            // Only try a logo when the headline actually is a retailer.
            AvatarBadge(source: headline, preferLogo: hasRetailer),
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
                  if (product.price != null || product.targetPrice != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _PriceLine(product: product),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ProductThumb(
              seed: product.id,
              productName: product.name,
              imageUrl: product.imageUrl,
            ),
            if (showSaveButton) ...[
              const SizedBox(width: AppSpacing.xs),
              SaveButton(product: product),
            ],
          ],
        ),
      ),
    );
  }
}

/// Price, discount and alert threshold on one line, in that priority order.
class _PriceLine extends StatelessWidget {
  final Product product;

  const _PriceLine({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final price = product.price;
    final target = product.targetPrice;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      children: [
        if (price != null)
          Text(
            formatUsd(price),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        if (product.isDiscounted)
          Text(
            formatUsd(product.originalPrice!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
              decorationColor: scheme.onSurfaceVariant,
            ),
          ),
        if (product.isDiscounted) _SavingBadge(product: product),
        if (target != null)
          Text(
            // Now shown alongside the price rather than instead of it: a tracked
            // product has both, and hiding the price was the reason watchlist
            // rows looked priceless.
            'alert ${formatUsd(target)}',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
          ),
      ],
    );
  }
}

/// "save $152.00" — the point of the app, so it gets emphasis.
class _SavingBadge extends StatelessWidget {
  final Product product;

  const _SavingBadge({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saving = product.originalPrice! - product.price!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'save ${formatUsd(saving)}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Current price with the pre-discount price struck through beside it. Kept as a
/// public widget because the history screen's detail card reuses it in its header.
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatUsd(price),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (isDiscounted) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatUsd(originalPrice!),
            style: theme.textTheme.bodyMedium?.copyWith(
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
