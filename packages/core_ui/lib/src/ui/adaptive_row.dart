/// Adaptive row/column container (UI-4, p14).
///
/// `compact` lane → [Column]; `medium`/`expanded` lanes → [Row]. The lane
/// comes from the ambient width via [ResponsiveBuilder] (LayoutBuilder —
/// never MediaQuery hacks). [spacing] is applied BETWEEN children in both
/// orientations; children order is preserved.
library;

import 'package:flutter/material.dart';

import 'app_breakpoints.dart';

/// Lays its children out in a Row on medium/expanded widths and a Column on
/// compact widths, with [spacing] between adjacent children.
class AdaptiveRow extends StatelessWidget {
  const AdaptiveRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.crossAxisAlignment,
    this.mainAxisAlignment,
  });

  /// The children, in preserved order.
  final List<Widget> children;

  /// Space inserted between adjacent children (both orientations).
  final double spacing;

  /// Optional cross-axis alignment forwarded to the Row/Column.
  final CrossAxisAlignment? crossAxisAlignment;

  /// Optional main-axis alignment forwarded to the Row/Column.
  final MainAxisAlignment? mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, lane) {
        final Widget Function(List<Widget> spaced) layout = switch (lane) {
          ResponsiveLane.compact => (spaced) => Column(
            crossAxisAlignment: crossAxisAlignment ?? CrossAxisAlignment.center,
            mainAxisAlignment: mainAxisAlignment ?? MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: spaced,
          ),
          _ => (spaced) => Row(
            crossAxisAlignment: crossAxisAlignment ?? CrossAxisAlignment.center,
            mainAxisAlignment: mainAxisAlignment ?? MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: spaced,
          ),
        };
        final spaced = <Widget>[
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              lane == ResponsiveLane.compact
                  ? SizedBox(height: spacing)
                  : SizedBox(width: spacing),
            children[i],
          ],
        ];
        return layout(spaced);
      },
    );
  }
}
