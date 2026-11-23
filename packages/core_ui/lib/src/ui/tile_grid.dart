import 'package:flutter/material.dart';

/// Embeddable tile grid (UI-3, T-5).
///
/// A thin layout wrapper over [GridView]: fixed [crossAxisCount], square-ish
/// [childAspectRatio], uniform [spacing] on both axes, children order
/// preserved. Defaults are embeddable by construction (L5): `shrinkWrap` +
/// `NeverScrollableScrollPhysics` so the grid lays out inside a parent
/// scroll view without stealing gestures; [scrollable] restores normal grid
/// scrolling when the grid itself is the scroll surface.
class TileGrid extends StatelessWidget {
  /// Number of columns.
  final int crossAxisCount;

  /// Width/height ratio of each cell (default 1.0 — square).
  final double childAspectRatio;

  /// Uniform gutter between cells on both axes.
  final double spacing;

  /// Whether the grid scrolls itself. Default `false`: shrinkWrap +
  /// NeverScrollable (embeddable); `true` restores normal scrolling.
  final bool scrollable;

  /// The tiles, in paint order (preserved verbatim).
  final List<Widget> children;

  const TileGrid({
    super.key,
    required this.crossAxisCount,
    this.childAspectRatio = 1.0,
    this.spacing = 12,
    this.scrollable = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
    );
    return GridView(
      gridDelegate: delegate,
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}
