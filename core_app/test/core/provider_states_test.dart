import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

/// Law 34 (State Mutex) + Law 46 (Exception Surface)
///
/// Asserts that Riverpod providers in isolation correctly transition through
/// loading → data and loading → error states with ZERO overlap.
/// A provider must never be simultaneously loading AND have a value/error.

// A controller that simulates delayed async Firestore operations.
class _FakeAsyncNotifier extends AsyncNotifier<List<String>> {
  final Future<List<String>> Function() _operation;

  _FakeAsyncNotifier(this._operation);

  @override
  Future<List<String>> build() => _operation();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_operation);
  }
}

void main() {
  group('Provider State Mutex Tests (Laws 34, 46)', () {
    test(
      'Provider starts in loading — hasValue and hasError are both false',
      () async {
        final completer = Future<List<String>>.delayed(
          const Duration(seconds: 60),
          () => <String>[], // Never resolves in test time
        );

        final provider =
            AsyncNotifierProvider<_FakeAsyncNotifier, List<String>>(
              () => _FakeAsyncNotifier(() => completer),
            );

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Read immediately before future resolves
        final state = container.read(provider);

        expect(state.isLoading, isTrue, reason: 'Must start in loading state');
        expect(
          state.hasValue,
          isFalse,
          reason: 'Cannot have a value while loading',
        );
        expect(
          state.hasError,
          isFalse,
          reason: 'Cannot have an error while loading',
        );
      },
    );

    test(
      'Successful resolution: isLoading=false, hasValue=true, hasError=false',
      () async {
        final provider =
            AsyncNotifierProvider<_FakeAsyncNotifier, List<String>>(
              () => _FakeAsyncNotifier(() async => ['Burger', 'Pizza']),
            );

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container.read(provider.future);
        final state = container.read(provider);

        expect(state.isLoading, isFalse);
        expect(state.hasValue, isTrue);
        expect(state.hasError, isFalse);
        expect(state.value, ['Burger', 'Pizza']);
      },
    );

    test(
      'Error resolution: isLoading=false, hasValue=false, hasError=true',
      () async {
        final provider =
            AsyncNotifierProvider<_FakeAsyncNotifier, List<String>>(
              () => _FakeAsyncNotifier(
                () async => throw FirebaseException(
                  plugin: 'cloud_firestore',
                  code: 'permission-denied',
                  message: 'Missing or insufficient permissions.',
                ),
              ),
            );

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Ignore the thrown error — we're testing the state, not letting it crash
        try {
          await container.read(provider.future);
        } catch (_) {}

        final state = container.read(provider);

        expect(state.isLoading, isFalse);
        expect(state.hasValue, isFalse);
        expect(state.hasError, isTrue);
        // Error must be a FirebaseException with the correct code
        expect(state.error, isA<FirebaseException>());
        expect((state.error as FirebaseException).code, 'permission-denied');
      },
    );

    test(
      'Error state clears after successful retry — no stale error',
      () async {
        bool shouldFail = true;

        final notifier = _FakeAsyncNotifier(
          () async => shouldFail
              ? throw FirebaseException(
                  plugin: 'cloud_firestore',
                  code: 'unavailable',
                )
              : ['Order #1', 'Order #2'],
        );

        final provider =
            AsyncNotifierProvider<_FakeAsyncNotifier, List<String>>(
              () => notifier,
            );

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // First: trigger error
        try {
          await container.read(provider.future);
        } catch (_) {}
        expect(container.read(provider).hasError, isTrue);

        // Fix the data source and retry
        shouldFail = false;
        await container.read(provider.notifier).refresh();

        final state = container.read(provider);
        expect(
          state.hasError,
          isFalse,
          reason: 'Stale error must be cleared after successful retry',
        );
        expect(state.hasValue, isTrue);
        expect(state.value, ['Order #1', 'Order #2']);
      },
    );

    test('Loading state has mutually exclusive sub-states', () async {
      final provider = AsyncNotifierProvider<_FakeAsyncNotifier, List<String>>(
        () => _FakeAsyncNotifier(
          () => Future.delayed(const Duration(hours: 1), () => <String>[]),
        ),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(provider);
      // Verify exactly one state flag is active
      final activeFlags = [
        state.isLoading,
        state.hasValue,
        state.hasError,
      ].where((f) => f).length;
      expect(
        activeFlags,
        1,
        reason: 'Exactly ONE state flag must be true at any time',
      );
    });
  });
}
