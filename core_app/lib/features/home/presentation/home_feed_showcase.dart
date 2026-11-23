import 'package:cached_network_image/cached_network_image.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/config/currency_format.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/l10n/app_localizations.dart';

import '../../../features/cart/presentation/cart_provider.dart';
import '../../../features/menu/domain/menu_item_model.dart';

/// PERF-5 T-3: the ONE pilot screen variant — the home feed's `showcase`
/// layout, chosen by config through the screen-variant registry
/// (`screenVariantProvider` resolving `HomeScreen` to `showcase`).
///
/// The variant mechanism (WHITE_LABEL_p05_perf5.md) is validated vocabulary
/// → registry → per-key behavior with a byte-for-byte default: a config with
/// no `variant` key never reaches this widget (the default `grid` layout
/// renders `_HomeFeedTab`'s original structure unchanged).
///
/// Behavior contracts are IDENTICAL to the grid — only the STRUCTURE
/// differs (full-width rows instead of the 2-column grid):
///  * tap → `RouteNames.dishDetail` with the path-param id + the item extra;
///  * add → `cartProvider.addItem` with the same haptic + localized
///    snackbar feedback (integer-cents price through [formatCurrencyCents]).
class ShowcaseHomeFeed extends ConsumerWidget {
  const ShowcaseHomeFeed({super.key, required this.items});

  final List<MenuItemModel> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList.builder(
        // Index 0 is the variant's section header; 1..n are the items.
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // C2 (p16): the feed section title adopts the library
            // SectionHeader — same titleLarge/w700 title, the string stays
            // caller-supplied from AppLocalizations (L14).
            return Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 4,
                top: 4,
                bottom: 12,
              ),
              child: SectionHeader(title: loc.homeShowcaseTitle),
            );
          }
          final item = items[index - 1];
          // C1 + L12.3 (p16): the showcase row adopts BrandCard (inside
          // _showcaseCard) and gains the SAME entrance stagger the grid feed
          // preserves — 200 ms + 40 ms per-row fade, 0.2 slide-up.
          final stagger = index - 1; // slot 0 is the section header
          return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _showcaseCard(context, ref, theme, loc, item),
              )
              .animate()
              .fade(duration: Duration(milliseconds: 200 + (stagger * 40)))
              .slideY(begin: 0.2);
        },
      ),
    );
  }

  Widget _showcaseCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppLocalizations loc,
    MenuItemModel item,
  ) {
    // C1 (p16): the showcase row is a BrandCard composition — token radius
    // (client-reshapable; was a hardcoded 16) and token surface, with the
    // SAME single tap surface (InkWell) and the flush Row layout as before.
    return BrandCard(
      onTap: () => context.pushNamed(
        RouteNames.dishDetail,
        pathParameters: {'id': item.id},
        extra: item,
      ),
      padding: EdgeInsets.zero,
      // CrossAxisAlignment.start (NOT stretch): a SliverList child has an
      // UNBOUNDED height, so stretching would feed infinite constraints to
      // the row's children (a SliverGrid tile is height-bounded — the grid
      // can stretch, a list row cannot). The fixed-size image block drives
      // the row's height instead.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _showcaseImage(context, item),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _showcaseDetails(context, ref, theme, loc, item),
            ),
          ),
        ],
      ),
    );
  }

  /// The row's fixed-size visual anchor (96×96) — the height driver of the
  /// card row. Same STATE-3 CDN thumbnail discipline — w_200 for the larger
  /// block; no-URL items render the same icon fallback the grid uses
  /// (deterministic in tests).
  Widget _showcaseImage(BuildContext context, MenuItemModel item) {
    if (item.imageUrl == null) {
      return Container(
        width: 96,
        height: 96,
        color: BrandColors.of(context).textSecondary.withValues(alpha: 0.2),
        child: const Icon(Icons.fastfood, size: 40),
      );
    }
    return SizedBox(
      width: 96,
      height: 96,
      child: CachedNetworkImage(
        imageUrl: cloudinaryThumb(item.imageUrl!, width: 200),
        fit: BoxFit.cover,
        memCacheWidth: 200,
        // UI-13 (p21 H2, F3-09): tinted box + raw spinner -> the library
        // skeleton at the showcase thumbnail's own 96 px footprint.
        placeholder: (context, url) =>
            SkeletonLoader.block(width: 96, height: 96),
        errorWidget: (context, url, err) => Container(
          color: BrandColors.of(context).textSecondary.withValues(alpha: 0.2),
          child: const Icon(Icons.fastfood, size: 40),
        ),
      ),
    );
  }

  Widget _showcaseDetails(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppLocalizations loc,
    MenuItemModel item,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style: theme.textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          item.category,
          style: theme.textTheme.bodySmall?.copyWith(
            color: BrandColors.of(context).textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                formatCurrencyCents(
                  item.priceCents,
                  currencyCode: ref
                      .read(restaurantConfigProvider)
                      .valueOrNull
                      ?.currency,
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Semantics(
              label: loc.addToCartItem(item.name),
              button: true,
              child: IconButton(
                icon: Icon(Icons.add_circle, color: theme.colorScheme.primary),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(cartProvider.notifier).addItem(item);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.addedToCart(item.name)),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
