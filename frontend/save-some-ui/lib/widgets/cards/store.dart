import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/common/avatar_badge.dart';

/// A store row on the maps screen: retailer initial, store name, and either the
/// locality or the computed distance.
///
/// Mirrors ProductCard's shape so the two lists read as one system.
class StoreCard extends StatelessWidget {
  final Store store;

  /// Resolved separately, since the stores endpoint returns retailer_id rather
  /// than a joined name.
  final String retailerName;

  final VoidCallback? onTap;

  const StoreCard({
    super.key,
    required this.store,
    required this.retailerName,
    this.onTap,
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
      child: Card(
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
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
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                if (distance != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${distance.toStringAsFixed(1)} mi',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
