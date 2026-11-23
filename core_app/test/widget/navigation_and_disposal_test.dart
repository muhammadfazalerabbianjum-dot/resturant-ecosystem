import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dummy controller and provider to simulate view model state
class ViewState {
  final bool isDisposed;
  ViewState(this.isDisposed);
}

class TestController extends StateNotifier<ViewState> {
  TestController() : super(ViewState(false));

  void disposeTracker() {
    state = ViewState(true);
  }

  @override
  void dispose() {
    disposeTracker();
    super.dispose();
  }
}

final testControllerProvider =
    StateNotifierProvider.autoDispose<TestController, ViewState>((ref) {
      return TestController();
    });

class PageA extends StatelessWidget {
  const PageA({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page A')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PageB()),
            );
          },
          child: const Text('Go to Page B'),
        ),
      ),
    );
  }
}

class PageB extends ConsumerWidget {
  const PageB({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Calling the provider so it initializes on PageB
    final state = ref.watch(testControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Page B')),
      body: Center(child: Text(state.isDisposed ? 'Disposed!' : 'Active')),
    );
  }
}

void main() {
  group('Navigation and Resource Disposal', () {
    testWidgets(
      'Popping a page correctly disposes autoDispose controllers (Memory Leak prevention)',
      (tester) async {
        // Create a ProviderContainer to observe the provider state externally
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: PageA()),
          ),
        );

        // Verify on Page A
        expect(find.text('Page A'), findsOneWidget);

        // Navigate to Page B
        await tester.tap(find.text('Go to Page B'));
        await tester.pumpAndSettle();

        // Verify on Page B and provider initialized
        expect(find.text('Page B'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);

        final bool initialized = container.exists(testControllerProvider);
        expect(
          initialized,
          isTrue,
          reason: 'Provider must init when Page B loads',
        );

        // Pop back to Page A using back button
        // Use the generic BackButton provided by AppBar
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // Verify returned to Page A
        expect(find.text('Page A'), findsOneWidget);

        // Verify provider disposed
        // Since it's autoDispose, and no one is listening anymore, it should be destroyed.
        final bool livesOn = container.exists(testControllerProvider);
        expect(
          livesOn,
          isFalse,
          reason: 'Popping the page MUST dispose the controller completely',
        );
      },
    );
  });
}
