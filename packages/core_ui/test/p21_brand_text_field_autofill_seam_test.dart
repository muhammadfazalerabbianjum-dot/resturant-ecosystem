// UI-13 (p21 D1) — receipted core_ui seam: BrandTextField forwards
// platform autofill hints.
//
// Why a seam (§2 additive-fallout rule): the auth screens' frozen UX-2
// contract (`core_app/test/features/auth/presentation/auth_autofill_test.dart`,
// untouched, must stay green) asserts `field.autofillHints` on the inner
// TextField of the REAL login/signup credential fields. Adopting
// BrandTextField without forwarding the hints would drop the platform
// password-manager contract (behaviour regression, L14). The seam is pure
// WIRING — the widget still composes no behaviour of its own.
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P21 D1 seam — BrandTextField autofillHints forwarding', () {
    testWidgets('forwards autofillHints to the inner TextField', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrandTextField(
              labelText: 'Email',
              autofillHints: [AutofillHints.email],
            ),
          ),
        ),
      );

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(BrandTextField),
          matching: find.byType(TextField),
        ),
      );
      expect(field.autofillHints, contains(AutofillHints.email));
    });

    testWidgets('defaults to no autofill hints (opt-in seam)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BrandTextField(labelText: 'Name')),
        ),
      );

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(BrandTextField),
          matching: find.byType(TextField),
        ),
      );
      expect(field.autofillHints, isNull);
    });
  });
}
