import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:core_ui/src/ui/shapes.dart';
import 'package:flutter/material.dart';

/// Semantic tone of an [InfoBanner].
///
/// Q3 (semantic state palette): five DISTINCT states — an availability
/// state (soldOut) is never dressed as a system error.
enum InfoTone { info, success, warning, error, soldOut }

/// Inline semantic banner (UI-1, T-7): tone → icon + brand color, container
/// tint at α .08, optional dismiss.
///
/// Colors resolve through [BrandColors.of] (config-driven; AppColors fallback
/// — Law 3). The banner is cosmetic chrome AROUND caller content (L5): the
/// message itself is [child], never hardcoded.
class InfoBanner extends StatelessWidget {
  /// A11y fallback tooltip (L3) — call sites are expected to pass a localized
  /// [dismissTooltip]; see `GlobalErrorWidget.kGlobalErrorFallbackBody` for
  /// the repo's documented-fallback precedent.
  static const String kDefaultDismissTooltip = 'Dismiss';

  /// The banner's semantic tone.
  final InfoTone tone;

  /// Optional bold lead line (caller-supplied).
  final String? title;

  /// The message content (caller-supplied; may be any widget).
  final Widget child;

  /// Optional dismiss callback; `null` renders no dismiss affordance.
  final VoidCallback? onDismiss;

  /// Semantic label for the dismiss button.
  final String dismissTooltip;

  const InfoBanner({
    super.key,
    required this.tone,
    required this.child,
    this.title,
    this.onDismiss,
    this.dismissTooltip = kDefaultDismissTooltip,
  });

  /// The tone's icon (pure, directly assertable).
  static IconData iconFor(InfoTone tone) => switch (tone) {
    InfoTone.info => Icons.info_outline,
    InfoTone.success => Icons.check_circle_outline,
    InfoTone.warning => Icons.warning_amber_rounded,
    InfoTone.error => Icons.error_outline,
    InfoTone.soldOut => Icons.remove_shopping_cart,
  };

  /// The tone's brand color (pure, directly assertable).
  static Color colorFor(InfoTone tone, BrandColors brand) => switch (tone) {
    InfoTone.info => brand.primary,
    InfoTone.success => brand.success,
    InfoTone.warning => brand.warning,
    InfoTone.error => brand.error,
    InfoTone.soldOut => brand.soldOut,
  };

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    final color = colorFor(tone, brand);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BrandShapes.borderMedium,
      ),
      child: Row(
        children: [
          Icon(iconFor(tone), color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                DefaultTextStyle.merge(
                  style: TextStyle(color: brand.textPrimary, fontSize: 13),
                  child: child,
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              tooltip: dismissTooltip,
              icon: const Icon(Icons.close),
              color: brand.textSecondary,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
