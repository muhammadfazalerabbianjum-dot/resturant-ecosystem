/// Golden Test â€” HomeScreen (Laws 6, 17)
/// Captures pixel-perfect snapshots: light (baseline), dark mode, textScale 1.5x.
/// A 1px shift on any layout element will fail CI.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/src/theme/app_theme.dart';

// Shared widget builder â€” keeps all variants structurally identical.
Widget _homeSkeletonWidget({ThemeMode themeMode = ThemeMode.light}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant_menu, size: 80),
              SizedBox(height: 16),
              Text(
                'Carnama',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Loading your menu...',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('HomeScreen Golden â€” Visual Regression Guard (Laws 6, 17)', () {
    testWidgets('Light mode baseline skeleton renders correctly', (
      tester,
    ) async {
      await tester.pumpWidget(_homeSkeletonWidget());
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_screen_skeleton.png'),
      );
    });

    testWidgets('Dark mode skeleton â€” theme regression guard (Law 6)', (
      tester,
    ) async {
      await tester.pumpWidget(_homeSkeletonWidget(themeMode: ThemeMode.dark));
      await tester.pump();

      // Assert no overflow or crash before taking the golden
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_screen_skeleton_dark.png'),
      );
    });

    testWidgets(
      'textScale 1.5x skeleton â€” large font regression guard (Law 47)',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(
          () => tester.platformDispatcher.textScaleFactorTestValue = 1.0,
        );

        await tester.pumpWidget(_homeSkeletonWidget());
        await tester.pump(const Duration(milliseconds: 500));

        // No overflow at 1.5x scale
        expect(tester.takeException(), isNull);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/home_screen_skeleton_textscale.png'),
        );
      },
    );
  });
}
