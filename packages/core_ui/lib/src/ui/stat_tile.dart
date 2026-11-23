import 'package:core_ui/src/theme/app_tokens.dart';
import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:flutter/material.dart';

/// Prominent metric tile (UI-3, T-1).
///
/// Label (secondary) + value (prominent `w800`), with an optional leading
/// icon and trailing delta string. Colors resolve through the [BrandColors]
/// token chain (L1) — never a hardcoded palette. Card shape follows the b10
/// [AppShapeTokens.cardRadius] token (fallback 16 = the frozen card radius).
///
/// Tap path (BrandCard pattern): when [onTap] is supplied the ONLY tap
/// surface is a real native [InkWell] (0.10 — no p12/p14 motion wrapper);
/// with no [onTap] the tile is inert (no tap path exists at all).
class StatTile extends StatelessWidget {
  /// The metric label (caller-supplied, L3).
  final String label;

  /// The metric value (caller-supplied, L3) — rendered prominent (w800).
  final String value;

  /// Optional leading icon.
  final IconData? icon;

  /// Optional trailing delta string (e.g. a trend marker).
  final String? delta;

  /// Optional tap callback; `null` renders an inert tile.
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.delta,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shapeTokens =
        theme.extension<AppShapeTokens>() ?? const AppShapeTokens();
    final brand = BrandColors.of(context);
    final spacing = AppSpacing.of(context);

    final Widget content = Padding(
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: brand.primary, size: 20),
                SizedBox(width: spacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: brand.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: brand.textPrimary,
                  ),
                ),
              ),
              if (delta != null)
                Text(
                  delta!,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: brand.success,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return Material(
      color: theme.colorScheme.surface,
      elevation: theme.extension<AppDepthTokens>()?.elevation ?? 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shapeTokens.cardRadius),
      ),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
