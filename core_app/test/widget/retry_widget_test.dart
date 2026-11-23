import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';

/// Law 34 (Retry UX)
///
/// Verifies the full fail → display Retry button → tap → succeed flow.
/// Also verifies that max-retry cap is respected with no crash.

// A fake repository that can be configured to fail N times before succeeding.
class _FlakyRepository {
  final int failCount;
  int _calls = 0;
  int get callCount => _calls;

  _FlakyRepository({required this.failCount});

  Future<List<String>> fetchItems() async {
    _calls++;
    if (_calls <= failCount) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return ['Item A', 'Item B'];
  }
}

// A widget that uses the repository and shows a Retry button on failure.
class _RetryableWidget extends StatefulWidget {
  final _FlakyRepository repo;
  final int maxRetries;
  const _RetryableWidget({required this.repo, this.maxRetries = 3});

  @override
  State<_RetryableWidget> createState() => _RetryableWidgetState();
}

class _RetryableWidgetState extends State<_RetryableWidget> {
  List<String>? _items;
  String? _error;
  int _retryCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.repo.fetchItems();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.code == 'unavailable'
              ? 'Service is temporarily unavailable. Please check your connection.'
              : 'An unexpected error occurred.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CircularProgressIndicator();
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!),
          if (_retryCount < widget.maxRetries)
            ElevatedButton(
              onPressed: () {
                setState(() => _retryCount++);
                _load();
              },
              child: const Text('Retry'),
            )
          else
            const Text('Maximum retries reached.'),
        ],
      );
    }
    return Column(children: _items!.map((i) => Text(i)).toList());
  }
}

void main() {
  group('Retry Widget Tests (Law 34)', () {
    testWidgets('Network unavailable: shows Retry button, no spinner', (
      tester,
    ) async {
      final repo = _FlakyRepository(failCount: 99); // always fails

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _RetryableWidget(repo: repo)),
        ),
      );

      await tester.pump(); // let future resolve

      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('unavailable'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Retry succeeds on second attempt', (tester) async {
      final repo = _FlakyRepository(failCount: 1); // fails once, then succeeds

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _RetryableWidget(repo: repo)),
        ),
      );
      await tester.pump();

      // First call failed — Retry button visible
      expect(find.text('Retry'), findsOneWidget);
      expect(repo.callCount, 1);

      // Tap Retry
      await tester.tap(find.text('Retry'));
      await tester.pump(); // trigger retry
      await tester.pump(); // let future resolve

      // Second call succeeded
      expect(repo.callCount, 2);
      expect(find.text('Item A'), findsOneWidget);
      expect(find.text('Item B'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets(
      'Max retry cap: after 3 attempts shows exhausted message, no crash',
      (tester) async {
        final repo = _FlakyRepository(failCount: 99); // always fails

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: _RetryableWidget(repo: repo, maxRetries: 3)),
          ),
        );
        await tester.pump();

        // Tap Retry 3 times
        for (int i = 0; i < 3; i++) {
          expect(find.text('Retry'), findsOneWidget);
          await tester.tap(find.text('Retry'));
          await tester.pump();
          await tester.pump();
        }

        // Max retries exhausted — Retry button gone, exhausted message shown, no crash
        expect(find.text('Retry'), findsNothing);
        expect(find.text('Maximum retries reached.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
