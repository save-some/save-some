import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/tokens.dart';

/// The page background every tab sits on.
///
/// The flat cream canvas was the single biggest reason the web build read as
/// unfinished: a 1900px window filled with one uniform beige left the content
/// looking like a strip someone forgot to decorate. This adds the minimum a
/// website background needs — a soft vertical warmth and two low-opacity
/// glows echoing the auth screens' blob palette — without competing with the
/// cards on top of it. Static, not animated: the drifting blobs belong behind
/// a login form, not behind a list you scroll.
class CanvasBackdrop extends StatelessWidget {
  final Widget child;

  const CanvasBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            brand.canvas,
            Color.alphaBlend(
              brand.blobSand.withValues(alpha: 0.14),
              brand.canvas,
            ),
          ],
          stops: const [0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Corner glows, same family as the auth blobs at a fraction of the
          // presence. Fractional positions keep the composition on phones.
          Positioned(
            right: -140,
            top: -160,
            child: _Glow(color: brand.blobTaupe, size: 460, alpha: 0.13),
          ),
          Positioned(
            left: -180,
            bottom: -200,
            child: _Glow(color: brand.blobSand, size: 560, alpha: 0.18),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double alpha;

  const _Glow({required this.color, required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
