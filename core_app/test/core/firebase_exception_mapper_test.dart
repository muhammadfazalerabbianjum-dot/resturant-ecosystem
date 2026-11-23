import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

void main() {
  group('FirebaseExceptionMapper Constitution Verification', () {
    test(
      'Simulates permission-denied and maps to secure localized fallback',
      () {
        final input = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
        final output = FirebaseExceptionMapper.map(input);
        expect(output, 'You do not have permission to perform this action.');
      },
    );

    test('Simulates unavailable (offline) and maps to connection error', () {
      final input = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      final output = FirebaseExceptionMapper.map(input);
      expect(
        output,
        'Service is temporarily unavailable. Please check your connection.',
      );
    });

    test('Simulates not-found and maps to entity error', () {
      final input = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
      );
      final output = FirebaseExceptionMapper.map(input);
      expect(output, 'The requested resource was not found.');
    });

    test('Simulates deadline-exceeded (timeout) and maps to retry prompt', () {
      final input = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'deadline-exceeded',
      );
      final output = FirebaseExceptionMapper.map(input);
      expect(output, 'The request took too long. Please try again.');
    });

    test(
      'Simulates unhandled/obscure exception and maps to generic fallback',
      () {
        final input = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'obscure-native-crash',
        );
        final output = FirebaseExceptionMapper.map(input);
        expect(
          output,
          'An unexpected server error occurred (obscure-native-crash).',
        );
      },
    );

    test('Simulates raw PlatformException fallback mapping capability', () {
      final output = FirebaseExceptionMapper.map(
        Exception('Standard native Exception'),
      );
      expect(output, 'An unexpected error occurred. Please try again.');
    });
  });
}
