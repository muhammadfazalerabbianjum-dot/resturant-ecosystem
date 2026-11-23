import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:core/src/error_logger/logger_service.dart';

/// Single source of truth for the deep-link route patterns.
///
/// MUST mirror the routes registered in CONFIG MODE — the 26 active
/// `screens[].route` paths in `core_app/assets/client_config.json` and
/// `apps/halal_boyz/assets/client_config.json` (ROUTER-1 / W2.2 prune).
/// Keeping them in sync here is what prevents valid deep links (e.g.
/// `/orders/ORD-123`, `/tracking/ORD-123`, `/terms`) from being silently
/// dropped as "invalid" — and prevents stale paths from being accepted and
/// producing a router error page.
///
/// The static-fallback-only routes (`/owner`, `/manager`, `/kitchen`,
/// `/delivery`, `/admin`, `/admin/menu`, `/logs`, `/error-logs`) are NOT
/// accepted: config mode does not register them, so an inbound link to them
/// is logged-and-dropped here (fail-closed) instead of landing on the router
/// error page. Staff and admin surfaces are reachable through the
/// `/role-router` gateway, which IS a registered config path.
///
/// Public + const so the route table is THE one truth: tests assert against it
/// directly and [DeepLinkService._isValidRoute] consults it.
class DeepLinkRouteTable {
  const DeepLinkRouteTable._();

  /// Every path pattern the app declares. `:param` segments are wildcards.
  static const Set<String> validRoutePatterns = {
    // Auth / onboarding
    '/splash',
    '/onboarding',
    '/login',
    '/signup',
    // Home / public
    '/',
    '/menu',
    '/dish/:id',
    '/cart',
    '/checkout',
    '/locations',
    '/waitlist',
    '/privacy',
    '/terms',
    '/admin-gateway',
    // Customer features
    '/orders',
    '/orders/:orderId',
    '/tracking/:orderId',
    '/reservations',
    '/loyalty',
    '/profile',
    '/delete-account',
    '/location/map',
    // Role gateway (staff/admin dashboards route through here in config mode)
    '/role-router',
    // Config-driven admin setup flows
    '/admin/setup/tier-flags',
    '/admin/setup/restaurant',
    '/admin/setup/hours',
  };

  /// Returns true when [path] matches any [validRoutePatterns] entry
  /// (segment-wise; `:param` segments are wildcards).
  static bool isValid(String path) {
    final pathSegments = path.split('/');
    for (final pattern in validRoutePatterns) {
      final patternSegments = pattern.split('/');
      if (pathSegments.length != patternSegments.length) continue;
      bool match = true;
      for (int i = 0; i < patternSegments.length; i++) {
        if (patternSegments[i].startsWith(':')) continue; // Parameter wildcard
        if (patternSegments[i] != pathSegments[i]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }
}

/// Narrow report seam (PERF-1 testability): mirrors the Crashlytics
/// `recordError(error, stack, fatal: false)` call shape so pure-Dart tests
/// can assert the drop/containment reporting without a Firebase app
/// (same injectable-seam pattern as [GdprStorageEraser] /
/// TelemetryService.forTest). Production behavior is unchanged — the default
/// is exactly the facade call that ran here before the seam existed.
typedef DeepLinkErrorReporter =
    Future<void> Function(Object error, StackTrace stack);

Future<void> _defaultErrorReport(Object error, StackTrace stack) =>
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);

class DeepLinkService {
  final AppLinks _appLinks;
  final LoggerService _logger;
  final Future<void> Function(String path)? navigationHandler;
  final DeepLinkErrorReporter _errorReporter;
  StreamSubscription<Uri>? _linkSubscription;

  DeepLinkService({
    AppLinks? appLinks,
    LoggerService? logger,
    this.navigationHandler,
    DeepLinkErrorReporter? errorReporter,
  }) : _appLinks = appLinks ?? AppLinks(),
       _logger = logger ?? LoggerService(),
       _errorReporter = errorReporter ?? _defaultErrorReport;

  Future<void> init() async {
    try {
      // 1. Handle deep link if app was launched directly from it (Cold start)
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri);
      }

      // 2. Listen to incoming links while app is in background/foreground
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          unawaited(_handleUri(uri));
        },
        onError: (Object err) {
          _logger.error(err, 'DeepLinkService Stream Error');
        },
      );
    } catch (e) {
      unawaited(_logger.error(e, 'DeepLinkService Init Error'));
    }
  }

  Future<void> _handleUri(Uri uri) async {
    // P4-08 (LAW 10): Use the project's LoggerService instead of print().
    // print() bypasses Crashlytics, PII scrubbing, and the local log file.
    await _logger.info({'uri': uri.toString()}, 'DeepLinkService Intercepted');

    final path = uri.path;

    // Validate: path must match a registered route pattern
    if (path.isEmpty || path == '/') return;
    if (!_isValidRoute(path)) {
      unawaited(
        _errorReporter(
          Exception('Invalid deep link path: $path'),
          StackTrace.current,
        ),
      );
      return; // Silently drop — better than crashing!
    }

    try {
      await navigationHandler?.call(path);
    } catch (e) {
      unawaited(_errorReporter(e, StackTrace.current));
    }
  }

  /// Validates a path against [DeepLinkRouteTable] (the real route table).
  /// Returns true if the path matches any known pattern.
  bool _isValidRoute(String path) => DeepLinkRouteTable.isValid(path);

  void dispose() {
    _linkSubscription?.cancel();
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService();
  ref.onDispose(() => service.dispose());
  return service;
});
