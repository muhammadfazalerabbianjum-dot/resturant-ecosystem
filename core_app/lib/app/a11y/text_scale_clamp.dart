import 'package:flutter/material.dart';

/// Maximum text scale the app's layouts are guaranteed to support.
///
/// UX-2 (05-P2-A11Y-TEXTSCALE): the audit found no clamp anywhere and trap
/// sites that break between 1.3x and 2.0x (fixed-aspect home-grid cells,
/// one-line CTA labels, two-line address rows). Every OS accessibility scale
/// ABOVE this ceiling is clamped to it, while 2.0x itself passes through
/// unchanged and is proven overflow-free against the real screens by
/// `test/ui/text_scale_clamp_test.dart`.
///
/// Applied per customer-facing screen surface (home, menu, cart, checkout,
/// tracker, locations, dish detail) instead of in `main.dart`: the app shell
/// is another window's territory (collision ledger) and no UX-2 sync point
/// covers it — recorded in the batch addendum.
const double kMaxSupportedTextScale = 2.0;

/// Clamps [MediaQueryData.textScaler] for the subtree to
/// [kMaxSupportedTextScale] so extreme OS font scales cannot break layout.
class ClampedTextScale extends StatelessWidget {
  const ClampedTextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: kMaxSupportedTextScale,
      child: child,
    );
  }
}
