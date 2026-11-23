import 'dart:io';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI-11 (p23) T-5 — W-5 `BrandedSplash` + `OnboardingShell` contract tests.
///
/// Written FIRST (red receipt: `tool_uilib/p23/red_w5.txt`) per the §3 T-5
/// row: splash = token-driven logo/name/loader slots, zero business logic,
/// reduced-motion aware; onboarding = N-page pager with skip/next/done,
/// tappable dots (advance/back), caller-supplied page content and
/// `Semantics` page announcements.
void main() {
  Widget wrap(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('T-5 BrandedSplash', () {
    testWidgets('renders caller-supplied name/message with the token logo '
        'slot', (tester) async {
      await tester.pumpWidget(
        wrap(const BrandedSplash(appName: 'Nile Bistro', message: 'Loading…')),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Nile Bistro'), findsOneWidget);
      expect(find.text('Loading…'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget, reason: 'default logo slot');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('caller logo slot replaces the default; showLoader: false '
        'removes the loader', (tester) async {
      await tester.pumpWidget(
        wrap(
          const BrandedSplash(
            appName: 'Custom Mark',
            logo: Icon(Icons.local_pizza),
            showLoader: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.local_pizza), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_menu), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Custom Mark'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('non-const constructor coverage', (tester) async {
      // Every other BrandedSplash in this file is canonicalised at compile
      // time, so its constructor body is never executed at runtime and its
      // lines stay uncounted. A runtime-computed argument is the only way to
      // force a non-const construction: with a literal instead, analyze
      // reports prefer_const_constructors (receipt:
      // tool_uilib/p23/probe_w5_const_lint.txt).
      final name = 'Dynamic Name'.trim();
      await tester.pumpWidget(
        wrap(
          BrandedSplash(
            appName: name,
            message: 'Dynamic Msg',
            logo: const Icon(Icons.star),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Dynamic Name'), findsOneWidget);
    });

    testWidgets('reduced motion: the spinner is replaced by a static glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: BrandedSplash(appName: 'Quiet App'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test(
      'no business logic: the splash owns no callbacks, timers or state',
      () {
        final source = File(
          'lib/src/ui/branded_splash.dart',
        ).readAsStringSync();
        final code = source
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        for (final token in <String>[
          'StatefulWidget',
          'setState',
          'Timer',
          'Future.delayed',
          'onPressed',
          'Navigator',
        ]) {
          expect(
            code.contains(token),
            isFalse,
            reason: 'branded_splash.dart must not own logic ($token found)',
          );
        }
      },
    );
  });

  group('T-5 OnboardingShell', () {
    List<Widget> pages() => const <Widget>[
      Center(child: Text('First page content')),
      Center(child: Text('Second page content')),
      Center(child: Text('Third page content')),
    ];

    Widget shell({
      VoidCallback? onDone,
      String Function(int page, int total)? pageLabelBuilder,
    }) {
      return OnboardingShell(
        pages: pages(),
        skipLabel: 'Skip',
        nextLabel: 'Next',
        doneLabel: 'Done',
        onDone: onDone,
        pageLabelBuilder: pageLabelBuilder,
      );
    }

    testWidgets('next advances the pager and moves the dots indicator', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(shell()));
      expect(find.text('First page content'), findsOneWidget);
      expect(
        find.byKey(const Key('brand-onboarding-dot-0')),
        findsOneWidget,
        reason: 'one dot per page',
      );
      expect(find.byKey(const Key('brand-onboarding-dot-2')), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Second page content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('first page shows skip+next (no done); skip jumps to the '
        'last page which shows done only', (tester) async {
      await tester.pumpWidget(wrap(shell()));
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Done'), findsNothing);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Third page content'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Next'), findsNothing, reason: 'last page has no next');
      expect(find.text('Skip'), findsNothing, reason: 'nothing left to skip');
    });
    testWidgets('custom onSkip callback is invoked when provided', (
      tester,
    ) async {
      var skipped = false;
      await tester.pumpWidget(
        wrap(
          OnboardingShell(
            pages: pages(),
            skipLabel: 'Skip',
            nextLabel: 'Next',
            doneLabel: 'Done',
            onSkip: () => skipped = true,
          ),
        ),
      );
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(skipped, isTrue);
    });

    testWidgets('dots are tappable: they page forward AND back', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(shell()));

      await tester.tap(find.byKey(const Key('brand-onboarding-dot-2')));
      await tester.pumpAndSettle();
      expect(find.text('Third page content'), findsOneWidget);

      await tester.tap(find.byKey(const Key('brand-onboarding-dot-0')));
      await tester.pumpAndSettle();
      expect(find.text('First page content'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget, reason: 'back on page one');
    });

    testWidgets('done fires onDone', (tester) async {
      var done = false;
      await tester.pumpWidget(wrap(shell(onDone: () => done = true)));

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(done, isTrue);
    });

    testWidgets('Semantics page announcements update as pages change', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(shell(pageLabelBuilder: (page, total) => 'Page $page of $total')),
      );

      final first = tester.getSemantics(find.bySemanticsLabel('Page 1 of 3'));
      expect(
        first.flagsCollection.isLiveRegion,
        isTrue,
        reason: 'page changes must be announced',
      );

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('reduced motion advances without the page animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: shell(),
          ),
        ),
      );

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Second page content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('golden: splash (light, ar)', (tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: BrandedSplash(
                appName: 'مطعم النخبة',
                message: 'جارٍ تحميل القائمة…',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/branded_splash_ar.png'),
      );
    });

    testWidgets('golden: onboarding first page (light, en)', (tester) async {
      tester.view.physicalSize = const Size(400, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: OnboardingShell(
              pages: <Widget>[
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.restaurant_menu, size: 72),
                      SizedBox(height: 16),
                      Text(
                        'Order in seconds',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Track your table from kitchen to table.'),
                    ],
                  ),
                ),
                Center(child: Text('Second page content')),
                Center(child: Text('Third page content')),
              ],
              skipLabel: 'Skip',
              nextLabel: 'Next',
              doneLabel: 'Get started',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/onboarding_en.png'),
      );
    });
  });

  group('T-5b — OnboardingShell copy contract (L3)', () {
    Widget wrapShell({
      String Function(int page)? pageDotLabelBuilder,
      String Function(int page, int total)? pageLabelBuilder,
    }) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: OnboardingShell(
            pages: const <Widget>[
              Center(child: Text('First page')),
              Center(child: Text('Second page')),
            ],
            skipLabel: 'Skip',
            nextLabel: 'Next',
            doneLabel: 'Done',
            pageDotLabelBuilder: pageDotLabelBuilder,
            pageLabelBuilder: pageLabelBuilder,
          ),
        ),
      );
    }

    testWidgets('a page dot announces the caller-supplied label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapShell(pageDotLabelBuilder: (page) => 'صفحة $page'),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .getSemantics(find.byKey(const Key('brand-onboarding-dot-1')))
            .label,
        'صفحة 2',
      );
      handle.dispose();
    });

    testWidgets('without a builder the dot uses the kOnboarding fallback', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrapShell());
      await tester.pumpAndSettle();

      expect(
        tester
            .getSemantics(find.byKey(const Key('brand-onboarding-dot-0')))
            .label,
        kOnboardingPageDotLabel(1),
      );
      handle.dispose();
    });

    testWidgets('the page announcement is caller-supplied or the fallback', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrapShell(pageLabelBuilder: (index, total) => 'صفحة $index من $total'),
      );
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.byType(PageView)).label, 'صفحة 1 من 2');

      await tester.pumpWidget(wrapShell());
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(PageView)).label,
        kOnboardingPageAnnouncement(1, 2),
      );
      handle.dispose();
    });

    test(
      'L3 — user-facing literals live only in the kOnboarding fallbacks',
      () {
        final source = File(
          'lib/src/ui/onboarding_shell.dart',
        ).readAsStringSync();
        final code = source
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');

        // Quoted prose = a single-quoted literal that starts with a letter and
        // contains a space; keys, imports and identifiers never match.
        final matches = RegExp(
          r"'([A-Za-z][^'\n]* [^'\n]*)'",
        ).allMatches(code).toList();

        expect(
          matches.map((m) => m.group(1)!).toSet(),
          <String>{r'Page $page of $total', r'Go to page $page'},
          reason:
              'user-facing copy must live only in the kOnboarding '
              'fallbacks',
        );

        for (final m in matches) {
          final decl = code.lastIndexOf('String kOnboarding', m.start);
          expect(
            decl,
            isNot(-1),
            reason:
                'prose literal outside any kOnboarding fallback: '
                '${m.group(0)}',
          );
          final semicolon = code.indexOf(';', decl);
          expect(
            semicolon,
            allOf(isNot(-1), greaterThanOrEqualTo(m.end)),
            reason:
                'prose literal beyond its kOnboarding fallback body: '
                '${m.group(0)}',
          );
        }
      },
    );
  });
}
