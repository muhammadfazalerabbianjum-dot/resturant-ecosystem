// UI-10 (p20) Phase D — waitlist adoption: the live queue position renders as
// a StatTile metric (D1) and the surface adopts SectionHeader / Gap / card
// primitives (L12). Written RED before the wiring (p20 §3 phase D).
//
// L16 SANCTUARY: the position provider, the ticket/ordinal math and the join
// transaction are untouched — this file asserts PRESENTATION only. The queue
// position loading/error states stay intentionally inert (no skeleton): a
// shimmer here would leave `pumpAndSettle` non-terminating for the live-queue
// suites that retire SnackBars after every join.
import 'dart:io';

import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/waitlist/data/waitlist_repository.dart';
import 'package:labs/features/waitlist/presentation/waitlist_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hermetic host: seeded active branch (the real branch-resolution path).
Future<Widget> _harness(
  FakeFirebaseFirestore firestore, {
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  await firestore.collection('branches').doc('branch1').set({
    'name': 'Downtown',
    'isActive': true,
    'isMainBranch': true,
  });
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('user1'),
      firestoreProvider.overrideWithValue(firestore),
      loggerProvider.overrideWithValue(
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const WaitlistScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('p20 D — waitlist adoption', () {
    testWidgets('D1: the queue position renders through a StatTile metric', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(
        await _harness(
          firestore,
          overrides: [
            // The real key the screen builds: (branchId, userId) from the
            // resolved branch + signed-in uid. 1 person ahead -> "#2".
            waitlistPositionProvider((
              branchId: 'branch1',
              userId: 'user1',
            )).overrideWith((ref) => Stream.value(1)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final tile = tester.widget<StatTile>(find.byType(StatTile));
      expect(
        tile.value,
        'You are #2 in line',
        reason: 'the tile carries the localized ordinal string verbatim',
      );
      expect(find.text('You are #2 in line'), findsOneWidget);
    });

    testWidgets('D1: the surface adopts SectionHeader + entrance motion', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(
        await _harness(
          firestore,
          overrides: [
            waitlistPositionProvider((
              branchId: 'branch1',
              userId: 'user1',
            )).overrideWith((ref) => Stream.value(0)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SectionHeader), findsAtLeastNWidgets(1));
      expect(find.byType(StaggeredEntrance), findsOneWidget);
      expect(find.byType(BrandCard), findsAtLeastNWidgets(1));
      // No spinner anywhere on the surface (the position placeholder is inert).
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SkeletonLoader), findsNothing);
    });

    testWidgets(
      'the party-size stepper keeps 48dp targets and its 1..12 bounds '
      '(L12.5 / L14)',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        await tester.pumpWidget(await _harness(firestore));
        await tester.pump(const Duration(milliseconds: 300));

        final addButton = find.widgetWithIcon(
          IconButton,
          Icons.add_circle_outline,
        );
        final removeButton = find.widgetWithIcon(
          IconButton,
          Icons.remove_circle_outline,
        );
        expect(addButton, findsOneWidget);
        expect(removeButton, findsOneWidget);
        for (final button in [addButton, removeButton]) {
          final size = tester.getSize(button);
          expect(size.width, greaterThanOrEqualTo(48.0));
          expect(size.height, greaterThanOrEqualTo(48.0));
        }

        await tester.tap(addButton);
        await tester.pump();
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Join Waitlist'), findsOneWidget);
      },
    );

    testWidgets('D2: a not-queued user renders no metric tile at all', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(
        await _harness(
          firestore,
          overrides: [
            // -1 == not on the list (the documented "render nothing" sentinel).
            waitlistPositionProvider((
              branchId: 'branch1',
              userId: 'user1',
            )).overrideWith((ref) => Stream.value(-1)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StatTile), findsNothing);
      expect(find.text('Join Waitlist'), findsOneWidget);
    });
  });
}
