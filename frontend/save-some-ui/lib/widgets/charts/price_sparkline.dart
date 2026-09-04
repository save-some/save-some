import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/theme/tokens.dart';

/// The thin polyline price chart from the design's history frame.
///
/// A CustomPainter rather than a charting package: the design asks for a single
/// unlabelled stroke, which isn't worth a dependency.
class PriceSparkline extends StatelessWidget {
  /// Chronological price observations. Fewer than two points can't form a line,
  /// so a message is shown instead.
  final List<ProductPrice> prices;
  final double height;

  /// Draws a soft fill under the stroke.
  final bool filled;

  const PriceSparkline({
    super.key,
    required this.prices,
    this.height = 140,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (prices.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Not enough price history yet',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: prices.map((p) => p.price).toList(),
          stroke: context.brand.chartLine,
          filled: filled,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color stroke;
  final bool filled;

  const _SparklinePainter({
    required this.values,
    required this.stroke,
    required this.filled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    // A flat series would divide by zero, so it's drawn down the middle.
    final span = max - min;
    const inset = 6.0;
    final usableHeight = size.height - inset * 2;

    double xAt(int i) => size.width * i / (values.length - 1);
    double yAt(double v) => span == 0
        ? size.height / 2
        : inset + usableHeight * (1 - (v - min) / span);

    final path = Path()..moveTo(xAt(0), yAt(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(xAt(i), yAt(values[i]));
    }

    if (filled) {
      final fill = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()..color = stroke.withValues(alpha: 0.10),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Mark the latest observation, which is the price shown alongside the chart.
    canvas.drawCircle(
      Offset(xAt(values.length - 1), yAt(values.last)),
      3.5,
      Paint()..color = stroke,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.stroke != stroke ||
      oldDelegate.filled != filled ||
      !listEquals(oldDelegate.values, values);
}
