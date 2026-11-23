/// UI-6 (p16) Phase B — before/after golden pairs for the DISH DETAIL screen.
///
/// Two surfaces are captured: an available dish (PriceTag + QuantityStepper +
/// Add to Cart) and a sold-out dish (the InfoBanner notice). The baselines in
/// `goldens/p16_dish_detail_*.png` are re-captured deliberately once per phase
/// (before = pre-wiring look, after = adoption look); both captures are copied
/// into `tool_uilib/p16/visual_review/` for the owner's appeal verdict (L12.6).
///
/// The fixtures carry NO `imageUrl` on purpose: the Hero/CachedNetworkImage
/// branch would otherwise hit the transport-blocked network double and leave a
/// shimmering skeleton plus flutter_cache_manager's 10 s cleanup Timer, which
/// makes the capture timing-dependent rather than deterministic. The image seam
/// is already covered by the phase-A menu golden and the A1 widget test.
library;

import 'dart:io';

import 'package:core/core.dart'
    show firestoreProvider, loggerProvider, LoggerService;
import 'package:core_ui/src/theme/app_theme.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/domain/menu_modifier_model.dart';
import 'package:labs/features/menu/presentation/dish_detail_screen.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/l10n/app_localizations.dart';

const _kModifier = MenuModifier(
  id: 'mod_size',
  name: 'Size',
  options: [
    ModifierOption(id: 'opt_small', name: 'Small'),
    ModifierOption(id: 'opt_large', name: 'Large', upchargeCents: 150),
  ],
);

Widget _host(MenuItemModel item) => ProviderScope(
  overrides: [
    mergedMenuProvider.overrideWith((ref) => Stream.value([item])),
    firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    loggerProvider.overrideWithValue(
      LoggerService(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      ),
    ),
    restaurantConfigProvider.overrideWith(
      (ref) => Stream<RestaurantConfigModel>.value(
        const RestaurantConfigModel(currency: 'USD'),
      ),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DishDetailScreen(menuItemId: item.id),
  ),
);

void main() {
  testWidgets('P16 dish detail golden — available dish (adoption pair)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const MenuItemModel(
          id: 'd1',
          name: 'Truffle Burger',
          description: 'Smashed patty, truffle aioli, brioche bun',
          priceCents: 1850,
          quantityRemaining: 6,
          isAvailable: true,
          modifiers: [_kModifier],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/p16_dish_detail_screen.png'),
    );
  });

  testWidgets('P16 dish detail golden — sold-out notice (adoption pair)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const MenuItemModel(
          id: 'd2',
          name: 'Salmon Roll',
          description: 'Sold out today',
          priceCents: 3500,
          quantityRemaining: 0,
          isAvailable: true,
          modifiers: [_kModifier],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/p16_dish_detail_soldout.png'),
    );
  });
}
