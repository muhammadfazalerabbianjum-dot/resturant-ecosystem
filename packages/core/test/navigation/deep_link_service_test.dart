import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';

/// PERF-1 (T-6) — DeepLinkService + the DeepLinkRouteTable matcher.
/// Covers the route-table matching rules (wildcard `:param` segments,
/// segment-count discipline, staff-route fail-closed drops) and the
/// service lifecycle (cold-start initial link, stream link, navigation
/// dispatch, invalid-path report drop, dispose). Crashlytics reporting is
/// asserted through the injectable [DeepLinkErrorReporter] seam.

class _MockAppLinks extends Mock implements AppLinks {}

class _MockLogger extends Mock implements LoggerService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAppLinks appLinks;
  late _MockLogger logger;
  late StreamController<Uri> linkStream;
  final List<Object> reported = <Object>[];

  Future<void> recordReport(Object error, StackTrace stack) async {
    reported.add(error);
  }

  setUp(() {
    reported.clear();
    appLinks = _MockAppLinks();
    logger = _MockLogger();
    // A FRESH controller per test — the previous one is closed in tearDown.
    linkStream = StreamController<Uri>.broadcast();
    when(() => logger.error(any(), any())).thenAnswer((_) async {});
    when(() => logger.info(any(), any())).thenAnswer((_) async {});
    when(() => appLinks.getInitialLink()).thenAnswer((_) async => null);
    when(() => appLinks.uriLinkStream).thenAnswer((_) => linkStream.stream);
  });

  tearDown(() async {
    await linkStream.close();
  });

  DeepLinkService service({
    Future<void> Function(String path)? navigationHandler,
  }) {
    return DeepLinkService(
      appLinks: appLinks,
      logger: logger,
      navigationHandler: navigationHandler,
      errorReporter: recordReport,
    );
  }

  group('DeepLinkRouteTable.isValid — pattern matching', () {
    test('static routes match exactly', () {
      expect(DeepLinkRouteTable.isValid('/menu'), isTrue);
      expect(DeepLinkRouteTable.isValid('/cart'), isTrue);
      expect(DeepLinkRouteTable.isValid('/privacy'), isTrue);
      expect(DeepLinkRouteTable.isValid('/loyalty'), isTrue);
    });

    test('`:param` segments act as segment wildcards', () {
      expect(DeepLinkRouteTable.isValid('/dish/shawarma-1'), isTrue);
      expect(DeepLinkRouteTable.isValid('/orders/ORD-123'), isTrue);
      expect(DeepLinkRouteTable.isValid('/tracking/ORD-123'), isTrue);
    });

    test('a wrong segment COUNT is rejected (no prefix matches)', () {
      expect(DeepLinkRouteTable.isValid('/dish/shawarma-1/extra'), isFalse);
      // Only '/dish/:id' is registered — the bare '/dish' is not.
      expect(DeepLinkRouteTable.isValid('/dish'), isFalse);
      // Only '/tracking/:orderId' is registered — the bare '/tracking' is not.
      expect(DeepLinkRouteTable.isValid('/tracking'), isFalse);
      expect(DeepLinkRouteTable.isValid('/menu/extra/deep'), isFalse);
    });

    test('unregistered staff/admin routes are dropped (fail-closed)', () {
      expect(DeepLinkRouteTable.isValid('/owner'), isFalse);
      expect(DeepLinkRouteTable.isValid('/admin'), isFalse);
      expect(DeepLinkRouteTable.isValid('/admin/menu'), isFalse);
      expect(DeepLinkRouteTable.isValid('/logs'), isFalse);
    });

    test('the table keeps its config-mode contract members', () {
      // ROUTER-1/W2.2: these MUST stay registered or valid deep links die.
      expect(
        DeepLinkRouteTable.validRoutePatterns,
        containsAll(<String>['/', '/role-router', '/tracking/:orderId']),
      );
    });
  });

  group('DeepLinkService — lifecycle dispatch', () {
    test('a COLD-START initial link is validated and dispatched', () async {
      when(
        () => appLinks.getInitialLink(),
      ).thenAnswer((_) async => Uri.parse('https://carnama.app/orders/ORD-77'));
      final navigated = <String>[];
      final svc = service(
        navigationHandler: (path) async => navigated.add(path),
      );

      await svc.init();
      await pumpEventQueue();

      expect(navigated, ['/orders/ORD-77']);
      svc.dispose();
    });

    test('a BACKGROUND stream link is validated and dispatched', () async {
      final navigated = <String>[];
      final svc = service(
        navigationHandler: (path) async => navigated.add(path),
      );
      await svc.init();

      linkStream.add(Uri.parse('https://carnama.app/dish/kabsa-9'));
      await pumpEventQueue();

      expect(navigated, ['/dish/kabsa-9']);
      svc.dispose();
    });

    test('the root path is ignored without dispatch (no navigation)', () async {
      final navigated = <String>[];
      final svc = service(
        navigationHandler: (path) async => navigated.add(path),
      );
      await svc.init();

      linkStream.add(Uri.parse('https://carnama.app/'));
      await pumpEventQueue();

      expect(navigated, isEmpty);
      svc.dispose();
    });

    test('an INVALID path is dropped and reported to Crashlytics '
        '(never lands on the router error page)', () async {
      final navigated = <String>[];
      final svc = service(
        navigationHandler: (path) async => navigated.add(path),
      );
      await svc.init();

      linkStream.add(Uri.parse('https://carnama.app/admin/secret'));
      await pumpEventQueue();

      expect(navigated, isEmpty);
      expect(
        reported,
        hasLength(1),
        reason: 'the drop is reported (Crashlytics in production)',
      );
      svc.dispose();
    });

    test('a navigation-handler throw is contained and reported '
        '(the app never crashes on a bad route)', () async {
      final svc = service(
        navigationHandler: (path) async => throw StateError('route gone'),
      );
      await svc.init();

      linkStream.add(Uri.parse('https://carnama.app/menu'));
      await pumpEventQueue();

      expect(
        reported,
        hasLength(1),
        reason: 'the handler failure is reported (Crashlytics in production)',
      );
      svc.dispose();
    });

    test('a stream error is logged, not crashed', () async {
      final svc = service();
      await svc.init();

      linkStream.addError(StateError('link stream broke'));
      await pumpEventQueue();

      verify(
        () => logger.error(any(), 'DeepLinkService Stream Error'),
      ).called(1);
      svc.dispose();
    });
  });
}
