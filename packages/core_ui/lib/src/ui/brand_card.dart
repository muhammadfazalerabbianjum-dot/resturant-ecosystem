import 'package:core_ui/src/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Token-radius card (UI-1, T-2).
///
/// Corner radius resolves from the b10 [AppShapeTokens.cardRadius] token
/// (fallback 16 = the frozen `cardTheme` radius), so a client that configures
/// `theme.shape.cardRadius` reshapes every card without touching this file.
/// Colors come from the ambient `ColorScheme.surface` unless overridden.
///
/// Tap path (P5-13 pattern): when [onTap] is supplied the ONLY tap surface is
/// a real [InkWell] — semantics are provided natively, no wrapper tap detectors.
/// With no [onTap] the card is inert (no tap path exists at all).
class BrandCard extends StatelessWidget {
  /// The card content.
  final Widget child;

  /// Optional tap callback; `null` renders an inert container.
  final VoidCallback? onTap;

  /// Margin OUTSIDE the material surface.
  final EdgeInsetsGeometry? margin;

  /// Padding INSIDE the material surface (default 16 all around).
  final EdgeInsetsGeometry? padding;

  /// Surface fill; falls back to `ColorScheme.surface`.
  final Color? color;

  /// Optional 1px border color (a null side means no side).
  final Color? borderColor;

  const BrandCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shapeTokens =
        theme.extension<AppShapeTokens>() ?? const AppShapeTokens();
    final spacing = AppSpacing.of(context);
    final effectivePadding = padding ?? EdgeInsets.all(spacing.lg);

    final Widget content = Padding(padding: effectivePadding, child: child);

    return Container(
      margin: margin,
      child: Material(
        color: color ?? theme.colorScheme.surface,
        elevation: theme.extension<AppDepthTokens>()?.elevation ?? 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapeTokens.cardRadius),
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!),
        ),
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
