import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loggerProvider', () {
    test('loggerProvider is defined as a Provider type', () {
      expect(loggerProvider, isA<Provider<LoggerService>>());
    });
  });
}
