import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// An SVG asset with a consistent loading placeholder.
///
/// The `SvgPicture.asset` + `CircularProgressIndicator(strokeWidth: 3)` block
/// this replaces was copy-pasted four times across three files, each with
/// slightly different placeholder dimensions.
class AppSvg extends StatelessWidget {
  final String asset;
  final double size;

  const AppSvg(this.asset, {super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      height: size,
      width: size,
      placeholderBuilder: (_) => SizedBox(
        height: size,
        width: size,
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
