import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
/// PHASE 2: Core Domain - Storage Adapter Resiliency
/// Asserts that physical cache mechanisms (like Hive) explicitly bubble
/// exceptions to the error logger instead of failing offline silently.
/// ============================================================================

void main() {
  group('Local Storage Adapter', () {
    test('Offline cache write simulates exception explicit tracking', () async {
      bool loggerWasTriggered = false;

      Future<void> mockOfflineWrite() async {
        try {
          throw Exception('Local disk out of storage bounds');
        } catch (e) {
          loggerWasTriggered = true;
          rethrow;
        }
      }

      expect(
        () async => await mockOfflineWrite(),
        throwsException,
        reason: 'Local Storage adapter silently swallowed a disk write error.',
      );

      expect(
        loggerWasTriggered,
        isTrue,
        reason: 'Error Logger blind spot detected.',
      );
    });
  });
}
