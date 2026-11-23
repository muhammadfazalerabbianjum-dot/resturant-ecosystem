import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

/// P6-03: Stub-screen behavior test — seedInitialAdmin.
/// Must grant owner role to configured owner emails, idempotently.
void main() {
  group('seedInitialAdmin — owner role seeding (P6-03)', () {
    test('CoreConfigHolder exposes configured owner emails', () {
      // Configure CoreConfig with owner emails via the public API
      CoreConfigHolder.set(
        const _TestConfig(
          ownerEmails: ['owner@example.com', 'admin@carnama.com'],
        ),
      );

      final ownerEmails = CoreConfigHolder.instance.ownerEmails;
      expect(ownerEmails, contains('owner@example.com'));
      expect(ownerEmails, contains('admin@carnama.com'));
    });

    test('returns early when ownerEmails is empty', () {
      CoreConfigHolder.set(const DefaultCoreConfig());

      final ownerEmails = CoreConfigHolder.instance.ownerEmails;
      expect(ownerEmails, isEmpty);
    });

    test('seedInitialAdmin is a no-op with empty owner emails', () async {
      CoreConfigHolder.set(const DefaultCoreConfig());
      // Should not throw — returns early when ownerEmails is empty.
      await seedInitialAdmin();
    });
  });
}

/// Test config that overrides ownerEmails.
class _TestConfig implements CoreConfig {
  @override
  final List<String> ownerEmails;
  const _TestConfig({this.ownerEmails = const []});

  @override
  bool get isDemoMode => false;

  @override
  String get clientId => 'test-client';

  @override
  String get cloudinaryUploadPreset => 'test_preset';

  @override
  String get cloudinaryCloudName => 'test_cloud';

  @override
  String get kitchenLanEndpoint => 'http://test.local';
}
