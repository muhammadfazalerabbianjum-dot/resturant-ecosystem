import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/admin/presentation/manager/manager_dashboard.dart';
import 'package:core/core.dart';

void main() {
  group('ManagerDashboard Golden Tests (TC2)', () {
    testWidgets('ManagerDashboard renders active operations view', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ManagerDashboard(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      await expectLater(
        find.byType(ManagerDashboard),
        matchesGoldenFile('goldens/manager_dashboard.png'),
      );
    });
  });
}
