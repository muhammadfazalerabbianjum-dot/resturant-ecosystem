import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/profile/presentation/profile_screen.dart';
import 'package:core/core.dart';
import 'package:core_ui/src/theme/app_theme.dart';
import 'package:labs/features/loyalty/presentation/loyalty_provider.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';
import 'package:labs/l10n/app_localizations.dart';
import '../mock_firebase.dart';

void main() {
  setUpAll(() {
    setupFirebaseAuthMocks();
  });

  group('Constitution Responsive Matrix Layout Test', () {
    testWidgets(
      'ProfileScreen renders cleanly without RenderFlex errors on both narrow and ultra-wide displays',
      (tester) async {
        // 1. Narrow display constraints (Mobile)
        await tester.binding.setSurfaceSize(const Size(400, 800));

        final widget = ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            userLoyaltyProvider.overrideWith(
              (ref) => Stream.value(const LoyaltyModel()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.lightTheme,
            home: const ProfileScreen(),
          ),
        );

        await tester.pumpWidget(widget);
        await tester.pump(const Duration(seconds: 2));

        // Implicitly, if a RenderFlex overflow occurred, takeException would capture it.
        expect(tester.takeException(), isNull);

        // 2. Wide display constraints (Tablet/Desktop)
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        await tester.pumpWidget(widget);
        await tester.pump(const Duration(seconds: 2));

        expect(tester.takeException(), isNull);

        // Tear down
        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}
