import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/presentation/owner/tabs/confirm_destructive_dialog.dart';
import 'package:labs/l10n/app_localizations.dart';

/// p28 lane B (T-4) — the shared destructive gate (UX-2) had ZERO references
/// anywhere in `core_app/test` (13 of 13 executable lines at DA:0). These
/// tests drive both resolutions the production tabs depend on: cancel must
/// resolve false (never mutate silently), confirm must resolve true.
void main() {
  group('confirmDestructive — destructive-gate contract', () {
    Future<bool?> openAndResolve(
      WidgetTester tester, {
      required int action,
    }) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await confirmDestructive(
                    context,
                    'Delete branch?',
                    'This cannot be undone.',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete branch?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
      final gateActions = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      );
      expect(gateActions, findsNWidgets(2));

      await tester.tap(gateActions.at(action));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      return result;
    }

    testWidgets('tapping Cancel resolves false and closes the gate', (
      tester,
    ) async {
      expect(await openAndResolve(tester, action: 0), isFalse);
    });

    testWidgets('tapping Delete resolves true and closes the gate', (
      tester,
    ) async {
      expect(await openAndResolve(tester, action: 1), isTrue);
    });
  });
}
