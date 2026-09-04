import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/tokens.dart';

/// A horizontally scrolling, non-interactive chip row — the design's
/// "Your Interests".
///
/// Colours come from the theme's chipTheme rather than per-call
/// `backgroundColor:` / `side:` arguments, which is how these were styled before.
class ChipRow extends StatelessWidget {
  final List<String> labels;

  const ChipRow({super.key, required this.labels});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Lets chips run to the screen edge while the row still starts at the
      // page gutter.
      clipBehavior: Clip.none,
      child: Row(
        spacing: AppSpacing.sm,
        children: [for (final label in labels) Chip(label: Text(label))],
      ),
    );
  }
}

/// A wrapping multi-select chip group — the design's retailer filters on the
/// products and maps screens.
class FilterChipGroup extends StatelessWidget {
  /// Selectable options as (id, label) pairs.
  final List<({String id, String label})> options;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  /// When true the group scrolls on one line instead of wrapping, matching the
  /// maps frame where the chips run off the right edge.
  final bool scrollable;

  const FilterChipGroup({
    super.key,
    required this.options,
    required this.selectedIds,
    required this.onToggle,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final option in options)
        FilterChip(
          label: Text(option.label),
          selected: selectedIds.contains(option.id),
          onSelected: (_) => onToggle(option.id),
        ),
    ];

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(spacing: AppSpacing.sm, children: chips),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: chips,
    );
  }
}
