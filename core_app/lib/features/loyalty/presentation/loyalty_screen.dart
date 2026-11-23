import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'loyalty_provider.dart';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.loyalty)),
        body: Center(child: Text(loc.signInToViewLoyalty)),
      );
    }
    final loyaltyAsync = ref.watch(userLoyaltyProvider);
    return Scaffold(
      appBar: AppBar(title: Text(loc.loyalty)),
      body: loyaltyAsync.when(
        // L12: the loading preview is the tile-skeleton set (UI-10 D2).
        loading: () => Semantics(
          label: loc.loadingLoyalty,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TileSkeletons.setting(),
                Gap.v16,
                TileSkeletons.stat(),
              ],
            ),
          ),
        ),
        error: (e, _) =>
            Center(child: Text(loc.failedToLoadLoyalty(e.toString()))),
        data: (loyalty) {
          final points = loyalty.totalPoints;
          final config = ref.read(restaurantConfigProvider).valueOrNull;
          // B4-6: tier thresholds come from `settings/restaurantConfig` when
          // seeded. The model's declared defaults are the single source of
          // truth for the no-config fallback — NO derived `silver * 4` magic.
          const fallbackConfig = RestaurantConfigModel();
          final silver =
              config?.redemptionThresholdPoints ??
              fallbackConfig.redemptionThresholdPoints;
          final gold =
              config?.goldThresholdPoints ?? fallbackConfig.goldThresholdPoints;
          final tier = LoyaltyCalculator.currentTier(
            points,
            silverThreshold: silver,
            goldThreshold: gold,
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            // UI-10 D2 / L12.3: the metric surface enters through the stagger.
            child: StaggeredEntrance(
              children: [
                Center(
                  child: Semantics(
                    label: loc.currentTier(tier),
                    child: Icon(
                      tier == 'Gold'
                          ? Icons.star
                          : tier == 'Silver'
                          ? Icons.star_half
                          : Icons.star_border,
                      size: 80,
                      color: tier == 'Gold'
                          ? theme.colorScheme.primary
                          : tier == 'Silver'
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.outline,
                    ),
                  ),
                ),
                Gap.v16,
                Semantics(
                  label: loc.loyaltyTier,
                  header: true,
                  child: Center(
                    child: Text(
                      tier.toUpperCase(),
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ),
                Gap.v24,
                // UI-10 D1: the points metric is a StatTile card. The value is
                // the SAME localized string the text row rendered (L14) — the
                // PERF-1 H-3 clamp still owns the number.
                Semantics(
                  label: loc.pointsLabel(points.toString()),
                  child: StatTile(
                    icon: Icons.card_giftcard,
                    label: loc.loyalty,
                    value: loc.pointsLabel(points.toString()),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
