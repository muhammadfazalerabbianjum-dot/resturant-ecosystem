import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

/// RELEASE-1 / W11.3 typography guard (audit 08-P2-2): a non-`System`
/// `fontFamily` in the client config must be a REGISTERED bundled font —
/// otherwise an explicit loadError entry is recorded and the built-in type
/// system is used (NEVER a silent fallback).
void main() {
  group('AppTheme typography guard (T-4)', () {
    tearDown(AppTheme.resetFontGuardForTest);

    test('System fontFamily resolves to the built-in type system silently', () {
      AppTheme.setBundledFontFamiliesForTest({'CarnamaSans'});
      expect(AppTheme.resolveFontFamily('System'), isNull);
      expect(AppTheme.fontLoadError, isNull);

      final theme = AppTheme.buildTheme(<String, dynamic>{
        'typography': {'fontFamily': 'System'},
      });
      expect(AppTheme.fontLoadError, isNull);
      expect(theme.textTheme.bodyMedium?.fontFamily, 'System');
    });

    test('registered bundled family resolves without an error', () {
      AppTheme.setBundledFontFamiliesForTest({'CarnamaSans'});
      expect(AppTheme.resolveFontFamily('CarnamaSans'), 'CarnamaSans');
      expect(AppTheme.fontLoadError, isNull);

      AppTheme.buildTheme(<String, dynamic>{
        'typography': {'fontFamily': 'CarnamaSans'},
      });
      expect(AppTheme.fontLoadError, isNull);
      // The guard applied no error; in the offline-safe test environment the
      // family itself is not applied (never loaded), but the guard verdict —
      // the contract under test — is "registered -> accepted".
      expect(AppTheme.resolveFontFamily('CarnamaSans'), 'CarnamaSans');
    });

    test('unregistered family -> explicit loadError entry + fallback', () {
      AppTheme.setBundledFontFamiliesForTest({'CarnamaSans'});

      final theme = AppTheme.buildTheme(<String, dynamic>{
        'typography': {'fontFamily': 'Comic Sans MS'},
      });

      expect(AppTheme.fontLoadError, contains('"Comic Sans MS"'));
      expect(
        AppTheme.fontLoadError,
        contains('is not a registered bundled font'),
      );
      // Never silently applied: the theme falls back to the built-in type
      // system instead of the unregistered family.
      expect(theme.textTheme.bodyMedium?.fontFamily, 'System');
    });

    test('dark theme follows the same guard', () {
      AppTheme.setBundledFontFamiliesForTest({'CarnamaSans'});

      final theme = AppTheme.buildDarkTheme(<String, dynamic>{
        'typography': {'fontFamily': 'Ghost Font'},
      });

      expect(AppTheme.fontLoadError, contains('Ghost Font'));
      expect(theme.textTheme.headlineMedium?.fontFamily, 'System');
    });

    test('a later clean build clears a previous loadError', () {
      AppTheme.setBundledFontFamiliesForTest({'CarnamaSans'});
      AppTheme.buildTheme(<String, dynamic>{
        'typography': {'fontFamily': 'Ghost Font'},
      });
      expect(AppTheme.fontLoadError, isNotNull);

      AppTheme.buildTheme(const <String, dynamic>{});
      expect(AppTheme.fontLoadError, isNull);
    });

    test('loadBundledFontFamilies parses real FontManifest JSON', () async {
      await AppTheme.loadBundledFontFamilies(
        readAsset: (_) async =>
            '[{"family": "CarnamaSans", "fonts": []}, '
            '{"family": "CarnamaSerif", "fonts": []}]',
      );
      expect(
        AppTheme.bundledFontFamilies,
        containsAll(<String>['CarnamaSans', 'CarnamaSerif']),
      );
      expect(AppTheme.resolveFontFamily('CarnamaSans'), 'CarnamaSans');
      expect(AppTheme.fontLoadError, isNull);
      expect(AppTheme.resolveFontFamily('Nope'), isNull);
      expect(AppTheme.fontLoadError, contains('Nope'));
    });

    test(
      'malformed manifest fails closed: unknown family -> loadError',
      () async {
        await AppTheme.loadBundledFontFamilies(
          readAsset: (_) async => '{"family": "not-a-list"}',
        );
        expect(AppTheme.bundledFontFamilies, isEmpty);
        expect(AppTheme.resolveFontFamily('CarnamaSans'), isNull);
        expect(AppTheme.fontLoadError, contains('CarnamaSans'));
      },
    );

    test('empty registry (manifest not loaded) fails closed, never silent', () {
      // Pristine state: no manifest loaded, no seed. An unregistered family
      // must still produce the explicit loadError, not a silent fallback.
      expect(AppTheme.resolveFontFamily('Roboto'), isNull);
      expect(AppTheme.fontLoadError, contains('Roboto'));
      expect(AppTheme.fontLoadError, contains('has not been loaded yet'));
    });
  });
}
