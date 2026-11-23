import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/force_update_guard.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Performs real initialization before the app navigates:
/// 1. Ensures AppConfig is loaded (config file + dotenv).
/// 2. Resolves the auth state so the router can decide where to go.
/// 3. Waits for the auth stream to emit its first value (or timeout).
///
/// This is NOT a stub — it does real work. The 1s minimum delay is a
/// cosmetic floor so the splash is visible; the real work happens in parallel.
final splashInitProvider = FutureProvider<void>((ref) async {
  // Ensure config is loaded (idempotent — no-op if already loaded).
  await AppConfig.loadConfig();

  // Wait for the auth stream to emit its first value so the router's
  // redirect logic has a resolved auth state before we navigate.
  final authStream = ref.watch(authRepositoryProvider).authStateChanges();
  final firstAuth = authStream.first;

  // STATE-3 (04-P1-BOOT): the version check moved OUT of the first frame.
  // It runs here as a PARALLEL future — started next to the auth race,
  // never awaited by the splash path — and the SAME shared future is
  // consumed by ForceUpdateGuard's mount-time watch (non-blocking), so the
  // Remote Config round-trip happens exactly once per launch. A failure is
  // fail-open (the guard locks only on a real `required` verdict); the
  // splash's own 30 s bound + fail-open + retry UI below still bounds the
  // whole init funnel.
  unawaited(
    ref
        .read(forceUpdateStatusProvider.future)
        .then<void>(
          (_) {},
          onError: (Object e, StackTrace s) {
            ref.read(loggerProvider).error(e, 'VersionCheckFailed', stack: s);
          },
        ),
  );

  await Future.any([
    firstAuth.timeout(const Duration(seconds: 10), onTimeout: () => null),
    Future<void>.delayed(const Duration(seconds: 1)),
  ]);
});

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _onboardingSeenKey = 'onboarding_completed';

  bool _initFailed = false;
  bool _isTimeout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInit();
    });
  }

  Future<void> _startInit() async {
    setState(() {
      _initFailed = false;
      _isTimeout = false;
    });

    try {
      await ref
          .read(splashInitProvider.future)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Timeout');
            },
          );
      // First launch: show onboarding. Returning users: go straight to the
      // configured navigation entry point (multi-app readiness). The router's
      // redirect logic handles auth gating from here.
      final prefs = await SharedPreferences.getInstance();
      final onboardingSeen = prefs.getBool(_onboardingSeenKey) ?? false;
      if (!mounted) return;
      if (!onboardingSeen) {
        context.goNamed(RouteNames.onboarding);
      } else {
        context.go(AppConfig.navigationEntryPoint);
      }
    } catch (e, st) {
      if (mounted) {
        await ref.read(loggerProvider).error(e, 'Init Failed', stack: st);
        setState(() {
          _initFailed = true;
          _isTimeout = e is TimeoutException;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (_initFailed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_isTimeout ? loc.splashTimeout : loc.splashInitFailed),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _startInit, child: Text(loc.retry)),
            ],
          ),
        ),
      );
    }

    // UI-13 (p21 C1, W-5): the hand-rolled Icon/Text/spinner Column is the
    // frozen library BrandedSplash — zero-logic slot screen; the init,
    // routing and timing logic above/below is untouched (§3-C C1).
    return BrandedSplash(appName: AppConfig.appName);
  }
}
