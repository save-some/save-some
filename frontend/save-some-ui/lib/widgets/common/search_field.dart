import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/tokens.dart';

/// The design's pill search bar: leading menu glyph, hint text, trailing
/// magnifier.
///
/// Tappable rather than a real inline TextField, so typing, debouncing and
/// results all stay inside a SearchDelegate. Replaces a private `_SearchBar`
/// that lived in products.dart and was needed again on the history and maps
/// screens.
class SearchField extends StatelessWidget {
  final String hint;
  final VoidCallback onTap;

  /// Shown at the leading edge. The design uses a menu glyph here rather than a
  /// magnifier, which sits on the trailing edge instead.
  final IconData leadingIcon;

  const SearchField({
    super.key,
    required this.hint,
    required this.onTap,
    this.leadingIcon = Icons.menu,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Icon(leadingIcon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  hint,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Icon(Icons.search, size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
