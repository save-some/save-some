import 'package:flutter/material.dart';

import 'package:save_some_ui/widgets/common/retailer_logo.dart';

/// The circle that leads every retailer and product row.
///
/// Shows the retailer's logo when one is bundled, and falls back to a lavender
/// initial-circle otherwise. The fill is the scheme's primaryContainer, which is
/// exactly the #EADEFF the design uses.
class AvatarBadge extends StatelessWidget {
  /// Text to derive the initial from, and to match a logo against.
  final String source;
  final double size;

  /// Set false where a logo would be wrong — a product name, say, rather than a
  /// retailer.
  final bool preferLogo;

  const AvatarBadge({
    super.key,
    required this.source,
    this.size = 40,
    this.preferLogo = true,
  });

  /// First *letter*, not first character: product names like `65" Samsung TV`
  /// would otherwise render a badge reading "6".
  static String initialOf(String source) {
    for (final char in source.trim().split('')) {
      if (RegExp(r'[A-Za-z]').hasMatch(char)) return char.toUpperCase();
    }
    final trimmed = source.trim();
    return trimmed.isEmpty ? '?' : trimmed[0];
  }

  @override
  Widget build(BuildContext context) {
    final letterCircle = _LetterCircle(source: source, size: size);
    if (!preferLogo) return letterCircle;
    return RetailerLogo(
      retailerName: source,
      size: size,
      fallback: letterCircle,
    );
  }
}

class _LetterCircle extends StatelessWidget {
  final String source;
  final double size;

  const _LetterCircle({required this.source, required this.size});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        AvatarBadge.initialOf(source),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              height: 1,
              fontSize: size * 0.42,
            ),
      ),
    );
  }
}
