import 'dart:io';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

/// UI-11 (p23) T-4 — W-4 `BrandSheet` / `BrandDialog` contract tests.
///
/// Written FIRST (red receipt: `tool_uilib/p23/red_w4.txt`) per the §3 T-4 row
/// and **L25 (barrier contract)**: configurable barrier dismiss with the
/// money-confirming DEFAULT = non-dismissable, branded header/actions,
/// `SafeArea` + `Semantics(scopesRoute)`, scroll-safe content, and callbacks
/// limited to `onConfirm`/`onCancel`.
void main() {
  late BuildContext host;

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget moneySheet({
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    Widget child = const Text('Order total follows the money authority.'),
  }) {
    return BrandSheet(
      title: 'Confirm payment',
      confirmLabel: 'Pay now',
      cancelLabel: 'Not now',
      onConfirm: onConfirm,
      onCancel: onCancel,
      child: child,
    );
  }

  group('T-4 BrandSheet — L25 barrier contract', () {
    testWidgets('money-confirming sheet is NOT dismissable by default: a '
        'barrier tap keeps it open, cancel closes it', (tester) async {
      await pumpHost(tester);
      var cancelled = false;
      BrandSheet.show(
        host,
        builder: (_) => moneySheet(onCancel: () => cancelled = true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BrandSheet), findsOneWidget);

      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(
        find.byType(BrandSheet),
        findsOneWidget,
        reason: 'L25: the money-confirming default is non-dismissable',
      );

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
      expect(find.byType(BrandSheet), findsNothing);
    });

    testWidgets('barrierDismissible: true opts in — a barrier tap closes it', (
      tester,
    ) async {
      await pumpHost(tester);
      BrandSheet.show(
        host,
        barrierDismissible: true,
        builder: (_) => moneySheet(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BrandSheet), findsOneWidget);

      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(find.byType(BrandSheet), findsNothing);
    });

    testWidgets('onConfirm fires and closes the sheet; both callbacks are '
        'wired to the branded actions', (tester) async {
      await pumpHost(tester);
      var confirmed = false;
      BrandSheet.show(
        host,
        builder: (_) => moneySheet(onConfirm: () => confirmed = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pay now'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
      expect(find.byType(BrandSheet), findsNothing);
    });

    testWidgets('SafeArea + Semantics(scopesRoute) composition (L25)', (
      tester,
    ) async {
      await pumpHost(tester);
      final handle = tester.ensureSemantics();
      BrandSheet.show(host, builder: (_) => moneySheet());
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(BrandSheet),
          matching: find.byType(SafeArea),
        ),
        findsOneWidget,
      );
      final node = tester.getSemantics(find.byType(BrandSheet));
      expect(
        node.flagsCollection.scopesRoute,
        isTrue,
        reason: 'the sheet scopes its route for assistive tech',
      );
      handle.dispose();
    });

    testWidgets('scroll-safe: a tall body scrolls inside the sheet while the '
        'actions stay pinned (no overflow)', (tester) async {
      await pumpHost(tester);
      BrandSheet.show(
        host,
        builder: (_) => moneySheet(
          child: const SizedBox(height: 1600, child: Text('deep content')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(BrandSheet),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Pay now'), findsOneWidget);
      expect(find.text('deep content'), findsOneWidget);
    });
  });

  group('T-4 BrandDialog — L25', () {
    testWidgets('dialog is NOT dismissable by default: barrier tap keeps it '
        'open, cancel closes it', (tester) async {
      await pumpHost(tester);
      var cancelled = false;
      BrandDialog.show(
        host,
        builder: (_) => BrandDialog(
          title: 'Discard changes?',
          cancelLabel: 'Keep editing',
          confirmLabel: 'Discard',
          onCancel: () => cancelled = true,
          child: const Text('Your edits will be lost.'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BrandDialog), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(BrandDialog), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
      expect(find.byType(BrandDialog), findsNothing);
    });

    testWidgets('barrierDismissible: true opts in for the dialog too', (
      tester,
    ) async {
      await pumpHost(tester);
      BrandDialog.show(
        host,
        barrierDismissible: true,
        builder: (_) => BrandDialog(
          title: 'Heads up',
          confirmLabel: 'OK',
          onConfirm: () {},
          child: const Text('Details.'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BrandDialog), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(BrandDialog), findsNothing);
    });

    testWidgets('SafeArea + Semantics(scopesRoute) composition (L25)', (
      tester,
    ) async {
      await pumpHost(tester);
      final handle = tester.ensureSemantics();
      BrandDialog.show(
        host,
        builder: (_) =>
            const BrandDialog(title: 'Note', child: Text('Body copy.')),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(BrandDialog),
          matching: find.byType(SafeArea),
        ),
        findsOneWidget,
      );
      final node = tester.getSemantics(find.byType(BrandDialog));
      expect(node.flagsCollection.scopesRoute, isTrue);
      handle.dispose();
    });

    testWidgets('focus containment: focus lands inside the dialog and Tab '
        'stays inside it', (tester) async {
      await pumpHost(tester);
      var confirmed = false;
      BrandDialog.show(
        host,
        builder: (_) => BrandDialog(
          title: 'Add a note',
          cancelLabel: 'Cancel',
          confirmLabel: 'Save',
          onCancel: () {},
          onConfirm: () => confirmed = true,
          child: const TextField(),
        ),
      );
      await tester.pumpAndSettle();

      final dialogElement = tester.element(find.byType(BrandDialog));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      bool focusWithinDialog() {
        final context = FocusManager.instance.primaryFocus!.context;
        expect(context, isNotNull);
        final element = context! as Element;
        if (element == dialogElement) return true;
        var found = false;
        element.visitAncestorElements((ancestor) {
          if (ancestor == dialogElement) {
            found = true;
            return false;
          }
          return true;
        });
        return found;
      }

      expect(
        focusWithinDialog(),
        isTrue,
        reason: 'tapped focus lives inside the dialog route',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        focusWithinDialog(),
        isTrue,
        reason: 'Tab must traverse within the modal, never escape it',
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue, reason: 'onConfirm fires');
      expect(find.byType(BrandDialog), findsNothing);
    });

    testWidgets('scroll-safe dialog body with pinned actions (no overflow)', (
      tester,
    ) async {
      await pumpHost(tester);
      BrandDialog.show(
        host,
        builder: (_) => BrandDialog(
          title: 'Terms',
          confirmLabel: 'Agree',
          onConfirm: () {},
          child: const SizedBox(height: 1600, child: Text('long legal copy')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(BrandDialog),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Agree'), findsOneWidget);
    });

    test('no business logic: both surfaces are stateless, schedule nothing '
        'and expose only the L25 contract', () {
      for (final file in const [
        'lib/src/ui/brand_sheet.dart',
        'lib/src/ui/brand_dialog.dart',
      ]) {
        final source = File(file).readAsStringSync();
        final code = source
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        for (final token in <String>[
          'StatefulWidget',
          'setState',
          'Timer',
          'Ticker',
          'Future.delayed',
          'onChanged',
          'onSubmitted',
          'validator',
        ]) {
          expect(
            code.contains(token),
            isFalse,
            reason: '$file must not own logic/state ($token found)',
          );
        }
      }
    });
  });

  group('T-4 goldens', () {
    testWidgets('confirm sheet (light, en)', (tester) async {
      tester.view.physicalSize = const Size(400, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 360,
                  child: BrandSheet(
                    title: 'Confirm payment',
                    cancelLabel: 'Not now',
                    confirmLabel: 'Pay now',
                    child: Text(
                      'Your card will be charged when the order is placed.',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/brand_sheet_en.png'),
      );
    });

    testWidgets('confirm dialog (dark, ar, RTL)', (tester) async {
      tester.view.physicalSize = const Size(400, 420);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: BrandDialog(
                    title: 'تأكيد الدفع',
                    cancelLabel: 'ليس الآن',
                    confirmLabel: 'ادفع الآن',
                    child: Text('سيتم خصم المبلغ عند تأكيد الطلب.'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/brand_dialog_dark_ar.png'),
      );
    });
  });
}
