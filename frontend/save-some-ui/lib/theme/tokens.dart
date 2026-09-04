import 'package:flutter/material.dart';

/// Raw design values, sampled pixel-by-pixel from the Figma file
/// (figma.com/design/9ToSwbI0gQmLDJrlsjgvFr).
///
/// Nothing here builds a widget or a ThemeData — see app_theme.dart for that.
/// Screens should read from `Theme.of(context)` rather than importing these
/// directly; they're public only so the theme and its tests can reference them.
///
/// Worth knowing: the design was drawn on top of the Material 3 baseline
/// palette. Card fill, search-field fill, selected-chip fill and the avatar
/// circle all sample to exact M3 tokens (#FEF7FF surface, #ECE6F0
/// surfaceContainerHigh, #E8DEF8 secondaryContainer, #EADEFF primaryContainer),
/// which is why the theme seeds from M3's own #6750A4 and only overrides the
/// handful of colours the design actually invents.
abstract final class AppColors {
  /// Seed for the generated ColorScheme, and the design's accent — sampled from
  /// the "Save Product" button, which is a flat #6750A4 across its whole face.
  static const seed = Color(0xFF6750A4);

  /// Roles the design specifies directly, sampled from the Figma frames.
  ///
  /// These are applied over `ColorScheme.fromSeed` rather than trusted to come
  /// out of it. The design was drawn on the Material 3 baseline palette, but
  /// Flutter's tonal-palette algorithm has since drifted — on Flutter 3.47
  /// seeding produces surface #FDF7FF and primary #65558F, close to but not the
  /// same as the design. Pinning them keeps the app matching the design across
  /// Flutter upgrades; everything not listed here is still derived.
  static const surface = Color(0xFFFEF7FF); // card fill
  static const surfaceContainerHigh = Color(0xFFECE6F0); // search field, thumbs
  static const secondaryContainer = Color(0xFFE8DEF8); // selected chip, nav pill
  static const primaryContainer = Color(0xFFEADEFF); // avatar circle
  static const onSurfaceVariant = Color(0xFF49454F); // secondary text

  /// Warm cream page background. The single most defining colour in the design
  /// and the one thing M3 does not give you — its default surface is near-white.
  static const canvas = Color(0xFFF5F1ED);

  /// Near-black used for primary calls to action (Log In, Sign Up, Submit for
  /// Vote). The voting frame uses pure #000000 but everything else uses this, so
  /// the theme unifies on it.
  static const ink = Color(0xFF262323);

  /// The two decorative circles behind the auth screens.
  static const blobTaupe = Color(0xFFA99985);
  static const blobSand = Color(0xFFDBD2BC);

  /// Switch track when on. The design uses the iOS green rather than M3's
  /// purple, so it needs to be carried explicitly.
  static const success = Color(0xFF35C759);

  /// Price chart stroke — the thin blue polyline on the history frame.
  static const chartLine = Color(0xFF5B9BD5);
}

/// Corner radii. The design uses four distinct values and no others.
abstract final class AppRadius {
  /// Text inputs.
  static const sm = 8.0;

  /// Search fields and image placeholder blocks.
  static const md = 12.0;

  /// Cards and list rows.
  static const lg = 14.0;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
}

/// Spacing scale. Replaces the magic `23` that appeared 11 times across the
/// auth screens, alongside an assortment of 8s and 15s.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;

  /// Horizontal page gutter. Already what the home and products screens use.
  static const gutter = 20.0;

  static const xl = 24.0;

  static const pageH = EdgeInsets.symmetric(horizontal: gutter);
  static const pageAll = EdgeInsets.symmetric(horizontal: gutter, vertical: lg);
}

/// Brand colours that have no slot in [ColorScheme], exposed through the theme
/// so widgets reach them the same way they reach every other colour, instead of
/// importing [AppColors] at the call site.
@immutable
class AppBrand extends ThemeExtension<AppBrand> {
  final Color canvas;
  final Color ink;
  final Color blobTaupe;
  final Color blobSand;
  final Color success;
  final Color chartLine;

  const AppBrand({
    required this.canvas,
    required this.ink,
    required this.blobTaupe,
    required this.blobSand,
    required this.success,
    required this.chartLine,
  });

  static const light = AppBrand(
    canvas: AppColors.canvas,
    ink: AppColors.ink,
    blobTaupe: AppColors.blobTaupe,
    blobSand: AppColors.blobSand,
    success: AppColors.success,
    chartLine: AppColors.chartLine,
  );

  /// Dark counterpart. The Figma only specifies a light scheme, so these are
  /// derived: the cream canvas becomes a warm near-black of the same hue family,
  /// and ink inverts to a light surface so CTAs stay high-contrast.
  static const dark = AppBrand(
    canvas: Color(0xFF16130F),
    ink: Color(0xFFEDE7E1),
    blobTaupe: Color(0xFF4A4238),
    blobSand: Color(0xFF322D26),
    success: AppColors.success,
    chartLine: Color(0xFF8FC1EA),
  );

  @override
  AppBrand copyWith({
    Color? canvas,
    Color? ink,
    Color? blobTaupe,
    Color? blobSand,
    Color? success,
    Color? chartLine,
  }) {
    return AppBrand(
      canvas: canvas ?? this.canvas,
      ink: ink ?? this.ink,
      blobTaupe: blobTaupe ?? this.blobTaupe,
      blobSand: blobSand ?? this.blobSand,
      success: success ?? this.success,
      chartLine: chartLine ?? this.chartLine,
    );
  }

  @override
  AppBrand lerp(AppBrand? other, double t) {
    if (other == null) return this;
    return AppBrand(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      blobTaupe: Color.lerp(blobTaupe, other.blobTaupe, t)!,
      blobSand: Color.lerp(blobSand, other.blobSand, t)!,
      success: Color.lerp(success, other.success, t)!,
      chartLine: Color.lerp(chartLine, other.chartLine, t)!,
    );
  }
}

/// Shorthand for the brand extension, so widgets can write
/// `context.brand.blobTaupe`.
extension AppBrandContext on BuildContext {
  AppBrand get brand => Theme.of(this).extension<AppBrand>() ?? AppBrand.light;
}
