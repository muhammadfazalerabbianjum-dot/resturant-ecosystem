import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI-9 (p19) T-1/L6 — the `OrderDraft` mapping: the platform→our-menu line
/// vocabulary, the namespaced idempotency key (L2), the `platform:<id>` order
/// source (L6) and the persisted-document shape that carries NO customerId
/// (so a platform order can never appear in a client user's own history).
void main() {
  group('OrderSource — the L6 isolation vocabulary', () {
    test('platform:<id> round-trips', () {
      expect(OrderSource.forPlatform('uber_eats'), 'platform:uber_eats');
      expect(OrderSource.isPlatformOrder('platform:uber_eats'), isTrue);
      expect(OrderSource.platformOf('platform:uber_eats'), 'uber_eats');
      expect(OrderSource.isPlatformOrder('carnama-app'), isFalse);
      expect(OrderSource.isPlatformOrder(null), isFalse);
      expect(OrderSource.isPlatformOrder(7), isFalse);
      expect(OrderSource.platformOf('carnama-app'), isNull);
      expect(OrderSource.platformOf(null), isNull);
    });

    test('the consumer-history filter field is customerId', () {
      expect(OrderSource.consumerHistoryFilterField, 'customerId');
    });
  });

  group('IngestedOrderLine — the re-derivation input shape', () {
    test('toPricingInput matches the existing money-path flat line', () {
      const line = IngestedOrderLine(
        menuItemId: 'mc_burger_1',
        quantity: 2,
        claimedUnitPriceCents: 2450,
        selectedOptions: <IngestedOption>[
          IngestedOption(id: 'opt_cheese', upchargeCents: 200),
          IngestedOption(id: 'opt_no_upcharge'),
        ],
      );
      expect(line.toPricingInput(), {
        'id': 'mc_burger_1',
        'quantity': 2,
        'priceCents': 2450,
        'selectedOptions': [
          {'id': 'opt_cheese', 'upchargeCents': 200},
          {'id': 'opt_no_upcharge'},
        ],
      });
    });

    test('defaults: quantity 1, no claim, no options', () {
      const line = IngestedOrderLine(menuItemId: 'mc_fries_1', quantity: 1);
      expect(line.claimedUnitPriceCents, isNull);
      expect(line.selectedOptions, isEmpty);
      expect(line.toPricingInput(), {
        'id': 'mc_fries_1',
        'quantity': 1,
        'priceCents': null,
        'selectedOptions': <Map<String, Object?>>[],
      });
      const option = IngestedOption(id: 'opt_cheese');
      expect(option.toString(), contains('opt_cheese'));
    });

    test('a runtime-built line/option pair is the same flat shape', () {
      final menuItemId = <String>['mc_burger_1'].first;
      final optionId = <String>['opt_cheese_1'].first;
      final option = IngestedOption(id: optionId, upchargeCents: 200);
      final line = IngestedOrderLine(
        menuItemId: menuItemId,
        quantity: 2,
        claimedUnitPriceCents: 2450,
        selectedOptions: <IngestedOption>[option],
      );
      expect(line.toPricingInput(), {
        'id': 'mc_burger_1',
        'quantity': 2,
        'priceCents': 2450,
        'selectedOptions': [
          {'id': 'opt_cheese_1', 'upchargeCents': 200},
        ],
      });
    });
  });

  group('IngestedOrderDraft — L2 key, L6 source, persisted document', () {
    const draft = IngestedOrderDraft(
      platformId: 'uber_eats',
      platformOrderId: 'ORDER123',
      storeId: 'STORE-HB-01',
      lines: <IngestedOrderLine>[
        IngestedOrderLine(
          menuItemId: 'mc_burger_1',
          quantity: 2,
          claimedUnitPriceCents: 2450,
        ),
      ],
    );

    test('the idempotency key is the namespaced platform order id', () {
      expect(draft.idempotencyKey, 'uber_eats:ORDER123');
      expect(draft.orderSource, OrderSource.forPlatform('uber_eats'));
      expect(draft.documentId, 'uber_eats_ORDER123');
      expect(draft.claimedTotalCents, isNull);
      expect(draft.pricingLines.single['id'], 'mc_burger_1');
    });

    test('a different platform namespace can never collide', () {
      const other = IngestedOrderDraft(
        platformId: 'delivery_hero',
        platformOrderId: 'ORDER123',
        storeId: 'carnama-branch-1',
        lines: <IngestedOrderLine>[],
      );
      expect(other.idempotencyKey, isNot(draft.idempotencyKey));
    });

    test(
      'the persisted document carries the verified money + NO customerId',
      () {
        final document = draft.toPersistedDocument(
          canonicalItems: const <Object?>[
            {
              'item': {'id': 'mc_burger_1'},
              'quantity': 2,
            },
          ],
          itemsSubtotalCents: 5300,
          branchId: 'carnama-branch-1',
          platformClaimedTotalCents: 6000,
        );
        expect(document['orderSource'], 'platform:uber_eats');
        expect(document['idempotencyKey'], 'uber_eats:ORDER123');
        expect(document['status'], 'confirmed');
        expect(document['branchId'], 'carnama-branch-1');
        expect(document['itemsSubtotalCents'], 5300);
        expect(document['totalCents'], 5300);
        expect(document['platformClaimedTotalCents'], 6000);
        expect(
          document.containsKey('customerId'),
          isFalse,
          reason: 'L6: consumer history filters on customerId == uid',
        );
        for (final key in document.keys) {
          expect(
            RegExp(
              'customer|address|phone|email',
              caseSensitive: false,
            ).hasMatch(key),
            isFalse,
            reason: 'no customer PII is persisted ($key)',
          );
        }
      },
    );

    test('a null platform-total claim is recorded as null, never 0', () {
      final document = draft.toPersistedDocument(
        canonicalItems: const <Object?>[],
        itemsSubtotalCents: 0,
        branchId: 'carnama-branch-1',
        platformClaimedTotalCents: null,
      );
      expect(document['platformClaimedTotalCents'], isNull);
      expect(document['totalCents'], 0);
    });
  });
}
