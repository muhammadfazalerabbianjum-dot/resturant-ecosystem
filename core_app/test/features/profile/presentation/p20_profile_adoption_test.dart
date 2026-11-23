import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/profile/presentation/profile_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group(
    'UI-10 Phase C: ProfileScreen SettingTile/SectionHeader/BrandDivider Adoption',
    () {
      Widget buildScreen() {
        final router = GoRouter(
          initialLocation: '/profile',
          routes: [
            GoRoute(
              path: '/profile',
              name: RouteNames.profile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        );

        return ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
      }

      testWidgets('uses SettingTile for navigation rows and privacy actions', (
        tester,
      ) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // SettingTile instances for items: Order History, Loyalty, Reservations, Export, Logs, Delete
        final settingTiles = find.byType(SettingTile);
        expect(settingTiles, findsAtLeastNWidgets(6));
      });

      testWidgets('uses SectionHeader groups for profile categorization', (
        tester,
      ) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final sectionHeaders = find.byType(SectionHeader);
        expect(sectionHeaders, findsAtLeastNWidgets(2));
      });

      testWidgets('uses BrandDivider separators between sections', (
        tester,
      ) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final dividers = find.byType(BrandDivider);
        expect(dividers, findsAtLeastNWidgets(2));
      });

      testWidgets('does not retain legacy ListTile or raw Divider', (
        tester,
      ) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.byType(ListTile), findsNothing);
        expect(find.byType(Divider), findsNothing);
      });
    },
  );
}
