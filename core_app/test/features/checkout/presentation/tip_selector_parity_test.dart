// UI-13 (p21) — L28 charge-parity proof for the tip chain (Phase A).
//
// The pre-adoption `TipSelectorWidget` computed tips with ONE expression:
//   (subtotalCents * pct) ~/ 100
// and built option labels with ONE composition:
//   pct == 0 ? loc.tipNoTip : loc.tipOptionLabel('$pct', moneyCents(...))
//
// Phase A (A2) DELETED that file in favour of the frozen library
// `TipSelector` composed directly in `checkout_screen.dart`. This test pins
// both moved authorities:
//   1. `tipCentsForPercent` — byte-identical integer math (the 199999 case
//      is the float-rounding trap: 29999, never 30000 — Law 3);
//   2. `tipOptionLabelFor` — byte-identical option labels (ARB keys only,
//      no inlined literals in production code — p18 owns the ARB files).
// The END-TO-END charged value is proven by the flow suite: "tip chip
// selection is forwarded into the server-side total calculation" asserts
// capturedTipCents == 500 (= 10% of the 5000-cent subtotal) at the
// `calculateFinalTotal` charge boundary.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/checkout/presentation/checkout_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

void main() {
  group('L28: tip cents parity (byte-identical integer math)', () {
    const cases = <(int, int, int)>[
      (5000, 0, 0),
      (5000, 10, 500),
      (2000, 15, 300),
      (2000, 20, 400),
      (1999, 10, 199),
      (1999, 15, 299),
      (1999, 20, 399),
      (199999, 15, 29999), // float rounding would give 30000
      (199999, 25, 49999), // truncation: 49999.75 -> 49999
    ];
    for (final (subtotal, percent, expected) in cases) {
      test('$percent% of $subtotal cents = $expected', () {
        expect(tipCentsForPercent(subtotal, percent), expected);
      });
    }
  });

  group('L28: tip option labels (ARB keys, byte-identical composition)', () {
    testWidgets('labels match the pre-adoption composition exactly', (
      tester,
    ) async {
      late AppLocalizations loc;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              loc = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // The zero option renders the localized "no tip" string verbatim.
      expect(tipOptionLabelFor(loc, 2000, 0, 'USD'), loc.tipNoTip);
      // Non-zero options: pct + preformatted amount, exactly as before
      // (the `tipOptionLabel` message owns the composition — no literals).
      expect(tipOptionLabelFor(loc, 2000, 15, 'USD'), '15% (\$3.00)');
      expect(tipOptionLabelFor(loc, 1999, 10, 'USD'), '10% (\$1.99)');
      expect(tipOptionLabelFor(loc, 1999, 15, 'USD'), '15% (\$2.99)');
      expect(tipOptionLabelFor(loc, 1999, 20, 'USD'), '20% (\$3.99)');
    });
  });
}
