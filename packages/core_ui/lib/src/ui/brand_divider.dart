import 'package:flutter/material.dart';

/// Solid hairline divider (UI-1, T-6).
///
/// Color falls back to the ambient `ThemeData.dividerColor` (theme-owned
/// chrome, same rule as [BrandTextField]'s input chrome). [BrandDivider.dashed]
/// paints a dash-gap rhythm through [DashedLinePainter], whose dash math is a
/// PURE static function (`dashOffsets`) so the layout rule is directly
/// testable (repo law: pure logic gets exact-math assertions, not pixel hopes).
class BrandDivider extends StatelessWidget {
  /// Line thickness (default 1).
  final double thickness;

  /// Leading empty space.
  final double? indent;

  /// Trailing empty space.
  final double? endIndent;

  /// Explicit color; falls back to the ambient divider color.
  final Color? color;

  /// Dash length (dashed variant only).
  final double dashWidth;

  /// Gap between dashes (dashed variant only).
  final double dashGap;

  /// Whether this divider paints dashes instead of a solid line.
  final bool dashed;

  const BrandDivider({
    super.key,
    this.thickness = 1,
    this.indent,
    this.endIndent,
    this.color,
  }) : dashed = false,
       dashWidth = 4,
       dashGap = 3;

  /// A dashed hairline.
  const BrandDivider.dashed({
    super.key,
    this.thickness = 1,
    this.indent,
    this.endIndent,
    this.color,
    this.dashWidth = 4,
    this.dashGap = 3,
  }) : dashed = true;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? Theme.of(context).dividerColor;
    return Container(
      height: thickness,
      margin: EdgeInsetsDirectional.only(
        start: indent ?? 0,
        end: endIndent ?? 0,
      ),
      color: dashed ? null : resolved,
      child: dashed
          ? CustomPaint(
              painter: DashedLinePainter(
                color: resolved,
                thickness: thickness,
                dashWidth: dashWidth,
                dashGap: dashGap,
              ),
              size: Size.fromHeight(thickness),
            )
          : null,
    );
  }
}

/// The dashed-line painter. [dashOffsets] is the pure layout kernel; `paint`
/// only translates it to canvas coordinates.
class DashedLinePainter extends CustomPainter {
  /// Dash color.
  final Color color;

  /// Line thickness.
  final double thickness;

  /// Dash length.
  final double dashWidth;

  /// Gap between dashes.
  final double dashGap;

  /// Paints dashes of [dashWidth] separated by [dashGap] in [color].
  const DashedLinePainter({
    required this.color,
    required this.thickness,
    required this.dashWidth,
    required this.dashGap,
  });

  /// PURE: the start offsets of every dash that FULLY fits in `[0, width]`.
  ///
  /// Inclusive fit (`x + dashWidth <= width`) — a trailing partial dash is
  /// dropped, never clipped. A width narrower than one dash yields nothing
  /// (cosmetic layer degrades, spec L5).
  static List<double> dashOffsets(
    double width,
    double dashWidth,
    double dashGap,
  ) {
    final offsets = <double>[];
    var x = 0.0;
    while (x + dashWidth <= width) {
      offsets.add(x);
      x += dashWidth + dashGap;
    }
    return offsets;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;
    final y = size.height / 2;
    for (final x in dashOffsets(size.width, dashWidth, dashGap)) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.thickness != thickness ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.dashGap != dashGap;
}
