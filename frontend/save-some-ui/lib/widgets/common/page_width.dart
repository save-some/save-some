import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/breakpoints.dart';

/// Caps how wide page content gets and centres it.
///
/// Applied once per screen rather than inside each card, so scrollbars and
/// backgrounds still span the full window while the content itself stays a
/// readable column. On a phone this is a no-op.
class PageWidth extends StatelessWidget {
  final Widget child;

  /// Override for screens that want a different measure — a wide chart, say.
  final double? maxWidth;

  const PageWidth({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final limit = maxWidth ?? WindowSize.of(context).contentMaxWidth;
    if (limit == double.infinity) return child;

    return Align(
      // Top, not centre: a short page should start at the top of the viewport
      // rather than float in the middle of it.
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: limit),
        child: child,
      ),
    );
  }
}
