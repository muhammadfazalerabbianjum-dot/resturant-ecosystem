import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'driver_location_service.dart';

final driverLocationServiceProvider = Provider<DriverLocationService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final logger = ref.watch(loggerProvider);
  // MONEY-3 (W3.5/P-2): the authenticated driver's uid is injected so every
  // deliveries row is uid-stamped and GDPR-queryable (deliveries/{orderId}).
  final driverUid = ref.watch(currentUserIdProvider);
  return DriverLocationService(firestore, logger, driverUid: driverUid);
});
