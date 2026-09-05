import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/tokens.dart';

/// A section label such as "Your Interests", "Trending this week" or
/// "Retailers".
///
/// The `titleMedium.copyWith(fontWeight: FontWeight.w600)` this replaces was
/// copy-pasted across the home and products screens, alongside a
/// `labelLarge.copyWith(color: Colors.grey[600])` variant for quieter labels —
/// hence [muted].
class SectionHeader extends StatelessWidget {
  final String title;

  /// Smaller and lower-contrast, for labels that introduce a chip row rather
  /// than a content section.
  final bool muted;

  /// Optional trailing affordance, e.g. a "See all" button.
  final Widget? trailing;

  const SectionHeader(
    this.title, {
    super.key,
    this.muted = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = muted
        ? theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
        : theme.textTheme.titleMedium;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(title, style: style)),
          ?trailing,
        ],
      ),
    );
  }
}
