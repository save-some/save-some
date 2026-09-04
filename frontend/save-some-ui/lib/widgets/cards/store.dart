import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/common/app_card.dart';
import 'package:save_some_ui/widgets/common/avatar_badge.dart';

/// A store row on the maps screen: retailer logo, store name, and either the
/// locality or the computed distance.
///
/// Mirrors ProductCard's shape so the two lists read as one system.
class StoreCard extends StatelessWidget {
  final Store store;

  /// Resolved separately, since the stores endpoint returns retailer_id rather
  /// than a joined name.
  final String retailerName;

  final VoidCallback? onTap;

  /// How many products this retailer carries, when known — the affordance for
  /// "tap to see what's here".
  final int? productCount;

  const StoreCard({
    super.key,
    required this.store,
    required this.retailerName,
    this.onTap,
    this.productCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final distance = store.distanceMiles;
    final subtitleParts = [
      if (store.name != null && store.name!.isNotEmpty) store.name!,
      if (store.locality.isNotEmpty) store.locality,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            AvatarBadge(source: retailerName),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    retailerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (distance != null)
                  Text(
                    // One decimal: a store 0.4 miles away and one 3.6 away is the
                    // distinction that matters, not metres.
                    '${distance.toStringAsFixed(1)} mi',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (productCount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$productCount item${productCount == 1 ? '' : 's'}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ],
              ],
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
