import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/a11y/text_scale_clamp.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/app/config/currency_format.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:core/core.dart';
import 'package:labs/l10n/app_localizations.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    // UX-4 (07-P1-7): cart_viewed is funnel step 1 — through the single
    // TelemetryService facade (never AnalyticsService directly).
    unawaited(TelemetryService().cartViewed());
  }

  void _proceedToCheckout(CartModel cart) {
    // UX-4: `begin_checkout` is the "checkout open" funnel boundary. The
    // facade's CF event is fired BEFORE navigation; never awaited (analytics
    // must never block the navigation or throw into it).
    // UI-7 (p17 T-2): the GA4 `begin_checkout` carries EVERY cart line
    // (items[] complete — L6: same event name, same `cart_total_cents`
    // property on the internal pipeline — the previous
    // `beginCheckout(totalCents)` call is REPLACED by this one, not doubled).
    unawaited(
      TelemetryService().beginCheckoutItems(
        BeginCheckoutEvent(
          items: [
            for (final line in cart.items)
              AnalyticsItem(
                itemId: line.item.id,
                itemName: line.item.name,
                // L2: the model's own unit price (base + option upcharges).
                priceCents: line.unitPriceCents,
                quantity: line.quantity,
              ),
          ],
          currency:
              ref.read(restaurantConfigProvider).valueOrNull?.currency ??
              kDefaultAnalyticsCurrency,
          // L2: read from the cart model, never recomputed here.
          valueCents: cart.totalCents,
        ),
      ),
    );
    context.pushNamed(RouteNames.checkout);
  }

  /// P2-3 (p31): quick-add is one EXPLICIT tap — a suggestion never enters
  /// the cart implicitly (nothing is charged or added before intent). The
  /// typed cart-limit rails mirror dish detail: raw exceptions are logged,
  /// the customer sees only localized copy.
  Future<void> _quickAdd(MenuItemModel item) async {
    final loc = AppLocalizations.of(context);
    try {
      await ref.read(cartProvider.notifier).addItem(item);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.addedToCart(item.name))));
    } on CartItemQuantityLimitException catch (e, stack) {
      if (!mounted) return;
      unawaited(
        ref
            .read(loggerProvider)
            .error(e, 'CartSuggestion_item_limit', stack: stack),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.cartItemLimitReached(e.maxQuantityPerItem))),
      );
    } on CartUniqueItemsLimitException catch (e, stack) {
      if (!mounted) return;
      unawaited(
        ref
            .read(loggerProvider)
            .error(e, 'CartSuggestion_line_limit', stack: stack),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.cartLineLimitReached(e.maxUniqueItems))),
      );
    } catch (e, stack) {
      if (!mounted) return;
      unawaited(
        ref
            .read(loggerProvider)
            .error(e, 'CartSuggestion_add_failed', stack: stack),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.addToCartFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cartAsync = ref.watch(cartProvider);
    // P2-3 (p31): cross-sell candidates come from the SAME merged menu
    // stream the home feed renders — live client data, never demo content.
    final menuItems =
        ref.watch(mergedMenuProvider).valueOrNull ?? const <MenuItemModel>[];

    final pendingSyncAsync = ref.watch(pendingSyncCountProvider);
    final pendingCount = pendingSyncAsync.valueOrNull ?? 0;

    return ClampedTextScale(
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.yourCart),
          actions: [
            if (pendingCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                // UX-2 (05-P2-L10N-PLURAL): real Intl.plural — no more
                // "1 order(s)" pseudo-plural.
                child: Tooltip(
                  message: loc.pendingSyncCount(pendingCount),
                  child: Badge(
                    label: Text('$pendingCount'),
                    child: Semantics(
                      label: loc.retrySync,
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.cloud_upload_outlined),
                        tooltip: loc.retrySync,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(loc.retryingPendingSync)),
                          );
                          ref.invalidate(pendingSyncCountProvider);
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: cartAsync.when(
          loading: () => Semantics(
            label: loc.loadingCart,
            // UI-13 (p21 H2, F3-09): the raw spinner yields to the library's
            // loading placeholder — three MenuTile footprints, the rows the
            // cart is about to render.
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TileSkeletons.menu(),
                    const SizedBox(height: 16),
                    TileSkeletons.menu(),
                    const SizedBox(height: 16),
                    TileSkeletons.menu(),
                  ],
                ),
              ),
            ),
          ),
          error: (err, stack) =>
              Center(child: Text(loc.errorLoadingCart(err.toString()))),
          data: (_) {
            final cart = cartAsync.requireValue;
            final suggestions = cartSuggestionsFor(menu: menuItems, cart: cart);
            Widget body;
            if (cart.items.isEmpty) {
              body = EmptyStateWidget(
                icon: Icons.shopping_cart_outlined,
                title: loc.yourCartIsEmpty,
                subtitle: loc.noItemsYet,
                ctaText: loc.browseMenu,
                onCtaPressed: () => context.pushNamed(RouteNames.menu),
              );
            } else {
              body = Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      // P2-3 (p31): one extra row hosts the cross-sell
                      // section that fills the dead zone below the lines.
                      itemCount:
                          cart.items.length + (suggestions.isEmpty ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (index >= cart.items.length) {
                          return _CartSuggestions(
                            items: suggestions,
                            currencyCode: ref
                                .read(restaurantConfigProvider)
                                .valueOrNull
                                ?.currency,
                            onQuickAdd: _quickAdd,
                            onOpen: (item) => context.pushNamed(
                              RouteNames.dishDetail,
                              pathParameters: {'id': item.id},
                              extra: item,
                            ),
                          );
                        }
                        final cartItem = cart.items[index];
                        final item = cartItem.item;
                        return Semantics(
                              label:
                                  '${item.name}, ${cartItem.quantity} x ${formatCurrencyCents(item.priceCents, currencyCode: ref.read(restaurantConfigProvider).valueOrNull?.currency)}',
                              child: Dismissible(
                                key: ValueKey(
                                  '${cartItem.item.id}_${cartItem.selectedOptions.map((o) => o.id).join('_')}',
                                ),
                                direction: DismissDirection.endToStart,
                                // UX-2 (05-P2-UX-CONFIRM): swiping away a cart line
                                // is destructive — confirm before dismissing.
                                confirmDismiss: (direction) => showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: Text(loc.removeCartItemTitle),
                                    content: Text(item.name),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(
                                          dialogContext,
                                        ).pop(false),
                                        child: Text(loc.cancel),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(
                                          dialogContext,
                                        ).pop(true),
                                        child: Text(loc.delete),
                                      ),
                                    ],
                                  ),
                                ),
                                // UX-2 (05-P2-RTL): the reveal background must
                                // mirror in RTL — directional alignment/edge-insets
                                // flip with text direction; the old absolute
                                // right-pinning did not.
                                background: Container(
                                  color: Theme.of(context).colorScheme.error,
                                  alignment: AlignmentDirectional.centerEnd,
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 20,
                                  ),
                                  child: Icon(
                                    Icons.delete,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onError,
                                  ),
                                ),
                                onDismissed: (direction) {
                                  ref
                                      .read(cartProvider.notifier)
                                      .removeItem(
                                        item.id,
                                        selectedOptions:
                                            cartItem.selectedOptions,
                                      );
                                },
                                child: MenuTile(
                                  // UI-13 (p21 H2, F3-10): the hand-rolled
                                  // `ListTile` row adopts the frozen MenuTile.
                                  // The line price moves from ListTile's
                                  // `subtitle:` slot into MenuTile's own
                                  // PriceTag slot — SAME `item.priceCents` and
                                  // SAME currency code, forwarded VERBATIM
                                  // (L13 display-only, unchanged from D1).
                                  title: item.name,
                                  cents: item.priceCents,
                                  currencyCode: ref
                                      .read(restaurantConfigProvider)
                                      .valueOrNull
                                      ?.currency,
                                  imageUrl: item.imageUrl,
                                  fallbackIcon: Icons.fastfood,
                                  // STATE-3 (04-P1-IMG) preserved through
                                  // MenuTile's image seam: the caller still owns
                                  // the CDN thumbnail (w_150 for the 50 px row),
                                  // the decode cap and the loading placeholder.
                                  imageBuilder: (context, url) =>
                                      CachedNetworkImage(
                                        // STATE-3 (04-P1-IMG): CDN thumbnail
                                        // (w_150) for the 50 px cart row.
                                        imageUrl: cloudinaryThumb(
                                          url,
                                          width: 150,
                                        ),
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 150,
                                        placeholder: (context, url) =>
                                            SkeletonLoader.block(
                                              width: 50,
                                              height: 50,
                                            ),
                                        errorWidget: (context, url, err) =>
                                            const Icon(Icons.fastfood),
                                      ),
                                  // D1 (p16): quantity editing adopts the library
                                  // QuantityStepper. Bounds are DISABLED controls:
                                  // min 0 keeps the unit decrement alive at qty 1
                                  // (the provider clears the line there), max is
                                  // the provider's own kMaxQuantityPerItem cap so
                                  // the limit-exception path is unreachable from
                                  // this control. Tooltips reuse the EXISTING l10n
                                  // keys (phase-B pattern); onChanged maps onto the
                                  // SAME two provider primitives — presentation
                                  // only, provider untouched: next < value →
                                  // removeItem (unit decrement), next > value →
                                  // addItem (+1 merge). The component owns the
                                  // press haptic (selectionClick), replacing the
                                  // old manual lightImpact on + (one haptic per
                                  // press preserved, flavor per the component).
                                  trailing: QuantityStepper(
                                    value: cartItem.quantity,
                                    minValue: 0,
                                    maxValue: kMaxQuantityPerItem,
                                    decrementTooltip: loc.decreaseQuantity,
                                    incrementTooltip: loc.increaseQuantity,
                                    onChanged: (next) {
                                      if (next < cartItem.quantity) {
                                        ref
                                            .read(cartProvider.notifier)
                                            .removeItem(
                                              item.id,
                                              selectedOptions:
                                                  cartItem.selectedOptions,
                                            );
                                      } else {
                                        ref
                                            .read(cartProvider.notifier)
                                            .addItem(item);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            )
                            // L12.3 (p16): the line list gains the feed
                            // grid's entrance stagger (200 ms + 40 ms/row
                            // fade, 0.2 slide-up); rows were static before
                            // (receipt D-D1). pumpAndSettle drains it, so
                            // every existing interaction lands post-settle.
                            .animate()
                            .fade(
                              duration: Duration(
                                milliseconds: 200 + (index * 40),
                              ),
                            )
                            .slideY(begin: 0.2);
                      },
                    ),
                  ),
                  // UI-13 (p21 H2, F3-15): the hand-rolled bottom tray (raw
                  // `Container` + `BoxDecoration` shadow) adopts the library's
                  // surface component — SAME 24 px padding and SAME fill; the
                  // frozen set ships no shadowed tray, so the token-radius card
                  // surface is the disclosed replacement.
                  BrandCard(
                    padding: const EdgeInsets.all(24),
                    color: Theme.of(context).cardColor,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              loc.total,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // D2 (p16): the TOTAL adopts the library PriceTag
                            // (prominent 22sp variant). L13 display-only:
                            // cart.totalCents is provider-derived and forwarded
                            // VERBATIM — never recomputed; the rendered string
                            // stays byte-identical (pinned by the D2 test).
                            PriceTag(
                              cents: cart.totalCents,
                              currencyCode: ref
                                  .read(restaurantConfigProvider)
                                  .valueOrNull
                                  ?.currency,
                              large: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          label: loc.proceedToCheckout,
                          button: true,
                          child: BrandButton(
                            text: loc.proceedToCheckout,
                            onPressed: () => _proceedToCheckout(cart),
                          ),
                        ),
                      ],
                    ),
                  ).animate().slideX(
                    begin: 1.0,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  ),
                ],
              );
            }
            if (cartAsync.isRefreshing) {
              return Stack(
                children: [
                  body,
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    // UI-13 (p21 H2, F3-09): background refresh is announced by
                    // the library's animated loading block, not a raw spinner.
                    child: SkeletonLoader.block(
                      width: 24,
                      height: 24,
                      borderRadius: 12,
                    ),
                  ),
                ],
              );
            }
            return body;
          },
        ),
      ),
    );
  }
}

