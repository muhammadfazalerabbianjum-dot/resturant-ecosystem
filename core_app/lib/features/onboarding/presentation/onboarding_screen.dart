import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:labs/app/config/feature_flag_gate.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/tour/domain/tour_manager.dart';
import 'package:labs/features/tour/presentation/tour_overlay.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding screen shown on first launch.
///
/// Persists a "seen" flag in SharedPreferences so returning users skip
/// onboarding and go straight to the configured navigation entry point
/// (handled by [SplashScreen]). The "Get Started" button writes the flag,
/// then routes to home (logged in) or login (logged out).
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  static const _onboardingSeenKey = 'onboarding_completed';

  Future<void> _getStarted(BuildContext context, WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    // UI-13 (p21 C3 / D-3): the documented decision point runs BEFORE the
    // flag write — it reads the current first-run truth and hands it to
    // TourManager unchanged (L30: shouldShowTour semantics never modified).
    final showTour = TourManager(
      isFirstRun: !(prefs.getBool(_onboardingSeenKey) ?? false),
    ).shouldShowTour;
    // The flow's single first-run write (unchanged; Law 9 — writing `true`
    // again later is a no-op, so the decision above can never re-arm).
    await prefs.setBool(_onboardingSeenKey, true);

    // Guard the async gap before touching BuildContext again.
    if (!context.mounted) return;
    // Capture the navigator while this route is still mounted and BEFORE the
    // go_router navigation below: the tour push must land after navigation
    // settles — a manual push scheduled in the same event would be discarded
    // by the router's next page-list update.
    final navigator = Navigator.of(context);
    final isLoggedIn = ref.read(authStateProvider).value != null;
    if (isLoggedIn) {
      context.goNamed(RouteNames.home);
    } else {
      context.goNamed(RouteNames.login);
    }

    // P37 T-2: the onboarding tour push is gated by `tourMode` — resolved at
    // tap time (imperative read; the flag doc may land while the screen sits).
    if (showTour && FlagGate.isEnabled(ref, 'tourMode')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(builder: (_) => const TourOverlay()),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    // UI-13 (p21 C2, W-5): the hand-rolled Column is replaced by the frozen
    // OnboardingShell. The pre-adoption single screen (welcome + description,
    // verbatim ARB copy and Semantics) becomes the shell's only page — the
    // shell shows Skip off the last page, so a 1-page flow keeps its
    // "NO skip control" first-run contract (L14).
    final pages = <Widget>[
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: loc.onboardingWelcome,
                child: Text(
                  loc.onboardingWelcome,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: loc.onboardingDescription,
                child: Text(
                  loc.onboardingDescription,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    return OnboardingShell(
      pages: pages,
      skipLabel: loc.skip,
      nextLabel: loc.next,
      doneLabel: loc.getStarted,
      onDone: () => _getStarted(context, ref),
      // Amendment A1 (WHITE_LABEL_p21_adoption3 §2) is superseded: UI-8 (p18)
      // Amendment A2.2 delivers the dedicated `onboardingPage` /
      // `onboardingPageDot` keys (en+ar, typed int placeholders) and deletes
      // the temporary step-label key reuse from this screen.
      pageLabelBuilder: (page, total) => loc.onboardingPage(page, total),
      pageDotLabelBuilder: (page) => loc.onboardingPageDot(page),
    );
  }
}
