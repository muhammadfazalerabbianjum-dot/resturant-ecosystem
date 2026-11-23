import 'package:core_ui/src/theme/app_tokens.dart';
import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:core_ui/src/ui/price_tag.dart';
import 'package:core_ui/src/ui/shapes.dart';
import 'package:flutter/material.dart';

typedef MenuTileImageBuilder =
    Widget Function(BuildContext context, String imageUrl);

/// Menu-item tile (UI-3, T-3).
///
/// Title (+ optional subtitle), an optional remote thumbnail and a
/// [PriceTag]-rendered price. MONEY LAW (L2): the tile NEVER computes on
/// cents — the [PriceTag] child formats via `moneyCents` and carries the
/// compare-at suppression rule; this widget only forwards parameters.
///
/// Fail-safe cosmetics (L5): a broken/unreachable [imageUrl] degrades to the
/// caller's [fallbackIcon] through `Image.errorBuilder` — never throws, and
/// the price/title content is never hidden by the decorative layer. Long
/// text is single-line ellipsized. Tap = exactly one native [InkWell] (0.10).
class MenuTile extends StatelessWidget {
  /// The item title (caller-supplied, L3).
  final String title;

  /// Optional one-line subtitle.
  final String? subtitle;

  /// The price in integer cents — forwarded verbatim to [PriceTag].
  final int cents;

  /// Optional compare-at cents — forwarded verbatim to [PriceTag].
  final int? compareAtCents;

  /// Currency code forwarded to `moneyCents` via [PriceTag].
  final String? currencyCode;

  /// Explicit currency symbol forwarded to `moneyCents` via [PriceTag].
  final String? currencySymbol;

  /// Optional remote image URL; load failures fall back to [fallbackIcon].
  final String? imageUrl;

  /// The caller icon shown when the image fails to load (L5 fail-safe).
  final IconData fallbackIcon;

  /// Optional image builder seam (UI-6 / p16 fallout) letting callers host
  /// custom caching / hero / skeleton layers inside MenuTile's layout slot.
  final MenuTileImageBuilder? imageBuilder;

  /// Optional trailing widget at the end of the row (e.g. an add-to-cart affordance).
  final Widget? trailing;

  /// Optional tap callback; `null` renders an inert tile.
  final VoidCallback? onTap;

  const MenuTile({
    super.key,
    required this.title,
    required this.cents,
    this.subtitle,
    this.compareAtCents,
    this.currencyCode,
    this.currencySymbol,
    this.imageUrl,
    this.fallbackIcon = Icons.restaurant,
    this.imageBuilder,
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

    final image = imageUrl;
    final Widget? thumbnail;
    if (image == null) {
      thumbnail = null;
    } else if (imageBuilder != null) {
      thumbnail = imageBuilder!(context, image);
    } else {
      thumbnail = ClipRRect(
        borderRadius: BrandShapes.borderSmall,
        child: Image.network(
          image,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 64,
            height: 64,
            color: brand.textPrimary12,
            alignment: Alignment.center,
            child: Icon(fallbackIcon, color: brand.textSecondary),
          ),
        ),
      );
    }

    final Widget content = Padding(
      padding: EdgeInsets.all(spacing.md),
      child: Row(
        children: [
          if (thumbnail != null) ...[thumbnail, SizedBox(width: spacing.md)],
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
                if (subtitle != null) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: brand.textSecondary),
                  ),
                ],
                SizedBox(height: spacing.sm),
                PriceTag(
                  cents: cents,
                  compareAtCents: compareAtCents,
                  currencyCode: currencyCode,
                  currencySymbol: currencySymbol,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
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
