import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/admin/presentation/owner/owner_dashboard.dart';
import 'package:core/core.dart';

import 'package:labs/features/admin/domain/cloud_function_mocks.dart';

class FakeCloudFunctionMocksService implements CloudFunctionMocksService {
  @override
  void startDaemons() {}
  @override
  void stopDaemons() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('OwnerDashboard Golden Tests (TC2)', () {
    testWidgets('OwnerDashboard renders revenue graphs and user tables', (
      WidgetTester tester,
    ) async {
      // Large physical bounding box for analytics layout
      tester.view.physicalSize = const Size(1440, 3120);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Disable animations globally for reliable golden bounds
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            // W2.9: OwnerDashboard is role-gated. Authorize the RoleGate with an
            // owner user while keeping authState null, so the widget's internal
            // "not signed in" empty state (the committed golden) still renders.
            currentUserProvider.overrideWith(
              (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
            ),
            cloudFunctionMocksProvider.overrideWith(
              (ref) => FakeCloudFunctionMocksService(),
            ),
          ],
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: OwnerDashboard(),
          ),
        ),
      );

      // Await widget layout
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(OwnerDashboard),
        matchesGoldenFile('goldens/owner_dashboard.png'),
      );
    });
  });
}
