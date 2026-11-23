import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI-9 (p19) T-1 — the `deliveryPlatforms` config vocabulary: fail-closed
/// validation at exact JSON paths, inert-when-absent (the screen_variants
/// STRICTLY-WHEN-PRESENT rule), and the documented platform allowlist.
///
/// The SAME fixture file drives the Dart runtime validator, the generator
/// mirror (`core_app/tool/whitelabel.dart`) and the server selector
/// (`core_app/functions/src/platform_ingestion.ts`) — the parity pin.
Map<String, dynamic> fixtureCases() {
  final file = File(
    '../../core_app/functions/test/fixtures/platform/'
    'delivery_platforms_config.json',
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<DeliveryPlatformViolation> validate(String caseName) {
  final fixture = fixtureCases()[caseName] as Map<String, dynamic>;
  return DeliveryPlatforms.validatePlatforms(fixture['deliveryPlatforms']);
}

void main() {
  group('DeliveryPlatforms catalog — the documented platform vocabulary', () {
    test('exactly the two documented platforms', () {
      expect(DeliveryPlatforms.catalog, {
        DeliveryPlatforms.uberEatsId,
        DeliveryPlatforms.deliveryHeroId,
      });
      expect(DeliveryPlatforms.uberEatsId, 'uber_eats');
      expect(DeliveryPlatforms.deliveryHeroId, 'delivery_hero');
    });

    test('credentialRef is an env-style REFERENCE, never a secret literal', () {
      final pattern = DeliveryPlatforms.credentialRefPattern;
      expect(pattern.hasMatch('UBER_EATS_WEBHOOK_SECRET'), isTrue);
      expect(pattern.hasMatch('DELIVERY_HERO_PGP_PASSPHRASE'), isTrue);
      expect(
        pattern.hasMatch('uber_eats_secret'),
        isFalse,
        reason: 'lowercase',
      );
      expect(
        pattern.hasMatch('Sk-Live-Key'),
        isFalse,
        reason: 'not an env name',
      );
      expect(pattern.hasMatch(''), isFalse);
      for (final literal in DeliveryPlatforms.forbiddenCredentialPrefixes) {
        expect(
          DeliveryPlatforms.looksLikeSecretLiteral('${literal}whatever'),
          isTrue,
          reason: '$literal must never appear as a credentialRef',
        );
      }
      expect(
        DeliveryPlatforms.looksLikeSecretLiteral('UBER_EATS_WEBHOOK_SECRET'),
        isFalse,
      );
      expect(DeliveryPlatforms.looksLikeSecretLiteral(null), isFalse);
    });
  });

  group('DeliveryPlatforms.validatePlatforms — absent/null = inert', () {
    test('a missing section yields no violations and no enabled platform', () {
      final cases = fixtureCases();
      final absent =
          (cases['absent'] as Map<String, dynamic>)['deliveryPlatforms'];
      for (final raw in <Object?>[null, absent]) {
        expect(DeliveryPlatforms.validatePlatforms(raw), isEmpty);
        expect(DeliveryPlatforms.enabledPlatforms(raw), isEmpty);
        expect(DeliveryPlatforms.isInert(raw), isTrue);
      }
      expect(
        DeliveryPlatforms.enabledPlatforms(<Object?>[]),
        isEmpty,
        reason: 'an empty list is inert too',
      );
    });

    test('a disabled platform is valid AND inert (config-gated)', () {
      final raw = <Object?>[
        {'id': 'uber_eats', 'enabled': false, 'storeId': 'STORE-HB-01'},
      ];
      expect(DeliveryPlatforms.validatePlatforms(raw), isEmpty);
      expect(DeliveryPlatforms.enabledPlatforms(raw), isEmpty);
      expect(DeliveryPlatforms.isInert(raw), isTrue);
    });
  });

  group(
    'DeliveryPlatforms.validatePlatforms — present-but-invalid fails CLOSED',
    () {
      test('a non-list section rejects at deliveryPlatforms', () {
        final violations = validate('not_a_list');
        expect(violations, hasLength(1));
        expect(violations.first.path, 'deliveryPlatforms');
        expect(violations.first.message, contains('list'));
        expect(violations.first.toString(), contains('"deliveryPlatforms"'));
      });

      test('a non-object row rejects at its index', () {
        final violations = DeliveryPlatforms.validatePlatforms(<Object?>[
          'junk',
          42,
        ]);
        expect(violations.map((v) => v.path), [
          'deliveryPlatforms[0]',
          'deliveryPlatforms[1]',
        ]);
      });

      test('an unknown platform id rejects with the allowed ids', () {
        final violations = validate('unknown_id');
        expect(violations, hasLength(1));
        expect(violations.first.path, 'deliveryPlatforms[0].id');
        expect(violations.first.message, contains('doordash'));
        expect(violations.first.message, contains('uber_eats'));
      });

      test('a missing/blank/non-string id rejects', () {
        final violations = DeliveryPlatforms.validatePlatforms(<Object?>[
          {'enabled': true, 'storeId': 's', 'credentialRef': 'A_B_C'},
          {'id': '   ', 'storeId': 's'},
          {'id': 7, 'storeId': 's'},
        ]);
        expect(violations.map((v) => v.path), [
          'deliveryPlatforms[0].id',
          'deliveryPlatforms[1].id',
          'deliveryPlatforms[2].id',
        ]);
        expect(violations.first.message, contains('non-empty'));
      });

      test('a duplicate platform id rejects the SECOND row', () {
        final violations = validate('duplicate_id');
        expect(violations, hasLength(1));
        expect(violations.first.path, 'deliveryPlatforms[1].id');
        expect(violations.first.message, contains('duplicate'));
        expect(
          DeliveryPlatforms.enabledPlatforms(<Object?>[
            {
              'id': 'uber_eats',
              'enabled': true,
              'credentialRef': 'UBER_EATS_WEBHOOK_SECRET',
              'storeId': 'A',
            },
            {'id': 'uber_eats', 'enabled': false, 'storeId': 'B'},
          ]),
          isEmpty,
          reason: 'an ambiguous duplicate set can never activate an adapter',
        );
      });

      test('a non-boolean enabled rejects at its path', () {
        final violations = validate('non_bool_enabled');
        expect(violations, hasLength(1));
        expect(violations.first.path, 'deliveryPlatforms[0].enabled');
        expect(violations.first.message, contains('boolean'));
      });
    },
  );

  test('an enabled platform MUST carry storeId + credentialRef', () {
    final violations = validate('missing_store_when_enabled');
    expect(violations.map((v) => v.path), ['deliveryPlatforms[0].storeId']);
    expect(violations.single.message, contains('storeId'));
  });

  test('an empty storeId rejects', () {
    final violations = DeliveryPlatforms.validatePlatforms(<Object?>[
      {'id': 'delivery_hero', 'enabled': true, 'storeId': '  '},
    ]);
    expect(violations.map((v) => v.path), [
      'deliveryPlatforms[0].storeId',
      'deliveryPlatforms[0].credentialRef',
    ]);
  });

  test('a secret LITERAL as credentialRef rejects (L4)', () {
    final violations = validate('secret_literal');
    expect(violations.map((v) => v.path), [
      'deliveryPlatforms[0].credentialRef',
    ]);
    expect(violations.first.message, contains('REFERENCE'));
    expect(
      DeliveryPlatforms.enabledPlatforms(<Object?>[
        {
          'id': 'delivery_hero',
          'enabled': true,
          'credentialRef': 'sk_live_example',
          'storeId': 's',
        },
      ]),
      isEmpty,
    );
  });

  test('a malformed credentialRef rejects', () {
    final violations = DeliveryPlatforms.validatePlatforms(<Object?>[
      {
        'id': 'delivery_hero',
        'enabled': true,
        'credentialRef': 'delivery hero secret',
        'storeId': 's',
      },
    ]);
    expect(violations, hasLength(1));
    expect(violations.first.path, 'deliveryPlatforms[0].credentialRef');
  });

  group('DeliveryPlatformConfig — the typed row the adapters read', () {
    test('a parsed row round-trips through toJson + toString', () {
      final row = DeliveryPlatformConfig.fromMap(<String, dynamic>{
        'id': 'delivery_hero',
        'enabled': true,
        'credentialRef': 'DELIVERY_HERO_WEBHOOK_SECRET',
        'storeId': 'carnama-branch-1',
      });
      expect(row, isNotNull);
      final parsed = row!;
      expect(parsed.id, 'delivery_hero');
      expect(parsed.enabled, isTrue);
      expect(parsed.toJson(), {
        'id': 'delivery_hero',
        'enabled': true,
        'credentialRef': 'DELIVERY_HERO_WEBHOOK_SECRET',
        'storeId': 'carnama-branch-1',
      });
      expect(parsed.toString(), contains('delivery_hero'));
      expect(parsed.toString(), contains('carnama-branch-1'));
    });

    test('an incomplete or unknown row parses to null (never a guess)', () {
      final cases = <Object?>[
        null,
        'delivery_hero',
        <Object?>[],
        <String, dynamic>{'id': 'delivery_hero'},
        <String, dynamic>{
          'id': 'doordash',
          'storeId': 's',
          'credentialRef': 'A_B',
        },
        <String, dynamic>{
          'id': 'delivery_hero',
          'storeId': 7,
          'credentialRef': 'A_B',
        },
      ];
      for (final raw in cases) {
        expect(DeliveryPlatformConfig.fromMap(raw), isNull, reason: '$raw');
      }
      expect(
        DeliveryPlatformConfig.fromMap(<String, dynamic>{
          'id': 'uber_eats',
          'storeId': 'STORE-HB-01',
          'credentialRef': 'UBER_EATS_WEBHOOK_SECRET',
        })?.enabled,
        isFalse,
        reason: 'an absent enabled key is inert, never implied true',
      );
    });

    test('a violation renders its exact path for the operator', () {
      const violation = DeliveryPlatformViolation(
        'deliveryPlatforms[0].credentialRef',
        'must be a secret REFERENCE',
      );
      expect(violation.path, 'deliveryPlatforms[0].credentialRef');
      expect(
        violation.toString(),
        '"deliveryPlatforms[0].credentialRef" must be a secret REFERENCE',
      );
    });
  });
}
