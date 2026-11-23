import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:flutter/material.dart';

/// Lifecycle state of one [OrderTimelineStep] (UI-11 / W-2, T-2).
enum TimelineStepState {
  /// Already done — rendered with a check marker.
  completed,

  /// The step in progress — rendered emphasised and announced as a live
  /// region so assistive tech answers "where is my order".
  current,

  /// Not started yet — rendered muted.
  future,

  /// Terminated badly (cancelled/failed) — rendered with the error marker.
  error,
}

/// Reading direction of an [OrderTimeline] (UI-11 / W-2, T-2).
enum OrderTimelineLayout {
  /// Stacked steps with a connector rail (the order-tracker default).
  vertical,

  /// Side-by-side steps with connectors between markers.
  horizontal,
}

/// One step of an [OrderTimeline] (UI-11 / W-2, T-2).
///
/// [label] and [timestamp] are caller-supplied, already-localised strings
/// (L3 — the library never composes copy; the timestamp is displayed and
/// announced verbatim, never parsed).
@immutable
class OrderTimelineStep {
  /// Caller-supplied, already-localised step name.
  final String label;

  /// Optional caller-supplied, already-formatted time for this step.
  final String? timestamp;

  /// Which lifecycle state this step renders.
  final TimelineStepState state;

  const OrderTimelineStep({
    required this.label,
    this.timestamp,
    this.state = TimelineStepState.future,
  });
}

/// Ordered step list for order/progress tracking (UI-11 / W-2, T-2).
///
/// Pure presentation: the widget renders the [steps] it is given and keeps no
/// state, no timers and no callbacks — an adoption surface for `p21` (M-8).
/// Semantics: every step is a header node labelled with the caller's label
/// (plus timestamp when present); completed/current steps are `selected` and
/// only the current step is a live region (mirroring the app-side tracker's
/// UX-2 announcement contract).
class OrderTimeline extends StatelessWidget {
  /// The ordered steps; first is top-most (vertical) / leading (horizontal).
  final List<OrderTimelineStep> steps;

  /// Which layout to render (default: [OrderTimelineLayout.vertical]).
  final OrderTimelineLayout layout;

  const OrderTimeline({
    super.key,
    required this.steps,
    this.layout = OrderTimelineLayout.vertical,
  });

  /// The announced/labelled string: the caller's label, plus the caller's
  /// timestamp when one exists. Both arrive formatted — this method only
  /// joins them (no parsing, no localisation of its own).
  String _announce(OrderTimelineStep step) {
    final time = step.timestamp;
    return time == null ? step.label : '${step.label} $time';
  }

  @override
  Widget build(BuildContext context) {
    if (layout == OrderTimelineLayout.vertical) {
      return Column(
        children: <Widget>[
          for (var index = 0; index < steps.length; index++)
            _buildVerticalStep(context, steps[index], index),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < steps.length; index++) ...<Widget>[
          if (index > 0) _buildHorizontalConnector(context),
          Expanded(child: _buildStepBody(context, steps[index], index)),
        ],
      ],
    );
  }

  Widget _buildVerticalStep(
    BuildContext context,
    OrderTimelineStep step,
    int index,
  ) {
    final brand = BrandColors.of(context);
    final isLast = index == steps.length - 1;
    return Semantics(
      container: true,
      header: true,
      selected: _isSelected(step),
      liveRegion: step.state == TimelineStepState.current,
      label: _announce(step),
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                children: <Widget>[
                  _buildMarker(context, step, index),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: brand.textPrimary12),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildStepBody(context, step, index)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalConnector(BuildContext context) {
    final brand = BrandColors.of(context);
    return SizedBox(
      width: 16,
      child: Padding(
        padding: const EdgeInsets.only(top: 13),
        child: Container(height: 2, color: brand.textPrimary12),
      ),
    );
  }

  /// Label (+ optional timestamp) block — shared by both layouts so the two
  /// readings never drift apart. In the horizontal layout the step marker
  /// leads the block; in the vertical layout the marker is the rail column.
  Widget _buildStepBody(
    BuildContext context,
    OrderTimelineStep step,
    int index,
  ) {
    final brand = BrandColors.of(context);
    final isCurrent = step.state == TimelineStepState.current;
    final isError = step.state == TimelineStepState.error;
    final isCompleted = step.state == TimelineStepState.completed;
    final Color labelColor = isError
        ? brand.error
        : isCurrent || isCompleted
        ? brand.textPrimary
        : brand.textSecondary;
    final time = step.timestamp;
    final horizontal = layout == OrderTimelineLayout.horizontal;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: horizontal
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: <Widget>[
        if (horizontal) ...<Widget>[
          _buildMarker(context, step, index),
          const SizedBox(height: 6),
        ],
        Text(
          step.label,
          textAlign: horizontal ? TextAlign.center : TextAlign.start,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: labelColor,
            fontSize: 14,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        if (time != null)
          Text(
            time,
            style: TextStyle(color: brand.textSecondary, fontSize: 12),
          ),
      ],
    );
  }

  /// Leading marker: check (completed), step number (current/future) or the
  /// error flag — token colours only (L1).
  Widget _buildMarker(BuildContext context, OrderTimelineStep step, int index) {
    final brand = BrandColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final Widget child;
    final BoxDecoration decoration;
    switch (step.state) {
      case TimelineStepState.completed:
        child = Icon(Icons.check, size: 16, color: scheme.onPrimary);
        decoration = BoxDecoration(
          color: brand.success,
          shape: BoxShape.circle,
        );
      case TimelineStepState.current:
        child = Text(
          '${index + 1}',
          style: TextStyle(
            color: scheme.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        );
        decoration = BoxDecoration(
          color: brand.primary,
          shape: BoxShape.circle,
        );
      case TimelineStepState.future:
        child = Text(
          '${index + 1}',
          style: TextStyle(color: brand.textSecondary, fontSize: 12),
        );
        decoration = BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: brand.textSecondary),
        );
      case TimelineStepState.error:
        child = Icon(Icons.error_outline, size: 16, color: scheme.onError);
        decoration = BoxDecoration(color: brand.error, shape: BoxShape.circle);
    }
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: decoration,
      child: child,
    );
  }

  bool _isSelected(OrderTimelineStep step) =>
      step.state == TimelineStepState.completed ||
      step.state == TimelineStepState.current;
}
