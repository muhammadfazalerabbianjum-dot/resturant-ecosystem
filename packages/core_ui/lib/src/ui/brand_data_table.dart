import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';
import 'empty_state_widget.dart';

/// Fallback copy for the [BrandDataTable] empty state. Rendered ONLY when the
/// caller supplies neither `emptyMessage` nor `emptyWidget`; every in-app call
/// site MUST pass a localized string (`AppLocalizations.of(context)`) — never
/// this English fallback on a localized hot path (the `GlobalErrorWidget`
/// precedent).
const String kBrandTableEmptyMessage = 'No data available';

/// Fallback tooltip + accessibility label for the previous-page control. Same
/// rule as [kBrandTableEmptyMessage]: a call site on a localized hot path MUST
/// pass [BrandDataTable.prevPageLabel].
const String kBrandTablePreviousPageLabel = 'Previous page';

/// Fallback tooltip + accessibility label for the next-page control. Same rule
/// as [kBrandTableEmptyMessage]: a localized call site MUST pass
/// [BrandDataTable.nextPageLabel].
const String kBrandTableNextPageLabel = 'Next page';

/// Fallback page-range label (`start–end of total`) for the pagination bar,
/// used only when [BrandDataTable.pageLabelBuilder] is omitted. A localization
/// layer cannot be consulted from the library, so a localized call site MUST
/// pass `pageLabelBuilder`.
String kBrandTablePageRangeLabel(int start, int end, int total) =>
    '$start–$end of $total';

/// Row-density preset for [BrandDataTable] (UI-11 / W-6, T-6).
enum BrandTableDensity {
  /// Framework defaults: 56 dp heading row, 24 dp outer margin, 56 dp column
  /// spacing and 48 dp rows.
  comfortable,

  /// Compact chrome — 44 dp heading row, 16 dp outer margin, 24 dp column
  /// spacing — with data rows pinned to the Material 48 dp minimum, so an
  /// interactive cell inside a dense row keeps its >=48 dp tap target.
  dense,
}

/// Specification for a column in a [BrandDataTable].
class BrandTableColumn<T> {
  const BrandTableColumn({
    required this.title,
    this.cellBuilder,
    this.numeric = false,
    this.sortable = false,
    this.tooltip,
  });

  /// The header title string.
  final String title;

  /// Builder for rendering the cell widget given row item `T`.
  final Widget Function(T item)? cellBuilder;

  /// Whether the column holds numeric data (right-aligned).
  final bool numeric;

  /// Whether the column can be tapped to sort.
  final bool sortable;

  /// Optional accessibility/hover tooltip.
  final String? tooltip;
}

