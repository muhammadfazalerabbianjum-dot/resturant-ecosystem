import 'dart:math' as math;

import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:core_ui/src/ui/empty_state_widget.dart';
import 'package:flutter/material.dart';

/// Chart variants in the family (UI-11 / W-3, T-3).
enum BrandChartKind {
  /// Discrete vertical bars, one per bucket.
  bars,

  /// Straight-segment line over discrete buckets — never a spline (L26).
  line,

  /// Share-of-total ring, one arc per bucket.
  donut,
}

/// One data bucket (UI-11 / W-3, T-3).
///
/// [value] drives GEOMETRY ONLY — the chart never formats money or numbers
/// for display (L2): caller-formatted strings belong in [label] or the
/// caller's own annotations around the chart.
@immutable
class BrandChartPoint {
  /// Caller-supplied, already-localised bucket label (L3).
  final String label;

  /// The bucket's numeric magnitude (display geometry only).
  final double value;

  const BrandChartPoint({required this.label, required this.value});
}

/// Token-coloured chart over caller-supplied series (UI-11 / W-3, T-3).
///
/// **L26 (chart honesty):** an empty series renders the library's
/// [EmptyStateWidget] (never a fake axis); a single-point series renders
/// without dividing by zero; buckets are discrete — the line variant draws
/// straight segments only, so it implies no precision the data does not
/// carry. Every label is caller-supplied; every colour is a brand token (L1).
class BrandChart extends StatelessWidget {
  /// Which visualisation to draw.
  final BrandChartKind kind;

  /// The caller's data; empty => [EmptyStateWidget].
  final List<BrandChartPoint> points;

  /// Caller-supplied empty-state title (L3).
  final String emptyTitle;

  /// Caller-supplied empty-state subtitle (L3).
  final String emptySubtitle;

  /// Empty-state icon (not user-facing copy, so it may default).
  final IconData emptyIcon;

  /// Optional caller-supplied heading.
  final String? title;

  /// Renders a token-coloured dot + label entry per point when true.
  final bool showLegend;

  /// Plot area height (and the donut's diameter) in logical pixels.
  final double chartHeight;

  const BrandChart({
    super.key,
    required this.kind,
    required this.points,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.emptyIcon = Icons.bar_chart_rounded,
    this.title,
    this.showLegend = false,
    this.chartHeight = 150,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    if (points.isEmpty) {
      return EmptyStateWidget(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }
    final colors = _palette(brand, points.length);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null) ...<Widget>[
          Text(
            title!,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: brand.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
        ],
        switch (kind) {
          BrandChartKind.bars => _buildBars(brand, colors),
          BrandChartKind.line => _buildLine(brand, colors),
          BrandChartKind.donut => _buildDonut(colors),
        },
        if (showLegend) ...<Widget>[
          const SizedBox(height: 10),
          _buildLegend(brand, colors),
        ],
      ],
    );
  }

  /// The token palette: brand hues cycled per bucket (L1 — never raw hues).
  static List<Color> _palette(BrandColors brand, int count) {
    final base = <Color>[
      brand.primary,
      brand.secondary,
      brand.accent,
      brand.success,
      brand.warning,
      brand.error,
    ];
    return <Color>[for (var i = 0; i < count; i++) base[i % base.length]];
  }

  /// Bar fill ratio in 0..1. Guards BOTH divisions (L26): a non-positive
  /// value renders flat, and an all-zero/all-negative series never divides.
  static double _barFactor(double value, double max) {
    if (value <= 0) return 0;
    if (max <= 0) return 0;
    return value / max;
  }

  static double _maxValue(List<BrandChartPoint> points) =>
      points.map((p) => p.value).reduce(math.max);

  Widget _buildBars(BrandColors brand, List<Color> colors) {
    final max = _maxValue(points);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < points.length; i++)
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: _barFactor(points[i].value, max),
                      widthFactor: 1,
                      child: Container(color: colors[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _buildLabels(brand),
      ],
    );
  }

  Widget _buildLine(BrandColors brand, List<Color> colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: chartHeight,
          width: double.infinity,
          child: CustomPaint(
            painter: BrandChartLinePainter(points: points, color: colors.first),
          ),
        ),
        const SizedBox(height: 6),
        _buildLabels(brand),
      ],
    );
  }

  Widget _buildDonut(List<Color> colors) {
    return SizedBox(
      height: chartHeight,
      width: chartHeight,
      child: CustomPaint(
        painter: BrandChartDonutPainter(points: points, colors: colors),
      ),
    );
  }

  /// Discrete bucket labels: one line, ellipsised, never a layout overflow.
  Widget _buildLabels(BrandColors brand) {
    return Row(
      children: <Widget>[
        for (final point in points)
          Expanded(
            child: Text(
              point.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: brand.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _buildLegend(BrandColors brand, List<Color> colors) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: <Widget>[
        for (var i = 0; i < points.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  points[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: brand.textSecondary),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Straight-segment painter for [BrandChartKind.line] (UI-11 / W-3, T-3).
///
/// **L26:** [plot] exposes the vertex layout so tests can prove (a) a single
/// point is CENTRED rather than divided by `n - 1`, (b) every vertex is
/// finite, and (c) the spacing is strictly linear — this painter draws
/// `lineTo` segments only, never a spline.
class BrandChartLinePainter extends CustomPainter {
  BrandChartLinePainter({required this.points, required this.color});

  /// The caller's discrete buckets.
  final List<BrandChartPoint> points;

  /// Brand token colour for the stroke and dots (L1).
  final Color color;

  /// Vertex layout for [size] — finite for every input, including a single
  /// point and an all-zero series (L26: no divide-by-zero, no NaN).
  List<Offset> plot(Size size) {
    var max = 0.0;
    for (final point in points) {
      if (point.value > max) max = point.value;
    }
    final n = points.length;
    final offsets = <Offset>[];
    for (var i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : size.width * i / (n - 1);
      final value = points[i].value;
      final ratio = max <= 0 || value <= 0 ? 0.0 : value / max;
      offsets.add(Offset(x, size.height - ratio * size.height));
    }
    return offsets;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final offsets = plot(size);
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = color;
    for (final offset in offsets) {
      canvas.drawCircle(offset, 3, dot);
    }
  }

  @override
  bool shouldRepaint(BrandChartLinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

/// Arc-per-bucket painter for [BrandChartKind.donut] (UI-11 / W-3, T-3).
///
/// **L26:** [fractions] guards every division — a single point fills the
/// ring, an all-zero series splits it evenly, negatives clamp to zero.
class BrandChartDonutPainter extends CustomPainter {
  BrandChartDonutPainter({required this.points, required this.colors});

  /// The caller's discrete buckets.
  final List<BrandChartPoint> points;

  /// Token colour per bucket (may be shorter than [points]; it cycles).
  final List<Color> colors;

  /// Share of the ring per bucket; always finite, always sums to 1.
  List<double> fractions() {
    var total = 0.0;
    for (final point in points) {
      total += point.value > 0 ? point.value : 0;
    }
    final n = points.length;
    if (total <= 0) {
      return <double>[for (var i = 0; i < n; i++) 1 / n];
    }
    return <double>[
      for (final point in points) (point.value > 0 ? point.value : 0) / total,
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shares = fractions();
    final rect = Offset.zero & size;
    var startAngle = -math.pi / 2;
    for (var i = 0; i < shares.length; i++) {
      final sweep = shares[i] * 2 * math.pi;
      canvas.drawArc(
        rect.deflate(8),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = colors[i % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 20
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(BrandChartDonutPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.colors != colors;
}
