import 'package:flutter/material.dart';

/// The lavender initial-circle that leads every retailer and product row.
///
/// Extracted from ProductCard so the maps and products lists can use the same
/// mark. The fill is the scheme's primaryContainer, which is exactly the
/// #EADEFF the design uses.
class AvatarBadge extends StatelessWidget {
  /// Text to derive the initial from. Empty falls back to a neutral glyph.
  final String source;
  final double size;

  const AvatarBadge({super.key, required this.source, this.size = 40});

  /// First *letter*, not first character: product names like `65" Samsung TV`
  /// would otherwise render a badge reading "6".
  static String _initialOf(String source) {
    for (final char in source.trim().split('')) {
      if (RegExp(r'[A-Za-z]').hasMatch(char)) return char.toUpperCase();
    }
    final trimmed = source.trim();
    return trimmed.isEmpty ? '?' : trimmed[0];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = _initialOf(source);

    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              height: 1,
            ),
      ),
    );
  }
}

/// The neutral rounded block the design shows in each card's trailing slot where
/// product photography would go. Products currently carry no images, so this is
/// what actually renders — and it's also the fallback when a URL fails to load.
class ThumbPlaceholder extends StatelessWidget {
  final double size;
  final String? imageUrl;

  const ThumbPlaceholder({super.key, this.size = 44, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final block = Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Icon(
        Icons.category_outlined,
        size: size * 0.45,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );

    final url = imageUrl;
    if (url == null || url.isEmpty) return block;

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Image.network(
        url,
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => block,
      ),
    );
  }
}
