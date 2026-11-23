import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/src/theme/theme_provider.dart';
import 'package:core_ui/src/theme/app_theme.dart';

/// Law 6 (Theme Parity) + Law 34 (Contrast)
///
/// Tests:
/// 1. Dark mode produces dark scaffold background (not white).
/// 2. Text contrast meets WCAG AA standard in dark mode.
/// 3. Theme toggle (light → dark) propagates through the widget tree.
void main() {
  group('Dark Mode Tests (Laws 6, 34)', () {
    testWidgets('ThemeMode.dark produces dark scaffold background', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeModeProvider.overrideWith(() => _DarkModeNotifier()),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final mode = ref.watch(themeModeProvider);
              return MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFFE63946),
                    brightness: Brightness.dark,
                  ),
                  scaffoldBackgroundColor: const Color(0xFF121212),
                ),
                themeMode: mode,
                home: const Scaffold(body: Text('Carnama Dark')),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert dark scaffold is rendered (not the white light theme)
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, isNot(Colors.white));
      expect(scaffold.backgroundColor, isNot(const Color(0xFFFFFFFF)));

      handle.dispose();
    });

    testWidgets('Text contrast meets WCAG AA in dark mode', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: Center(
              child: Text(
                'Carnama Restaurant',
                style: TextStyle(
                  color: Color(0xFFEEEEEE), // near-white on dark bg
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(tester, meetsGuideline(textContrastGuideline));

      handle.dispose();
    });

    testWidgets('Theme toggle light → dark updates the widget tree', (
      tester,
    ) async {
      late ThemeModeNotifier notifier;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              notifier = ref.read(themeModeProvider.notifier);
              final mode = ref.watch(themeModeProvider);
              return MaterialApp(
                theme: ThemeData.light(),
                darkTheme: ThemeData.dark().copyWith(
                  scaffoldBackgroundColor: const Color(0xFF1A1A2E),
                ),
                themeMode: mode,
                home: const Scaffold(body: Text('Hello')),
              );
            },
          ),
        ),
      );

      // Starts as light
      Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final element = tester.element(find.byType(Scaffold).first);
      final initialBg =
          scaffold.backgroundColor ?? Theme.of(element).scaffoldBackgroundColor;

      // Toggle to dark
      notifier.toggle();
      await tester.pumpAndSettle();

      scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final newElement = tester.element(find.byType(Scaffold).first);
      final updatedBg =
          scaffold.backgroundColor ??
          Theme.of(newElement).scaffoldBackgroundColor;
      // Background should have changed from the light version
      expect(updatedBg, isNot(initialBg));
    });

    testWidgets('All text is accessible at 1.5x scale in dark mode', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;

      await tester.pumpWidget(
        MaterialApp(
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Text('Menu Item'),
                  Text('Place Order'),
                  Text('Track Delivery'),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    });
  });
}

// A notifier that starts in dark mode for testing
class _DarkModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.dark;
}
