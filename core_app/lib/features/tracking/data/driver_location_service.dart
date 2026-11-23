import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:geolocator/geolocator.dart';

/// Service responsible for tracking driver location and publishing
/// coordinates to Firestore for customer tracking. Designed to be
/// highly efficient to stay within the free Spark plan tier.
class DriverLocationService {
  final FirebaseFirestore _firestore;
  final LoggerService _logger;
  final String? _driverUid;

  StreamSubscription<Position>? _positionStream;
  Position? _lastPublishedPosition;
  String? _activeOrderId;

  DriverLocationService(this._firestore, this._logger, {String? driverUid})
    : _driverUid = driverUid;

  /// Starts tracking the driver's location and publishing to the current order.
  ///
  /// W8.2 (03-P1-GPS): single-session GPS — a start for the order already
  /// being tracked is a no-op (re-assigning the stream without cancelling the
  /// prior subscription produced duplicate GPS listeners, doubled writes and
  /// battery drain); when switching orders the prior stream is cancelled
  /// BEFORE any new work so two streams can never publish concurrently.
  Future<void> startTracking(String orderId) async {
    if (_activeOrderId == orderId && _positionStream != null) return;
    await _positionStream?.cancel();
    _positionStream = null;
    _activeOrderId = orderId;

    // Request permission (Apple/Google require this before use)
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _logger.error(
        Exception('Disabled'),
        'Location services are disabled.',
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await _logger.error(
          Exception('Denied'),
          'Location permissions are denied',
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _logger.error(
        Exception('DeniedForever'),
        'Location permissions are permanently denied',
      );
      return;
    }

    // Configure for high accuracy but balanced battery/writes
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 30, // ONLY fire update if moved > 30 meters
    );

    // Initial publish to establish connection instantly
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _publishLocation(initialPosition);
    } catch (e) {
      await _logger.error(e, 'DriverLocationService_initialGet');
    }

    // Start stream
    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) => _publishLocation(position),
          onError: (Object e, StackTrace stack) =>
              _logger.error(e, 'DriverLocationService_stream', stack: stack),
        );
  }

  /// Publishes location to the specific order document. Throttled to prevent
  /// excessive Firestore writes and battery drain.
  Future<void> _publishLocation(Position position) async {
    if (_activeOrderId == null) return;

    // Additional safeguard: Only publish if moved more than 20 meters since last publish
    if (_lastPublishedPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPublishedPosition!.latitude,
        _lastPublishedPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance < 20) {
        return; // Prevent GPS flutter from causing ghost writes
      }
    }

    try {
      await _firestore.collection('deliveries').doc(_activeOrderId).set({
        'lat': position.latitude,
        'lng': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'timestamp': FieldValue.serverTimestamp(),
        // MONEY-3 (W3.5/P-2): stamp the driver's uid on every row so future
        // deliveries are directly queryable for GDPR erasure
        // (deliveries.where('driverId', ==, uid)). null when the uid is not
        // available (defensive — the row still erases via order-id path).
        if (_driverUid != null) 'driverId': _driverUid,
      });
      _lastPublishedPosition = position;
    } catch (e, stack) {
      await _logger.error(e, 'DriverLocationService_publish', stack: stack);
    }
  }

  /// Stops tracking
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _activeOrderId = null;
    _lastPublishedPosition = null;
  }
}
