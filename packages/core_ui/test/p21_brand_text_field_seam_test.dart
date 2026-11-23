// UI-13 (p21) — `BrandTextField.inputFormatters` seam test (DECISIONS entry).
//
// The seam is ADDITIVE and optional: the checkout promo-code field's
// pre-adoption raw `TextField` carried a `FilteringTextInputFormatter.deny`
// sanitiser (blocks `<`/`>` in a code that later reaches server-side
// rendering). Adoption must NOT drop that control (behaviour unchanged) and
// must NOT keep a raw `TextField` (F3-12 adoption). This test proves the
// passthrough is verbatim: a supplied formatter filters typed characters,
// and an unsupplied field is untouched (null passthrough).
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget field) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: field)),
    ),
  );
}

void main() {
  testWidgets('supplied formatter filters typed characters verbatim', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _wrap(
        BrandTextField(
          controller: controller,
          hintText: 'Promo code',
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[<>]'))],
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'AB<CD>E');
    await tester.pump();

    // `<` and `>` were denied by the caller's formatter; the rest is kept.
    expect(controller.text, 'ABCDE');
    controller.dispose();
  });

  testWidgets('omitted formatter keeps the default (null) passthrough', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _wrap(BrandTextField(controller: controller, hintText: 'Search')),
    );

    await tester.enterText(find.byType(TextFormField), 'plain');
    await tester.pump();

    expect(controller.text, 'plain');
    controller.dispose();
  });

  // UI-13 (p21 H2) — `suffixIcon` seam: the home search field's clear
  // affordance must survive the F3-12 adoption verbatim (the caller composes
  // the widget; this widget only wires it into the decoration).
  testWidgets('supplied suffix widget renders inside the field', (
    tester,
  ) async {
    var cleared = 0;
    await tester.pumpWidget(
      _wrap(
        BrandTextField(
          hintText: 'Search menu',
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear search',
            onPressed: () => cleared++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(cleared, 1, reason: 'the caller-owned suffix stays interactive');
    expect(find.byType(TextFormField), findsOneWidget);
  });

  testWidgets('omitted suffix keeps the default (null) passthrough', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const BrandTextField(hintText: 'Search')));

    expect(find.byIcon(Icons.clear), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
  });
}
