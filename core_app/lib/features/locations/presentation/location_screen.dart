import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/a11y/text_scale_clamp.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/l10n/app_localizations.dart';
import '../data/location_repository.dart';

/// Branch picker (M-4).
///
/// UI-13 (p21) phase E: the body is now the frozen library composition —
/// `SectionHeader` + `SettingTile` + `SkeletonLoader` + `EmptyStateWidget` —
/// with no raw `ListTile` and no raw `CircularProgressIndicator`. Behaviour is
/// unchanged (W2.5 branch selection through the provider's `setBranch`, W2.6
/// map entry point, UX-2 recoverable empty state) and every string is an
/// existing ARB key (p18 owns `l10n/**`).
class LocationScreen extends ConsumerWidget {
  const LocationScreen({super.key});

  /// Skeleton row count for the loading state (mirrors `menu_screen.dart`).
  static const int _skeletonRows = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final locationsAsync = ref.watch(locationsProvider);

    return ClampedTextScale(
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.locationsTitle),
          actions: [
            // W2.6 / 00-P2-1: surface the pin-drop map from the branch picker.
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: loc.selectLocation,
              onPressed: () => context.pushNamed(RouteNames.pinDropMap),
            ),
          ],
        ),
        body: locationsAsync.when(
          // F3-09 (L32, customer side): the loading state is a skeleton list,
          // not a raw centered spinner.
          loading: () => ListView.separated(
            itemCount: _skeletonRows,
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => Gap.v8,
            itemBuilder: (_, __) => SkeletonLoader.listTile(),
          ),
          // L31: a failed read stays a handled, localized state — never a raw
          // trace — now surfaced through the library banner.
          error: (e, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: InfoBanner(
                tone: InfoTone.error,
                child: Text(loc.couldNotLoadLocations),
              ),
            ),
          ),
          // UX-2 (05-P2-UX-STATES): the empty-locations dead end gets the same
          // recoverable CTA pattern as the empty cart / order history states.
          data: (locations) => locations.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.location_on_outlined,
                  title: loc.noLocationsFound,
                  subtitle: loc.noLocationsHint,
                  ctaText: loc.browseMenu,
                  onCtaPressed: () => context.pushNamed(RouteNames.menu),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      // Existing ARB key (`selectBranchTitle`) — no new string.
                      child: SectionHeader(title: loc.selectBranchTitle),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: locations.length,
                        // Card-shaped library tiles are separated by whitespace
                        // instead of a hairline rule.
                        separatorBuilder: (_, __) => Gap.v8,
                        itemBuilder: (context, i) {
                          final location = locations[i];
                          return SettingTile(
                            icon: Icons.location_on,
                            title: location.name,
                            // L31 preservation: the row still carries the branch
                            // address AND its open hours. The frozen component's
                            // subtitle is a single ellipsized line, so the two
                            // values share it, joined the way the old three-line
                            // row joined them (separator glyph, no new copy).
                            subtitle:
                                '${location.address} · ${location.openHours}',
                            // W2.5 / 00-P1-2: the branch picker selects the
                            // operating branch through the provider's existing
                            // StateNotifier API (previously setBranch had zero
                            // callers).
                            onTap: () => ref
                                .read(currentBranchIdProvider.notifier)
                                .setBranch(location.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
