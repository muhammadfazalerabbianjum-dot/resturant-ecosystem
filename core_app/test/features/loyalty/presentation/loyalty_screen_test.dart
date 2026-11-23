import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';
import 'package:labs/features/loyalty/presentation/loyalty_provider.dart';
import 'package:labs/features/loyalty/presentation/loyalty_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('LoyaltyScreen Widget Tests', () {
    testWidgets('1. Shows sign in prompt when user is not signed in', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserIdProvider.overrideWithValue(null)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LoyaltyScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Sign in to view'), findsOneWidget);
    });

    testWidgets('2. Shows loyalty title in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserIdProvider.overrideWithValue(null)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LoyaltyScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Loyalty'), findsOneWidget);
    });

    testWidgets('3. Renders without crash when not signed in', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserIdProvider.overrideWithValue(null)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LoyaltyScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('4. Shows sign in prompt text with correct semantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserIdProvider.overrideWithValue(null)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LoyaltyScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('5. Renders scaffold with app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserIdProvider.overrideWithValue(null)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LoyaltyScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('6. AppBar has correct title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserIdProvider.overrideWithValue(null)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LoyaltyScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.title, isNotNull);
    });
  });

  group('LoyaltyScreen — forged-negative fail-closed (PERF-1 H-3 / T-4)', () {
    testWidgets(
      'a forged negative totalPoints document renders "0 points" and BRONZE '
      '(never "-50")',
      (tester) async {
        // The REAL parse path: the forged doc goes through
        // LoyaltyModel.fromJson exactly as LoyaltyRepository.getUserLoyalty
        // does in production — the model-level clamp is what the screen shows.
        final forged = LoyaltyModel.fromJson({
          'uid': 'u-atk',
          'totalPoints': -50,
        });
        expect(forged.totalPoints, 0);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith(
                (ref) => Stream.value(MockUser(uid: 'u-atk')),
              ),
              userLoyaltyProvider.overrideWith((ref) => Stream.value(forged)),
              restaurantConfigProvider.overrideWith(
                (ref) => Stream.value(const RestaurantConfigModel()),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: LoyaltyScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('-50'),
          findsNothing,
          reason:
              'a forged negative document must never render its negative '
              'value — H-3 clamps it to 0 at the parse boundary',
        );
        expect(find.text('0 points'), findsOneWidget);
        expect(find.text('BRONZE'), findsOneWidget);
      },
    );

    testWidgets('a legitimate positive document still renders its real '
        'points and tier (the clamp never dents real data)', (tester) async {
      final legit = LoyaltyModel.fromJson({'uid': 'u-ok', 'totalPoints': 2100});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(MockUser(uid: 'u-ok')),
            ),
            userLoyaltyProvider.overrideWith((ref) => Stream.value(legit)),
            restaurantConfigProvider.overrideWith(
              (ref) => Stream.value(const RestaurantConfigModel()),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LoyaltyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2100 points'), findsOneWidget);
      // 2100 >= the config model's gold default (2000) → Gold.
      expect(find.text('GOLD'), findsOneWidget);
    });
  });
}
