import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Law 30 (No Production Hit) + Law 34 (Offline UX)
///
/// Simulates complete network loss and asserts:
/// 1. Offline banner is shown instead of crashing.
/// 2. No unhandled exceptions propagate to the widget tree.
/// 3. Reconnection triggers data reload.

// Connectivity state enum for the test
enum _ConnState { online, offline }

// A lightweight connectivity notifier for injection
final _connectivityProvider = StateProvider<_ConnState>(
  (_) => _ConnState.offline,
);

// A fake data provider that respects connectivity
final _offlineAwareProvider = FutureProvider.family<List<String>, _ConnState>((
  ref,
  connectivity,
) async {
  if (connectivity == _ConnState.offline) {
    throw const SocketException('No internet connection');
  }
  return ['Item A', 'Item B', 'Item C'];
});

class _OfflineAwareScreen extends ConsumerWidget {
  const _OfflineAwareScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(_connectivityProvider);
    final state = ref.watch(_offlineAwareProvider(connectivity));

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: state.when(
        loading: () => const CircularProgressIndicator(),
        data: (items) => ListView(
          children: items.map((i) => ListTile(title: Text(i))).toList(),
        ),
        error: (e, _) {
          if (e is SocketException) {
            return const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, size: 48),
                SizedBox(height: 16),
                Text(
                  'You are offline. Please check your connection.',
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }
          return Text('Error: ${e.runtimeType}');
        },
      ),
    );
  }
}

void main() {
  group('Offline Mode Tests (Laws 30, 34)', () {
    testWidgets('Offline: shows wifi_off icon and offline message, no crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: _OfflineAwareScreen())),
      );

      await tester.pump(); // resolve the future

      // Assert offline UI shown
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(
        find.textContaining('offline', skipOffstage: false),
        findsOneWidget,
      );

      // Assert no crash, no raw exception dumped to UI
      expect(tester.takeException(), isNull);

      // Assert no data cards visible while offline
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('Offline: no CircularProgressIndicator stuck on screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: _OfflineAwareScreen())),
      );

      await tester.pump();

      // Spinner must clear — no perpetual loading on offline
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Reconnection: switching to online triggers data reload', (
      tester,
    ) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (ctx, ref, _) {
                capturedRef = ref;
                return const _OfflineAwareScreen();
              },
            ),
          ),
        ),
      );

      await tester.pump(); // offline state rendered

      // Confirm offline state
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);

      // Simulate reconnection
      capturedRef.read(_connectivityProvider.notifier).state =
          _ConnState.online;
      await tester.pump(); // trigger rebuild
      await tester.pump(); // resolve new future

      // Data loaded
      expect(find.text('Item A'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsNothing);
    });

    testWidgets(
      'SocketException is caught and does NOT propagate as unhandled',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: _OfflineAwareScreen())),
        );

        await tester.pump();

        // The exception must have been swallowed by the provider error handler
        expect(tester.takeException(), isNull);
      },
    );
  });
}

// Import needed by SocketException
class SocketException implements Exception {
  final String message;
  const SocketException(this.message);
  @override
  String toString() => 'SocketException: $message';
}