/// P2-3 (p31): in-cart cross-sell candidates from the SAME merged menu
/// stream — carted, unavailable and zero-stock items drop out, menu order
/// is kept, and [limit] caps the section (four fills the dead zone without
/// burying the totals tray). Display-plus-tap only: this never mutates the
/// cart.
List<MenuItemModel> cartSuggestionsFor({
  required List<MenuItemModel> menu,
  required CartModel cart,
  int limit = 4,
}) {
  if (menu.isEmpty || cart.items.isEmpty) return const [];
  final cartedIds = <String>{for (final line in cart.items) line.item.id};
  final suggestions = <MenuItemModel>[];
  for (final item in menu) {
    if (suggestions.length >= limit) break;
    if (cartedIds.contains(item.id)) continue;
    if (!item.isAvailable) continue;
    if (item.quantityRemaining == 0) continue;
    suggestions.add(item);
  }
  return suggestions;
}

/// P2-3 (p31): the "You may also like" block appended to the cart list —
/// it fills the mid-screen dead zone with the client's own live menu.
/// Every row opens the dish detail; the trailing quick-add renders ONLY
/// for modifier-free dishes, because modifier selection belongs to the
/// detail flow and never happens implicitly.
class _CartSuggestions extends StatelessWidget {
  const _CartSuggestions({
    required this.items,
    required this.currencyCode,
    required this.onQuickAdd,
    required this.onOpen,
  });

