import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI-9 (p19) T-1 — the `DeliveryPlatformAdapter` contract and the
/// config-gated registry: each platform is an implementation, the client's
/// config picks theirs, and a disabled/absent platform is INERT (the registry
/// never hands out an adapter for it).
class _FakeAdapter implements DeliveryPlatformAdapter {
  _FakeAdapter(this.id, {this.throwOnSync = false});

  @override
  final String id;

  final bool throwOnSync;
  final List<List<DishAvailabilityUpdate>> syncCalls =
      <List<DishAvailabilityUpdate>>[];
  final List<Map<String, dynamic>> mappedOrders = <Map<String, dynamic>>[];
  final List<String> acknowledged = <String>[];
  final List<String> rejectedReasons = <String>[];

  @override
  Future<void> syncAvailability(List<DishAvailabilityUpdate> updates) async {
    if (throwOnSync) throw StateError('platform unavailable');
    syncCalls.add(updates);
  }

  @override
  IngestedOrderDraft mapInboundOrder(
    Map<String, dynamic> payload, {
    required String storeId,
  }) {
    mappedOrders.add(payload);
    final orderId = payload['order_id'];
    if (orderId is! String || orderId.isEmpty) {
      throw const IngestedOrderMappingError(
        'malformed_payload',
        'order_id must be a non-empty string',
      );
    }
    return IngestedOrderDraft(
      platformId: id,
      platformOrderId: orderId,
      storeId: storeId,
      lines: const <IngestedOrderLine>[],
      claimedTotalCents: 6000,
    );
  }

  @override
  Future<void> acknowledge(String platformOrderId) async {
    acknowledged.add(platformOrderId);
  }

  @override
  Future<void> reject(String platformOrderId, {required String reason}) async {
    rejectedReasons.add(reason);
  }
}

Map<String, dynamic> _fixture(String caseName) {
  final file = File(
    '../../core_app/functions/test/fixtures/platform/'
    'delivery_platforms_config.json',
  );
  final cases = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return cases[caseName] as Map<String, dynamic>;
}

