import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:mocktail/mocktail.dart';

class MockLogger extends Mock implements LoggerService {}

void main() {
  test('runZonedGuarded catches uncaught errors in main', () async {
    final mockLogger = MockLogger();
    when(
      () => mockLogger.error(any(), any(), stack: any(named: 'stack')),
    ).thenAnswer((_) async {});

    final completer = Completer<void>();
    runZonedGuarded(
      () {
        // Simulate error
        throw Exception('Simulated Main Crash');
      },
      (error, stack) {
        mockLogger.error(error, 'UncaughtZoneError', stack: stack);
        completer.complete();
      },
    );

    await completer.future.timeout(const Duration(seconds: 2));
    verify(
      () => mockLogger.error(
        any(),
        'UncaughtZoneError',
        stack: any(named: 'stack'),
      ),
    ).called(1);
  });
}
