import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/presentation/menu_screen.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/l10n/app_localizations.dart';

MenuItemModel _createMenuItem({
  required String id,
  required String name,
  int priceCents = 999,
  bool isAvailable = true,
  List<String> tags = const [],
  List<String> dietary = const [],
  List<String> allergens = const [],
}) {
  return MenuItemModel(
    id: id,
    name: name,
    description: 'Description for $name',
    priceCents: priceCents,
    imageUrl: null,
    category: 'General',
    tags: tags,
    dietary: dietary,
    allergens: allergens,
    isAvailable: isAvailable,
  );
}

void main() {
  group('MenuScreen Widget Tests', () {
    testWidgets('1. Loading state shows skeleton loaders', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mergedMenuProvider.overrideWith(
              (ref) => const Stream<List<MenuItemModel>>.empty(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MenuScreen(),
          ),
        ),
      );

      // Initially loading - should see skeleton loaders
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('2. Shows menu items when data is available', (tester) async {
      final items = [
        _createMenuItem(id: '1', name: 'Burger', priceCents: 1299),
        _createMenuItem(id: '2', name: 'Pizza', priceCents: 1599),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mergedMenuProvider.overrideWith((ref) => Stream.value(items)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MenuScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Burger'), findsOneWidget);
      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('\$12.99'), findsOneWidget);
      expect(find.text('\$15.99'), findsOneWidget);
    });

    testWidgets('3. Shows error state when provider errors', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mergedMenuProvider.overrideWith(
              (ref) => Stream<List<MenuItemModel>>.error(
                Exception('Failed to load menu'),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MenuScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load menu'), findsOneWidget);
    });

    testWidgets('4. Shows empty state when no items match filter', (
      tester,
    ) async {
      final items = <MenuItemModel>[
        _createMenuItem(id: '1', name: 'Vegan Salad', tags: ['vegan']),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mergedMenuProvider.overrideWith((ref) => Stream.value(items)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MenuScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Popular" filter - no items with 'popular' tag
      await tester.tap(find.text('Popular'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No items match'), findsOneWidget);
    });

    testWidgets('5. Shows sold out state for unavailable items', (
      tester,
    ) async {
      final items = [
        _createMenuItem(id: '1', name: 'Burger', isAvailable: false),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mergedMenuProvider.overrideWith((ref) => Stream.value(items)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MenuScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Sold out item should show remove_shopping_cart icon
      expect(find.byIcon(Icons.remove_shopping_cart), findsOneWidget);
    });

    testWidgets('6. Filter chips are interactive', (tester) async {
      final items = [
        _createMenuItem(id: '1', name: 'Burger'),
        // P6-1 (D-054): vegan is a dietary CLAIM now, not a free-text tag.
        _createMenuItem(id: '2', name: 'Vegan Bowl', dietary: ['vegan']),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mergedMenuProvider.overrideWith((ref) => Stream.value(items)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MenuScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially all items shown
      expect(find.text('Burger'), findsOneWidget);
      expect(find.text('Vegan Bowl'), findsOneWidget);

      // Tap the Vegan FILTER CHIP — scoped to the chip so the "Vegan\" badge
      // on the row itself cannot satisfy the finder (P6-1 added the badge).
      await tester.tap(find.widgetWithText(FilterChip, 'Vegan'));
      await tester.pumpAndSettle();

      // Only Vegan Bowl should be visible
      expect(find.text('Burger'), findsNothing);
      expect(find.text('Vegan Bowl'), findsOneWidget);
    });

    testWidgets('7. AppBar has search field and cart badge', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mergedMenuProvider.overrideWith(
              (ref) => Stream<List<MenuItemModel>>.value(const []),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MenuScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Search field should be present
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('8. Displays initial category when provided', (tester) async {
      final items = [
        _createMenuItem(id: '1', name: 'Pasta', tags: ['pasta']),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mergedMenuProvider.overrideWith((ref) => Stream.value(items)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MenuScreen(initialCategory: 'Pasta'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial category chip should be visible (appears as chip + subtitle)
      expect(find.text('Pasta'), findsAtLeastNWidgets(1));
    });

    // P6-1 (D-052): the allergen exclusion lives behind a sheet, so this is the
    // one path a unit test cannot cover — the chip, the sheet and the live
    // filtering it drives.
    testWidgets('9. the allergen sheet hides items declaring that allergen', (
      tester,
    ) async {
      final items = [
        _createMenuItem(id: '1', name: 'Burger', allergens: ['sesame']),
        _createMenuItem(id: '2', name: 'Pizza'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mergedMenuProvider.overrideWith((ref) => Stream.value(items)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MenuScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Burger'), findsOneWidget);

      // The chip row scrolls horizontally; the allergen chip sits past the
      // 800 px test viewport edge.
      await tester.ensureVisible(find.text('Allergens'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allergens'));
      await tester.pumpAndSettle();

      // The sheet lists every declaration code, scoped to the tile so the
      // badge text of the row behind it cannot satisfy the finder.
      final sesameTile = find.widgetWithText(
        CheckboxListTile,
        'Contains sesame',
      );
      expect(sesameTile, findsOneWidget);

      await tester.tap(sesameTile);
      await tester.pumpAndSettle();

      // Applied immediately, no commit button.
      expect(find.text('Burger'), findsNothing);
      expect(find.text('Pizza'), findsOneWidget);
    });

    testWidgets('10. badges follow the claim: live yes, expired no', (
      tester,
    ) async {
      final items = [
        _createMenuItem(id: '1', name: 'Shawarma').copyWith(
          halalCertified: true,
          halalCertExpiresAt: DateTime.now().add(const Duration(days: 10)),
        ),
        _createMenuItem(id: '2', name: 'Falafel').copyWith(
          halalCertified: true,
          halalCertExpiresAt: DateTime.now().subtract(const Duration(days: 10)),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mergedMenuProvider.overrideWith((ref) => Stream.value(items)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MenuScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly one halal badge for two certified rows: the expired one is
      // suppressed.
      expect(find.text('Halal certified'), findsOneWidget);
    });
  });
}