void main() {
  group('DeliveryPlatformAdapter — the four-member contract (L1)', () {
    test('an implementation can satisfy sync/map/acknowledge/reject', () async {
      final adapter = _FakeAdapter('uber_eats');
      expect(adapter.id, 'uber_eats');

      await adapter.syncAvailability(const <DishAvailabilityUpdate>[
        DishAvailabilityUpdate(
          menuItemId: 'mc_fries_1',
          branchId: 'carnama-branch-1',
          isAvailable: false,
        ),
      ]);
      expect(adapter.syncCalls.single.single.menuItemId, 'mc_fries_1');
      expect(adapter.syncCalls.single.single.isAvailable, isFalse);
      expect(adapter.syncCalls.single.single.branchId, 'carnama-branch-1');

      final draft = adapter.mapInboundOrder(<String, dynamic>{
        'order_id': 'ORDER123',
      }, storeId: 'STORE-HB-01');
      expect(draft.idempotencyKey, 'uber_eats:ORDER123');
      expect(draft.storeId, 'STORE-HB-01');
      expect(draft.claimedTotalCents, 6000);
      expect(adapter.mappedOrders.single['order_id'], 'ORDER123');

      await adapter.acknowledge('ORDER123');
      await adapter.reject('ORDER124', reason: 'item_unavailable');
      expect(adapter.acknowledged, ['ORDER123']);
      expect(adapter.rejectedReasons, ['item_unavailable']);
    });

    test('a malformed platform payload fails closed with a typed reason', () {
      final adapter = _FakeAdapter('delivery_hero');
      expect(
        () => adapter.mapInboundOrder(<String, dynamic>{}, storeId: 's'),
        throwsA(
          isA<IngestedOrderMappingError>()
              .having((e) => e.reason, 'reason', 'malformed_payload')
              .having(
                (e) => e.toString(),
                'toString',
                contains('malformed_payload'),
              ),
        ),
      );
    });

    test(
      'a platform error surfaces (the caller decides retry vs DLQ)',
      () async {
        final adapter = _FakeAdapter('uber_eats', throwOnSync: true);
        await expectLater(
          adapter.syncAvailability(const <DishAvailabilityUpdate>[]),
          throwsA(isA<StateError>()),
        );
        expect(adapter.syncCalls, isEmpty);
      },
    );

    test('the update + mapping-error types are plain runtime values', () {
      final menuItemId = <String>['mc_fries_1'].first;
      final update = DishAvailabilityUpdate(
        menuItemId: menuItemId,
        branchId: 'carnama-branch-1',
        isAvailable: true,
      );
      expect(update.menuItemId, menuItemId);
      expect(update.branchId, 'carnama-branch-1');
      expect(update.isAvailable, isTrue);

      final reason = <String>['malformed_payload'].first;
      final error = IngestedOrderMappingError(reason, 'order_id missing');
      expect(error.reason, reason);
      expect(error.detail, 'order_id missing');
      expect(error.toString(), contains('order_id missing'));
    });
  });

  group('DeliveryPlatformRegistry — config-gated, inert by default', () {
    DeliveryPlatformRegistry registryFor(
      Object? raw, {
      Map<String, DeliveryPlatformAdapterFactory>? factories,
    }) {
      return DeliveryPlatformRegistry.fromConfig(
        raw,
        factories:
            factories ??
            <String, DeliveryPlatformAdapterFactory>{
              'uber_eats': (config) => _FakeAdapter(config.id),
              'delivery_hero': (config) => _FakeAdapter(config.id),
            },
      );
    }

    test('the enabled platform resolves to its implementation', () {
      final registry = registryFor(_fixture('valid')['deliveryPlatforms']);
      expect(registry.enabledIds, ['uber_eats']);
      expect(registry.isEnabled('uber_eats'), isTrue);
      expect(registry.isEnabled('delivery_hero'), isFalse);
      expect(registry.adapterFor('uber_eats')?.id, 'uber_eats');
      expect(registry.adapterFor('delivery_hero'), isNull);
      expect(registry.require('uber_eats').id, 'uber_eats');
      expect(registry.configFor('uber_eats')?.storeId, 'STORE-HB-01');
      expect(registry.configFor('delivery_hero'), isNull);
    });

    test('a disabled platform is INERT even when a factory exists', () {
      final registry = registryFor(_fixture('disabled')['deliveryPlatforms']);
      expect(registry.enabledIds, isEmpty);
      expect(registry.adapterFor('uber_eats'), isNull);
      expect(registry.isEnabled('uber_eats'), isFalse);
      expect(
        () => registry.require('uber_eats'),
        throwsA(
          isA<AdapterNotConfiguredError>().having(
            (e) => e.toString(),
            'toString',
            contains('uber_eats'),
          ),
        ),
      );
    });

    test('an absent section is inert (no adapters, no throw on lookup)', () {
      final registry = registryFor(null);
      expect(registry.enabledIds, isEmpty);
      expect(registry.adapterFor('uber_eats'), isNull);
      expect(registry.isEnabled('doordash'), isFalse);
    });

    test('a configured platform with NO factory stays inert', () {
      final registry = registryFor(
        _fixture('valid')['deliveryPlatforms'],
        factories: const <String, DeliveryPlatformAdapterFactory>{},
      );
      expect(registry.enabledIds, ['uber_eats']);
      expect(registry.isEnabled('uber_eats'), isFalse);
      expect(registry.adapterFor('uber_eats'), isNull);
    });

    test('the factory receives the validated config row', () {
      DeliveryPlatformConfig? seen;
      registryFor(
        _fixture('valid')['deliveryPlatforms'],
        factories: <String, DeliveryPlatformAdapterFactory>{
          'uber_eats': (config) {
            seen = config;
            return _FakeAdapter(config.id);
          },
        },
      );
      expect(seen?.credentialRef, 'UBER_EATS_WEBHOOK_SECRET');
    });
  });
}
