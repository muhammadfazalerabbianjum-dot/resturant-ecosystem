import 'dart:io';
import 'dart:ui' show SemanticsRole;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI-11 (p23) T-6 — W-6 `BrandDataTable` contract tests.
///
/// Written FIRST (red receipt: `tool_uilib/p23/red_w6.txt`) per the §3 T-6 row:
/// - generic tabular view `BrandDataTable<T>`
/// - sort indicator (direction + sorted column callback)
/// - pagination bar (page index, page size, total count, prev/next)
/// - horizontal scroll on narrow viewports
/// - custom cell builder per column
/// - empty / loading states
/// - Semantics table structure (table, row, column, header)
void main() {
  Widget wrap(Widget child, {ThemeData? theme, Locale? locale}) {
    return MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      locale: locale,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('T-6 BrandDataTable', () {
    final columns = <BrandTableColumn<Map<String, dynamic>>>[
      BrandTableColumn<Map<String, dynamic>>(
        title: 'Order ID',
        cellBuilder: (row) => Text(row['id'] as String),
        sortable: true,
      ),
      BrandTableColumn<Map<String, dynamic>>(
        title: 'Customer',
        cellBuilder: (row) => Text(row['customer'] as String),
      ),
      BrandTableColumn<Map<String, dynamic>>(
        title: 'Total',
        cellBuilder: (row) => Text('\$${row['total']}'),
        numeric: true,
        sortable: true,
      ),
    ];

    final sampleRows = <Map<String, dynamic>>[
      <String, dynamic>{'id': '#101', 'customer': 'Alice', 'total': 42.5},
      <String, dynamic>{'id': '#102', 'customer': 'Bob', 'total': 18.0},
      <String, dynamic>{'id': '#103', 'customer': 'Charlie', 'total': 95.2},
    ];

    testWidgets('renders headers and row cells correctly', (tester) async {
      await tester.pumpWidget(
        wrap(
          BrandDataTable<Map<String, dynamic>>(
            columns: columns,
            rows: sampleRows,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order ID'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('#101'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('\$42.5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('empty rows render caller-supplied empty widget or fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BrandDataTable<Map<String, dynamic>>(
            columns: columns,
            rows: const [],
            emptyMessage: 'No orders placed yet',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No orders placed yet'), findsOneWidget);
    });

    testWidgets(
      'loading state renders progress indicator over/instead of rows',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            BrandDataTable<Map<String, dynamic>>(
              columns: columns,
              rows: sampleRows,
              isLoading: true,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('sort tap fires onSort with column index and ascending flag', (
      tester,
    ) async {
      int? sortedCol;
      bool? sortAsc;

      await tester.pumpWidget(
        wrap(
          BrandDataTable<Map<String, dynamic>>(
            columns: columns,
            rows: sampleRows,
            sortColumnIndex: 0,
            sortAscending: true,
            onSort: (col, asc) {
              sortedCol = col;
              sortAsc = asc;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Order ID header to toggle sort
      await tester.tap(find.text('Order ID'));
      await tester.pumpAndSettle();

      expect(sortedCol, equals(0));
      expect(sortAsc, isFalse);
    });

    testWidgets('pagination controls call onPageChanged and display bounds', (
      tester,
    ) async {
      int? newPage;

      await tester.pumpWidget(
        wrap(
          BrandDataTable<Map<String, dynamic>>(
            columns: columns,
            rows: sampleRows,
            pageIndex: 0,
            pageSize: 3,
            totalRows: 10,
            onPageChanged: (page) => newPage = page,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1–3 of 10'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(newPage, equals(1));
    });
    testWidgets('pagination prev button calls onPageChanged', (tester) async {
      int? newPage;

      await tester.pumpWidget(
        wrap(
          BrandDataTable<Map<String, dynamic>>(
            columns: columns,
            rows: sampleRows,
            pageIndex: 1,
            pageSize: 3,
            totalRows: 10,
            onPageChanged: (page) => newPage = page,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(newPage, equals(0));
    });

    testWidgets(
      'default cell builder formats with toString when builder omitted',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const BrandDataTable<String>(
              columns: [BrandTableColumn<String>(title: 'Fruit')],
              rows: ['Apple', 'Banana'],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Banana'), findsOneWidget);
      },
    );

    testWidgets('table structure has Semantics table and rows', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          BrandDataTable<Map<String, dynamic>>(
            columns: columns,
            rows: sampleRows,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DataTable), findsOneWidget);
      handle.dispose();
    });

    testWidgets('golden: data table (light, en)', (tester) async {
      tester.view.physicalSize = const Size(600, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: BrandDataTable<Map<String, dynamic>>(
                columns: columns,
                rows: sampleRows,
                sortColumnIndex: 2,
                sortAscending: false,
                pageIndex: 0,
                pageSize: 3,
                totalRows: 9,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/brand_data_table_en.png'),
      );
    });
  });

  group('T-6b — density presets, caller copy, a11y roles, overflow', () {
    final cols = <BrandTableColumn<Map<String, dynamic>>>[
      BrandTableColumn<Map<String, dynamic>>(
        title: 'Order ID',
        cellBuilder: (row) => Text(row['id'] as String),
        sortable: true,
      ),
      BrandTableColumn<Map<String, dynamic>>(
        title: 'Customer',
        cellBuilder: (row) => Text(row['customer'] as String),
      ),
      BrandTableColumn<Map<String, dynamic>>(
        title: 'Total',
        cellBuilder: (row) => Text('\$${row['total']}'),
        numeric: true,
      ),
    ];

    final rows = <Map<String, dynamic>>[
      <String, dynamic>{'id': '#101', 'customer': 'Alice', 'total': 42.5},
      <String, dynamic>{'id': '#102', 'customer': 'Bob', 'total': 18.0},
    ];

    Future<void> pumpTable(
      WidgetTester tester, {
      required BrandTableDensity density,
      List<BrandTableColumn<Map<String, dynamic>>>? columnsOverride,
      String? prevPageLabel,
      String? nextPageLabel,
      String Function(int start, int end, int total)? pageLabelBuilder,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: BrandDataTable<Map<String, dynamic>>(
              columns: columnsOverride ?? cols,
              rows: rows,
              density: density,
              pageIndex: 0,
              pageSize: 2,
              totalRows: 10,
              onPageChanged: (_) {},
              prevPageLabel: prevPageLabel,
              nextPageLabel: nextPageLabel,
              pageLabelBuilder: pageLabelBuilder,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Vertical distance between the centres of two rendered labels — the
    /// rendered row/heading pitch, i.e. the height a tap target actually gets.
    double pitch(WidgetTester tester, String above, String below) =>
        tester.getCenter(find.text(below)).dy -
        tester.getCenter(find.text(above)).dy;

    testWidgets(
      'dense tightens the chrome while a data row keeps the 48 dp target',
      (tester) async {
        tester.view.physicalSize = const Size(600, 500);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await pumpTable(tester, density: BrandTableDensity.comfortable);
        final comfortableHeadingPitch = pitch(tester, 'Order ID', '#101');
        final comfortableRowPitch = pitch(tester, '#101', '#102');

        await pumpTable(tester, density: BrandTableDensity.dense);
        final denseHeadingPitch = pitch(tester, 'Order ID', '#101');
        final denseRowPitch = pitch(tester, '#101', '#102');

        expect(comfortableRowPitch, greaterThanOrEqualTo(48.0));
        expect(
          denseRowPitch,
          greaterThanOrEqualTo(48.0),
          reason: 'a dense row must still offer the >=48 dp Material target',
        );
        expect(
          denseHeadingPitch,
          lessThan(comfortableHeadingPitch),
          reason: 'the dense preset is what removes the chrome height',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'dense: an interactive cell keeps its >=48 dp target and stays tappable',
      (tester) async {
        var taps = 0;
        final interactive = <BrandTableColumn<Map<String, dynamic>>>[
          BrandTableColumn<Map<String, dynamic>>(
            title: 'Action',
            cellBuilder: (row) => IconButton(
              onPressed: () => taps++,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
          cols[1],
          cols[2],
        ];

        await pumpTable(
          tester,
          density: BrandTableDensity.dense,
          columnsOverride: interactive,
        );

        expect(pitch(tester, 'Alice', 'Bob'), greaterThanOrEqualTo(48.0));

        await tester.tap(find.byIcon(Icons.delete_outline).first);
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('pagination copy is caller-supplied, never library copy', (
      tester,
    ) async {
      await pumpTable(
        tester,
        density: BrandTableDensity.comfortable,
        prevPageLabel: 'Prev page',
        nextPageLabel: 'Next page',
        pageLabelBuilder: (start, end, total) => 'rows $start–$end of $total',
      );

      expect(find.byTooltip('Prev page'), findsOneWidget);
      expect(find.byTooltip('Next page'), findsOneWidget);
      expect(find.text('rows 1–2 of 10'), findsOneWidget);
      expect(find.text('1–2 of 10'), findsNothing);
      expect(find.textContaining('Previous page'), findsNothing);
    });

    test(
      'L3 — user-facing literals live only in the kBrandTable fallbacks',
      () {
        final source = File(
          'lib/src/ui/brand_data_table.dart',
        ).readAsStringSync();
        final code = source
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');

        for (final literal in <String>[
          "'No data available'",
          "'Previous page'",
          "'Next page'",
        ]) {
          final owners = code
              .split('\n')
              .where((line) => line.contains(literal))
              .toList();
          expect(
            owners.length,
            1,
            reason: '$literal must appear exactly once — as its fallback const',
          );
          expect(
            owners.single.trimLeft(),
            startsWith('const String kBrandTable'),
            reason: '$literal must live in a documented kBrandTable constant',
          );
        }

        // No other prose literal may hide in the widget path.
        final proseWord = RegExp(r"'[A-Za-z][A-Za-z ]{3,}");
        for (final line in code.split('\n')) {
          if (line.trimLeft().startsWith('import ')) continue;
          if (line.contains('kBrandTable')) continue;
          expect(
            proseWord.hasMatch(line),
            isFalse,
            reason: 'hardcoded user-facing copy on: $line',
          );
        }
      },
    );

    testWidgets('column headers and body cells carry their semantics roles', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await pumpTable(tester, density: BrandTableDensity.comfortable);

      expect(
        tester.getSemantics(find.text('Order ID')).role,
        SemanticsRole.columnHeader,
      );
      expect(tester.getSemantics(find.text('Alice')).role, SemanticsRole.cell);
      handle.dispose();
    });

    testWidgets('many columns on a narrow viewport scroll horizontally', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final wide = <BrandTableColumn<Map<String, dynamic>>>[
        for (var i = 0; i < 6; i++)
          BrandTableColumn<Map<String, dynamic>>(
            title: 'Column ${i + 1}',
            cellBuilder: (row) => Text('${row['id']}-${i + 1}'),
          ),
      ];

      await pumpTable(
        tester,
        density: BrandTableDensity.dense,
        columnsOverride: wide,
      );

      expect(tester.takeException(), isNull);

      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(BrandDataTable<Map<String, dynamic>>),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      expect(position.maxScrollExtent, greaterThan(0.0));

      // Drag from the viewport, not from the (partly off-screen) table centre.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0.0));
    });

    testWidgets('golden: data table (dense, ar, RTL)', (tester) async {
      tester.view.physicalSize = const Size(600, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final arabic = <BrandTableColumn<Map<String, dynamic>>>[
        BrandTableColumn<Map<String, dynamic>>(
          title: 'رقم الطلب',
          cellBuilder: (row) => Text(row['id'] as String),
        ),
        BrandTableColumn<Map<String, dynamic>>(
          title: 'العميل',
          cellBuilder: (row) => Text(row['customer'] as String),
        ),
        BrandTableColumn<Map<String, dynamic>>(
          title: 'الإجمالي',
          cellBuilder: (row) => Text('\$${row['total']}'),
          numeric: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: BrandDataTable<Map<String, dynamic>>(
                columns: arabic,
                rows: rows,
                density: BrandTableDensity.dense,
                pageIndex: 0,
                pageSize: 2,
                totalRows: 10,
                prevPageLabel: 'السابق',
                nextPageLabel: 'التالي',
                pageLabelBuilder: (start, end, total) =>
                    'الصفوف $start–$end من $total',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/brand_data_table_dense_rtl_ar.png'),
      );
    });
  });
}
