import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app_bootstrap.dart'
    show buildGracefulErrorWidget, navigatorKey;

/// ROUTER-1 T-4 — the ErrorWidget "Restart" button must re-navigate through
/// go_router (`context.go('/')` on the main app's navigator context), not the
/// deprecated Navigator name API which never registered `'/'` on a go_router
/// stack (00-P0-3).
///
/// The EXACT production builder (`buildGracefulErrorWidget`) is installed, and
/// its Crashlytics guard is what makes it installable here (no Firebase app
/// in the test environment — an unguarded `recordFlutterError` would throw
/// inside the error UI itself).
void main() {
  testWidgets('ErrorWidget Restart re-navigates to home via go_router', (
    tester,
  ) async {
    // Install the EXACT production builder. flutter_test verifies at the end
    // of the test body that the builder is unset, so restore it inline
    // (addTearDown runs too late for that verification).
    final ErrorWidgetBuilder originalBuilder = ErrorWidget.builder;
    ErrorWidget.builder = buildGracefulErrorWidget;

    final router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/broken',
      routes: [
        GoRoute(
          path: '/broken',
          name: 'broken',
          builder: (_, __) => const _CrashingWidget(),
        ),
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, __) => const Text('HomeRestored'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    // The crashing widget forced the production ErrorWidget to render.
    expect(find.text('Restart'), findsOneWidget);
    expect(tester.takeException(), isNotNull);

    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(find.text('HomeRestored'), findsOneWidget);
    expect(find.text('Restart'), findsNothing);

    // Restore the framework default BEFORE the end-of-test verification.
    ErrorWidget.builder = originalBuilder;
  });
}

class _CrashingWidget extends StatelessWidget {
  const _CrashingWidget();

  @override
  Widget build(BuildContext context) {
    throw StateError('ROUTER-1 T-4: intentional build failure');
  }
}
