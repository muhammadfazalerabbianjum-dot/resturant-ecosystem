import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/l10n/app_localizations.dart';

class PanicSwitchBanner extends ConsumerWidget {
  const PanicSwitchBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final state = ref.watch(ordersAcceptingProvider);
    // COLOR-1: panic-mode card follows the client success/error hues.
    final brand = BrandColors.of(context);

    return state.when(
      data: (_) {
        final isAccepting = state.requireValue;
        // E1 F3-11/F3-10: BrandCard shell + a token row (no raw Card/ListTile).
        final card = BrandCard(
          color: isAccepting
              ? brand.success.withValues(alpha: 0.12)
              : brand.error.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isAccepting ? Icons.check_circle : Icons.warning,
                // UX-2: semantic token — same hue family, theme-aware.
                color: isAccepting ? brand.success : brand.error,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAccepting ? loc.acceptingOrders : loc.kitchenPanicMode,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isAccepting ? brand.success : brand.error,
                      ),
                    ),
                    Text(
                      isAccepting
                          ? loc.storeOpenCheckoutActive
                          : loc.checkoutsHaltedGlobally,
                    ),
                  ],
                ),
              ),
              Switch(
                value: isAccepting,
                activeThumbColor: brand.success,
                onChanged: (val) => ref
                    .read(panicSwitchServiceProvider)
                    .setOrdersAccepting(val),
              ),
            ],
          ),
        );
        if (state.isRefreshing) {
          return Stack(
            children: [
              card,
              const PositionedDirectional(
                top: 8,
                end: 8,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: SkeletonLoader(
                    width: 24,
                    height: 24,
                    borderRadius: 12,
                  ),
                ),
              ),
            ],
          );
        }
        return card;
      },
      loading: () => Center(
        child: SkeletonLoader.block(width: double.infinity, height: 64),
      ),
      error: (e, s) => Text(FirebaseExceptionMapper.map(e)),
    );
  }
}
