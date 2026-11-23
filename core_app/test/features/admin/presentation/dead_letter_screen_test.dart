import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/admin/presentation/dead_letter_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

/// In-memory [SyncQueue] double driving the DLQ screen test.
///
/// The DLQ screen's real providers sit on Isar `watchLazy()` streams; widget
/// tests run in a fake-async zone where real Isar I/O never completes (the
/// whole file would hang — observed during QUEUE-1 development). The repo
/// convention (e.g. `runtime_audit_flow_test.dart`) is to override the queue
/// stream providers with in-memory doubles. THIS double implements the REAL
/// retry/dismiss semantics against an in-memory list and re-emits the
/// `deadLettersProvider` stream on every mutation, so every UI assertion below
/// proves a real behaviour (list → retry → pending / dismiss → removed).
class _FakeSyncQueue implements SyncQueue {
  _FakeSyncQueue();

  final List<IsarDeadLetter> deadLetters = [];
  final List<Map<String, dynamic>> pending = [];
  final StreamController<void> _mutations = StreamController<void>.broadcast();

  /// Stream for `deadLettersProvider`: yields the CURRENT list on listen, then
  /// re-yields on every mutation (mirrors Isar `watchLazy().asyncMap`).
  Stream<List<IsarDeadLetter>> get stream async* {
    yield List.of(deadLetters);
    await for (final _ in _mutations.stream) {
      yield List.of(deadLetters);
    }
  }

  void _emit() => _mutations.add(null);

  @override
  Future<void> retryDeadLetter(Id id) async {
    final index = deadLetters.indexWhere((e) => e.id == id);
    if (index >= 0) {
      final entry = deadLetters.removeAt(index);
      pending.add(jsonDecode(entry.dataString) as Map<String, dynamic>);
    }
    _emit();
  }

  @override
  Future<void> dismissDeadLetter(Id id) async {
    deadLetters.removeWhere((e) => e.id == id);
    _emit();
  }

  @override
  Future<void> enqueue(
    String operation,
    String collectionName,
    Map<String, dynamic> data,
  ) async {}

  @override
  Future<void> processQueue() async {}

  @override
  Future<void> removeOperation(String operation, String id) async {}

  @override
  Future<List<IsarDeadLetter>> getDeadLetters() async => List.of(deadLetters);
}

IsarDeadLetter _seedDeadLetter() {
  return IsarDeadLetter()
    ..operation = 'create'
    ..collectionName = 'orders'
    ..dataString = '{"id":"ord-dlq"}'
    ..timestamp = DateTime(2026, 1, 1)
    ..retryCount = 0
    ..lastError = 'permission-denied';
}

