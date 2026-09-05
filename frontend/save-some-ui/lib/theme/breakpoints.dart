import 'package:flutter/material.dart';

/// Window size classes, following Material 3's own thresholds.
///
/// The app was built phone-first and then run in a browser, where every list
/// stretched to the full 1440px: a card's text sat on the left, its thumbnail on
/// the far right, and a lake of empty cream in between. Layout decisions now key
/// off these rather than assuming a phone.
enum WindowSize {
  /// Phones, and narrow browser windows.
  compact,

  /// Large phones in landscape, small tablets, half-screen desktop windows.
  medium,

  /// Tablets and desktops.
  expanded;

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static WindowSize fromWidth(double width) {
    if (width < 600) return WindowSize.compact;
    if (width < 1024) return WindowSize.medium;
    return WindowSize.expanded;
  }

  bool get isCompact => this == WindowSize.compact;

  /// Whether navigation belongs at the side rather than the bottom. A bottom bar
  /// on a laptop puts the primary controls as far from the content as possible.
  bool get usesNavigationRail => this != WindowSize.compact;

  /// Whether the rail has room to show labels beside its icons.
  bool get usesExtendedRail => this == WindowSize.expanded;

  /// How wide a column of content is allowed to get.
  ///
  /// Capped deliberately: these are single-column lists of cards, and a card
  /// 1400px wide is unreadable regardless of how much window there is. Roughly a
  /// comfortable reading measure, a little wider on big screens so the extra
  /// space isn't purely wasted.
  double get contentMaxWidth => switch (this) {
        WindowSize.compact => double.infinity,
        WindowSize.medium => 640,
        WindowSize.expanded => 760,
      };
}
