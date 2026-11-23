import 'package:core_ui/src/theme/app_tokens.dart';
import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:flutter/material.dart';

/// Settings-list tile (UI-3, T-2).
///
/// Leading icon + title (+ optional subtitle) + a trailing slot: the caller's
/// [trailing] widget when supplied, otherwise a native chevron when [onTap]
/// is non-null. Disabled ([onTap] == null) renders NO chevron and NO tap
/// path — an inert row, not a fake button. Semantics stay native (the
/// InkWell's own tap action; no wrapper detectors — 0.10).
///
/// Colors resolve through the [BrandColors] token chain (L1); card shape
/// follows the b10 [AppShapeTokens.cardRadius] token (fallback 16).
class SettingTile extends StatelessWidget {
  /// The leading icon.
  final IconData icon;

  /// The tile title (caller-supplied, L3).
  final String title;

  /// Optional one-line subtitle under the title.
  final String? subtitle;

  /// Optional caller trailing slot (switch, value, badge …). When `null` and
  /// [onTap] is set, a chevron communicates affordance.
  final Widget? trailing;

  /// Optional tap callback; `null` renders a disabled, inert tile.
  final VoidCallback? onTap;

  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shapeTokens =
        theme.extension<AppShapeTokens>() ?? const AppShapeTokens();
    final brand = BrandColors.of(context);
    final spacing = AppSpacing.of(context);

    final Widget effectiveTrailing =
        trailing ??
        (onTap != null
            ? Icon(Icons.chevron_right, color: brand.textSecondary)
            : const SizedBox.shrink());

    final Widget content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: brand.primary),
          SizedBox(width: spacing.lg),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: brand.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: brand.textSecondary),
                  ),
              ],
            ),
          ),
          effectiveTrailing,
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
