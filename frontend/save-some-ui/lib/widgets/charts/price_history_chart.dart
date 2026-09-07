import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/util/format.dart';

/// One retailer's price history for a product, as a line in the chart.
class PriceSeries {
  final String label;
  final Color color;

  /// Oldest first.
  final List<ProductPrice> points;

  const PriceSeries({
    required this.label,
    required this.color,
    required this.points,
  });

  double get latest => points.last.price;
}

/// A price chart with real axes — as many lines as retailers carrying the
/// product, each in its own colour, with a legend.
///
/// Replaces the old single-line sparkline on the product page, which drew one
/// unlabelled trace for the whole product: when two chains stocked the same
/// item their observations interleaved into a zig-zag that looked like wild
/// price swings but was really two stores' different prices alternating. The
/// comparison IS the product, so the chart shows the comparison — and axes so
/// the eye can read "is now a good time to buy" without hovering anything.
class PriceHistoryChart extends StatelessWidget {
  final List<PriceSeries> series;
  final double height;

  const PriceHistoryChart({super.key, required this.series, this.height = 180});

  /// Stable brand-ish palette; index by series so a retailer keeps its colour
  /// across products within a session.
  static List<Color> paletteFor(ColorScheme scheme) => [
    scheme.primary,
    const Color(0xFFE07A3F),
    const Color(0xFF2A9D8F),
    const Color(0xFFB44C4C),
    const Color(0xFF5B7DB1),
    scheme.tertiary,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = series.expand((s) => s.points).toList();
    if (all.isEmpty) {
      return SizedBox(height: height);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _ChartPainter(
              series: series,
              gridColor: scheme.outlineVariant.withValues(alpha: 0.5),
              labelColor: scheme.onSurfaceVariant,
              labelStyle: theme.textTheme.labelSmall!,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: [
            for (final s in series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${s.label}  ${formatUsd(s.latest)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<PriceSeries> series;
  final Color gridColor;
  final Color labelColor;
  final TextStyle labelStyle;

  _ChartPainter({
    required this.series,
    required this.gridColor,
    required this.labelColor,
    required this.labelStyle,
  });

  static const double _leftGutter = 48;
  static const double _bottomGutter = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final all = series.expand((s) => s.points).toList();
    if (all.isEmpty) return;

    var minP = all.first.price, maxP = all.first.price;
    var minT = all.first.scrapedAt, maxT = all.first.scrapedAt;
    for (final p in all) {
      if (p.price < minP) minP = p.price;
      if (p.price > maxP) maxP = p.price;
      if (p.scrapedAt.isBefore(minT)) minT = p.scrapedAt;
      if (p.scrapedAt.isAfter(maxT)) maxT = p.scrapedAt;
    }
    // Pad the value axis so lines and labels never touch the frame, and a
    // perfectly flat history (single price) still gets a sane span.
    var span = maxP - minP;
    if (span < 0.01) span = (maxP * 0.1).clamp(1.0, double.infinity);
    minP -= span * 0.08;
    maxP += span * 0.08;
    span = maxP - minP;

    final plot = Rect.fromLTRB(
      _leftGutter,
      4,
      size.width - 6,
      size.height - _bottomGutter,
    );
    if (plot.width <= 0) return;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    TextSpan span1(String t) => TextSpan(
      text: t,
      style: labelStyle.copyWith(color: labelColor),
    );

    // Horizontal grid + price labels (four lines: the span itself and 1/3s).
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final frac = i / 3;
      final y = plot.bottom - frac * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final value = minP + frac * span;
      textPainter
        ..text = span1(formatUsd(value))
        ..layout();
      textPainter.paint(
        canvas,
        Offset(plot.left - 6 - textPainter.width, y - textPainter.height / 2),
      );
    }

    // Date labels at the ends of the time axis.
    final days = maxT.difference(minT).inDays;
    void dateLabel(DateTime t, bool trailing) {
      final stamp = '${t.month}/${t.day}';
      textPainter
        ..text = span1(stamp)
        ..layout();
      canvas.drawLine(
        Offset(trailing ? plot.right : plot.left, plot.bottom),
        Offset(trailing ? plot.right : plot.left, plot.bottom + 3),
        grid,
      );
      textPainter.paint(
        canvas,
        Offset(
          trailing ? plot.right - textPainter.width : plot.left,
          plot.bottom + 6,
        ),
      );
    }

    if (days > 0) {
      dateLabel(minT, false);
      dateLabel(maxT, true);
    }

    Offset toPoint(ProductPrice p) => Offset(
      plot.left +
          (days == 0
              ? plot.width / 2
              : (p.scrapedAt.difference(minT).inSeconds /
                        Duration.millisecondsPerSecond /
                        (days * 86400)) *
                    plot.width),
      plot.bottom - ((p.price - minP) / span) * plot.height,
    );

    for (final s in series) {
      final line = Paint()
        ..color = s.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path();
      for (var i = 0; i < s.points.length; i++) {
        final o = toPoint(s.points[i]);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(path, line);

      // A dot on the newest observation, so "where each retailer is now"
      // reads at a glance.
      final latest = s.points.last;
      canvas.drawCircle(toPoint(latest), 3.5, Paint()..color = s.color);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.series != series || old.labelStyle != labelStyle;
}
