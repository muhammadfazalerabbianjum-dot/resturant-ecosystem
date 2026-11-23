import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

import 'helpers/isar_native.dart';
import 'helpers/recording_logger.dart';

class _EmptyEndpointConfig implements CoreConfig {
  const _EmptyEndpointConfig();

  @override
  bool get isDemoMode => true;

  @override
  String get clientId => 'carnama-test';

  @override
  String get cloudinaryUploadPreset => '';

  @override
  String get cloudinaryCloudName => '';

  @override
  List<String> get ownerEmails => const <String>[];

  @override
  String get kitchenLanEndpoint => '';
}

class _Payload implements OrderPayload {
  const _Payload({required this.id, required this.totalCents});

  final String id;
  final int totalCents;

  factory _Payload.fromJson(Map<String, dynamic> json) =>
      _Payload(id: json['id'] as String, totalCents: json['totalCents'] as int);

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'totalCents': totalCents,
  };
}

/// CORE-COV Tier-2 KITCHEN suite (PUSH-1 P-3): the heartbeat empty-endpoint
/// guard (fail-closed — NEVER build a relative `/orders` URL or POST to a
/// bogus destination) and the [OrderPayload] round-trip contract.
void main() {
  setUpAll(ensureIsarCoreForTests);

  tearDown(() => CoreConfigHolder.set(const DefaultCoreConfig()));

  group('KitchenOfflineService.runHeartbeat — PUSH-1 endpoint guard', () {
    test(
      'empty endpoint logs KitchenHeartbeatSkipped and NEVER touches the parser',
      () async {
        CoreConfigHolder.set(const _EmptyEndpointConfig());
        final logger = RecordingLogger();
        // A parser that would THROW proves the guard returns before any
        // payload parsing or connectivity check can run.
        final service = KitchenOfflineService(
          logger: logger,
          orderPayloadParser: (json) => throw StateError('parser must not run'),
        );

        await service.runHeartbeat();

        expect(logger.warns, hasLength(1));
        expect(logger.warns.single, contains('KitchenHeartbeatSkipped'));
        expect(logger.warns.single, contains('kitchenLanEndpoint'));
      },
    );

    test(
      'whitespace-only endpoint is treated as absent (trim before check)',
      () async {
        CoreConfigHolder.set(const _WhitespaceEndpointConfig());
        final logger = RecordingLogger();
        final service = KitchenOfflineService(
          logger: logger,
          orderPayloadParser: (json) => throw StateError('parser must not run'),
        );

        await service.runHeartbeat();

        expect(logger.warns.single, contains('KitchenHeartbeatSkipped'));
      },
    );

    test(
      'the DefaultCoreConfig endpoint is a NON-empty production sentinel',
      () {
        expect(const DefaultCoreConfig().kitchenLanEndpoint, isNotEmpty);
      },
    );
  });

  group('OrderPayload contract', () {
    test(
      'the parser round-trips exactly what the heartbeat JSON path rehydrates',
      () {
        const payload = _Payload(id: 'F-1', totalCents: 1999);
        OrderPayloadParser parser = _Payload.fromJson;

        final encoded = jsonEncode(
          const <OrderPayload>[payload].map((o) => o.toJson()).toList(),
        );
        final decoded = jsonDecode(encoded) as List<dynamic>;
        final rehydrated = parser(
          Map<String, dynamic>.from(decoded.single as Map),
        );

        expect(rehydrated.toJson(), <String, dynamic>{
          'id': 'F-1',
          'totalCents': 1999,
        });
      },
    );
  });
}

class _WhitespaceEndpointConfig extends _EmptyEndpointConfig {
  const _WhitespaceEndpointConfig();

  @override
  String get kitchenLanEndpoint => '   ';
}
