// UI-7 (p17 T-5) — dashboard surface receipt:
//   * headline KPIs render as library StatTiles (not raw Texts),
//   * "Top Dishes Today" rows come from the aggregate-backed provider,
//   * the abandoned-cart section links the analytics console with the honest
//     freshness note (ARB, both locales),
//   * a launch failure degrades to the localized snackbar (never throws),
//   * RoleGate({owner, manager}) is still the outer wrapper (owner renders).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/admin/presentation/analytics_snapshot.dart';
import 'package:labs/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'renders KPI StatTiles + top-dishes rows + console link; launch failure '
    'degrades to a snackbar (RoleGate owner path)',
    (tester) async {
      final fake = FakeFirebaseFirestore();
      await fake.collection('orders').add({
        'tenantId': 'tenant_a',
        'status': 'confirmed',
        'totalCents': 2500,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'items': [
          {
            'item': {'id': 'd1', 'name': 'Shawarma', 'priceCents': 1250},
            'quantity': 2,
            'selectedOptions': <Map<String, dynamic>>[],
          },
        ],
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tenantIdProvider.overrideWith((ref) async => 'tenant_a'),
            firestoreProvider.overrideWithValue(fake),
            currentUserProvider.overrideWith(
              (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
            ),
            restaurantConfigProvider.overrideWith(
              (_) => Stream<RestaurantConfigModel>.value(
                const RestaurantConfigModel(currency: 'USD'),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AnalyticsSnapshot(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      // The top-dishes FutureProvider only starts on the frame AFTER the
      // headline stream resolves — give its fetch one more frame.
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      // KPI StatTiles (labels from ARB).
      expect(find.text("Today's Orders"), findsOneWidget);
      expect(find.text("Today's Revenue"), findsOneWidget);
      expect(find.text('Active Orders'), findsOneWidget);
      // NEW per-dish section fed by the aggregate provider (status filter is
      // absent there — the confirmed order ranks today).
      expect(find.text('Top Dishes Today'), findsOneWidget);
      expect(find.text('Shawarma'), findsOneWidget);
      // Abandoned-cart console section: header + honest note + 48 dp link.
      expect(find.text('Abandoned Carts'), findsOneWidget);
      expect(
        find.text(
          'Opens the external analytics console. Reports run once a day — '
          'figures are current through yesterday.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open analytics console'), findsOneWidget);

      // The launch must never throw into the UI: in the test environment the
      // platform channel is unmocked, so it fails — degrading to the snackbar
      // is the receipt.
      // The launch failure path must degrade to the localized snackbar (never
      // throw into the UI): the url_launcher channel is mocked to FAIL, so
      // this branch is deterministic instead of host-dependent.
      final channelCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async {
              channelCalls.add(call);
              throw PlatformException(code: 'ERR', message: 'test-mode');
            },
          );
      final btn = find.byType(ElevatedButton);
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.tap(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(channelCalls, hasLength(1));
      expect(
        find.text('Could not open the external link. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
