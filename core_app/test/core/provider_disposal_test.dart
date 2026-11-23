import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/loyalty/presentation/loyalty_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider platform channel
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return '/tmp/test';
          }
          return null;
        },
      );

  group('C1: Provider Disposal Tests', () {
    test(
      'userLoyaltyProvider disposes automatically when container is disposed',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Listen to the provider
        final sub = container.listen(userLoyaltyProvider, (prev, next) {});

        // Verify the provider is active
        expect(container.read(userLoyaltyProvider), isA<AsyncValue<dynamic>>());

        // Close subscription
        sub.close();

        // Dispose the container — this should trigger provider disposal
        container.dispose();

        // After disposal, reading should throw (provider is disposed)
        expect(
          () => container.read(userLoyaltyProvider),
          throwsA(isA<StateError>()),
          reason: 'Provider should be disposed after container disposal',
        );
      },
    );

    test('userLoyaltyProvider is AutoDispose type', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify it's an AutoDisposeStreamProvider by checking the type
      final provider = userLoyaltyProvider;
      expect(
        provider.runtimeType.toString().contains('AutoDispose'),
        isTrue,
        reason: 'Must be an AutoDisposeStreamProvider to prevent memory leaks',
      );
    });
  });
}