  final List<MenuItemModel> items;
  final String? currencyCode;
  final Future<void> Function(MenuItemModel item) onQuickAdd;
  final void Function(MenuItemModel item) onOpen;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const thumbSize = 48.0;
    const thumbRadius = 8.0;
    const blockPadding = EdgeInsets.fromLTRB(16, 16, 16, 8);

    return Padding(
      padding: blockPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.cartYouMayAlsoLike,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Semantics(
              button: true,
              label:
                  '${item.name}, ${formatCurrencyCents(item.priceCents, currencyCode: currencyCode)}',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onOpen(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(thumbRadius),
                        child: SizedBox(
                          width: thumbSize,
                          height: thumbSize,
                          child: item.imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: cloudinaryThumb(
                                    item.imageUrl!,
                                    width: 96,
                                  ),
                                  fit: BoxFit.cover,
                                  memCacheWidth: 96,
                                  placeholder: (context, url) =>
                                      SkeletonLoader.block(
                                        width: thumbSize,
                                        height: thumbSize,
                                        borderRadius: thumbRadius,
                                      ),
                                  errorWidget: (context, url, err) =>
                                      ColoredBox(
                                        color: BrandColors.of(
                                          context,
                                        ).textSecondary.withValues(alpha: 0.2),
                                        child: const Icon(
                                          Icons.fastfood,
                                          size: 20,
                                        ),
                                      ),
                                )
                              : ColoredBox(
                                  color: BrandColors.of(
                                    context,
                                  ).textSecondary.withValues(alpha: 0.2),
                                  child: const Icon(Icons.fastfood, size: 20),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              formatCurrencyCents(
                                item.priceCents,
                                currencyCode: currencyCode,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.modifiers.isEmpty)
                        IconButton(
                          tooltip: loc.addToCart,
                          icon: const Icon(Icons.add_shopping_cart),
                          onPressed: () => onQuickAdd(item),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
