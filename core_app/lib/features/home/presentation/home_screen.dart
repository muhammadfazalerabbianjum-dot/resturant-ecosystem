import 'package:core_ui/core_ui.dart' hide GdprConsentDialog;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:labs/app/a11y/text_scale_clamp.dart';
import 'package:labs/app/compliance/gdpr_consent_dialog.dart';
import 'package:labs/app/config/app_config.dart'
    show AppConfig, screenVariantProvider;
import 'package:labs/app/config/currency_format.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/config/screen_variants.dart' show ScreenVariants;
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/l10n/app_localizations.dart';
import '../../../features/cart/presentation/cart_screen.dart';
import '../../../features/orders/presentation/order_history_screen.dart';
import '../../../features/profile/presentation/profile_screen.dart';
import '../../../features/cart/presentation/cart_provider.dart';
import '../../../features/menu/presentation/merged_menu_provider.dart';
import 'package:core/core.dart';
import '../domain/home_service.dart';
import 'home_feed_showcase.dart';

/// P2-1 (p31): sentinel `_selectedCategory` value for the config price-band
/// chip — it filters by `freeDeliveryThresholdCents`, and its label renders
/// the live amount (the demo-era "Under 30 min" copy was wrong: it never
/// filtered by time).
const String _kPriceBandCategory = 'under_30';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  /// W8.9 (04-P2-1): tabs are built on FIRST VISIT. `{0}` = the home feed is
  /// the launch tab and builds immediately; the other four slots render a
  /// placeholder until the user opens them, so their heavy providers/streams
  /// do not all fire during boot. Once visited, a tab stays mounted in the
  /// IndexedStack — navigation state (scroll position, form input) is kept.
  final Set<int> _visitedTabs = {0};

  @override
  void initState() {
    super.initState();
    // W9.8 (06-P1-3): the consent dialog is asked ONCE, when the user first
    // lands home — the splash routes first-launch users through onboarding
    // BEFORE home, so onboarding has completed by the time this fires.
    // showIfNeeded no-ops once ANY decision (accept OR decline) is stored,
    // so the prompt is never re-shown and the durable opt-out is respected
    // on every later launch. barrierDismissible:false keeps the ask
    // unskippable; the decision reaches TelemetryService + the boot
    // analytics guard through the one canonical key.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(GdprConsentDialog.showIfNeeded(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    // W8.9 (04-P2-1): each slot mounts its tab only after FIRST VISIT; the
    // unvisited slots render a placeholder so their heavy providers/streams
    // never fire during boot. Visited tabs stay mounted (IndexedStack) so
    // navigation state (scroll position, form input) is kept.
    final List<Widget> tabs = <Widget>[
      _visitedTabs.contains(0) ? const _HomeFeedTab() : const SizedBox.shrink(),
      _visitedTabs.contains(1) ? const _SearchTab() : const SizedBox.shrink(),
      _visitedTabs.contains(2) ? const CartScreen() : const SizedBox.shrink(),
      _visitedTabs.contains(3)
          ? const OrderHistoryScreen()
          : const SizedBox.shrink(),
      _visitedTabs.contains(4)
          ? const ProfileScreen()
          : const SizedBox.shrink(),
    ];

    return ClampedTextScale(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_selectedIndex != 0) {
            setState(() => _selectedIndex = 0);
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(loc.pressHomeToExit)));
          }
        },
        child: Scaffold(
          appBar: _selectedIndex == 0
              ? AppBar(
                  // P1 (impeccable re-rate 2026-10-03): the brand slot reads
                  // the CLIENT's config (`app.name`, what the whitelabel
                  // generator rebrands) — the l10n `appName` was a demo-era
                  // second source of truth that drifted to "Labs". A brand
                  // name is a proper noun, not a translated string.
                  title: Text(AppConfig.appName),
                  centerTitle: true,
                  leading: IconButton(
                    icon: const Icon(Icons.location_on_outlined),
                    tooltip: loc.selectBranch,
                    onPressed: () => context.pushNamed(RouteNames.locations),
                  ),
                  actions: const [],
                )
              : null,
          // WHY SafeArea(top) here: the shell only owns an AppBar on the
          // home tab (index 0) — the search tab's field rendered UNDER the
          // status bar (screenshot 19). Scaffold removes the top inset for
          // this body while the home AppBar exists, so the home tab cannot
          // double-pad; tabs with their own Scaffolds absorb exactly what
          // SafeArea consumed (net position unchanged). bottom:false keeps
          // the NavigationBar inset behaviour untouched.
          body: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                const PendingSyncBanner(),
                Expanded(
                  child: IndexedStack(index: _selectedIndex, children: tabs),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Semantics(
            label: loc.mainNavigation,
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() {
                _selectedIndex = i;
                // W8.9 (04-P2-1): build-on-first-visit — the tab's widgets
                // mount the first time it is opened and stay alive after.
                _visitedTabs.add(i);
              }),
              destinations: [
                NavigationDestination(
                  icon: Semantics(
                    label: loc.homeTab,
                    child: const Icon(Icons.home_outlined),
                  ),
                  selectedIcon: Semantics(
                    label: loc.homeTab,
                    child: const Icon(Icons.home),
                  ),
                  label: loc.homeTab,
                ),
                NavigationDestination(
                  icon: Semantics(
                    label: loc.searchTab,
                    child: const Icon(Icons.search),
                  ),
                  label: loc.searchTab,
                ),
                NavigationDestination(
                  icon: RepaintBoundary(
                    child: Semantics(
                      label: loc.cartTab,
                      child: const Icon(Icons.shopping_cart_outlined),
                    ),
                  ),
                  selectedIcon: RepaintBoundary(
                    child: Semantics(
                      label: loc.cartTab,
                      child: const Icon(Icons.shopping_cart),
                    ),
                  ),
                  label: loc.cartTab,
                ),
                NavigationDestination(
                  icon: Semantics(
                    label: loc.ordersTab,
                    child: const Icon(Icons.receipt_long_outlined),
                  ),
                  selectedIcon: Semantics(
                    label: loc.ordersTab,
                    child: const Icon(Icons.receipt_long),
                  ),
                  label: loc.ordersTab,
                ),
                NavigationDestination(
                  icon: Semantics(
                    label: loc.profileTab,
                    child: const Icon(Icons.person_outline),
                  ),
                  selectedIcon: Semantics(
                    label: loc.profileTab,
                    child: const Icon(Icons.person),
                  ),
                  label: loc.profileTab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeFeedTab extends ConsumerStatefulWidget {
  const _HomeFeedTab();
  @override
  ConsumerState<_HomeFeedTab> createState() => _HomeFeedTabState();
}

class _HomeFeedTabState extends ConsumerState<_HomeFeedTab>
    with WidgetsBindingObserver {
  final PageController _heroController = PageController();
  int _heroIndex = 0;
  Timer? _heroTimer;
  List<HomePromotion> _promotions = const [];
  bool _promotionsLoading = true;

  /// True when the promotions fetch threw — the carousel shows a visible
  /// error state instead of silently masquerading as "no promotions".
  bool _promotionsFailed = false;
  String? _selectedCategory;

  /// P2-1 (p31): distinct menu categories in first-seen order, each with
  /// its display label — the demo-era keys localize through l10n; any other
  /// owner-authored value title-cases exactly as stored (content, not UI
  /// chrome). Case-insensitive dedupe keeps one chip per taxonomy.
  List<({String label, String value})> _menuCategoryLabels(
    List<MenuItemModel> items,
    AppLocalizations loc,
  ) {
    final seen = <String>{};
    final labels = <({String label, String value})>[];
    for (final item in items) {
      final raw = item.category.trim();
      if (raw.isEmpty) continue;
      final lower = raw.toLowerCase();
      if (!seen.add(lower)) continue;
      labels.add((value: raw, label: _categoryLabelFor(raw, lower, loc)));
    }
    return labels;
  }

  String _categoryLabelFor(String raw, String lower, AppLocalizations loc) =>
      switch (lower) {
        'pizza' => loc.categoryPizza,
        'sushi' => loc.categorySushi,
        'vegan' => loc.categoryVegan,
        _ => raw[0].toUpperCase() + raw.substring(1),
      };

  @override
  void initState() {
    super.initState();
    // W8.9 (04-P2-5): observer so the carousel timer PAUSES when the app is
    // not visible and resumes on return (see didChangeAppLifecycleState).
    WidgetsBinding.instance.addObserver(this);
    _loadPromotions();
    _startHeroTimer();
  }

  /// Guarded start — `??=` can never double-schedule the periodic timer.
  void _startHeroTimer() {
    _heroTimer ??= Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      if (_heroController.hasClients && _promotions.isNotEmpty) {
        final next = (_heroIndex + 1) % _promotions.length;
        _heroController.animateToPage(
          next,
          duration: 400.ms,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopHeroTimer() {
    _heroTimer?.cancel();
    _heroTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // W8.9 (04-P2-5): the hero carousel timer is lifecycle-aware. Previously
    // the Timer.periodic kept firing while the app was backgrounded/hidden —
    // wasted battery and pointless page animations no one can see.
    switch (state) {
      case AppLifecycleState.resumed:
        _startHeroTimer();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _stopHeroTimer();
    }
  }

  Future<void> _loadPromotions() async {
    try {
      final svc = ref.read(homeServiceProvider);
      final promotions = await svc.getPromotions();
      if (mounted) {
        setState(() {
          _promotions = promotions;
          _promotionsLoading = false;
          // home_service itself is fail-safe (returns []), so a non-throwing
          // empty result is a legitimate "no promotions" state, NOT an error.
          _promotionsFailed = false;
        });
      }
    } catch (e, stack) {
      // B4-1: never swallow. Log the exact failure (PII-free) and surface it
      // in the UI so a broken promotions query is visible, not silent.
      await ref
          .read(loggerProvider)
          .error(e, 'HomeScreen._loadPromotions failed', stack: stack);
      if (mounted) {
        setState(() {
          _promotionsLoading = false;
          _promotionsFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeroTimer();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final menuAsync = ref.watch(mergedMenuProvider);
    // PERF-5: the home feed's layout variant resolves through the
    // config-driven registry. 'grid' (the catalog default, what every
    // config without a `variant` key resolves to) renders the ORIGINAL
    // structure below byte-for-byte; 'showcase' swaps the menu sliver.
    final variant = ref.watch(
      screenVariantProvider(ScreenVariants.homeScreenId),
    );
    final theme = Theme.of(context);
    // P2-1 (p31): the chips derive from the LIVE menu and LIVE config —
    // never a hardcoded demo taxonomy (every generated app inherits this
    // screen, so hardcoded categories would ship across the fleet).
    final menuItems = menuAsync.valueOrNull ?? const <MenuItemModel>[];
    final categories = _menuCategoryLabels(menuItems, loc);
    final restaurantConfig = ref.watch(restaurantConfigProvider).valueOrNull;
    final priceBandThreshold =
        restaurantConfig?.freeDeliveryThresholdCents ?? 3000;
    final priceBandLabel = loc.categoryUnderAmount(
      formatCurrencyCents(
        priceBandThreshold,
        currencyCode: restaurantConfig?.currency,
      ),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: _promotionsLoading
                // UI-13 (p21 H2, F3-09): the hero carousel's loading slot is
                // the library card placeholder at the SAME 200 px height.
                ? SkeletonLoader.card(height: 200)
                : _promotionsFailed
                ? Center(
                    child: Text(
                      loc.failedToLoadPromotions,
                      textAlign: TextAlign.center,
                    ),
                  )
                : PageView(
                    controller: _heroController,
                    onPageChanged: (i) => setState(() => _heroIndex = i),
                    children: _promotions.asMap().entries.map((entry) {
                      final promo = entry.value;
                      return Container(
                        color: _promotionColor(
                          promo.backgroundColor,
                          theme,
                          entry.key,
                        ),
                        child: Center(
                          child: Text(
                            promo.title,
                            style: TextStyle(
                              color: BrandColors.of(context).background,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
        // P2-1 (p31): the chips are the OWNER's live categories — the
        // demo-era pizza/sushi/vegan row only renders values the menu
        // actually carries (known values localize; other owner values
        // title-case as stored). The row hides while the menu is empty so
        // a fresh client never inherits another restaurant's taxonomy. The
        // price band is config-driven with an honest amount label.
        if (menuItems.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  for (final category in categories) ...[
                    Semantics(
                      label: loc.filterByCategory(category.label),
                      button: true,
                      child: FilterChip(
                        label: Text(category.label),
                        onSelected: (_) => setState(() {
                          _selectedCategory =
                              _selectedCategory == category.value
                              ? null
                              : category.value;
                        }),
                        selected: _selectedCategory == category.value,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Semantics(
                    label: loc.filterByCategory(priceBandLabel),
                    button: true,
                    child: FilterChip(
                      label: Text(priceBandLabel),
                      onSelected: (_) => setState(() {
                        _selectedCategory =
                            _selectedCategory == _kPriceBandCategory
                            ? null
                            : _kPriceBandCategory;
                      }),
                      selected: _selectedCategory == _kPriceBandCategory,
                    ),
                  ),
                ],
              ),
            ),
          ),
        menuAsync.when(
          data: (_) {
            final items = menuAsync.requireValue;
            final svc = ref.read(homeServiceProvider);
            var filtered = items;

            // Apply category filter
            if (_selectedCategory != null) {
              if (_selectedCategory == _kPriceBandCategory) {
                filtered = svc.filterByMaxPrice(filtered, priceBandThreshold);
              } else {
                filtered = svc.filterByCategory(filtered, _selectedCategory!);
              }
            }

            Widget sliverContent;
            if (filtered.isEmpty) {
              sliverContent = SliverToBoxAdapter(
                child: EmptyStateWidget(
                  icon: Icons.restaurant_menu,
                  title: loc.menuEmpty,
                  subtitle: loc.menuEmptySubtitle,
                  ctaText: loc.refresh,
                  onCtaPressed: () => ref.invalidate(mergedMenuProvider),
                ),
              );
            } else if (variant == ScreenVariants.homeShowcaseVariant) {
              // PERF-5 pilot variant: the showcase layout, resolved through
              // the config-driven registry. The grid in the branch below
              // stays byte-for-byte for the default ('grid').
              sliverContent = ShowcaseHomeFeed(items: filtered);
            } else {
              sliverContent = SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return BrandCard(
                          // C1 (p16): the feed tile is a BrandCard
                          // composition — token surface/radius with the SAME
                          // single tap path (InkWell); Hero, semantics, add
                          // contracts and the animate stagger below are
                          // preserved untouched (L14). Zero padding keeps the
                          // tile's flush layout (edge-to-edge image block,
                          // 8 px details padding).
                          onTap: () => context.pushNamed(
                            RouteNames.dishDetail,
                            pathParameters: {'id': item.id},
                            extra: item,
                          ),
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: item.imageUrl != null
                                    ? AspectRatio(
                                        aspectRatio: 1,
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                          child: Hero(
                                            tag: item.id,
                                            child: CachedNetworkImage(
                                              // STATE-3 (04-P1-IMG): CDN
                                              // thumbnail — the feed grid
                                              // downloads w_400, not the
                                              // full-res original.
                                              imageUrl: cloudinaryThumb(
                                                item.imageUrl!,
                                                width: 400,
                                              ),
                                              fit: BoxFit.cover,
                                              memCacheWidth: 400,
                                              // UI-13 (p21 H2, F3-09): the
                                              // theme-aware tinted box + raw
                                              // spinner yields to the library
                                              // skeleton, sized to the image
                                              // slot it stands in for.
                                              placeholder: (context, url) =>
                                                  SkeletonLoader.block(
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                  ),
                                              errorWidget:
                                                  (context, url, err) =>
                                                      Container(
                                                        color:
                                                            BrandColors.of(
                                                                  context,
                                                                ).textSecondary
                                                                .withValues(
                                                                  alpha: 0.2,
                                                                ),
                                                        child: const Icon(
                                                          Icons.fastfood,
                                                          size: 50,
                                                        ),
                                                      ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: BrandColors.of(
                                          context,
                                        ).textSecondary.withValues(alpha: 0.2),
                                        child: const Icon(
                                          Icons.fastfood,
                                          size: 50,
                                        ),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: theme.textTheme.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          formatCurrencyCents(
                                            item.priceCents,
                                            currencyCode: ref
                                                .read(restaurantConfigProvider)
                                                .valueOrNull
                                                ?.currency,
                                          ),
                                          style: theme.textTheme.bodyLarge,
                                        ),
                                        Semantics(
                                          label: loc.addToCartItem(item.name),
                                          button: true,
                                          // UX-2 (05-P2-A11Y-TAP): the
                                          // default IconButton footprint
                                          // is the 48dp minimum — the old
                                          // zero-constraints override made
                                          // this target ~24dp.
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.add_circle,
                                              color: theme.colorScheme.primary,
                                            ),
                                            onPressed: () {
                                              HapticFeedback.lightImpact();
                                              ref
                                                  .read(cartProvider.notifier)
                                                  .addItem(item);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    loc.addedToCart(item.name),
                                                  ),
                                                  duration: const Duration(
                                                    seconds: 1,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .fade(
                          duration: Duration(milliseconds: 200 + (index * 40)),
                        )
                        .slideY(begin: 0.2);
                  },
                ),
              );
            }
            if (menuAsync.isRefreshing) {
              return SliverToBoxAdapter(
                child: Stack(
                  children: [
                    SizedBox(child: CustomScrollView(slivers: [sliverContent])),
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      // UI-13 (p21 H2, F3-09): background refresh is announced
                      // by the library's animated loading block, not a raw
                      // spinner.
                      child: SkeletonLoader.block(
                        width: 24,
                        height: 24,
                        borderRadius: 12,
                      ),
                    ),
                  ],
                ),
              );
            }
            return sliverContent;
          },
          // UI-13 (p21 H2, F3-09): the raw spinner yields to the library
          // loading placeholder — MenuTile footprints, the rows about to
          // render below.
          loading: () => SliverToBoxAdapter(
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
          error: (err, stack) => SliverToBoxAdapter(
            child: Center(child: Text(loc.errorLoadingHome(err.toString()))),
          ),
        ),
      ],
    );
  }

  Color _promotionColor(String? colorName, ThemeData theme, int index) {
    switch (colorName?.toLowerCase()) {
      case 'primary':
        return theme.colorScheme.primary;
      case 'secondary':
        return theme.colorScheme.secondary;
      case 'tertiary':
        return theme.colorScheme.tertiary;
      default:
        // Cycle through default colors based on the promo's own index,
        // NOT the currently-displayed page (which would re-color every
        // promo as the carousel auto-advances).
        return switch (index % 3) {
          0 => theme.colorScheme.primary,
          1 => theme.colorScheme.secondary,
          _ => theme.colorScheme.tertiary,
        };
    }
  }
}

class PendingSyncBanner extends ConsumerWidget {
  const PendingSyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final pendingAsync = ref.watch(pendingSyncCountProvider);
    // QUEUE-1 (W5.1(d)): only owner/manager roles see the DLQ link, and only
    // when the DLQ actually holds entries (defense-in-depth stays with the
    // screen's RoleGate; this only avoids a dead link for customers).
    final dlqCount = ref.watch(deadLetterCountProvider).valueOrNull ?? 0;
    final role = ref.watch(currentUserProvider).valueOrNull?.role;
    final canViewDlq = role?.canViewDeadLetterQueue ?? false;

    Widget dlqLink() => (canViewDlq && dlqCount > 0)
        ? TextButton(
            onPressed: () => context.goNamed(RouteNames.deadLetterQueue),
            child: Text(
              loc.deadLetterQueueView,
              style: TextStyle(
                color: BrandColors.of(context).background,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        : const SizedBox.shrink();

    return pendingAsync.when(
      data: (_) {
        final count = pendingAsync.requireValue;
        if (pendingAsync.isRefreshing) {
          return Stack(
            children: [
              if (count > 0)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.tertiary,
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off,
                        color: BrandColors.of(context).background,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        loc.offlinePendingWrites(count.toString()),
                        style: TextStyle(
                          color: BrandColors.of(context).background,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      dlqLink(),
                      TextButton(
                        onPressed: () async {
                          await IsarService.shared().syncPendingOperations();
                          ref.invalidate(pendingSyncCountProvider);
                        },
                        child: Text(
                          loc.retry,
                          style: TextStyle(
                            color: BrandColors.of(context).background,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
              PositionedDirectional(
                top: 4,
                end: 4,
                // UI-13 (p21 H2, F3-09): the pending-sync indicator adopts the
                // library's animated loading block (16 px, same footprint).
                child: SkeletonLoader.block(
                  width: 16,
                  height: 16,
                  borderRadius: 8,
                ),
              ),
            ],
          );
        }
        if (count > 0) {
          return Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.tertiary,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  color: BrandColors.of(context).background,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  loc.offlinePendingWrites(count.toString()),
                  style: TextStyle(
                    color: BrandColors.of(context).background,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                dlqLink(),
                TextButton(
                  onPressed: () async {
                    await IsarService.shared().syncPendingOperations();
                    ref.invalidate(pendingSyncCountProvider);
                  },
                  child: Text(
                    loc.retry,
                    style: TextStyle(
                      color: BrandColors.of(context).background,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final menuAsync = ref.watch(mergedMenuProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          // UX-2 (05-P2-A11Y-FIELD): hint-only fields are invisible to screen
          // readers — expose the field with an explicit semantics label.
          child: Semantics(
            label: loc.searchMenu,
            textField: true,
            // UI-13 (p21 H2, F3-12): the raw `TextField` adopts the frozen
            // `BrandTextField` — WIRING only: label/hint/prefix still come
            // from the same l10n keys, the clear affordance survives through
            // the `suffixIcon` seam, and chrome stays whatever the client
            // input theme declares (the same b10 rule checkout adopted in A).
            child: BrandTextField(
              labelText: loc.searchMenu,
              hintText: loc.searchMenu,
              prefixIcon: Icons.search,
              // UX-2 (05-P2-UX-KEYBOARD): search surfaces the search action.
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: loc.clearSearch,
                      onPressed: () => setState(() => _query = ''),
                    )
                  : null,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
        ),
        Expanded(
          child: menuAsync.when(
            // UI-13 (p21 H2, F3-09): raw spinner -> library loading
            // placeholder (MenuTile footprints).
            loading: () => Center(
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
            error: (e, _) => Center(child: Text('${loc.error}: $e')),
            data: (items) {
              final svc = ref.read(homeServiceProvider);
              final filtered = svc.searchMenuItems(items, _query);

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: BrandColors.of(context).textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        loc.noItemsFound,
                        style: TextStyle(
                          color: BrandColors.of(context).textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final item = filtered[i];
                  // UI-13 (p21 H2, F3-11 + F3-10): the hand-rolled
                  // `Card` > `ListTile` search row collapses into the frozen
                  // MenuTile — its Material already owns the card surface and
                  // token radius, so the 8 px row gap moves to a Padding. The
                  // trailing price moves into MenuTile's own PriceTag slot:
                  // SAME `item.priceCents` and SAME currency code, forwarded
                  // VERBATIM (L13 display-only).
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MenuTile(
                      title: item.name,
                      subtitle: item.description,
                      cents: item.priceCents,
                      currencyCode: ref
                          .read(restaurantConfigProvider)
                          .valueOrNull
                          ?.currency,
                      imageUrl: item.imageUrl,
                      fallbackIcon: Icons.fastfood,
                      // STATE-3 (04-P1-IMG): CDN thumbnail (w_100) for the
                      // 56 px search row — unchanged and still asserted by the
                      // STATE-3 test, now hosted through MenuTile's image seam.
                      imageBuilder: (context, url) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: cloudinaryThumb(url, width: 100),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          memCacheWidth: 100,
                          placeholder: (context, url) =>
                              SkeletonLoader.block(width: 56, height: 56),
                          errorWidget: (context, url, err) =>
                              const Icon(Icons.fastfood, size: 40),
                        ),
                      ),
                      onTap: () => context.pushNamed(
                        RouteNames.dishDetail,
                        pathParameters: {'id': item.id},
                        extra: item,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