/// Pumps [DeadLetterScreen] inside a minimal GoRouter with the DLQ + home
/// routes so RoleGate's NoPermissionRedirect can navigate away for wrong roles.
///
/// Real-I/O-free by design (see [_FakeSyncQueue]): the prepared [fake] drives
/// both the list provider and the retry/dismiss actions.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeSyncQueue fake,
  required UserRole role,
}) async {
  final router = GoRouter(
    initialLocation: '/dead-letters',
    routes: [
      GoRoute(
        name: RouteNames.home,
        path: '/',
        builder: (_, __) => const Scaffold(body: Center(child: Text('home'))),
      ),
      GoRoute(
        name: RouteNames.deadLetterQueue,
        path: '/dead-letters',
        builder: (_, __) => const DeadLetterScreen(),
      ),
    ],
  );

  final logger = LoggerService(
    testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncQueueProvider.overrideWithValue(fake),
        deadLettersProvider.overrideWith((ref) => fake.stream),
        currentUserProvider.overrideWith(
          (ref) async => UserModel(id: 'u-1', role: role),
        ),
        loggerProvider.overrideWithValue(logger),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// QUEUE-1 T-6 (W5.1(d)) — the DLQ screen lists `IsarDeadLetter` entries via
/// the shared provider and exposes retry + dismiss row actions.
void main() {
  group('QUEUE-1 T-6: DeadLetterScreen', () {
    late _FakeSyncQueue fake;

    setUp(() {
      fake = _FakeSyncQueue();
    });

    testWidgets('owner sees the seeded dead letters and retry re-enqueues', (
      tester,
    ) async {
      fake.deadLetters.add(_seedDeadLetter());

      await _pumpScreen(tester, fake: fake, role: UserRole.owner);

      // Row renders operation · collection + the rules-rejection reason.
      expect(find.text('create · orders'), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsOneWidget);

      // Retry action: DLQ entry re-enqueues as a fresh pending op.
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('create · orders'), findsNothing);
      expect(fake.pending.length, 1);
      expect(fake.pending.single, containsPair('id', 'ord-dlq'));
      expect(fake.deadLetters, isEmpty);
    });

    testWidgets('manager is allowed (role gate) and dismiss drops the entry', (
      tester,
    ) async {
      fake.deadLetters.add(_seedDeadLetter());

      await _pumpScreen(tester, fake: fake, role: UserRole.manager);

      expect(find.text('create · orders'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('create · orders'), findsNothing);
      expect(
        fake.deadLetters,
        isEmpty,
        reason: 'dismiss must delete the DLQ entry',
      );
      expect(fake.pending, isEmpty, reason: 'dismiss must NOT re-enqueue');
    });

    testWidgets('empty DLQ renders the empty message', (tester) async {
      await _pumpScreen(tester, fake: fake, role: UserRole.owner);

      expect(find.text('create · orders'), findsNothing);
      expect(find.textContaining('No failed operations'), findsOneWidget);
    });

    testWidgets('a customer is role-gated away from the DLQ surface', (
      tester,
    ) async {
      fake.deadLetters.add(_seedDeadLetter());

      await _pumpScreen(tester, fake: fake, role: UserRole.customer);

      // The customer never sees the dead-letter rows (RoleGate defence).
      expect(find.text('create · orders'), findsNothing);
      // E1 F3-09: NoPermissionRedirect shows the library skeleton while
      // redirecting.
      expect(find.byType(SkeletonLoader), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // Redirected home; the DLQ surface is gone.
      expect(find.text('create · orders'), findsNothing);
    });
  });

  /// UI-12 (p22) B2 — the DLQ surface adopts the frozen `BrandDataTable`
  /// (`dense` row density) with a tone-mapped `InfoBanner` per failure class
  /// and the library `EmptyStateWidget` while the queue is healthy. Written RED
  /// before the wiring. The QUEUE-1 group above is unchanged, and the last test
  /// here re-proves that retry/dismiss still drive the REAL queue — only the
  /// chrome changed (L16/RULE-2).
  group('UI-12 (p22) B2: DLQ adopts BrandDataTable (dense)', () {
    late _FakeSyncQueue fake;

    setUp(() {
      fake = _FakeSyncQueue();
    });

    test('B2: failure classes map to banner tones (pure mapping)', () {
      // Rules rejections and unknowns are never softened (fail-visible).
      expect(deadLetterToneFor('permission-denied'), InfoTone.error);
      expect(deadLetterToneFor('unauthenticated'), InfoTone.error);
      expect(
        deadLetterToneFor('[cloud_firestore/permission-denied] denied'),
        InfoTone.error,
      );
      expect(deadLetterToneFor('weird-thing'), InfoTone.error);
      expect(deadLetterToneFor(''), InfoTone.error);
      // Transient infrastructure failures may self-heal on retry.
      expect(deadLetterToneFor('unavailable'), InfoTone.warning);
      expect(deadLetterToneFor('deadline-exceeded'), InfoTone.warning);
      expect(deadLetterToneFor('network-request-failed'), InfoTone.warning);
      expect(deadLetterToneFor('resource-exhausted'), InfoTone.warning);
      expect(deadLetterToneFor('UNAVAILABLE'), InfoTone.warning);
    });

    testWidgets('B2: populated queue renders the dense table + tone banner', (
      tester,
    ) async {
      fake.deadLetters.add(_seedDeadLetter());

      await _pumpScreen(tester, fake: fake, role: UserRole.owner);

      final table = tester.widget<BrandDataTable<IsarDeadLetter>>(
        find.byWidgetPredicate((w) => w is BrandDataTable<IsarDeadLetter>),
      );
      expect(table.density, BrandTableDensity.dense);
      expect(table.columns.length, 4);
      expect(table.rows.length, 1);

      // The rules rejection keeps its verbatim copy, inside an error banner.
      expect(find.byType(InfoBanner), findsOneWidget);
      expect(
        tester.widget<InfoBanner>(find.byType(InfoBanner)).tone,
        InfoTone.error,
      );
      expect(find.textContaining('permission-denied'), findsOneWidget);
      // The raw row chrome is gone.
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('B2: a transient failure renders the warning tone', (
      tester,
    ) async {
      fake.deadLetters.add(_seedDeadLetter()..lastError = 'unavailable');

      await _pumpScreen(tester, fake: fake, role: UserRole.owner);

      expect(
        tester.widget<InfoBanner>(find.byType(InfoBanner)).tone,
        InfoTone.warning,
      );
    });

    testWidgets('B2: the healthy queue renders EmptyStateWidget', (
      tester,
    ) async {
      await _pumpScreen(tester, fake: fake, role: UserRole.owner);

      // The table is still there; it renders the library empty state.
      final table = tester.widget<BrandDataTable<IsarDeadLetter>>(
        find.byWidgetPredicate((w) => w is BrandDataTable<IsarDeadLetter>),
      );
      expect(table.rows, isEmpty);
      expect(find.byType(EmptyStateWidget), findsOneWidget);
      expect(find.textContaining('No failed operations'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('B2: dense rows keep >= 48 dp action targets (L19)', (
      tester,
    ) async {
      fake.deadLetters.add(_seedDeadLetter());

      await _pumpScreen(tester, fake: fake, role: UserRole.owner);

      final handle = tester.ensureSemantics();
      try {
        for (final icon in <IconData>[Icons.refresh, Icons.delete_outline]) {
          final size = tester.getSize(find.widgetWithIcon(IconButton, icon));
          expect(size.height, greaterThanOrEqualTo(48.0));
          expect(size.width, greaterThanOrEqualTo(48.0));
        }
      } finally {
        handle.dispose();
      }
    });

    testWidgets('B2: retry still re-enqueues through the real queue', (
      tester,
    ) async {
      fake.deadLetters.add(_seedDeadLetter());

      await _pumpScreen(tester, fake: fake, role: UserRole.owner);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fake.pending.length, 1);
      expect(fake.deadLetters, isEmpty);
      // The queue is healthy now, so the empty state takes over.
      expect(find.byType(EmptyStateWidget), findsOneWidget);
    });
  });
}
