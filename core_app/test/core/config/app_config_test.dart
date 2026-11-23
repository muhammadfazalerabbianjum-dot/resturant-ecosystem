import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('appName is defined', () {
      expect(AppConfig.appName, isNotEmpty);
    });

    test('fcmChannelDescription is defined', () {
      expect(AppConfig.fcmChannelDescription, isNotEmpty);
    });
  });
}
