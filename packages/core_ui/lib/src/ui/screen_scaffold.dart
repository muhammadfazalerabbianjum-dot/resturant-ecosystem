/// Screen scaffold composition for the white-label apps (UI-4, p14).
///
/// Pure widget composition — no platform channels: SafeArea + the b10
/// [ScaffoldBackground] decorative layer (degrade-safe) + an optional
/// centered max-content-width constraint + an optional bottom nav slot
/// passthrough. The body is always rendered.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Screen shell: SafeArea → ScaffoldBackground → (optional centered
/// [maxContentWidth]) → body.
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.body,
    this.maxContentWidth = 640,
    this.bottomNav,
  });

  /// The screen content — always rendered.
  final Widget body;

  /// Maximum content width; the body is centered within it. Defaults to
  /// 640; pass `null` to leave the body unconstrained.
  final double? maxContentWidth;

  /// Optional bottom navigation slot, passed through to the [Scaffold]
  /// untouched.
  final Widget? bottomNav;

  @override
  Widget build(BuildContext context) {
    Widget content = maxContentWidth == null
        ? body
        : Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth!),
              child: body,
            ),
          );
    return Scaffold(
      bottomNavigationBar: bottomNav,
      body: SafeArea(child: ScaffoldBackground(child: content)),
    );
  }
}
