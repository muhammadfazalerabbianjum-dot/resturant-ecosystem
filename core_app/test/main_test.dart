import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ARCH-2 T-1 (core_app boots identically) + T-3 (the 16-step init order is
/// preserved), pinned as SOURCE-CONTRACT tests on the real production files:
/// `lib/main.dart` is a THIN wrapper (all it may do is call `initCarnamaApp`
/// with the template app's inputs) and `lib/app_bootstrap.dart`'s `/// STEP
/// nn` comment block matches the REAL call-site order of the 16-step chain.
///
/// This is the test the ARCH-2 spec's T-3 row demands — not a structure
/// taste check: every order below is a boot/accepted-behavior invariant that
/// a mis-ordered refactor would silently break (e.g. schema gate AFTER
/// Firebase init would boot on defaults; a heartbeat scheduled BEFORE Isar
/// would throw).
void main() {
  group('ARCH-2 T-1: main.dart is a thin wrapper', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    test(
      'calls initCarnamaApp with the template app inputs and nothing else',
      () {
        expect(mainSource, contains('await initCarnamaApp('));
        expect(mainSource, contains('CarnamaBootstrap('));
        expect(
          mainSource,
          contains('firebaseOptions: DefaultFirebaseOptions.currentPlatform'),
        );
        expect(mainSource, contains('coreConfig: const CoreAppConfig()'));
        expect(mainSource, contains('appBuilder: () => const CoreApp()'));

        // The init chain must NOT live here anymore:
        expect(
          mainSource.contains('Firebase.initializeApp('),
          isFalse,
          reason: 'the Firebase init step lives in app_bootstrap.dart',
        );
        expect(
          mainSource.contains('LoggerService()'),
          isFalse,
          reason: 'the logger init step lives in app_bootstrap.dart',
        );
        expect(
          mainSource.contains('runApp('),
          isFalse,
          reason: 'the runApp step lives in app_bootstrap.dart',
        );
        expect(
          mainSource.contains('dotenv.load'),
          isFalse,
          reason: 'the dotenv step lives in app_bootstrap.dart',
        );
        expect(
          mainSource.contains('useAuthEmulator'),
          isFalse,
          reason: 'the emulator step lives in app_bootstrap.dart',
        );
      },
    );

    test('is thin (~50 lines, spec acceptance contract 2)', () {
      final lines = mainSource.split('\n').length;
      expect(
        lines,
        lessThanOrEqualTo(60),
        reason:
            'the pre-ARCH-2 main.dart was 519 lines; the wrapper must '
            'stay a thin facade (got $lines)',
      );
    });
  });

  group('ARCH-2 T-3: the 16-step init order is preserved', () {
    final fullSource = File('lib/app_bootstrap.dart').readAsStringSync();

    // The production chain's call sites, scoped to initCarnamaApp itself
    // (the background-handler definitions above the function are helpers,
    // not order steps).
    final scoped = fullSource.substring(
      fullSource.indexOf('Future<void> initCarnamaApp'),
    );

    // The canonical doc-block markers: `/// STEP nn` (exactly 16 lines).
    final docSteps = RegExp(
      r'^/// STEP (\d\d)\b',
      multiLine: true,
    ).allMatches(fullSource).map((m) => int.parse(m.group(1)!)).toList();

    test('the comment block documents exactly STEP 01..16', () {
      expect(
        docSteps,
        List<int>.generate(16, (i) => i + 1),
        reason:
            'the INIT ORDER block must list every step exactly once, in '
            'ascending order',
      );
    });

    // The production call-site anchor for each step (the actual code the
    // order is about). Each anchor must appear in the SOURCE REGION that
    // starts with its `// STEP nn` marker — a misplaced step fails loudly.
    const anchors = <int, String>{
      1: '_assertSafeBuildConfig();',
      2: 'FirebaseMessaging.onBackgroundMessage(',
      3: 'ErrorWidget.builder = buildGracefulErrorWidget;',
      4: 'PlatformDispatcher.instance.onError =',
      5: 'WidgetsFlutterBinding.ensureInitialized();',
      6: 'loadEnvLayer(enabled: bootstrap.loadEnv)',
      7: 'await AppConfig.loadConfig();',
      8: 'await AppTheme.loadBundledFontFamilies();',
      9: 'CoreConfigHolder.set(',
      10: 'final logger = LoggerService(',
      11: 'if (AppConfig.loadFailed)',
      12: 'final schemaError = AppConfig.schemaError;',
      13: 'firebaseKeyConfigured(options)',
      14: 'if (Firebase.apps.isEmpty)',
      15: 'await IsarService.shared().openDB();',
      16: 'runApp(',
    };

    test('each documented step call site follows its own STEP marker', () {
      for (var step = 1; step <= 16; step++) {
        final name = step.toString().padLeft(2, '0');
        final regionStart = scoped.indexOf('// STEP $name');
        expect(
          regionStart,
          isNonNegative,
          reason: 'STEP $name marker missing from initCarnamaApp',
        );

        // Step 16's region ends where initCarnamaApp ends (its runApp is
        // the LAST chain call); the others end at the next step's marker.
        final regionEnd = step < 16
            ? scoped.indexOf('// STEP ${(step + 1).toString().padLeft(2, '0')}')
            : scoped.length;
        expect(regionEnd, greaterThan(regionStart));

        final region = scoped.substring(regionStart, regionEnd);
        expect(
          region.contains(anchors[step]!),
          isTrue,
          reason:
              'STEP $step call site ("${anchors[step]}") must appear '
              'in the source region that follows its marker',
        );
      }
    });

    test('the cross-step order invariants hold in the real sequence', () {
      int at(String anchor) {
        final i = scoped.indexOf(anchor);
        expect(i, isNonNegative, reason: 'missing anchor "$anchor"');
        return i;
      }

      // logger BEFORE Firebase
      expect(
        at('final logger = LoggerService(') < at('Firebase.initializeApp('),
        isTrue,
      );
      // schema check BEFORE runApp and BEFORE Firebase
      expect(
        at('final schemaError = AppConfig.schemaError;') <
            scoped.lastIndexOf('runApp('),
        isTrue,
        reason: 'the W6.5 schema gate must precede the real app launch',
      );
      expect(
        at('final schemaError = AppConfig.schemaError;') <
            at('Firebase.initializeApp('),
        isTrue,
      );
      // error widget builder BEFORE Firebase init
      expect(
        at('ErrorWidget.builder =') < at('Firebase.initializeApp('),
        isTrue,
      );
      // W6.1 key gate BEFORE Firebase.initializeApp
      expect(
        at('firebaseKeyConfigured(options)') < at('Firebase.initializeApp('),
        isTrue,
      );
      // push AFTER FCM, consent AFTER Firebase
      expect(
        at('Firebase.initializeApp(') <
            at('PushNotificationService.initialize('),
        isTrue,
      );
      expect(
        at('Firebase.initializeApp(') < at('GdprConsentDialog.hasConsent()'),
        isTrue,
      );
      // push navigation bridge before runApp
      expect(
        at('PushNotificationService.navigationHandler =') <
            scoped.lastIndexOf('runApp('),
        isTrue,
        reason:
            'the push bridge is installed in STEP 16 before the real '
            'app launch',
      );

      // heartbeat + queue triggers AFTER Isar — STEP 15 calls
      // _startSyncQueueTriggers only after openDB() inside initCarnamaApp
      // (the shared helper's KitchenHeartbeatScheduler definition lives
      // above the function, so the CHAIN call is the ordering anchor).
      expect(
        at('await IsarService.shared().openDB();') <
            at('_startSyncQueueTriggers(logger)'),
        isTrue,
      );
    });
  });
}
