// PERF-10 T-8 — direct behavioral coverage for the presence lifecycle wiring
// (`core_app/lib/app/presence_lifecycle_observer.dart`), WIRED-UNTESTED before
// this wave: [main.dart] wraps the app with it but nothing asserted the
// attach/detach transitions it owns.
//
// The observer's REAL contract (read from source, P1):
//   * build(): watches `presenceServiceProvider`; when the resolved service is
//     not IDENTICAL to the last one it detaches the old, stores the new and
//     attaches it — attach exactly once per identity (a plain rebuild with the
//     same instance must NOT re-attach / re-write presence).
//   * sign-in (staff) -> attach; sign-out / role change to customer -> the
//     provider resolves to null -> detach the previous service.
//   * dispose() -> detach the active service and clear the reference (the app
//     being torn down must not leave the staff member marked online).
//
// The service is a recording double so no Firestore/binding work happens —
// PresenceService's own write contract is covered in
// packages/core/test/presence/presence_service_test.dart.
import 'dart:io';

import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/presence_lifecycle_observer.dart';

/// Records the lifecycle transitions the observer performs, without touching
/// Firestore (attach/detach are overridden — the real ones write presence).
/// The injected DB is the in-repo FakeFirebaseFirestore; it is never read
/// because every presence write goes through the overridden methods.
class _RecordingPresenceService extends PresenceService {
  _RecordingPresenceService()
    : super(
        userId: 'staff-1',
        branchId: 'branch-1',
        role: UserRole.kitchen,
        db: FakeFirebaseFirestore(),
        logger: LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  int attaches = 0;
  int detaches = 0;

  @override
  void attach() => attaches++;

  @override
  void detach() => detaches++;
}

/// The mutable "provider value" the test drives: staff signed in -> a service,
/// signed out / customer -> null.
final _serviceState = StateProvider<PresenceService?>((ref) => null);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        presenceServiceProvider.overrideWith((ref) => ref.watch(_serviceState)),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpObserver(WidgetTester tester, {Widget? child}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PresenceLifecycleObserver(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }

  testWidgets('attaches the staff service exactly once per identity', (
    tester,
  ) async {
    final service = _RecordingPresenceService();
    container.read(_serviceState.notifier).state = service;

    await pumpObserver(tester);
    expect(service.attaches, 1);
    expect(service.detaches, 0);

    // Rebuilds (unrelated setState / provider re-read) must NOT re-attach —
    // the `identical` gate is what keeps a hot UI from spamming presence.
    await pumpObserver(tester, child: const Placeholder());
    await tester.pump();
    await pumpObserver(tester, child: const SizedBox.shrink());
    await tester.pump();
    expect(service.attaches, 1, reason: 'same identity must not re-attach');
    expect(service.detaches, 0);
  });

  testWidgets('renders its child unchanged (startup unaffected)', (
    tester,
  ) async {
    await pumpObserver(tester, child: const SizedBox(key: Key('app-body')));
    expect(find.byKey(const Key('app-body')), findsOneWidget);
  });

  testWidgets('does nothing while no staff service is resolved', (
    tester,
  ) async {
    // Signed out / customer: provider is null -> no attach, no crash.
    await pumpObserver(tester);
    expect(find.byType(PresenceLifecycleObserver), findsOneWidget);
  });

  testWidgets('role change to customer detaches the previous service', (
    tester,
  ) async {
    final staff = _RecordingPresenceService();
    container.read(_serviceState.notifier).state = staff;
    await pumpObserver(tester);

    // Sign-out / downgrade to customer -> provider resolves to null.
    container.read(_serviceState.notifier).state = null;
    await tester.pump();

    expect(staff.detaches, 1);
    expect(staff.attaches, 1);
  });

  testWidgets(
    'a different service identity swaps: old detaches, new attaches',
    (tester) async {
      final first = _RecordingPresenceService();
      container.read(_serviceState.notifier).state = first;
      await pumpObserver(tester);
      expect(first.attaches, 1);

      final second = _RecordingPresenceService();
      container.read(_serviceState.notifier).state = second;
      await tester.pump();

      expect(
        first.detaches,
        1,
        reason: 'the previous staff member goes offline',
      );
      expect(second.attaches, 1);
    },
  );

  testWidgets('dispose detaches the active service (app teardown)', (
    tester,
  ) async {
    final service = _RecordingPresenceService();
    container.read(_serviceState.notifier).state = service;
    await pumpObserver(tester);
    expect(service.attaches, 1);

    // Unmount the observer entirely — mirrors app shutdown.
    await tester.pumpWidget(const SizedBox.shrink());

    expect(service.detaches, 1);
  });
}
