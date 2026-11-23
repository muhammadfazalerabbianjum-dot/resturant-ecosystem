import 'package:core_ui/src/theme/app_tokens.dart';
import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:flutter/material.dart';

/// Composed backdrop (UI-1, T-8) — deliberately NOT a Scaffold, so it nests
/// inside screens, tab bodies, sheets and dialogs alike.
///
/// Layer order, bottom-up: scaffold background → b10 [ScaffoldBackground]
/// decorative overlay (degrades silently when unconfigured) → optional
/// top-down brand gradient derived from [BrandColors.primary] at α .06 →
/// [body]. Both decorative layers are independently disable-able and both
/// fail safe (spec L5): they render BENEATH content and never throw when a
/// client config omits them.
class GradientScaffold extends StatelessWidget {
  /// The screen content, rendered above every decorative layer.
  final Widget body;

  /// Whether the brand-tinted top-down gradient is applied (default true).
  final bool applyGradient;

  /// Whether the b10 backdrop overlay is applied (default true).
  final bool applyOverlay;

  const GradientScaffold({
    super.key,
    required this.body,
    this.applyGradient = true,
    this.applyOverlay = true,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    final background = Theme.of(context).scaffoldBackgroundColor;

    Widget content = ColoredBox(color: background, child: body);
    if (applyGradient) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [brand.primary.withValues(alpha: 0.06), background],
          ),
        ),
        child: content,
      );
    }
    if (applyOverlay) {
      content = ScaffoldBackground(child: content);
    }
    return content;
  }
}
