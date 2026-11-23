import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/home/presentation/home_screen.dart';
import 'package:core/src/network/pending_sync_provider.dart';

void main() {
  testWidgets(
    'PendingSyncBanner displays offline sync failure banner with retry button',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingSyncCountProvider.overrideWith(
              (ref) => Stream.value(3),
            ), // Inject 3 pending writes
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: PendingSyncBanner()),
          ),
        ),
      );

      // Wait for async providers
      await tester.pumpAndSettle();

      // Verify the banner is shown
      expect(find.textContaining('Offline • 3 pending writes'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry (should not crash)
      await tester.tap(find.text('Retry'));
      await tester.pump();
    },
  );
}
