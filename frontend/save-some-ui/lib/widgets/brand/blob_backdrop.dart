import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/tokens.dart';

/// The soft taupe circles behind the auth screens.
///
/// These are the largest visual element of the log-in and sign-up frames and were
/// absent from the implementation entirely, which is most of why those screens
/// read as unstyled.
///
/// Blurred and slowly drifting. Hard-edged static circles looked like flat vector
/// shapes sitting on top of the page; a soft edge and a little movement make them
/// read as depth behind the form instead.
class BlobBackdrop extends StatefulWidget {
  final Widget child;

  /// Turns off the animation. Set in tests and honoured automatically when the
  /// platform asks for reduced motion.
  final bool animate;

  const BlobBackdrop({super.key, required this.child, this.animate = true});

  @override
  State<BlobBackdrop> createState() => _BlobBackdropState();
}

class _BlobBackdropState extends State<BlobBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// One slow cycle. Long enough that the movement is felt rather than watched —
  /// a fast drift behind a login form is a distraction.
  static const _period = Duration(seconds: 48);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period);
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    // Respect the OS setting rather than animating regardless.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion && _controller.isAnimating) {
      _controller.stop();
    } else if (!reduceMotion && widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    }

    // Positions, radii and drift are fractions of the shortest side so the
    // composition holds from a narrow phone to a wide desktop window.
    //
    // Ordered as the design has them: a taupe circle upper-right behind the logo,
    // a smaller one clipped off the left edge, and a large sand circle across the
    // bottom. They deliberately stay clear of the vertical middle, where the form
    // sits — an earlier arrangement put the dark circle directly behind the input
    // fields and cost legibility.
    final blobs = <_Blob>[
      _Blob(center: const Offset(0.74, 0.17), radius: 0.34, color: brand.blobTaupe, phase: 0.0),
      _Blob(center: const Offset(-0.06, 0.44), radius: 0.26, color: brand.blobTaupe, phase: 0.35),
      _Blob(center: const Offset(0.50, 0.94), radius: 0.38, color: brand.blobSand, phase: 0.65),
      _Blob(center: const Offset(1.02, 0.70), radius: 0.22, color: brand.blobSand, phase: 0.85),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(color: brand.canvas),
      child: Stack(
        children: [
          // Clipped so a blurred circle can't bleed past the screen edges and
          // brighten the status bar area.
          Positioned.fill(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    for (final blob in blobs)
                      _DriftingBlob(
                        blob: blob,
                        controller: _controller,
                        size: constraints.biggest,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class _Blob {
  /// Centre as a fraction of the viewport.
  final Offset center;

  /// Radius as a fraction of the viewport's *shortest* side.
  ///
  /// Not the width: on a 1440x900 window that made the largest blob 1152px
  /// across, and four of those blurred together left no cream page at all — just
  /// a brown wash.
  final double radius;

  final Color color;

  /// Offset into the shared cycle, so the blobs don't move in lockstep.
  final double phase;

  const _Blob({
    required this.center,
    required this.radius,
    required this.color,
    required this.phase,
  });
}

/// One blurred circle, translated along a slow closed path.
///
/// The blur is applied to a static child and only the transform animates, so the
/// expensive part rasterises once — a RepaintBoundary keeps it that way. Blurring
/// inside the animated subtree would re-run the filter every frame.
class _DriftingBlob extends StatelessWidget {
  final _Blob blob;
  final AnimationController controller;
  final Size size;

  const _DriftingBlob({
    required this.blob,
    required this.controller,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final shortest = size.shortestSide;
    final diameter = shortest * blob.radius * 2;
    // Clamped, not proportional. Tying sigma to the diameter meant a desktop
    // window got a 138px blur, which is indistinguishable from a solid fill.
    final sigma = (diameter * 0.10).clamp(16.0, 44.0);

    // A Lissajous path, so it returns to where it started and never jumps.
    final travel = shortest * 0.05;

    final circle = RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        ),
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            // Slightly translucent so the cream canvas reads through them and
            // they sit behind the page rather than replacing it.
            color: blob.color.withValues(alpha: 0.82),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      // `child` is the pre-blurred circle, passed below so the filter isn't
      // re-run on every frame.
      builder: (context, child) {
        final t = (controller.value + blob.phase) % 1.0;
        final angle = t * 2 * math.pi;
        final dx = math.sin(angle) * travel;
        final dy = math.cos(angle * 2) * travel * 0.6;

        return Positioned(
          left: size.width * blob.center.dx - diameter / 2 + dx,
          top: size.height * blob.center.dy - diameter / 2 + dy,
          child: child!,
        );
      },
      child: circle,
    );
  }
}
