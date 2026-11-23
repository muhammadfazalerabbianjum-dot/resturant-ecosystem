import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';

/// Error markers for a TRANSIENT infrastructure failure (`unavailable`,
/// `deadline-exceeded`, `network-request-failed`, `resource-exhausted`) — the
/// classes a retry can plausibly clear.
const List<String> _kTransientErrorMarkers = <String>[
  'unavailable',
  'deadline-exceeded',
  'network-request-failed',
  'resource-exhausted',
];

/// PURE `lastError -> InfoTone` mapping for a dead-letter row's reason banner
/// (B2/p22), the DLQ counterpart of `trackerInfoToneFor` (p20 B1). DISPLAY
/// ONLY (L16): it picks a banner tone and nothing else — the queue's
/// retry/dismiss semantics are untouched.
///
/// Transient infrastructure failures → [InfoTone.warning] (retry may clear
/// them). Everything else — Security-Rules rejections such as
/// `permission-denied` / `unauthenticated` AND any unknown error — →
/// [InfoTone.error], so an unrecognised failure is never softened (W8.5
/// fail-visible).
InfoTone deadLetterToneFor(String lastError) {
  final reason = lastError.toLowerCase();
  final isTransient = _kTransientErrorMarkers.any(reason.contains);
  return isTransient ? InfoTone.warning : InfoTone.error;
}

/// The bounded width of the reason column. `InfoBanner` lays out a `Row` with
/// an `Expanded` label, and the table body is horizontally scrollable, so the
/// cell MUST declare a finite width instead of asking for an unbounded one.
/// No design token covers a table column width; the value only decides how
/// much of a long failure string is visible before the table scrolls.
const double _kReasonColumnWidth = 320;

/// QUEUE-1 (W5.1(d)) — Dead-Letter Queue screen.
///
/// Owner/admin-only surface (defense-in-depth via [RoleGate]; Firestore Rules
/// remain the authority) that lists every `IsarDeadLetter` entry through the
/// shared `deadLettersProvider` and offers two row actions:
///   • retry — re-enqueue as a fresh pending op (retryCount reset);
///   • dismiss — drop the entry without re-enqueuing.
/// Reached via [RouteNames.deadLetterQueue], which is registered in BOTH
/// router modes (static fallback + config mode) so the ops route always
/// resolves regardless of the client-config screens whitelist.
class DeadLetterScreen extends ConsumerWidget {
  const DeadLetterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoleGate(
      allowedRoles: const {UserRole.owner, UserRole.manager},
      builder: (_) => const _DeadLetterQueueView(),
    );
  }
}

class _DeadLetterQueueView extends ConsumerWidget {
  const _DeadLetterQueueView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final entriesAsync = ref.watch(deadLettersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(loc.deadLetterQueueTitle)),
      body: entriesAsync.when(
        data: (entries) => _deadLetterTable(context, ref, loc, entries),
        // F3-09 sweep (p22 wave): a bare centred spinner becomes the skeleton
        // list every other operator surface uses.
        loading: () => _deadLetterSkeleton(),
        error: (err, _) {
          ref.read(loggerProvider).error(err, 'DeadLetterQueueError');
          return Center(child: Text(FirebaseExceptionMapper.map(err)));
        },
      ),
    );
  }

  /// B2 (p22): the frozen [BrandDataTable] replaces the raw `ListTile` rows —
  /// `dense` row density, the failure reason carried by a tone-mapped
  /// [InfoBanner], and the library [EmptyStateWidget] while the queue is
  /// healthy. Retry/dismiss keep their exact callbacks and icons, so the
  /// QUEUE-1 behaviour tests still pass unchanged.
  Widget _deadLetterTable(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations loc,
    List<IsarDeadLetter> entries,
  ) {
    return BrandDataTable<IsarDeadLetter>(
      density: BrandTableDensity.dense,
      rows: entries,
      // DECISION (p22 B2): the action column is pinned FIRST. A 4-column table
      // of this data is wider than a phone viewport, so a trailing action
      // column would put the 48 dp retry/dismiss targets — the whole point of
      // the screen — behind a horizontal scroll (measured: the actions cell
      // landed at x≈1173 on the 800 dp test surface, i.e. unhittable).
      columns: <BrandTableColumn<IsarDeadLetter>>[
        BrandTableColumn<IsarDeadLetter>(
          title: loc.deadLetterQueueColumnActions,
          cellBuilder: (entry) => Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: loc.retry,
                icon: const Icon(Icons.refresh),
                onPressed: () => _retryEntry(ref, context, entry),
              ),
              IconButton(
                tooltip: loc.deadLetterQueueDismiss,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _dismissEntry(ref, context, entry),
              ),
            ],
          ),
        ),
        BrandTableColumn<IsarDeadLetter>(
          title: loc.deadLetterQueueColumnOperation,
          cellBuilder: (entry) =>
              Text('${entry.operation} · ${entry.collectionName}'),
        ),
        BrandTableColumn<IsarDeadLetter>(
          title: loc.deadLetterQueueColumnReason,
          cellBuilder: (entry) => SizedBox(
            width: _kReasonColumnWidth,
            child: InfoBanner(
              tone: deadLetterToneFor(entry.lastError),
              child: Text(entry.lastError),
            ),
          ),
        ),
        BrandTableColumn<IsarDeadLetter>(
          title: loc.deadLetterQueueColumnAttempts,
          cellBuilder: (entry) => Text(
            '${loc.deadLetterQueueRetries(entry.retryCount.toString())} · '
            '${entry.timestamp.toLocal()}',
          ),
        ),
      ],
      // The healthy-queue copy stays byte-identical to the pre-adoption string.
      // `subtitle: ''` mirrors the widget's own documented fallback (the
      // library passes an empty subtitle when only `emptyMessage` is given).
      emptyWidget: EmptyStateWidget(
        icon: Icons.check_circle_outline,
        title: loc.deadLetterQueueEmpty,
        subtitle: '',
      ),
    );
  }

  Future<void> _retryEntry(
    WidgetRef ref,
    BuildContext context,
    IsarDeadLetter entry,
  ) async {
    final loc = AppLocalizations.of(context);
    await ref.read(syncQueueProvider).retryDeadLetter(entry.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.retryingPendingSync)));
  }

  Future<void> _dismissEntry(
    WidgetRef ref,
    BuildContext context,
    IsarDeadLetter entry,
  ) async {
    final loc = AppLocalizations.of(context);
    await ref.read(syncQueueProvider).dismissDeadLetter(entry.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.deadLetterQueueDismissed)));
  }
}

/// B2 (p22): loading placeholders at the row footprint, matching the operator
/// skeleton pattern adopted in phase A (`_ticketSkeletonList`).
Widget _deadLetterSkeleton() => ListView.separated(
  padding: const EdgeInsets.all(12),
  itemCount: 6,
  separatorBuilder: (_, __) => Gap.v8,
  itemBuilder: (_, __) => SkeletonLoader.block(
    width: double.infinity,
    height: 72,
    borderRadius: BrandShapes.medium,
  ),
);
