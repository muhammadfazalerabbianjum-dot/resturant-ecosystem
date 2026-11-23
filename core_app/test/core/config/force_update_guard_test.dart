import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/force_update_guard.dart';
import 'package:labs/app/config/force_update_service.dart';

/// ForceUpdateGuard — widget tests.
///
/// STATE-3 (04-P1-BOOT) migrated the old service-injection tests to the
/// provider seam: the guard no longer takes a `service` (it is above the
/// first frame and consumes the shared `forceUpdateStatusProvider` future
/// started by `splashInitProvider`), so the verdict state is injected via
/// the provider override while the REAL guard + provider wiring run.
///
/// T-3: the first frame is the app, never a pre-check spinner (04-P1-BOOT).
/// T-4: the lock renders ONLY when the check resolves to `required`.
ForceUpdateDecision _decision(ForceUpdateStatus status) => ForceUpdateDecision(
  status: status,
  androidUpdateUrl: 'https://play.google.com/store/apps/details?id=test',
  iosUpdateUrl: 'https://apps.apple.com/app/test',
);

Widget _boot({required Override statusOverride}) {
  return ProviderScope(
    overrides: [statusOverride],
    // Production child is CoreApp (its own MaterialApp); the Directionality
    // here stands in for the MaterialApp-provided one the child needs.
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: ForceUpdateGuard(child: Text('App Content')),
    ),
  );
}

void main() {
  group('ForceUpdateGuard boot contract (STATE-3 T-3/T-4)', () {
    testWidgets(
      'T-3: first frame is the app — no pre-check spinner while the check '
      'is still loading',
      (tester) async {
        await tester.pumpWidget(
          _boot(
            statusOverride: forceUpdateStatusProvider.overrideWith(
              // Never completes = the Remote Config round-trip still in
              // flight (the cold-start state this batch removed from the
              // first frame).
              (ref) => Completer<ForceUpdateDecision>().future,
            ),
          ),
        );
        // Single pump — assert the literal FIRST frame.
        expect(find.text('App Content'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Update Required'), findsNothing);
      },
    );

    testWidgets(
      'T-3: an `ok` verdict keeps rendering the app (old "shows child when '
      'update is not required")',
      (tester) async {
        await tester.pumpWidget(
          _boot(
            statusOverride: forceUpdateStatusProvider.overrideWith(
              (ref) async => _decision(ForceUpdateStatus.ok),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('App Content'), findsOneWidget);
        expect(find.text('Update Required'), findsNothing);
      },
    );

    testWidgets(
      'T-3: a failed check fails open — the app renders, never the lock '
      '(old "shows child when check throws error")',
      (tester) async {
        // Standalone container so the test consumes the .future error the
        // same way the production splash does (parallel read with onError).
        final container = ProviderContainer(
          overrides: [
            forceUpdateStatusProvider.overrideWith(
              (ref) => Future<ForceUpdateDecision>.error(
                StateError('remote config unavailable'),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        unawaited(
          container
              .read(forceUpdateStatusProvider.future)
              .catchError((Object _) => _decision(ForceUpdateStatus.ok)),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: ForceUpdateGuard(child: Text('App Content')),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('App Content'), findsOneWidget);
        expect(find.text('Update Required'), findsNothing);
      },
    );

    testWidgets(
      'T-4: the lock renders ONLY when required — first frame stays the '
      'app, the lock replaces it once the verdict arrives',
      (tester) async {
        final completer = Completer<ForceUpdateDecision>();
        await tester.pumpWidget(
          _boot(
            statusOverride: forceUpdateStatusProvider.overrideWith(
              (ref) => completer.future,
            ),
          ),
        );
        // First frame: the app (non-blocking mount).
        expect(find.text('App Content'), findsOneWidget);

        completer.complete(_decision(ForceUpdateStatus.required));
        await tester.pumpAndSettle();
        // The REAL lock screen: title, localized body, CTA, icon — and the
        // app child is gone. Renders without crashing now that the lock's
        // MaterialApp carries its own localizations delegates.
        expect(find.text('Update Required'), findsOneWidget);
        expect(find.textContaining('A new version of'), findsOneWidget);
        expect(find.text('Update Now'), findsOneWidget);
        expect(find.byIcon(Icons.system_update_alt), findsOneWidget);
        expect(find.text('App Content'), findsNothing);
      },
    );
  });
}
