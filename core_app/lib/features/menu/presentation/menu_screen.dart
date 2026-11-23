import 'dart:async';

import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/dietary_codes.dart';
import '../domain/dietary_filter.dart';
import '../domain/menu_item_model.dart';
import 'merged_menu_provider.dart';
import 'widgets/dietary_badges.dart';
import '../../../app/a11y/text_scale_clamp.dart';
import '../../../app/config/app_config.dart';
import '../../../app/navigation/route_names.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../cart/presentation/cart_provider.dart';
import '../../../app/animated_cart_badge.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/app/config/currency_format.dart';
import 'package:labs/app/config/restaurant_config_service.dart';

class MenuScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  const MenuScreen({super.key, this.initialCategory});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  late String _activeCategory;
  String _query = '';

  /// P6-1: the diner's own dietary selection. Not persisted — a filter that
  /// outlives the visit would silently hide items on the next launch.
  final Set<String> _dietaryFilter = <String>{};
  final Set<String> _excludedAllergens = <String>{};

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.initialCategory ?? 'All';
  }

  List<MenuItemModel> _filter(List<MenuItemModel> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where(
          (i) =>
              i.name.toLowerCase().contains(q) ||
              (i.description.isNotEmpty &&
                  i.description.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final menuAsync = ref.watch(mergedMenuProvider);

    return ClampedTextScale(
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.digitalMenu),
          actions: const [AnimatedCartBadge(), SizedBox(width: 16)],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Semantics(
                label: loc.searchMenu,
                textField: true,
                // UI-13 (p21 H2, F3-12): the raw `TextField` adopts the frozen
                // `BrandTextField` — WIRING only: the same `searchMenu` hint,
                // the same prefix icon, the same keyboard action and change
                // callback. Chrome (fill/border/radius) now comes from the
                // client input theme instead of an inline `InputDecoration`
                // (the same b10 rule checkout adopted in phase A).
                child: BrandTextField(
                  hintText: loc.searchMenu,
                  prefixIcon: Icons.search,
                  // UX-2 (05-P2-UX-KEYBOARD): search surfaces the search action.
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  onChanged: (val) => setState(() => _query = val),
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  Semantics(
                    label: loc.filterByCategory(loc.all),
                    button: true,
                    child: ActionChip(
                      label: Text(loc.all),
                      backgroundColor: _activeCategory == 'All'
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      onPressed: () => setState(() => _activeCategory = 'All'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: loc.filterByCategory(loc.popular),
                    button: true,
                    child: ActionChip(
                      label: Text(loc.popular),
                      backgroundColor: _activeCategory == 'Popular'
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      onPressed: () =>
                          setState(() => _activeCategory = 'Popular'),
                    ),
                  ),
                  // P6-1 (D-054): the tag-based "Vegan" category chip is GONE.
                  // It sat beside a identically labelled dietary claim chip,
                  // and two controls with one label doing different things is a
                  // trap. The `dietary` claim below is the authoritative one;
                  // the legacy tag path survives only for deep links
                  // (`initialCategory`), so old links keep working.
                  if (widget.initialCategory != null &&
                      ![
                        'All',
                        'Popular',
                        'Vegan',
                      ].contains(widget.initialCategory)) ...[
                    const SizedBox(width: 8),
                    Semantics(
                      label: loc.filterByCategory(widget.initialCategory!),
                      button: true,
                      child: ActionChip(
                        label: Text(widget.initialCategory!),
                        backgroundColor:
                            _activeCategory == widget.initialCategory
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        onPressed: () => setState(
                          () => _activeCategory = widget.initialCategory!,
                        ),
                      ),
                    ),
                  ],
                  // ── P6-1 (D-052): the three dietary filter chips are the
                  // whole chip-row budget for this axis; the 13 allergen
                  // exclusions live behind the sheet so the row stays
                  // scrollable by thumb rather than by squint.
                  for (final code in kDietaryFilterCodes) ...[
                    const SizedBox(width: 8),
                    Semantics(
                      label:
                          '${loc.dietaryLabel}: ${dietaryLabelOf(loc, code)}',
                      button: true,
                      selected: _dietaryFilter.contains(code),
                      child: FilterChip(
                        label: Text(dietaryLabelOf(loc, code)),
                        selected: _dietaryFilter.contains(code),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _dietaryFilter.add(code);
                          } else {
                            _dietaryFilter.remove(code);
                          }
                        }),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Semantics(
                    label: loc.allergensLabel,
                    button: true,
                    child: ActionChip(
                      avatar: const Icon(
                        Icons.warning_amber_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _excludedAllergens.isEmpty
                            ? loc.allergensLabel
                            : '${loc.allergensLabel} '
                                  '(${_excludedAllergens.length})',
                      ),
                      backgroundColor: _excludedAllergens.isEmpty
                          ? null
                          : Theme.of(context).colorScheme.errorContainer,
                      onPressed: _openAllergenSheet,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: menuAsync.when(
                data: (_) {
                  final allItems = menuAsync.requireValue;
                  final categoryItems = _activeCategory == 'All'
                      ? allItems
                      : allItems
                            .where(
                              (i) => i.tags.contains(
                                _activeCategory.toLowerCase(),
                              ),
                            )
                            .toList();
                  final items = filterByDietary(
                    _filter(categoryItems),
                    dietary: _dietaryFilter,
                    excludeAllergens: _excludedAllergens,
                  );

                  if (items.isEmpty) {
                    // A4 (L12): the empty-category state adopts the library
                    // EmptyStateWidget. Both strings stay caller-supplied via
                    // AppLocalizations (L14 — l10n untouched, existing keys).
                    return EmptyStateWidget(
                      icon: Icons.search_off,
                      title: loc.noItemsMatchCategory,
                      subtitle: loc.searchMenu,
                    );
                  }

                  // W9.3 + p37 T-3: config-driven currency (no literal `$`),
                  // resolved through the ONE precedence rule (doc → config
                  // seed → USD) and forwarded verbatim to every row's PriceTag
                  // — prices are never recomputed (L13 / money law).
                  final currency = resolveCurrencyCode(
                    fromDoc: ref
                        .watch(restaurantConfigProvider)
                        .valueOrNull
                        ?.currency,
                    fromConfig: AppConfig.currencyCode,
                  );

                  // A3 (L12.3): the body enters through the library's
                  // StaggeredEntrance — index i is delayed i * 60 ms inside the
                  // M3 standard/300 ms window. This replaces the hand-rolled
                  // flutter_animate fade chain (L15 allows the swap where it is
                  // visibly equivalent or better: fade + slide + stagger).
                  final listView = SingleChildScrollView(
                    child: StaggeredEntrance(
                      children: [
                        for (final item in items)
                          _menuRow(item: item, loc: loc, currency: currency),
                      ],
                    ),
                  );

                  if (menuAsync.isRefreshing) {
                    return Stack(
                      children: [
                        listView,
                        PositionedDirectional(
                          top: 8,
                          end: 8,
                          // UI-13 (p21 H2, F3-09): background refresh is
                          // announced by the library's animated loading block,
                          // not a raw spinner.
                          child: SkeletonLoader.block(
                            width: 24,
                            height: 24,
                            borderRadius: 12,
                          ),
                        ),
                      ],
                    );
                  }
                  return listView;
                },
                loading: () => ListView.separated(
                  itemCount: 6,
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, __) => SkeletonLoader.listTile(),
                ),
                error: (error, stack) =>
                    Center(child: Text(loc.errorLoadingMenu(error.toString()))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The allergen exclusion sheet: 13 declaration codes, each reading
  /// "Contains X" so the checkbox states what it hides. Selections apply
  /// IMMEDIATELY (the sheet is a lens on the list behind it), so there is no
  /// commit button to miss.
  Future<void> _openAllergenSheet() async {
    final selected = Set<String>.of(_excludedAllergens);
    void apply() => setState(() {
      _excludedAllergens
        ..clear()
        ..addAll(selected);
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final loc = AppLocalizations.of(sheetContext);
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 16,
                      end: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            loc.hideItemsContaining,
                            style: Theme.of(sheetContext).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: selected.isEmpty
                              ? null
                              : () => setSheetState(() {
                                  selected.clear();
                                  apply();
                                }),
                          child: Text(loc.clearFilters),
                        ),
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            sheetContext,
                          ).closeButtonTooltip,
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final code in kAllergenCodes)
                          CheckboxListTile(
                            dense: true,
                            value: selected.contains(code),
                            title: Text(
                              loc.containsAllergen(allergenLabelOf(loc, code)),
                            ),
                            onChanged: (on) => setSheetState(() {
                              if (on ?? false) {
                                selected.add(code);
                              } else {
                                selected.remove(code);
                              }
                              apply();
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// One adopted menu row (p16 phase A).
  ///
  /// `MenuTile` owns the layout and renders the price through the library
  /// `PriceTag`, while the caller keeps every L14 behavior: the Hero +
  /// STATE-3 Cloudinary thumbnail (through the additive `imageBuilder` seam),
  /// the composed `Semantics` label, the sold-out gating, and the haptic +
  /// snackbar add-to-cart flow (through the `trailing` seam).
  Widget _menuRow({
    required MenuItemModel item,
    required AppLocalizations loc,
    required String? currency,
  }) {
    final isSoldOut =
        !item.isAvailable ||
        (item.quantityRemaining != null && item.quantityRemaining! <= 0);
    final addLabel = isSoldOut
        ? loc.soldOut(item.name)
        : loc.addToCartItem(item.name);

    // P6-1: the badges sit under the row, indented past the thumbnail so they
    // read as annotations on the dish rather than as a second list.
    final hasBadges =
        item.allergens.isNotEmpty ||
        item.dietary.isNotEmpty ||
        isHalalClaimLive(
          certified: item.halalCertified,
          expiresAt: item.halalCertExpiresAt,
        );

    return Semantics(
      label:
          '${item.name}, ${formatCurrencyCents(item.priceCents, currencyCode: currency)}. ${loc.tapToAddToCart}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MenuTile(
            title: item.name,
            // A2 (L13): the price is forwarded VERBATIM in cents — PriceTag is
            // display-only and formats through the same `moneyCents` rule set as
            // `formatCurrencyCents` (which is a one-line delegate to it), so the
            // rendered string stays byte-identical for the supported code set.
            cents: item.priceCents,
            currencyCode: currency,
            imageUrl: item.imageUrl,
            fallbackIcon: Icons.fastfood,
            // A1 (L14): Hero tag on the dish image + STATE-3 (04-P1-IMG) CDN
            // thumbnail (w_100) for the 50 px row, with the skeleton placeholder
            // and the fail-safe error icon preserved.
            imageBuilder: (context, url) => Hero(
              tag: item.id,
              child: CachedNetworkImage(
                imageUrl: cloudinaryThumb(url, width: 100),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                memCacheWidth: 100,
                memCacheHeight: 100,
                placeholder: (context, url) =>
                    SkeletonLoader.block(width: 50, height: 50),
                errorWidget: (context, url, err) => const Icon(Icons.fastfood),
              ),
            ),
            // W2.4 / 00-P1-1: dish detail stays reachable from the menu row.
            onTap: () => context.pushNamed(
              RouteNames.dishDetail,
              pathParameters: {'id': item.id},
            ),
            trailing: Semantics(
              label: addLabel,
              button: true,
              child: IconButton(
                // L12.5: the row affordance keeps a >= 48 x 48 dp touch target.
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: addLabel,
                icon: isSoldOut
                    ? Icon(
                        Icons.remove_shopping_cart,
                        // Q3: the unavailable affordance wears the DEDICATED
                        // sold-out token (config `theme.colors.soldOut`), not the
                        // generic muted-copy slot — a client can now re-tone
                        // sold-out without touching text semantics.
                        color: BrandColors.of(context).soldOut,
                      )
                    : const Icon(Icons.add_shopping_cart),
                onPressed: isSoldOut
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        ref.read(cartProvider.notifier).addItem(item);
                        // UI-7 (p17 T-2): GA4 `add_to_cart` from the list
                        // quick-add (quantity 1). Fire-and-forget through the
                        // single consent gate (L1); the snackbar below is the
                        // user-visible half and is never blocked by it.
                        unawaited(
                          TelemetryService().addToCartItem(
                            AddToCartEvent(
                              item: AnalyticsItem(
                                itemId: item.id,
                                itemName: item.name,
                                priceCents: item.priceCents,
                              ),
                              currency:
                                  ref
                                      .read(restaurantConfigProvider)
                                      .valueOrNull
                                      ?.currency ??
                                  kDefaultAnalyticsCurrency,
                            ),
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(loc.addedToCart(item.name)),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
              ),
            ),
          ),
          if (hasBadges)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 66,
                end: 12,
                bottom: 10,
              ),
              child: DietaryBadges(
                allergens: item.allergens,
                dietary: item.dietary,
                halalCertified: item.halalCertified,
                halalCertExpiresAt: item.halalCertExpiresAt,
              ),
            ),
        ],
      ),
    );
  }
}
