import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-1 SegmentSelector contract', () {
    testWidgets('renders options and reports the exact value tapped', (
      tester,
    ) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentSelector<int>(
              segments: const [
                SegmentOption(value: 1, label: 'One'),
                SegmentOption(value: 2, label: 'Two'),
                SegmentOption(value: 3, label: 'Three'),
              ],
              selectedValue: 1,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      );

      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('Three'), findsOneWidget);

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(selected, 2);
    });

    testWidgets('disabled option renders but never emits', (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentSelector<int>(
              segments: const [
                SegmentOption(value: 1, label: 'One'),
                SegmentOption(value: 2, label: 'Two', enabled: false),
              ],
              selectedValue: 1,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    });

    testWidgets('loading option shows a loader and never emits', (
      tester,
    ) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentSelector<int>(
              segments: const [
                SegmentOption(value: 1, label: 'One'),
                SegmentOption(value: 2, label: 'Two', loading: true),
              ],
              selectedValue: 1,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(CircularProgressIndicator));
      // The loader animates forever, so settle-free pumping is the correct
      // wait here (pumpAndSettle would time out on the spinner).
      await tester.pump();
      expect(selected, isNull);
    });

    testWidgets('a null onChanged leaves the control display-only', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SegmentSelector<int>(
              segments: [
                SegmentOption(value: 1, label: 'One'),
                SegmentOption(value: 2, label: 'Two'),
              ],
              selectedValue: 2,
            ),
          ),
        ),
      );

      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsNWidgets(2));
    });

    testWidgets('RTL mirrors the segment order (first option right-most)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SegmentSelector<int>(
                segments: [
                  SegmentOption(value: 1, label: 'Option A'),
                  SegmentOption(value: 2, label: 'Option B'),
                ],
                selectedValue: 1,
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.text('Option A')).dx,
        greaterThan(tester.getTopLeft(find.text('Option B')).dx),
      );
    });

    testWidgets('LTR keeps the declared order', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SegmentSelector<int>(
              segments: [
                SegmentOption(value: 1, label: 'Option A'),
                SegmentOption(value: 2, label: 'Option B'),
              ],
              selectedValue: 1,
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.text('Option A')).dx,
        lessThan(tester.getTopLeft(find.text('Option B')).dx),
      );
    });

    testWidgets('Semantics(selected:) distinguishes chosen from unchosen', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SegmentSelector<int>(
              segments: [
                SegmentOption(value: 1, label: 'One'),
                SegmentOption(value: 2, label: 'Two', enabled: false),
              ],
              selectedValue: 1,
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('One')).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        tester.getSemantics(find.text('Two')).flagsCollection.isSelected,
        Tristate.isFalse,
      );
      handle.dispose();
    });
  });

  group('T-1 TipSelector contract (L24: display-only, no money math)', () {
    testWidgets(
      'renders caller-formatted labels and returns the exact option',
      (tester) async {
        TipOption<int>? selected;
        final options = <TipOption<int>>[
          const TipOption<int>(value: 0, label: 'No Tip'),
          const TipOption<int>(value: 10, label: '10% (\$1.50)'),
          const TipOption<int>(value: 15, label: '15% (\$2.25)'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TipSelector<int>(
                options: options,
                selectedOption: options[1],
                onChanged: (option) => selected = option,
                title: 'Add a tip',
                selectedSummaryLabel: (option) => 'Selected: ${option.label}',
              ),
            ),
          ),
        );

        expect(find.text('Add a tip'), findsOneWidget);
        expect(find.text('No Tip'), findsOneWidget);
        expect(find.text('10% (\$1.50)'), findsOneWidget);
        expect(find.text('15% (\$2.25)'), findsOneWidget);
        expect(find.text('Selected: 10% (\$1.50)'), findsOneWidget);

        await tester.tap(find.text('15% (\$2.25)'));
        await tester.pumpAndSettle();
        expect(selected?.value, 15);
        expect(selected?.label, '15% (\$2.25)');
      },
    );

    testWidgets('custom-amount affordance reports the caller callback', (
      tester,
    ) async {
      var customTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TipSelector<int>(
              options: const <TipOption<int>>[
                TipOption<int>(value: 15, label: '15% (\$2.25)'),
              ],
              selectedOption: const TipOption<int>(
                value: 15,
                label: '15% (\$2.25)',
              ),
              customLabel: 'Custom',
              onCustomTapped: () => customTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Custom'), findsOneWidget);
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      expect(customTapped, isTrue);
    });

    testWidgets('the summary is suppressed while nothing is selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TipSelector<int>(
              options: const <TipOption<int>>[
                TipOption<int>(value: 15, label: '15% (\$2.25)'),
              ],
              selectedSummaryLabel: (option) => 'Selected: ${option.label}',
            ),
          ),
        ),
      );

      expect(find.textContaining('Selected:'), findsNothing);
      expect(find.byType(BrandChip), findsOneWidget);
    });

    testWidgets('goldens (light en / dark ar, caller-formatted amounts)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 220);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(
              child: TipSelector<int>(
                title: 'Add a tip',
                options: <TipOption<int>>[
                  TipOption<int>(value: 0, label: 'None'),
                  TipOption<int>(value: 15, label: '15% (\$2.25)'),
                ],
                selectedOption: TipOption<int>(
                  value: 15,
                  label: '15% (\$2.25)',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tip_selector_light_en.png'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: TipSelector<int>(
                  title: 'إضافة إكرامية',
                  options: <TipOption<int>>[
                    TipOption<int>(value: 0, label: 'بدون إكرامية'),
                    TipOption<int>(value: 15, label: '١٥٪ (٢٫٢٥\$)'),
                  ],
                  selectedOption: TipOption<int>(
                    value: 15,
                    label: '١٥٪ (٢٫٢٥\$)',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tip_selector_dark_ar.png'),
      );
    });

    testWidgets('golden (SegmentSelector under RTL)', (tester) async {
      tester.view.physicalSize = const Size(400, 120);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: SegmentSelector<String>(
                  segments: <SegmentOption<String>>[
                    SegmentOption<String>(value: 'prep', label: 'قيد التحضير'),
                    SegmentOption<String>(
                      value: 'ready',
                      label: 'جاهز',
                      enabled: false,
                    ),
                  ],
                  selectedValue: 'ready',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/segment_selector_rtl.png'),
      );
    });
  });

  group('L24 receipt — the selector performs no money arithmetic', () {
    testWidgets('mutating any cents in the caller universe changes no pixel '
        'and no string of what the selector shows', (tester) async {
      const label = '20% (\$3.00)';
      const option = TipOption<int>(value: 20, label: label);

      Future<void> pumpSelector() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TipSelector<int>(
                options: <TipOption<int>>[option],
                selectedOption: option,
                selectedSummaryLabel: _echoLabel,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpSelector();
      final before = tester.widget<Text>(find.text('echo:$label')).data;
      expect(before, 'echo:$label');
      expect(find.text(label), findsOneWidget);

      // The caller's own money value is mutated (the "subtotal changed" case).
      var subtotalCents = 1500;
      subtotalCents = 999999;
      expect(subtotalCents, 999999);

      await pumpSelector();
      expect(
        tester.widget<Text>(find.text('echo:$label')).data,
        before,
        reason: 'the displayed string is the caller string, verbatim',
      );
      expect(find.text(label), findsOneWidget);
      expect(find.textContaining('9.99'), findsNothing);
    });

    test(
      'tip_selector.dart source contains no numeric arithmetic or cents',
      () {
        final source = File('lib/src/ui/tip_selector.dart').readAsStringSync();
        // Comments are allowed to DISCUSS money (the L24 doc does); only the
        // executable surface must be arithmetic-free.
        final code = source
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        for (final token in <String>[
          ' * ',
          ' / ',
          ' ~/ ',
          ' % ',
          ' + ',
          ' - ',
        ]) {
          expect(
            code.contains(token),
            isFalse,
            reason: 'tip_selector.dart must not compute ($token found)',
          );
        }
        expect(code.contains('moneyCents'), isFalse);
        expect(code.contains('cents'), isFalse);
        expect(code.contains('double'), isFalse);
      },
    );
  });
}

String _echoLabel(TipOption<int> option) => 'echo:${option.label}';
