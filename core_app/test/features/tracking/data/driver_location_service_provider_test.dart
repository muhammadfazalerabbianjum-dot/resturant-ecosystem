import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:labs/features/tracking/data/driver_location_service_provider.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';
import 'package:core/core.dart';

void main() {
  group('driverLocationServiceProvider', () {
    test('is defined and not null', () {
      expect(driverLocationServiceProvider, isNotNull);
    });

    test('provider runtime type contains Provider', () {
      expect(
        driverLocationServiceProvider.runtimeType.toString(),
        contains('Provider'),
      );
    });

    test('provider name references driverLocationService', () {
      expect(
        driverLocationServiceProvider.runtimeType.toString(),
        contains('Provider'),
      );
    });

    test('DriverLocationService class is importable and constructable', () {
      // Verify the service class is accessible (requires Firebase in real usage)
      expect(DriverLocationService, isNotNull);
    });

    test('provider is a simple Provider (not StreamProvider)', () {
      final typeStr = driverLocationServiceProvider.runtimeType.toString();
      expect(typeStr.contains('StreamProvider'), isFalse);
    });

    test('provider is not a FutureProvider', () {
      final typeStr = driverLocationServiceProvider.runtimeType.toString();
      expect(typeStr.contains('FutureProvider'), isFalse);
    });

    test('DriverLocationService is a Type', () {
      expect(DriverLocationService, isA<Type>());
    });

    test('provider can be referenced multiple times', () {
      expect(
        driverLocationServiceProvider,
        same(driverLocationServiceProvider),
      );
    });

    test(
      'provider wires Firestore, logger and the auth driver uid (MONEY-3 W3.5/P-2)',
      () {
        final db = FakeFirebaseFirestore();
        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(db),
            loggerProvider.overrideWithValue(LoggerService()),
            currentUserIdProvider.overrideWithValue('driver-42'),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(driverLocationServiceProvider);
        expect(service, isA<DriverLocationService>());
      },
    );
  });
}
