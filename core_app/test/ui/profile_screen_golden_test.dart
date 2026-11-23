/// Golden Test â€” ProfileScreen (Laws 6, 17, 47)
/// Pixel-perfect snapshots: light baseline, dark mode, textScale 1.5x.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/src/theme/app_theme.dart';
import 'package:core/core.dart';
import 'package:labs/app/config/feature_flags_service.dart';
import 'package:labs/features/loyalty/presentation/loyalty_provider.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';
import 'package:labs/features/profile/presentation/profile_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';

Widget _profileWidget({ThemeMode themeMode = ThemeMode.light}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      userLoyaltyProvider.overrideWith(
        (ref) => Stream.value(const LoyaltyModel()),
      ),
      // p37 T-2: ProfileScreen gates its loyalty tile through FlagGate, which
      // watches featureFlagsProvider — feed it the shipped default (empty doc
      // => all flags true) instead of the real `settings/featureFlags` stream.
      featureFlagsProvider.overrideWith(
        (ref) => Stream.value(FeatureFlagsService(const <String, dynamic>{})),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const ProfileScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  group(
    'ProfileScreen Golden â€” Visual Regression Guard (Laws 6, 17, 47)',
    () {
      testWidgets('Light mode: all UI landmarks render correctly', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_profileWidget());
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/profile_screen.png'),
        );
      });

      testWidgets('Dark mode: theme regression guard (Law 6)', (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_profileWidget(themeMode: ThemeMode.dark));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/profile_screen_dark.png'),
        );
      });

      testWidgets('textScale 1.5x: no overflow, large-font guard (Law 47)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 3.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.platformDispatcher.textScaleFactorTestValue = 1.0;
        });

        await tester.pumpWidget(_profileWidget());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/profile_screen_textscale.png'),
        );
      });
    },
  );
}
