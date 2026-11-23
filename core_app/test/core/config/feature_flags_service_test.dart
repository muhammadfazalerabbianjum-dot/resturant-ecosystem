import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/feature_flags_service.dart';

void main() {
  group('FeatureFlagsService', () {
    test(
      'isEnabled returns true for default flags when flags map is empty',
      () {
        final service = FeatureFlagsService({});
        expect(service.isEnabled('smartReorder'), isTrue);
        expect(service.isEnabled('loyaltyPoints'), isTrue);
        expect(service.isEnabled('tourMode'), isTrue);
        expect(service.isEnabled('waitlist'), isTrue);
        expect(service.flags.containsKey('referrals'), isFalse);
        expect(
          service.isEnabled('referrals'),
          isFalse,
          reason:
              'D-2: `referrals` is no longer a default flag (register row '
              'F3-05) and, with no Firestore override, it fails closed',
        );
        expect(service.isEnabled('deliveryTracking'), isTrue);
        expect(service.isEnabled('promoCode'), isTrue);
      },
    );

    test('isEnabled returns false for unknown flag', () {
      final service = FeatureFlagsService({});
      expect(service.isEnabled('nonexistentFlag'), isFalse);
    });

    test(
      'isEnabled returns Firestore value when flag is overridden to true',
      () {
        final service = FeatureFlagsService({'waitlist': true});
        expect(service.isEnabled('waitlist'), isTrue);
      },
    );

    test(
      'isEnabled returns Firestore value when flag is overridden to false',
      () {
        final service = FeatureFlagsService({'waitlist': false});
        expect(service.isEnabled('waitlist'), isFalse);
      },
    );

    test('isEnabled overrides default with Firestore value', () {
      final service = FeatureFlagsService({'smartReorder': false});
      expect(service.isEnabled('smartReorder'), isFalse);
    });

    test('isEnabled handles null value in flags map', () {
      final service = FeatureFlagsService({'smartReorder': null});
      // Should fall back to default true
      expect(service.isEnabled('smartReorder'), isTrue);
    });

    test(
      'isEnabled returns false for unknown flag even when map has other flags',
      () {
        final service = FeatureFlagsService({'waitlist': false});
        expect(service.isEnabled('unknownFlag'), isFalse);
      },
    );

    test(
      'D-2: an orphan referrals key from a stale doc is tolerated (F3-05)',
      () {
        // `apps/halal_boyz/assets/client_config.json:43` still carries the
        // orphan key and `apps/**` is forbidden territory for this wave (p25
        // handoff row). A stale Firestore/config document that still ships it
        // must neither throw nor disturb the flags that ARE in the default set.
        final service = FeatureFlagsService({'referrals': true});
        expect(service.isEnabled('referrals'), isTrue);
        expect(service.isEnabled('promoCode'), isTrue);
        expect(service.isEnabled('waitlist'), isTrue);
      },
    );
  });
}
