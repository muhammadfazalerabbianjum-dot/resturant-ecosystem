import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/currency_format.dart';

/// P37 T-3 — the config `currency` block becomes the seed default.
///
/// R3 (WHITE_LABEL_p37_nine_push.md §1): both shipped configs carry
/// `currency: {code, symbol}` with ZERO Dart readers — the money path resolved
/// the Firestore doc only. Liveness pins the readers; the behavior groups
/// pin the precedence rule end to end.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('P37 T-3 liveness: the config currency block has production readers', () {
    test(
      'AppConfig parses `currency` and exposes currencyCode/currencySymbol',
      () {
        final src = File(
          '${Directory.current.path}/lib/app/config/app_config.dart',
        ).readAsStringSync();
        expect(
          src,
          contains("json['currency']"),
          reason: 'the config currency block has no parser (R3)',
        );
        expect(src, contains('static String get currencyCode'));
        expect(src, contains('static String get currencySymbol'));
      },
    );

    test('the ONE precedence resolver exists in currency_format.dart', () {
      final src = File(
        '${Directory.current.path}/lib/app/config/currency_format.dart',
      ).readAsStringSync();
      expect(src, contains('String resolveCurrencyCode'));
    });

    test('the customer money path (menu_screen) routes through the resolver', () {
      final src = File(
        '${Directory.current.path}/lib/features/menu/presentation/menu_screen.dart',
      ).readAsStringSync();
      expect(src, contains('resolveCurrencyCode('));
    });
  });

  group('resolveCurrencyCode precedence (doc -> config seed -> USD)', () {
    test('the runtime doc wins even when a config seed exists', () {
      expect(resolveCurrencyCode(fromDoc: 'EUR', fromConfig: 'USD'), 'EUR');
    });

    test('doc absent or whitespace falls back to the config seed', () {
      expect(resolveCurrencyCode(fromDoc: null, fromConfig: 'SAR'), 'SAR');
      expect(resolveCurrencyCode(fromDoc: '  ', fromConfig: 'SAR'), 'SAR');
      expect(resolveCurrencyCode(fromDoc: 'EUR', fromConfig: ''), 'EUR');
    });

    test('both absent fails closed to USD', () {
      expect(resolveCurrencyCode(fromDoc: null, fromConfig: null), 'USD');
      expect(resolveCurrencyCode(fromDoc: '', fromConfig: ' '), 'USD');
    });
  });

  group('shipped configs pin the seed default', () {
    test('both shipped client_config.json files declare currency.code USD', () {
      for (final path in [
        'assets/client_config.json',
        '../apps/halal_boyz/assets/client_config.json',
      ]) {
        final json =
            jsonDecode(
                  File('${Directory.current.path}/$path').readAsStringSync(),
                )
                as Map<String, dynamic>;
        final currency = json['currency'] as Map<String, dynamic>;
        expect(currency['code'], 'USD', reason: path);
        expect(currency['symbol'], '', reason: path);
      }
    });

    test(
      'AppConfig.loadConfig surfaces the shipped seed through getters',
      () async {
        await AppConfig.loadConfig();
        expect(
          AppConfig.loadFailed,
          isFalse,
          reason: 'template asset must parse',
        );
        expect(AppConfig.currencyCode, 'USD');
        expect(AppConfig.currencySymbol, '');
      },
    );
  });
}
