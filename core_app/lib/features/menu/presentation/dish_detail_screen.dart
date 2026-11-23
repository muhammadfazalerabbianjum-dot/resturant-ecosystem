import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/app/a11y/text_scale_clamp.dart';
import 'package:labs/app/config/currency_format.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import '../../cart/presentation/cart_provider.dart';
import '../domain/dietary_codes.dart';
import '../domain/menu_item_model.dart';
import 'widgets/dietary_badges.dart';
import '../domain/menu_modifier_model.dart';
import 'menu_provider.dart';

class DishDetailScreen extends ConsumerStatefulWidget {
  final String menuItemId;
  const DishDetailScreen({super.key, required this.menuItemId});

  @override
  ConsumerState<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends ConsumerState<DishDetailScreen> {
  /// Tracks the currently selected optional modifier for each modifier group.
  /// Single-select behaviour: tapping another option in the same group replaces
  /// the previous selection (Law 25 — modifiers preserved in the cart item).
  final Map<String, ModifierOption> _selectedOptions = {};

  /// B2 (p16): how many portions this submission adds. The cart provider
  /// increments by exactly one per call, so the stepper's value is applied by
  /// repeating the SAME `addItem` call — providers and money math are untouched
  /// (§0.10) and the typed-limit handling below is reached identically.
  int _quantity = 1;

  /// UI-7 (p17 T-2): the dish whose GA4 `view_item` has ALREADY fired — one
  /// event per opened detail; stepper/modifier rebuilds must not re-fire.
  String? _viewItemTrackedForId;

  /// Resolves the configured currency code (falls back to `$` on absent code).
  String? _currencyCode() =>
      ref.read(restaurantConfigProvider).valueOrNull?.currency;

  /// [quantity] is the stepper's value (B2). Each unit goes through the SAME
  /// `addItem` call as a single tap, so the per-item cap, the unique-line cap,
  /// the optimistic-save restore and every typed error path behave exactly as
  /// they did before this wave.
  Future<void> _addToCart(MenuItemModel item, int quantity) async {
    final loc = AppLocalizations.of(context);
    final selected = _selectedOptions.values.toList();
    unawaited(HapticFeedback.lightImpact());
    try {
      for (var i = 0; i < quantity; i++) {
        await ref
            .read(cartProvider.notifier)
            .addItem(item, selectedOptions: selected);
        if (!mounted) return;
      }
      if (!mounted) return;
      // UI-7 (p17 T-2): GA4 `add_to_cart` fires only after the cart accepted
      // EVERY unit — each limit/error path above returns into its catch and
      // never reaches this line, so failed adds are never counted. The price
      // is the model's `priceCents` (L2 — zero money math at this site).
      unawaited(
        TelemetryService().addToCartItem(
          AddToCartEvent(
            item: AnalyticsItem(
              itemId: item.id,
              itemName: item.name,
              priceCents: item.priceCents,
              quantity: quantity,
            ),
            currency: _currencyCode() ?? kDefaultAnalyticsCurrency,
          ),
        ),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.addedToCart(item.name))));
    } on CartItemQuantityLimitException catch (e, stack) {
      if (!mounted) return;
      // B2-5: never surface a raw exception — the typed cart limit maps to
      // its own localized copy WITH the limit number (W8.9 04-P2-5).
      unawaited(
        ref
            .read(loggerProvider)
            .error(e, 'DishDetail_cart_item_limit', stack: stack),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.cartItemLimitReached(e.maxQuantityPerItem))),
      );
    } on CartUniqueItemsLimitException catch (e, stack) {
      if (!mounted) return;
      unawaited(
        ref
            .read(loggerProvider)
            .error(e, 'DishDetail_cart_line_limit', stack: stack),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.cartLineLimitReached(e.maxUniqueItems))),
      );
    } catch (e, stack) {
      if (!mounted) return;
      // B2-5: never surface a raw exception (or its internals) to the user.
      // The exception is audit-logged; the user sees a clean localization.
      unawaited(
        ref
            .read(loggerProvider)
            .error(e, 'DishDetail_addToCart_failed', stack: stack),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.addToCartFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(menuItemByIdProvider(widget.menuItemId));
    final loc = AppLocalizations.of(context);

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.dishDetails)),
        body: Center(child: Text(loc.itemNotFound)),
      );
    }

    // UI-7 (p17 T-2): GA4 `view_item` — fired ONCE per opened dish, deferred
    // to post-frame so the screen paints first. GA4 auto-attaches
    // `engagement_time_msec` to this event, which is the per-dish dwell-time
    // source (spec T-2 — documented inline). Fire-and-forget through the
    // single consent gate in TelemetryService (L1).
    if (_viewItemTrackedForId != item.id) {
      _viewItemTrackedForId = item.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          TelemetryService().viewItem(
            ViewItemEvent(
              item: AnalyticsItem(
                itemId: item.id,
                itemName: item.name,
                priceCents: item.priceCents,
              ),
              currency: _currencyCode() ?? kDefaultAnalyticsCurrency,
            ),
          ),
        );
      });
    }

    final isSoldOut =
        !item.isAvailable ||
        (item.quantityRemaining != null && item.quantityRemaining! <= 0);
    final totalModifierCents = _selectedOptions.values.fold<int>(
      0,
      (sum, o) => sum + o.upchargeCents,
    );
    final totalCents = item.priceCents + totalModifierCents;

    // B2 bounds (p16): never offer more portions than can actually be added —
    // the smaller of the remaining stock (null = untracked) and the cart's
    // per-item cap. Floored at 1 so the control stays coherent when the dish is
    // sold out (the add is disabled separately by `isSoldOut`).
    final stockCap = item.quantityRemaining ?? kMaxQuantityPerItem;
    final maxAddable = stockCap < 1
        ? 1
        : (stockCap > kMaxQuantityPerItem ? kMaxQuantityPerItem : stockCap);
    // Defensive: the stepper enforces its own bounds, but a live stock update
    // could shrink `maxAddable` beneath an already-chosen value.
    final quantity = _quantity > maxAddable ? maxAddable : _quantity;

    return ClampedTextScale(
      child: Scaffold(
        appBar: AppBar(title: Text(item.name)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (item.imageUrl != null)
              // STATE-3 (04-P2-3): the detail hero is the DESTINATION half of
              // the list-row Hero(tag: item.id) flights (menu_screen.dart:196,
              // home_screen.dart:393) — the flight now morphs into this capped
              // decode instead of popping a second, uncapped full-res decode.
              Hero(
                tag: item.id,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    // STATE-3 (04-P1-IMG): CDN thumbnail — the detail hero
                    // never downloads the full-resolution original.
                    imageUrl: cloudinaryThumb(item.imageUrl!, width: 400),
                    height: 220,
                    fit: BoxFit.cover,
                    // STATE-3 (04-P2-3): cap the decode — this was the only
                    // image site with no memCacheWidth (full-res decode).
                    memCacheWidth: 400,
                    // UX-2 (05-P2-A11Y-COLORLIT): theme-aware placeholder —
                    // raw Colors.black12 renders as a dark void in dark mode.
                    // UI-13 (p21 H2, F3-09): the tinted box + raw spinner
                    // becomes the library skeleton at the hero's own 220 px
                    // height (same decode-cap site, untouched above).
                    placeholder: (context, url) => SkeletonLoader.block(
                      width: double.infinity,
                      height: 220,
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 220,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.restaurant, size: 64),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                // B1 (p16): the detail price adopts the library `PriceTag` in
                // its prominent 22sp variant. B1b (L13): the total is forwarded
                // VERBATIM in cents — `PriceTag` is display-only and formats
                // through the same `moneyCents` rule set as
                // `formatCurrencyCents` (a one-line delegate to it), so the
                // rendered string stays byte-identical for the supported code
                // set and the modifier-inclusive total is never recomputed.
                PriceTag(
                  cents: totalCents,
                  currencyCode: _currencyCode(),
                  large: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isSoldOut)
              // B3 (p16) + Q3 (semantic state palette): the sold-out notice
              // adopts the library `InfoBanner` with an EXPLICIT tone mapping
              // — a sold-out dish is a blocking `InfoTone.soldOut` notice (its
              // OWN availability state, never dressed as a system error;
              // p16 chose `error` only because no soldOut tone existed yet).
              // It stays non-dismissible, the copy stays caller-supplied from
              // AppLocalizations (L14), and colors resolve through BrandColors
              // (config `theme.colors.soldOut`).
              InfoBanner(
                tone: InfoTone.soldOut,
                child: Text(loc.soldOut(item.name)),
              ),
            if (item.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(item.description),
              ),
            // ── P6-1 (D-051/D-052): the dietary claims travel with the dish.
            // The note is shown here (not on the row) because it is prose; the
            // halal badge renders only for a live claim.
            if (item.allergens.isNotEmpty ||
                item.dietary.isNotEmpty ||
                item.allergenNotes.trim().isNotEmpty ||
                isHalalClaimLive(
                  certified: item.halalCertified,
                  expiresAt: item.halalCertExpiresAt,
                ))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DietaryBadges(
                  allergens: item.allergens,
                  dietary: item.dietary,
                  halalCertified: item.halalCertified,
                  halalCertExpiresAt: item.halalCertExpiresAt,
                  notes: item.allergenNotes,
                  showNotes: true,
                ),
              ),
            const SizedBox(height: 16),
            ...item.modifiers.map(
              (modifier) => _ModifierGroup(
                modifier: modifier,
                selected: _selectedOptions[modifier.id],
                onSelect: (option) {
                  setState(() {
                    if (_selectedOptions[modifier.id] == option) {
                      _selectedOptions.remove(modifier.id);
                    } else {
                      _selectedOptions[modifier.id] = option;
                    }
                  });
                },
                currencyCode: _currencyCode(),
              ),
            ),
            // L12.2: new spacing goes through the library `Gap` vocabulary
            // instead of a fresh magic number.
            Gap.v24,
            // B2 (p16): the quantity picker adopts the library
            // `QuantityStepper`. Both bounds are DISABLED controls inside the
            // component, so the value cannot leave [1, maxAddable] through the
            // UI. The tooltips reuse existing l10n keys (no new strings; ARB is
            // outside this wave's territory).
            QuantityStepper(
              value: quantity,
              minValue: 1,
              maxValue: maxAddable,
              decrementTooltip: loc.decreaseQuantity,
              incrementTooltip: loc.increaseQuantity,
              onChanged: (next) => setState(() => _quantity = next),
            ),
            Gap.v16,
            ElevatedButton.icon(
              onPressed: isSoldOut || !item.isAvailable
                  ? null
                  : () => _addToCart(item, quantity),
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(loc.addToCart),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModifierGroup extends StatelessWidget {
  final MenuModifier modifier;
  final ModifierOption? selected;
  final ValueChanged<ModifierOption> onSelect;
  final String? currencyCode;

  const _ModifierGroup({
    required this.modifier,
    required this.selected,
    required this.onSelect,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          modifier.isRequired ? '${modifier.name} *' : modifier.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: selected?.id,
          onChanged: (value) {
            if (value == null || value == selected?.id) return;
            final option = modifier.options.firstWhere((o) => o.id == value);
            onSelect(option);
          },
          child: Column(
            children: modifier.options.map((option) {
              return RadioListTile<String>(
                title: Text(
                  option.upchargeCents > 0
                      ? '${option.name}  +${formatCurrencyCents(option.upchargeCents, currencyCode: currencyCode)}'
                      : option.name,
                ),
                value: option.id,
                dense: true,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
