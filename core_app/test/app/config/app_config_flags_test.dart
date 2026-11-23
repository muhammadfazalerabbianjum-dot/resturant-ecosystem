import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/app_config.dart';

/// WL-1 T-4: with the flattened `features.flags` format ("flagName": bool),
/// the REAL config parser produces a NON-EMPTY featureFlags map from the REAL
/// bundled template asset. Before WL-1 the config shipped object-valued flags
/// ({"enabled": true}) which this parser drops, leaving featureFlags == {}
/// and making flag gating silently inert (P0-WL-2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppConfig.loadConfig parses the real template config into non-empty '
      'bool flags', () async {
    await AppConfig.loadConfig();

    expect(
      AppConfig.loadFailed,
      isFalse,
      reason: 'the template asset must parse',
    );
    final flags = AppConfig.featureFlags;
    expect(flags, isNotEmpty);
    for (final value in flags.values) {
      expect(value, isA<bool>());
    }

    // unknownFlagDefault fallback (never crash, fail-closed): a flag that
    // is in neither the config map nor any known set resolves to
    // features.unknownFlagDefault (false in the template config).
    expect(AppConfig.featureFlagDefault, isFalse);
    expect(AppConfig.featureEnabled('flagThatDoesNotExist'), isFalse);
  });
}
