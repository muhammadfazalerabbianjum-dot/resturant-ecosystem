import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:labs/app/config/force_update_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseRemoteConfig extends Mock implements FirebaseRemoteConfig {}

class FakeRemoteConfigSettings extends Fake implements RemoteConfigSettings {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(FakeRemoteConfigSettings());
    registerFallbackValue(<String, String>{});
  });

  group('ForceUpdateService — Version Check Logic', () {
    late MockFirebaseRemoteConfig mockRemoteConfig;
    late ForceUpdateService service;

    setUp(() {
      mockRemoteConfig = MockFirebaseRemoteConfig();
      service = ForceUpdateService(remoteConfig: mockRemoteConfig);
    });

    test('androidUpdateUrl returns from remote config', () {
      when(
        () => mockRemoteConfig.getString('update_url_android'),
      ).thenReturn('https://play.google.com/store/apps/details?id=test');

      expect(
        service.androidUpdateUrl,
        equals('https://play.google.com/store/apps/details?id=test'),
      );
    });

    test('iosUpdateUrl returns from remote config', () {
      when(
        () => mockRemoteConfig.getString('update_url_ios'),
      ).thenReturn('https://apps.apple.com/app/test/id123');

      expect(
        service.iosUpdateUrl,
        equals('https://apps.apple.com/app/test/id123'),
      );
    });

    test('ForceUpdateStatus enum has correct values', () {
      expect(ForceUpdateStatus.ok, isA<ForceUpdateStatus>());
      expect(ForceUpdateStatus.required, isA<ForceUpdateStatus>());
      expect(ForceUpdateStatus.values.length, equals(2));
    });
  });
}
