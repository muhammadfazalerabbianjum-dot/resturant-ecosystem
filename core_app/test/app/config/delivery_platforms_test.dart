import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/client_config.dart';

/// UI-9 (p19) T-1 — the `deliveryPlatforms` config surface end-to-end:
/// `ClientConfig.fromMap` (the W6.5 schema gate), the `AppConfig` parser, and
/// the fail-closed boot (an invalid row blocks on the
/// ConfigValidationErrorScreen exactly like the screen-variant vocabulary).
///
/// The `unknown platform id` / `missing credentialRef` cases read the SHARED
/// fixture at `functions/test/fixtures/platform/delivery_platforms_config.json`
/// — the same file the server selector (`platform_ingestion.ts`) and the
/// generator mirror are pinned to.
Map<String, dynamic> fixtureCases() {
  final file = File(
    'functions/test/fixtures/platform/delivery_platforms_config.json',
  );
  expect(file.existsSync(), isTrue, reason: 'run from core_app/');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> withDeliveryPlatforms(
  Object? section,
) => <String, dynamic>{
  // P0-6: tenancy identity is required by both validators.
  'tenantId': 'halal_boyz',
  '_meta': <String, dynamic>{
    'schemaVersion': ClientConfig.supportedSchemaVersion,
  },
  'app': <String, dynamic>{'name': 'Client App', 'bundleId': 'com.client.app'},
  'theme': <String, dynamic>{
    'injection': ClientConfig.requiredInjectionMode,
    'colors': <String, dynamic>{'primary': '0xFF2E7D32'},
  },
  'navigation': <String, dynamic>{'entryPoint': '/'},
  if (section != null) 'deliveryPlatforms': section,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockAssets(Map<String, String> assets) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          if (message == null) return null;
          final key = utf8.decode(message.buffer.asUint8List());
          final content = assets[key];
          if (content == null) return null;
          return ByteData.view(Uint8List.fromList(utf8.encode(content)).buffer);
        });
  }

  String configJson(Object? section) =>
      jsonEncode(withDeliveryPlatforms(section));

  group('ClientConfig.fromMap — the delivery-platform schema gate', () {
    test('an absent section is valid AND inert (adapters never activate)', () {
      expect(
        () => ClientConfig.fromMap(withDeliveryPlatforms(null)),
        returnsNormally,
      );
    });

    test('the shared valid fixture case parses', () {
      expect(
        () => ClientConfig.fromMap(
          withDeliveryPlatforms(
            (fixtureCases()['valid']
                as Map<String, dynamic>)['deliveryPlatforms'],
          ),
        ),
        returnsNormally,
      );
    });

    test('an unknown platform id fails CLOSED at the exact JSON path', () {
      try {
        ClientConfig.fromMap(
          withDeliveryPlatforms(
            (fixtureCases()['unknown_id']
                as Map<String, dynamic>)['deliveryPlatforms'],
          ),
        );
        fail('expected ConfigException');
      } on ConfigException catch (error) {
        expect(error.jsonPath, 'deliveryPlatforms[0].id');
        expect(error.toString(), contains('"deliveryPlatforms[0].id"'));
        expect(error.toString(), contains('doordash'));
      }
    });

    test('a secret literal credentialRef fails CLOSED (L4)', () {
      try {
        ClientConfig.fromMap(
          withDeliveryPlatforms(
            (fixtureCases()['secret_literal']
                as Map<String, dynamic>)['deliveryPlatforms'],
          ),
        );
        fail('expected ConfigException');
      } on ConfigException catch (error) {
        expect(error.jsonPath, 'deliveryPlatforms[0].credentialRef');
        expect(error.toString(), contains('REFERENCE'));
      }
    });

    test('a duplicate platform id fails CLOSED', () {
      try {
        ClientConfig.fromMap(
          withDeliveryPlatforms(
            (fixtureCases()['duplicate_id']
                as Map<String, dynamic>)['deliveryPlatforms'],
          ),
        );
        fail('expected ConfigException');
      } on ConfigException catch (error) {
        expect(error.jsonPath, 'deliveryPlatforms[1].id');
      }
    });

    test('a non-list section fails CLOSED at deliveryPlatforms', () {
      try {
        ClientConfig.fromMap(
          withDeliveryPlatforms(
            (fixtureCases()['not_a_list']
                as Map<String, dynamic>)['deliveryPlatforms'],
          ),
        );
        fail('expected ConfigException');
      } on ConfigException catch (error) {
        expect(error.jsonPath, 'deliveryPlatforms');
      }
    });
  });

  group('AppConfig.loadConfig — the parser + the fail-closed boot', () {
    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    test('the parsed rows are exposed raw AND typed (enabled only)', () async {
      AppConfig.resetForTest();
      mockAssets({
        'assets/client_config.json': configJson(
          (fixtureCases()['valid']
              as Map<String, dynamic>)['deliveryPlatforms'],
        ),
      });
      await AppConfig.loadConfig();
      expect(AppConfig.loadFailed, isFalse);
      expect(AppConfig.schemaError, isNull);
      expect(AppConfig.deliveryPlatforms, hasLength(2));
      expect(AppConfig.deliveryPlatforms.first['id'], 'uber_eats');
      final enabled = AppConfig.enabledDeliveryPlatforms;
      expect(enabled, hasLength(1));
      expect(enabled.first.id, DeliveryPlatforms.uberEatsId);
      expect(enabled.first.storeId, 'STORE-HB-01');
      expect(DeliveryPlatforms.isInert(AppConfig.deliveryPlatforms), isFalse);
    });

    test('an absent section leaves the adapters inert', () async {
      AppConfig.resetForTest();
      mockAssets({'assets/client_config.json': configJson(null)});
      await AppConfig.loadConfig();
      expect(AppConfig.loadFailed, isFalse);
      expect(AppConfig.deliveryPlatforms, isEmpty);
      expect(AppConfig.enabledDeliveryPlatforms, isEmpty);
      expect(DeliveryPlatforms.isInert(AppConfig.deliveryPlatforms), isTrue);
    });

    test('an invalid row blocks the boot with the typed schemaError', () async {
      AppConfig.resetForTest();
      mockAssets({
        'assets/client_config.json': configJson(
          (fixtureCases()['unknown_id']
              as Map<String, dynamic>)['deliveryPlatforms'],
        ),
      });
      await AppConfig.loadConfig();
      expect(AppConfig.loadFailed, isTrue);
      expect(AppConfig.schemaError, isNotNull);
      expect(AppConfig.schemaError!.jsonPath, 'deliveryPlatforms[0].id');
      expect(AppConfig.enabledDeliveryPlatforms, isEmpty);
    });
  });
}
