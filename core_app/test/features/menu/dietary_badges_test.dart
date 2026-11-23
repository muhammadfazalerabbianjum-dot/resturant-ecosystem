// P6-1: what the diner actually sees. The trust rules live here — an expired
// certification must never render as a halal badge.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/menu/presentation/widgets/dietary_badges.dart';
import 'package:labs/l10n/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('dietary claims and declarations both render', (tester) async {
    await tester.pumpWidget(
      host(
        const DietaryBadges(
          dietary: ['vegan'],
          allergens: ['sesame', 'gluten'],
        ),
      ),
    );
    expect(find.text('Vegan'), findsOneWidget);
    expect(find.text('Contains sesame'), findsOneWidget);
    expect(find.text('Contains gluten'), findsOneWidget);
  });

  testWidgets('a live certification renders the halal badge', (tester) async {
    await tester.pumpWidget(
      host(
        DietaryBadges(
          dietary: const [],
          allergens: const [],
          halalCertified: true,
          halalCertExpiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
      ),
    );
    expect(find.text('Halal certified'), findsOneWidget);
  });

  testWidgets('an EXPIRED certification renders no halal badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DietaryBadges(
          dietary: const [],
          allergens: const [],
          halalCertified: true,
          halalCertExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ),
    );
    expect(find.text('Halal certified'), findsNothing);
  });

  testWidgets('uncertified never renders the badge', (tester) async {
    await tester.pumpWidget(
      host(
        DietaryBadges(
          dietary: const [],
          allergens: const [],
          halalCertified: false,
          halalCertExpiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
      ),
    );
    expect(find.text('Halal certified'), findsNothing);
  });

  testWidgets('the contamination note shows on the detail view only', (
    tester,
  ) async {
    const badges = DietaryBadges(
      dietary: ['vegan'],
      allergens: [],
      notes: 'Shared fryer',
    );
    await tester.pumpWidget(host(badges));
    expect(find.text('Shared fryer'), findsNothing);

    await tester.pumpWidget(
      host(
        const DietaryBadges(
          dietary: ['vegan'],
          allergens: [],
          notes: 'Shared fryer',
          showNotes: true,
        ),
      ),
    );
    expect(find.text('Shared fryer'), findsOneWidget);
  });

  testWidgets('nothing declared renders nothing at all', (tester) async {
    await tester.pumpWidget(
      host(const DietaryBadges(dietary: [], allergens: [])),
    );
    expect(find.byType(Wrap), findsNothing);
  });

  testWidgets('an unknown code still renders rather than vanishing', (
    tester,
  ) async {
    // The write boundary rejects this, but a stale document from before the
    // vocabulary existed must not silently drop a warning.
    await tester.pumpWidget(
      host(const DietaryBadges(dietary: [], allergens: ['legacy_code'])),
    );
    expect(find.text('Contains legacy_code'), findsOneWidget);
  });

  testWidgets('Arabic renders Arabic labels, not English fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('ar'),
        home: Scaffold(
          body: DietaryBadges(dietary: ['vegan'], allergens: ['sesame']),
        ),
      ),
    );
    expect(find.text('نباتي صرف'), findsOneWidget);
    expect(find.text('يحتوي على سمسم'), findsOneWidget);
  });
}
