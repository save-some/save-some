import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/tokens.dart';

/// The soft taupe circles behind the auth screens.
///
/// These are the largest single visual element of the design's log-in and
/// sign-up frames and were absent from the implementation entirely, which is
/// most of why those screens read as unstyled. Drawn with a painter rather than
/// positioned Containers so the circles can overflow the viewport without
/// affecting layout or introducing scrollable overhang.
class BlobBackdrop extends StatelessWidget {
  final Widget child;

  const BlobBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return DecoratedBox(
      decoration: BoxDecoration(color: brand.canvas),
      child: CustomPaint(
        painter: _BlobPainter(taupe: brand.blobTaupe, sand: brand.blobSand),
        child: child,
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Color taupe;
  final Color sand;

  const _BlobPainter({required this.taupe, required this.sand});

  @override
  void paint(Canvas canvas, Size size) {
    // Positions and radii are fractions of the viewport so the composition holds
    // from a narrow phone to a wide desktop window.
    //
    // Ordered as the design has them: a taupe circle upper-right behind the
    // logo, a smaller taupe one clipped off the left edge, and a large sand
    // circle across the bottom. They deliberately stay clear of the vertical
    // middle, where the form sits — an earlier arrangement put the dark circle
    // directly behind the input fields and cost legibility.
    final circles = <(Offset, double, Color)>[
      (Offset(size.width * 0.74, size.height * 0.17), size.width * 0.40, taupe),
      (Offset(size.width * -0.06, size.height * 0.44), size.width * 0.26, taupe),
      (Offset(size.width * 0.50, size.height * 0.94), size.width * 0.46, sand),
      (Offset(size.width * 1.02, size.height * 0.70), size.width * 0.22, sand),
    ];

    for (final (center, radius, color) in circles) {
      canvas.drawCircle(center, radius, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter oldDelegate) =>
      oldDelegate.taupe != taupe || oldDelegate.sand != sand;
}
