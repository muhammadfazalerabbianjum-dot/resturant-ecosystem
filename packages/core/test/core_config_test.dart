import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

/// CORE-COV CONFIG module test: the safe production-like defaults (OFFLINE-
/// FALLBACK never silently uploads into a live Cloudinary account) and the
/// CoreConfigHolder.set/get swap contract that every white-label app relies on.
class _CustomConfig implements CoreConfig {
  const _CustomConfig();

  @override
  bool get isDemoMode => true;

  @override
  String get clientId => 'com.halalboyz.app';

  @override
  String get cloudinaryUploadPreset => 'preset-x';

  @override
  String get cloudinaryCloudName => 'cloud-x';

  @override
  List<String> get ownerEmails => const <String>['owner@example.com'];

  @override
  String get kitchenLanEndpoint => 'http://10.0.0.5:8080/orders';
}

void main() {
  tearDown(() => CoreConfigHolder.set(const DefaultCoreConfig()));

  group('DefaultCoreConfig — safe, production-like defaults', () {
    test('demo is OFF and the client id defaults to carnama', () {
      const config = DefaultCoreConfig();
      expect(config.isDemoMode, isFalse);
      expect(config.clientId, 'carnama');
    });

    test('OFFLINE_FALLBACK: empty cloudinary credentials can never upload', () {
      const config = DefaultCoreConfig();
      expect(config.cloudinaryUploadPreset, isEmpty);
      expect(config.cloudinaryCloudName, isEmpty);
      expect(config.ownerEmails, isEmpty);
    });

    test('the kitchen LAN endpoint default is present but app-overridable', () {
      expect(const DefaultCoreConfig().kitchenLanEndpoint, isNotEmpty);
    });
  });

  group('CoreConfigHolder', () {
    test('set replaces the active config; defaults otherwise', () {
      expect(CoreConfigHolder.instance.clientId, 'carnama');

      CoreConfigHolder.set(const _CustomConfig());

      expect(CoreConfigHolder.instance.isDemoMode, isTrue);
      expect(CoreConfigHolder.instance.clientId, 'com.halalboyz.app');
      expect(CoreConfigHolder.instance.cloudinaryUploadPreset, 'preset-x');
      expect(CoreConfigHolder.instance.ownerEmails, <String>[
        'owner@example.com',
      ]);
      expect(
        CoreConfigHolder.instance.kitchenLanEndpoint,
        'http://10.0.0.5:8080/orders',
      );
    });
  });
}
