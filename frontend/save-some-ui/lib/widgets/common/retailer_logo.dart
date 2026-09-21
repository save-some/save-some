import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A retailer's mark, for the circle that leads every retailer row.
///
/// Resolved by name against bundled assets. This is deliberately not a
/// `retailers.logo_url` column: schema changes are off the table for now, and a
/// bundled asset needs no network, no CORS negotiation and stays crisp at any
/// size — favicon services send no CORS header, so the web build can't draw them
/// at all.
///
/// The bundled marks are brand-accurate where a logo is geometry (Target's
/// bullseye, Walmart's spark, Home Depot's orange square) and brand-coloured
/// monograms otherwise. **To use official artwork instead, drop an SVG into
/// `assets/logos/` and point [_assetForName] at it — no other code changes.**
///
/// Anything unmapped falls back to the caller's widget, normally an initial
/// letter, so an unknown retailer still renders sensibly.
class RetailerLogo extends StatelessWidget {
  final String retailerName;
  final double size;

  /// Shown when there's no asset for this retailer.
  final Widget fallback;

  const RetailerLogo({
    super.key,
    required this.retailerName,
    required this.size,
    required this.fallback,
  });

  /// Whether a bundled mark exists, so callers can decide layout up front.
  static bool hasLogo(String retailerName) =>
      _assetForName(retailerName) != null;

  /// The bundled logo slug for a retailer name ("BJ's Wholesale Club" ->
  /// "bjs"), or null when there is no mark for it. Shared by the SVG widget
  /// and the map's PNG pin assets so the two can never point at different
  /// files for the same chain.
  static String? slugFor(String retailerName) {
    // Normalise so "BJ's", "BJs" and "bj's wholesale club" all land together.
    final key = retailerName
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), ' ')
        .trim();

    const table = <String, String>{
      'walmart': 'walmart',
      'target': 'target',
      'amazon': 'amazon',
      'home depot': 'home_depot',
      'the home depot': 'home_depot',
      'lowe s': 'lowes',
      'lowes': 'lowes',
      'bj s': 'bjs',
      'bjs': 'bjs',
      'bj s wholesale club': 'bjs',
      'sam s club': 'sams_club',
      'sams club': 'sams_club',
      'best buy': 'best_buy',
      'costco': 'costco',
      'costco wholesale': 'costco',
    };
    return table[key];
  }

  /// The pre-rendered circular badge PNG for a chain, used as a map pin.
  static String? pngAssetFor(String retailerName) {
    final slug = slugFor(retailerName);
    return slug == null ? null : 'assets/logos/png/$slug.png';
  }

  static String? _assetForName(String retailerName) {
    final slug = slugFor(retailerName);
    return slug == null ? null : 'assets/logos/$slug.svg';
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assetForName(retailerName);
    if (asset == null) return fallback;

    return SizedBox(
      height: size,
      width: size,
      child: SvgPicture.asset(
        asset,
        height: size,
        width: size,
        // The marks are already circular, so no clipping is needed.
        placeholderBuilder: (_) => fallback,
      ),
    );
  }
}
