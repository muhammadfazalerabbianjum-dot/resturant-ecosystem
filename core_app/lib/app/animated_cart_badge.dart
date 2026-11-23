import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:labs/l10n/app_localizations.dart';
import '../app/navigation/route_names.dart';
import '../features/cart/presentation/cart_provider.dart';

class AnimatedCartBadge extends ConsumerWidget {
  const AnimatedCartBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final count =
        cartState.valueOrNull?.items.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        ) ??
        0;
    // UX-2 (05-P1-A11Y-CART): TalkBack must announce an item-count phrase —
    // never a bare "button" and never the raw digit leaked into the tree.
    final countLabel = AppLocalizations.of(context).cartItemsCount(count);
    // COLOR-1 (08-P0-WL-3): config palette via BrandColors — the static
    // AppColors constants are banned outside core_ui (enforced by the
    // app_colors_theme_ban_test repo test).
    final brand = BrandColors.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Semantics(
          label: countLabel,
          button: true,
          child: IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: countLabel,
            onPressed: () => context.pushNamed(RouteNames.cart),
          ),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child:
                // UI-13 (p21 H2, F3-15): the hand-rolled count disc (raw
                // `Container` + `BoxDecoration(shape: circle)`) adopts the
                // platform's circle surface — SAME config `primary` fill and
                // SAME `brand.background` digit colour, so the W10.2 COLOR-1
                // palette proof keeps its exact hexes (see the receipt test).
                // `BrandBadge` was rejected on purpose: its tone palette
                // resolves to `textPrimary12`/`success`/`error`, which under
                // the W10.2 fixture are AppColors fallbacks, not config
                // colours — a palette regression this badge must not take.
                ExcludeSemantics(
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            color: brand.background,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    .animate(
                      key: ValueKey(count),
                    ) // Animates whenever count changes
                    .scale(
                      duration: 200.ms,
                      curve: Curves.easeOutBack,
                      begin: const Offset(0.5, 0.5),
                    ),
          ),
      ],
    );
  }
}