/// UI-11 (p23) W-6 `BrandDataTable` — generic tabular view.
///
/// Implements §3 W-6 row:
/// - Generic typed rows `BrandDataTable<T>`
/// - Sort indicator & callback
/// - Pagination controls
/// - Horizontal scrolling wrapper
/// - Custom cell builder
/// - Empty & loading states
/// - Semantics table structure
class BrandDataTable<T> extends StatelessWidget {
  const BrandDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.isLoading = false,
    this.density = BrandTableDensity.comfortable,
    this.emptyMessage = kBrandTableEmptyMessage,
    this.emptyWidget,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSort,
    this.pageIndex,
    this.pageSize,
    this.totalRows,
    this.onPageChanged,
    this.prevPageLabel,
    this.nextPageLabel,
    this.pageLabelBuilder,
  });

  final List<BrandTableColumn<T>> columns;
  final List<T> rows;
  final bool isLoading;

  /// Row-density preset; [BrandTableDensity.comfortable] keeps the framework
  /// defaults, [BrandTableDensity.dense] tightens only the chrome.
  final BrandTableDensity density;

  /// Caller-supplied (localized) empty-state message.
  final String emptyMessage;
  final Widget? emptyWidget;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex, bool ascending)? onSort;

  final int? pageIndex;
  final int? pageSize;
  final int? totalRows;
  final ValueChanged<int>? onPageChanged;

  /// Caller-supplied (localized) previous-page control label; falls back to
  /// [kBrandTablePreviousPageLabel].
  final String? prevPageLabel;

  /// Caller-supplied (localized) next-page control label; falls back to
  /// [kBrandTableNextPageLabel].
  final String? nextPageLabel;

  /// Caller-supplied (localized) page-range label; falls back to
  /// [kBrandTablePageRangeLabel].
  final String Function(int start, int end, int total)? pageLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    final isDense = density == BrandTableDensity.dense;

    if (isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(brand.primary),
          ),
        ),
      );
    }

    if (rows.isEmpty) {
      return emptyWidget ??
          EmptyStateWidget(
            title: emptyMessage,
            subtitle: '',
            icon: Icons.table_chart_outlined,
          );
    }

    final tableWidget = DataTable(
      sortColumnIndex: sortColumnIndex,
      sortAscending: sortAscending,
      // Density touches ONLY the chrome: a dense row is pinned to the Material
      // 48 dp minimum, so an interactive cell inside it keeps its tap target.
      headingRowHeight: isDense ? 44 : null,
      horizontalMargin: isDense ? 16 : null,
      columnSpacing: isDense ? 24 : null,
      dataRowMinHeight: isDense ? kMinInteractiveDimension : null,
      dataRowMaxHeight: isDense ? kMinInteractiveDimension : null,
      headingRowColor: WidgetStatePropertyAll(
        brand.primary.withValues(alpha: 0.08),
      ),
      columns: List<DataColumn>.generate(columns.length, (index) {
        final col = columns[index];
        return DataColumn(
          label: Text(
            col.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          numeric: col.numeric,
          tooltip: col.tooltip,
          onSort: col.sortable
              ? (colIndex, ascending) {
                  onSort?.call(
                    colIndex,
                    sortColumnIndex == colIndex ? !sortAscending : ascending,
                  );
                }
              : null,
        );
      }),
      rows: List<DataRow>.generate(rows.length, (rowIndex) {
        final item = rows[rowIndex];
        return DataRow(
          cells: List<DataCell>.generate(columns.length, (colIndex) {
            final col = columns[colIndex];
            final cellChild = col.cellBuilder != null
                ? col.cellBuilder!(item)
                : Text(item.toString());
            return DataCell(cellChild);
          }),
        );
      }),
    );

    final showPagination =
        pageIndex != null && pageSize != null && totalRows != null;
    // The visible range is data, not copy: only the label text is caller-owned.
    final pageStart = showPagination
        ? pageIndex! * pageSize! + (totalRows! == 0 ? 0 : 1)
        : 0;
    final pageEnd = showPagination
        ? ((pageIndex! + 1) * pageSize!).clamp(0, totalRows!)
        : 0;
    final pageLabel = showPagination
        ? pageLabelBuilder?.call(pageStart, pageEnd, totalRows!) ??
              kBrandTablePageRangeLabel(pageStart, pageEnd, totalRows!)
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: tableWidget,
        ),
        if (showPagination) ...<Widget>[
          const Divider(height: 1),
          _PaginationBar(
            pageIndex: pageIndex!,
            totalRows: totalRows!,
            pageLabel: pageLabel,
            canPrevious: pageIndex! > 0,
            canNext: pageEnd < totalRows!,
            onPageChanged: onPageChanged,
            prevPageLabel: prevPageLabel ?? kBrandTablePreviousPageLabel,
            nextPageLabel: nextPageLabel ?? kBrandTableNextPageLabel,
          ),
        ],
      ],
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.pageIndex,
    required this.totalRows,
    required this.pageLabel,
    required this.canPrevious,
    required this.canNext,
    required this.prevPageLabel,
    required this.nextPageLabel,
    this.onPageChanged,
  });

  final int pageIndex;
  final int totalRows;
  final String pageLabel;
  final bool canPrevious;
  final bool canNext;
  final String prevPageLabel;
  final String nextPageLabel;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    // `Icons.chevron_left`/`chevron_right` carry `matchTextDirection: true`, so
    // the framework mirrors them for RTL on its own — no manual icon swap here.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(pageLabel),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: prevPageLabel,
            onPressed: canPrevious
                ? () => onPageChanged?.call(pageIndex - 1)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: nextPageLabel,
            onPressed: canNext
                ? () => onPageChanged?.call(pageIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
