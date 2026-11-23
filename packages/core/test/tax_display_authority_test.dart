import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mock_firebase.dart';
import 'helpers/recording_logger.dart';

/// FIX-B4 T-5 — display/authority split (contract 0.10: server = money
/// authority; the client never computes an authoritative tax).
///
/// [TaxService] stays display/preview ONLY:
///  * its source never computes an authoritative total — no rate table, no
///    subtotal x rate product, no rounding rule of its own;
///  * the request it sends carries INPUTS only (never a precomputed tax);
///  * for every shared row of the T-4 parity table
///    (`tool_fix/b4/tax_round_parity.js`, receipt
///    `tool_fix/b4/green_t4_parity.txt`) the value it PARSES equals the
///    charge path's committed integer-cent pin, and that pin equals Dart's
///    `num.round()` — the pinned rounding contract in BOTH languages.
void main() {
  setUp(() {
    NetworkRetry.delay = (Duration duration) async {};
  });
  tearDown(() {
    NetworkRetry.delay = Future<void>.delayed;
  });

  /// Shared rows `(subtotalCents, rate, taxCents)` of the T-4 parity table:
  /// every POSITIVE row — byte-identical under OLD / NEW / DART (P1 + P2 of
  /// `tool_fix/b4/green_t4_parity.txt`). These integers are what
  /// `computeTaxCents` returns on the charge path.
  const sharedRows = <(int, double, int)>[
    (7, 0.5, 4),
    (7, 0.05, 0),
    (7, 0.025, 0),
    (7, 0.0625, 0),
    (50, 0.5, 25),
    (50, 0.05, 3),
    (50, 0.025, 1),
    (50, 0.0625, 3),
    (1, 0.5, 1),
    (1, 0.05, 0),
    (1, 0.025, 0),
    (1, 0.0625, 0),
    (999, 0.5, 500),
    (999, 0.05, 50),
    (999, 0.025, 25),
    (999, 0.0625, 62),
    (999, 0.0725, 72),
    (999, 0.0825, 82),
    (1000, 0.05, 50),
    (1000, 0.0725, 73),
    (1000, 0.0825, 83),
    (1000, 0.0625, 63),
    (1000, 0.025, 25),
    (1000, 0.5, 500),
    (333, 0.05, 17),
    (333, 0.5, 167),
    (123456, 0.05, 6173),
    (123456, 0.0725, 8951),
    (123456, 0.0825, 10185),
    (123456, 0.0625, 7716),
    (2000, 0.0725, 145),
    (1250, 0.08, 100),
    (2000, 0.0625, 125),
    (0, 0.05, 0),
  ];

  /// Locates `lib/src/tax/tax_service.dart` by walking up from the test's
  /// working directory (repo root, `packages/core`, or deeper). Fail-closed:
  /// a missing source fails the test — never a silent skip.
  File taxServiceSource() {
    var dir = Directory.current;
    for (var i = 0; i < 10; i++) {
      for (final rel in const <String>[
        'packages/core/lib/src/tax/tax_service.dart',
        'core/lib/src/tax/tax_service.dart',
        'lib/src/tax/tax_service.dart',
      ]) {
        final candidate = File('${dir.path}/$rel');
        if (candidate.existsSync()) return candidate;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    throw StateError(
      'tax_service.dart not found from ${Directory.current.path} '
      '— T-5 structural check cannot run (fail-closed, never skipped)',
    );
  }

  test('T-5 TaxService source never computes an authoritative total', () {
    final source = taxServiceSource().readAsStringSync();
    // Display/preview contract, pinned in source:
    expect(source, contains("httpsCallable('calculateTax')"));
    expect(source, contains('no client-side tax calculation'));
    // ...and no computation surface at all:
    expect(source, isNot(contains('subtotalCents *')));
    expect(source, isNot(contains('* rate')));
    expect(source, isNot(contains('.round(')));
    expect(source, isNot(contains('taxCents =')));
    expect(source, isNot(contains('0.0725'))); // no hardcoded rate table
  });

  test('T-5 request carries inputs only — never a precomputed tax', () async {
    final functions = MockFirebaseFunctions();
    final callable = MockHttpsCallable();
    final result = MockCallableResult();
    when(() => functions.httpsCallable('calculateTax')).thenReturn(callable);
    when(
      () => callable.call(captureAny<dynamic>()),
    ).thenAnswer((_) async => result);
    when(() => result.data).thenReturn(<String, dynamic>{
      'taxCents': 145,
      'rate': 0.0725,
      'stateCode': 'CA',
    });

    final tax = await TaxService(
      functions: functions,
      logger: RecordingLogger(),
    ).calculate(stateCode: 'CA', subtotalCents: 2000, clientId: 'wl-test');

    final payload =
        verify(() => callable.call(captureAny<dynamic>())).captured.single
            as Map<dynamic, dynamic>;
    expect(
      payload.keys.toSet(),
      <Object>{'stateCode', 'subtotalCents', 'clientId'},
      reason: 'the client sends inputs only — tax is NEVER computed or sent',
    );
    expect(payload['subtotalCents'], 2000);
    expect(payload['clientId'], 'wl-test');
    // Parsed value is the server's authority — passed through unchanged.
    expect(tax.taxCents, 145);
  });

  test(
    'T-5 parsed value equals the charge-path pin on every shared row',
    () async {
      for (final (subtotal, rate, pin) in sharedRows) {
        final functions = MockFirebaseFunctions();
        final callable = MockHttpsCallable();
        final result = MockCallableResult();
        when(
          () => functions.httpsCallable('calculateTax'),
        ).thenReturn(callable);
        when(
          () => callable.call(captureAny<dynamic>()),
        ).thenAnswer((_) async => result);
        when(() => result.data).thenReturn(<String, dynamic>{
          'taxCents': pin,
          'rate': rate,
          'stateCode': 'CA',
        });

        final tax =
            await TaxService(
              functions: functions,
              logger: RecordingLogger(),
            ).calculate(
              stateCode: 'CA',
              subtotalCents: subtotal,
              clientId: 'wl-test',
            );

        final row = 'row subtotal=$subtotal rate=$rate';
        // Parsed value == the charge path's committed integer-cent pin.
        expect(tax.taxCents, pin, reason: row);
        expect(tax.rate, rate, reason: row);
        // Display authority's rounding rule == the pin (Dart num.round()).
        expect((subtotal * rate).round(), pin, reason: row);
      }
    },
  );
}
