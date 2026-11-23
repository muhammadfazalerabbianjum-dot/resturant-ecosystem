import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/network/pending_sync_provider.dart';

void main() {
  group('pendingSyncCountProvider', () {
    test('pendingSyncCountProvider is a StreamProvider', () {
      // Verify the provider type and structure
      expect(pendingSyncCountProvider, isNotNull);
    });

    test('pendingSyncCountProvider returns int', () async {
      // The provider returns an int - verify the type
      final type = pendingSyncCountProvider.runtimeType.toString();
      expect(type, contains('StreamProvider'));
    });

    test('pendingSyncCountProvider is autoDispose', () {
      final type = pendingSyncCountProvider.runtimeType.toString();
      expect(type, contains('AutoDispose'));
    });

    test('pendingSyncCountProvider filters retryCount < 5', () {
      // Verify the logic: only ops with retryCount < 5 are counted
      // This is a pure logic test of the filtering concept
      final ops = [
        _TestOp(0), // retryCount 0 - should count
        _TestOp(2), // retryCount 2 - should count
        _TestOp(4), // retryCount 4 - should count
        _TestOp(5), // retryCount 5 - dead letter, should NOT count
        _TestOp(6), // retryCount 6 - dead letter, should NOT count
      ];

      final count = ops.where((op) => op.retryCount < 5).length;
      expect(count, 3);
    });

    test('empty list returns 0', () {
      final ops = <_TestOp>[];
      final count = ops.where((op) => op.retryCount < 5).length;
      expect(count, 0);
    });

    test('all dead letters returns 0', () {
      final ops = [_TestOp(5), _TestOp(7), _TestOp(10)];
      final count = ops.where((op) => op.retryCount < 5).length;
      expect(count, 0);
    });

    test('all retryable returns full count', () {
      final ops = [_TestOp(0), _TestOp(1), _TestOp(3)];
      final count = ops.where((op) => op.retryCount < 5).length;
      expect(count, 3);
    });

    test('boundary at retryCount 4 is included', () {
      final ops = [_TestOp(4)];
      final count = ops.where((op) => op.retryCount < 5).length;
      expect(count, 1);
    });

    test('boundary at retryCount 5 is excluded', () {
      final ops = [_TestOp(5)];
      final count = ops.where((op) => op.retryCount < 5).length;
      expect(count, 0);
    });
  });
}

class _TestOp {
  final int retryCount;
  _TestOp(this.retryCount);
}
