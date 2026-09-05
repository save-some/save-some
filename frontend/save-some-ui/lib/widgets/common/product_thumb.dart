import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/tokens.dart';

/// A product's picture, or a designed stand-in when there isn't one.
///
/// Most products have no `image_url`: nothing populates it until a scraper runs,
/// and even then retailer CDNs often refuse cross-origin reads so the web build
/// can't draw them. Rather than leave a grey hole, the fallback is a deterministic
/// tile — a soft gradient keyed off the product id plus a glyph inferred from the
/// name — so a list of products looks composed instead of broken, and the same
/// product always gets the same tile.
class ProductThumb extends StatelessWidget {
  /// Used to pick the fallback tile's colour, so it's stable per product.
  final String seed;

  /// Used to pick the fallback tile's glyph.
  final String productName;

  final String? imageUrl;
  final double size;

  const ProductThumb({
    super.key,
    required this.seed,
    required this.productName,
    this.imageUrl,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size < 60 ? AppRadius.sm : AppRadius.md);
    final fallback = _Tile(
      seed: seed,
      productName: productName,
      size: size,
      radius: radius,
    );

    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        height: size,
        width: size,
        fit: BoxFit.cover,
        // Show the tile while loading rather than a blank box, so the row height
        // never changes and there's no flash of empty space.
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
        // Covers both a dead URL and a cross-origin refusal on web.
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String seed;
  final String productName;
  final double size;
  final BorderRadius radius;

  const _Tile({
    required this.seed,
    required this.productName,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    // A curated set of hues rather than the full wheel. Free hue rotation put a
    // pink tile next to a green one and the list looked like confetti; these all
    // sit in the violet-to-sand range the rest of the app occupies.
    const hues = <double>[265, 250, 288, 218, 40, 22];
    final hue = hues[_hash(seed) % hues.length];

    final base = HSLColor.fromAHSL(1, hue, 0.30, isDark ? 0.26 : 0.90).toColor();
    final tint =
        HSLColor.fromAHSL(1, hue, 0.34, isDark ? 0.19 : 0.83).toColor();
    final ink = HSLColor.fromAHSL(1, hue, 0.42, isDark ? 0.78 : 0.40).toColor();

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, tint],
        ),
      ),
      child: Center(
        child: Icon(_glyphFor(productName), size: size * 0.42, color: ink),
      ),
    );
  }

  /// Keyword match on the product name. Deliberately small and ordered — first
  /// hit wins — with a neutral default rather than a guess.
  static IconData _glyphFor(String name) {
    final n = name.toLowerCase();
    const table = <String, IconData>{
      'tv': Icons.tv,
      'television': Icons.tv,
      'monitor': Icons.monitor,
      'laptop': Icons.laptop_mac,
      'thinkpad': Icons.laptop_mac,
      'macbook': Icons.laptop_mac,
      'mouse': Icons.mouse,
      'keyboard': Icons.keyboard,
      'headphone': Icons.headphones,
      'phone': Icons.smartphone,
      'iphone': Icons.smartphone,
      'drill': Icons.handyman,
      'tool': Icons.handyman,
      'saw': Icons.carpenter,
      'kit': Icons.build,
      'repair': Icons.build,
      'reliever': Icons.medication,
      'tablet': Icons.medication,
      'vitamin': Icons.medication,
      'camera': Icons.photo_camera,
      'chair': Icons.chair,
      'shirt': Icons.dry_cleaning,
      'shoe': Icons.hiking,
    };
    for (final entry in table.entries) {
      if (n.contains(entry.key)) return entry.value;
    }
    return Icons.inventory_2_outlined;
  }

  /// FNV-1a. Any stable hash would do; Dart's String.hashCode is explicitly not
  /// guaranteed stable across runs, which would make tiles change colour.
  static int _hash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
