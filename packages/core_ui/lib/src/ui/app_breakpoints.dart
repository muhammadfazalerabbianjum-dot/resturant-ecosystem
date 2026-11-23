/// Breakpoint algebra for the white-label layout primitives (UI-4, p14).
///
/// Pure vocabulary + one LayoutBuilder-backed builder widget. Lanes are the
/// canonical Material adaptive lanes: `compact < 600 <= medium < 1024 <=
/// expanded`. No theme reads, no platform channels — pure width algebra.
library;

import 'package:flutter/widgets.dart';

/// The canonical breakpoint bounds (logical pixels).
///
/// Exact semantics: `width < 600` → compact; `600 <= width < 1024` → medium;
/// `width >= 1024` → expanded.
abstract final class AppBreakpoints {
  /// Upper bound (exclusive) of the compact lane.
  static const double compact = 600;

  /// Upper bound (exclusive) of the medium lane.
  static const double medium = 1024;

  /// The [ResponsiveLane] for [width], by the exact bounds above.
  static ResponsiveLane laneFor(double width) {
    if (width < compact) return ResponsiveLane.compact;
    if (width < medium) return ResponsiveLane.medium;
    return ResponsiveLane.expanded;
  }
}

/// The three responsive lanes.
enum ResponsiveLane { compact, medium, expanded }

/// Rebuilds on ambient-width crossings via [LayoutBuilder] and calls the
/// right [ResponsiveLane].
///
/// The [builder] result is the ONLY child — no wrapper widgets are inserted
/// between the [LayoutBuilder] and the returned widget.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  /// Called with the resolved lane for the current ambient width.
  final Widget Function(BuildContext context, ResponsiveLane lane) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          builder(context, AppBreakpoints.laneFor(constraints.maxWidth)),
    );
  }
}
