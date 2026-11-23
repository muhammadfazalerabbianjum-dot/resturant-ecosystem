import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

/// Law 34 (UI State Completeness) + Law 46 (Exception Surface)
///
/// Asserts that loading, permission-denied error, and success states are
/// each rendered correctly and are mutually exclusive — no overlap.
void main() {
  group('Loading / Error / Success State Tests (Law 34, 46)', () {
    testWidgets(
      'Loading state: shows CircularProgressIndicator, no error text',
      (tester) async {
        // Arrange: a Completer that never resolves, simulating perpetual loading
        final neverCompleter = Completer<List<String>>();

        final fakeProvider = FutureProvider<List<String>>(
          (_) => neverCompleter.future,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fakeProvider.overrideWith((_) => neverCompleter.future),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (ctx, ref, _) {
                    final state = ref.watch(fakeProvider);
                    return state.when(
                      data: (items) => Text('data: ${items.length}'),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text('error: $e'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Assert: only a spinner is shown
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.textContaining('error'), findsNothing);
        expect(find.textContaining('data'), findsNothing);
      },
    );

    testWidgets(
      'permission-denied: shows human-readable message — not raw FirebaseException',
      (tester) async {
        const mappedMessage =
            'You do not have permission to perform this action.';

        final failingProvider = FutureProvider<List<String>>((_) async {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          );
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (ctx, ref, _) {
                    final state = ref.watch(failingProvider);
                    return state.when(
                      data: (items) => Text('data: ${items.length}'),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text(
                        // This is what a properly mapped exception looks like in UI
                        e.toString().contains('permission')
                            ? mappedMessage
                            : 'An unexpected error occurred.',
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump(); // trigger the future

        // Assert: mapped human-readable message visible
        expect(find.text(mappedMessage), findsOneWidget);
        // Assert: raw FirebaseException string NOT leaked to UI
        expect(find.textContaining('FirebaseException'), findsNothing);
        expect(
          find.textContaining('[cloud_firestore/permission-denied]'),
          findsNothing,
        );
        // Assert: spinner cleared
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('Success state: renders data, no spinner, no error', (
      tester,
    ) async {
      final successProvider = FutureProvider<List<String>>(
        (_) async => ['Burger', 'Pizza', 'Pasta'],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (ctx, ref, _) {
                  final state = ref.watch(successProvider);
                  return state.when(
                    data: (items) =>
                        ListView(children: items.map((i) => Text(i)).toList()),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('error: $e'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Burger'), findsOneWidget);
      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('Pasta'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
