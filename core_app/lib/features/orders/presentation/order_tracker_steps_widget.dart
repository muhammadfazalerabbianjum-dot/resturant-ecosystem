import 'dart:ui' as ui;
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import '../domain/order_model.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/app/l10n/status_role_labels.dart';

/// OrderTrackerStepsWidget displays the steps of an order's progress.
///
/// UI-13 (p21 B1, M-8): the hand-rolled ListTile rows are replaced by the
/// frozen library [OrderTimeline] (p23 W-2) — this widget now only maps
/// `OrderStatus` -> [TimelineStepState] and feeds the timeline the UX-2
/// step-of-total label composition byte-identically, so the header/selected/
/// live-region announcement contract of the current step survives the
/// restyle (p20 B2's sanctuary assertion).
///
/// Law 6 glassmorphism shell (BackdropFilter + AnimatedContainer) is
/// preserved around the timeline — p20 B2's frozen visual contract.
class OrderTrackerStepsWidget extends StatelessWidget {
  final OrderModel order;
  final OrderStatus currentStatus;

  const OrderTrackerStepsWidget({
    super.key,
    required this.order,
    required this.currentStatus,
  });

  @override
  Widget build(BuildContext context) {
    const statuses = OrderStatus.values;
    final currentIndex = statuses.indexOf(currentStatus);
    final loc = AppLocalizations.of(context);

    final steps = <OrderTimelineStep>[
      for (var index = 0; index < statuses.length; index++)
        OrderTimelineStep(
          // UX-2 (05-P1-A11Y-TRACKER): the header label is the step-of-total
          // phrase plus the localized status name — the exact pre-adoption
          // composition, so "Step n of m" nodes and the current-step live
          // region are unchanged (the library announces `label` verbatim).
          label:
              '${loc.trackerStepOfTotal(index + 1, statuses.length)}: '
              '${orderStatusLabel(loc, statuses[index])}',
          state: index < currentIndex
              ? TimelineStepState.completed
              : index == currentIndex
              ? TimelineStepState.current
              : TimelineStepState.future,
          // OrderModel carries no per-step timestamps (createdAt/updatedAt
          // only), so the library's caller-formatted timestamp stays null —
          // this wave never fabricates displayed data (L13/L14, DECISIONS).
        ),
    ];

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
      // p20 B2 keeps the animated glass shell (BackdropFilter + margin +
      // duration are unchanged); UI-13 (p21 H2, F3-15) drops the shell's
      // `BoxDecoration` — it painted NOTHING (a fully transparent fill, no
      // border, no shadow) and only existed to carry an 8 px radius a
      // transparent surface never showed. The per-row primary tint lives in
      // the library's completed/current/future markers, so future steps are
      // still never washed in the active colour.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: OrderTimeline(steps: steps),
      ),
    );
  }
}
