import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/util/format.dart';
import 'package:save_some_ui/widgets/common/avatar_badge.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';

/// The same product at every retailer that stocks it, cheapest first.
///
/// This is the comparison the product is built around — "compare the same
/// products across inventories" — and until now no screen showed it, even though
/// the data model supported it all along.
class OfferList extends StatelessWidget {
  final List<ProductOffer> offers;

  /// Tapping a retailer, e.g. to open its detail screen.
  final void Function(ProductOffer offer)? onSelect;

  const OfferList({super.key, required this.offers, this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) {
      return const AppEmptyState(
        message: 'No retailers are carrying this yet',
        icon: Icons.store_outlined,
      );
    }

    final cheapest = offers.cheapest;
    final spread = offers.spread;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spread != null && spread > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _SpreadBanner(spread: spread, count: offers.priced.length),
          ),
        for (final offer in offers)
          _OfferRow(
            offer: offer,
            // Only mark a winner when there's something to win against.
            isCheapest: cheapest != null &&
                offer.retailerId == cheapest.retailerId &&
                offers.priced.length > 1,
            cheapestPrice: cheapest?.price,
            onTap: onSelect == null ? null : () => onSelect!(offer),
          ),
      ],
    );
  }
}

/// "Save $39.73 by buying at the cheapest of 2 retailers" — the headline number.
class _SpreadBanner extends StatelessWidget {
  final double spread;
  final int count;

  const _SpreadBanner({required this.spread, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        children: [
          Icon(Icons.savings_outlined,
              size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Save ${formatUsd(spread)} by picking the cheapest of $count retailers',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  final ProductOffer offer;
  final bool isCheapest;
  final double? cheapestPrice;
  final VoidCallback? onTap;

  const _OfferRow({
    required this.offer,
    required this.isCheapest,
    this.cheapestPrice,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final price = offer.price;

    // How much dearer than the best price. Null on the cheapest row and when
    // either price is missing.
    final delta = (price != null && cheapestPrice != null && !isCheapest)
        ? formatUsdDelta(cheapestPrice!, price)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: isCheapest
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : Colors.transparent,
        borderRadius: AppRadius.smAll,
        child: InkWell(
          borderRadius: AppRadius.smAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                AvatarBadge(source: offer.retailerName, size: 32),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              offer.retailerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          if (isCheapest) ...[
                            const SizedBox(width: AppSpacing.sm),
                            _Pill(
                              label: 'cheapest',
                              background: scheme.primary,
                              foreground: scheme.onPrimary,
                            ),
                          ],
                        ],
                      ),
                      if (offer.scrapedAt != null)
                        Text(
                          'updated ${formatRelative(offer.scrapedAt!)}',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      price == null ? 'price unknown' : formatUsd(price),
                      style: price == null
                          ? theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)
                          : theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (delta != null)
                      Text(
                        delta,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.error),
                      ),
                    if (offer.inStock == false)
                      Text(
                        'out of stock',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
