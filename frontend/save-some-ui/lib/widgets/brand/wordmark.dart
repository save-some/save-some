import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/common/svg_asset.dart';

/// The stacked "SAVE / SOME" wordmark.
///
/// Replaces a raw `Text('SAVE\nSOME')` that was pinned inside a
/// `SizedBox(100, 100)` at `fontSize: 30` — which clipped — and that appeared as
/// 'SAVE\nSOME' on sign-in but 'Save\nSome' on sign-up. Casing is fixed here so
/// the two screens can't drift again.
class SaveSomeWordmark extends StatelessWidget {
  /// Cap height of the type. The auth screens use the default; smaller values
  /// suit headers.
  final double fontSize;

  /// Whether to show the wallet logo above the type.
  final bool showLogo;

  final double logoSize;

  const SaveSomeWordmark({
    super.key,
    this.fontSize = 44,
    this.showLogo = true,
    this.logoSize = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLogo) ...[
          AppSvg('assets/wallet-logo.svg', size: logoSize),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(
          'SAVE\nSOME',
          textAlign: TextAlign.center,
          // No SizedBox: the text lays itself out, so it can't clip.
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: fontSize,
              ),
        ),
      ],
    );
  }
}
