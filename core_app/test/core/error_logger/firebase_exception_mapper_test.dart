import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:core/core.dart';

void main() {
  group('FirebaseExceptionMapper', () {
    test('maps permission-denied to friendly message', () {
      final result = FirebaseExceptionMapper.map(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
      );
      expect(result, contains('permission'));
    });

    test('maps unavailable to connection error', () {
      final result = FirebaseExceptionMapper.map(
        FirebaseException(plugin: 'firestore', code: 'unavailable'),
      );
      expect(result, contains('connection'));
    });

    test('maps not-found to entity error', () {
      final result = FirebaseExceptionMapper.map(
        FirebaseException(plugin: 'firestore', code: 'not-found'),
      );
      expect(result, contains('not found'));
    });

    test('maps deadline-exceeded to retry prompt', () {
      final result = FirebaseExceptionMapper.map(
        FirebaseException(plugin: 'firestore', code: 'deadline-exceeded'),
      );
      expect(result, contains('try again'));
    });

    test('maps unauthenticated to login prompt', () {
      final result = FirebaseExceptionMapper.map(
        FirebaseException(plugin: 'auth', code: 'unauthenticated'),
      );
      expect(result, contains('log in'));
    });

    test('maps unknown exception to generic fallback', () {
      final result = FirebaseExceptionMapper.map(Exception('unknown error'));
      expect(result, contains('unexpected error'));
    });

    test('maps PlatformException network_error', () {
      final result = FirebaseExceptionMapper.map(
        PlatformException(code: 'network_error', message: ''),
      );
      expect(result, contains('Network error'));
    });
  });
}
