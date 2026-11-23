import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';
import 'package:core/core.dart';

/// Deterministic geolocator fake (T-1, STATE-1 / master W8.2): replaces
/// [GeolocatorPlatform.instance] so the test can count how many position
/// streams the service opens, how many subscriptions are taken, and how many
/// subscriptions are cancelled — the exact observables the 03-P1-GPS bug
/// (duplicate GPS listeners) is made of.
class _ProbingGeolocator extends GeolocatorPlatform {
  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();

  int getPositionStreamCalls = 0;
  int listenCalls = 0;
  int cancelCalls = 0;

  Position get _fakePosition => Position(
    longitude: 55.2708,
    latitude: 25.2048,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => _fakePosition;

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => 1000;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    getPositionStreamCalls++;
    return _ProbedPositionStream(_controller.stream, this);
  }

  Future<void> dispose() => _controller.close();
}

class _ProbedPositionStream extends Stream<Position> {
  final Stream<Position> _inner;
  final _ProbingGeolocator probe;

  _ProbedPositionStream(this._inner, this.probe);

  @override
  StreamSubscription<Position> listen(
    void Function(Position)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    probe.listenCalls++;
    return _ProbedSubscription(
      _inner.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      ),
      probe,
    );
  }
}

class _ProbedSubscription implements StreamSubscription<Position> {
  final StreamSubscription<Position> _inner;
  final _ProbingGeolocator probe;

  _ProbedSubscription(this._inner, this.probe);

  @override
  Future<void> cancel() {
    probe.cancelCalls++;
    return _inner.cancel();
  }

  @override
  void onData(void Function(Position)? handle) => _inner.onData(handle);

  @override
  void onError(Function? handle) => _inner.onError(handle);

  @override
  void onDone(void Function()? handle) => _inner.onDone(handle);

  @override
  bool get isPaused => _inner.isPaused;

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture<E>(futureValue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ProbingGeolocator probe;
  late FakeFirebaseFirestore fakeFirestore;
  late DriverLocationService service;
  final originalPlatform = GeolocatorPlatform.instance;

  setUp(() {
    probe = _ProbingGeolocator();
    GeolocatorPlatform.instance = probe;
    fakeFirestore = FakeFirebaseFirestore();
    service = DriverLocationService(fakeFirestore, LoggerService());
  });

  tearDown(() async {
    await service.stopTracking();
    await probe.dispose();
    GeolocatorPlatform.instance = originalPlatform;
  });

  group('DriverLocationService single-session GPS (T-1 — W8.2)', () {
    test(
      'double-start on the same order opens exactly ONE stream subscription',
      () async {
        await service.startTracking('order-1');
        await service.startTracking('order-1');

        expect(
          probe.getPositionStreamCalls,
          1,
          reason:
              'startTracking for the already-tracked order must early-return '
              'instead of opening a second position stream (duplicate '
              'listeners doubled writes/battery — 03-P1-GPS)',
        );
        expect(
          probe.listenCalls,
          1,
          reason: 'exactly one active listener must exist',
        );
      },
    );

    test(
      'switching orders cancels the prior stream BEFORE subscribing again',
      () async {
        await service.startTracking('order-1');
        await service.startTracking('order-2');

        expect(
          probe.cancelCalls,
          1,
          reason: 'the prior subscription must be cancelled',
        );
        expect(
          probe.listenCalls,
          2,
          reason: 'one fresh subscription serves the new order',
        );
      },
    );

    test('restart after stopTracking re-arms a fresh subscription', () async {
      await service.startTracking('order-1');
      await service.stopTracking();
      await service.startTracking('order-1');

      expect(
        probe.cancelCalls,
        1,
        reason: 'stopTracking cancelled the first stream',
      );
      expect(
        probe.listenCalls,
        2,
        reason: 'a fresh subscription must serve the restart',
      );
    });
  });
}
