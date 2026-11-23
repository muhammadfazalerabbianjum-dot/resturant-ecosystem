// ignore_for_file: unnecessary_brace_in_string_interps
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// BACKEND-1 (W7.1, 09-P0-FB-1): the generator's per-client backend bundle.
///
/// - T-1: `writeBackendBundle` writes firestore.rules / storage.rules /
///   firestore.indexes.json / .firebaserc / firebase.json into a scratch app.
/// - T-2: `.firebaserc` wires `projects.default = <config firebase.projectId>`.
/// - T-3: the scratch app's platform identity is consistent
///   (applicationId == pbxproj == config bundleId, checked by the generator's
///   own post-generation checker).
/// - T-4: the deploy runbook (`docs/CLIENT_BACKEND_RUNBOOK.md`) covers every
///   master Â§12 VERIFY-IN-CONSOLE item.
/// - T-6: `alignReleaseSigningGate` re-applies the RELEASE-1 signing gate to a
///   stock `flutter create` baseline byte-identically to the shipped gradle
///   (F-AUD2-15: regeneration can no longer revert it).
void main() {
  const bundleId = 'labs.scratch.client';
  const projectId = 'scratch-project-1234';
  late Directory tempDir;
  late Directory repoRoot;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('whitelabel_backend_');
    repoRoot = _findRepoRoot();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Directory scratchApp() {
    final app = Directory(
      '${tempDir.path}${Platform.pathSeparator}scratch_app',
    );
    // Build the minimal generated-app platform skeleton the identity checker
    // reads (same fixture shape as the WL-2 identity test).
    final sep = Platform.pathSeparator;
    File(
      '${app.path}${sep}android${sep}app${sep}build.gradle.kts',
    ).parent.createSync(recursive: true);
    File(
      '${app.path}${sep}android${sep}app${sep}build.gradle.kts',
    ).writeAsStringSync('applicationId = "$bundleId"\n');
    File(
      '${app.path}${sep}android${sep}app${sep}src${sep}main'
      '${sep}AndroidManifest.xml',
    ).parent.createSync(recursive: true);
    File(
      '${app.path}${sep}android${sep}app${sep}src${sep}main'
      '${sep}AndroidManifest.xml',
    ).writeAsStringSync(
      '<manifest><application android:label="Scratch Client">'
      '</application></manifest>\n',
    );
    File(
      '${app.path}${sep}ios${sep}Runner.xcodeproj${sep}project.pbxproj',
    ).parent.createSync(recursive: true);
    File(
      '${app.path}${sep}ios${sep}Runner.xcodeproj${sep}project.pbxproj',
    ).writeAsStringSync(
      'PRODUCT_BUNDLE_IDENTIFIER = $bundleId;\n'
      'PRODUCT_BUNDLE_IDENTIFIER = $bundleId.RunnerTests;\n',
    );
    File(
      '${app.path}${sep}ios${sep}Runner${sep}Info.plist',
    ).parent.createSync(recursive: true);
    File('${app.path}${sep}ios${sep}Runner${sep}Info.plist').writeAsStringSync(
      '<dict>\n\t<key>CFBundleDisplayName</key>\n'
      '\t<string>Scratch Client</string>\n</dict>\n',
    );
    return app;
  }

  group('T-1: backend bundle files written', () {
    test('writes all 5 bundle files into apps/<scratch>/backend/', () {
      final app = scratchApp();
      final sep = Platform.pathSeparator;
      final files = whitelabel.writeBackendBundle(
        appPath: app.path,
        repoRoot: repoRoot,
        projectId: projectId,
      );

      for (final name in const <String>[
        'firestore.rules',
        'storage.rules',
        'firestore.indexes.json',
        '.firebaserc',
        'firebase.json',
      ]) {
        final path = '${app.path}${sep}backend${sep}$name';
        expect(
          File(path).existsSync(),
          isTrue,
          reason: 'expected $name at $path',
        );
        expect(files, contains(path));
      }
    });

    test('bundle copies are byte-identical template copies', () {
      final app = scratchApp();
      final sep = Platform.pathSeparator;
      whitelabel.writeBackendBundle(
        appPath: app.path,
        repoRoot: repoRoot,
        projectId: projectId,
      );
      final template = '${repoRoot.path}${sep}core_app';
      for (final name in const <String>[
        'firestore.rules',
        'storage.rules',
        'firestore.indexes.json',
      ]) {
        expect(
          File('${app.path}${sep}backend${sep}$name').readAsStringSync(),
          File('$template${sep}$name').readAsStringSync(),
          reason: '$name must be a byte-identical copy of the template',
        );
      }
    });

    test(
      'indexes bundle carries the W3.6 orders(status, createdAt) composite',
      () {
        final app = scratchApp();
        final sep = Platform.pathSeparator;
        whitelabel.writeBackendBundle(
          appPath: app.path,
          repoRoot: repoRoot,
          projectId: projectId,
        );
        final indexes =
            jsonDecode(
                  File(
                    '${app.path}${sep}backend${sep}firestore.indexes.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final hasComposite = (indexes['indexes'] as List).any((entry) {
          if (entry is! Map) return false;
          final fields = (entry['fields'] as List? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map((f) => '${f['fieldPath']}:${f['order']}')
              .toList();
          return entry['collectionGroup'] == 'orders' &&
              fields.contains('status:ASCENDING') &&
              fields.contains('createdAt:ASCENDING');
        });
        expect(hasComposite, isTrue, reason: 'W3.6 composite must be shipped');
      },
    );
  });

  group('T-2: projectId wired into .firebaserc + firebase.json', () {
    test('projects.default == config firebase.projectId', () {
      final app = scratchApp();
      final sep = Platform.pathSeparator;
      whitelabel.writeBackendBundle(
        appPath: app.path,
        repoRoot: repoRoot,
        projectId: projectId,
      );
      final firebaserc =
          jsonDecode(
                File(
                  '${app.path}${sep}backend${sep}.firebaserc',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(
        ((firebaserc['projects'] as Map<String, dynamic>)['default']),
        projectId,
      );
    });

    test('firebase.json points at the SHARED core_app/functions', () {
      final app = scratchApp();
      final sep = Platform.pathSeparator;
      whitelabel.writeBackendBundle(
        appPath: app.path,
        repoRoot: repoRoot,
        projectId: projectId,
      );
      final firebaseJson =
          jsonDecode(
                File(
                  '${app.path}${sep}backend${sep}firebase.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(
        (firebaseJson['functions'] as Map<String, dynamic>)['source'],
        '../../core_app/functions',
      );
      expect(
        ((firebaseJson['functions'] as Map<String, dynamic>)['predeploy']
            as List),
        contains('npm --prefix "\$RESOURCE_DIR" run build'),
      );
      expect(
        (firebaseJson['firestore'] as Map<String, dynamic>)['rules'],
        'firestore.rules',
      );
      expect(
        (firebaseJson['firestore'] as Map<String, dynamic>)['indexes'],
        'firestore.indexes.json',
      );
      expect(
        (firebaseJson['storage'] as Map<String, dynamic>)['rules'],
        'storage.rules',
      );
    });

    test('empty projectId throws (fail-closed, mirrors W6.1 gate)', () {
      final app = scratchApp();
      expect(
        () => whitelabel.writeBackendBundle(
          appPath: app.path,
          repoRoot: repoRoot,
          projectId: '',
        ),
        throwsArgumentError,
      );
    });
  });

  group('T-3: identity check on the scratch app', () {
    test('applicationId == pbxproj == config bundleId', () {
      final app = scratchApp();
      final sep = Platform.pathSeparator;
      whitelabel.writeBackendBundle(
        appPath: app.path,
        repoRoot: repoRoot,
        projectId: projectId,
      );
      expect(whitelabel.generatedIdentityErrors(app.path, bundleId), isEmpty);
      // And the bundle survives the check untouched.
      expect(
        File('${app.path}${sep}backend${sep}.firebaserc').existsSync(),
        isTrue,
      );
    });
  });

  group('T-4: runbook completeness vs master Â§12', () {
    test('runbook covers every Â§12 VERIFY-IN-CONSOLE item', () {
      final sep = Platform.pathSeparator;
      final runbook = File(
        '${repoRoot.path}${sep}docs${sep}CLIENT_BACKEND_RUNBOOK.md',
      );
      expect(runbook.existsSync(), isTrue, reason: 'runbook must exist');
      final text = runbook.readAsStringSync();

      // Every Â§12 item must appear in the coverage table.
      for (var i = 1; i <= 8; i++) {
        expect(
          text,
          contains('| 12.$i |'),
          reason: 'Â§12.$i must be represented in the coverage table',
        );
      }
      // Mandatory ordered ops + alerting-pipeline anchors (acceptance
      // contract item 3 + master Â§12.6/Â§12.8).
      for (final anchor in const <String>[
        'App Check',
        'Blaze',
        'stripeWebhook',
        'firestore-security-alerts',
        'protoPayload.status.code=7',
        'admin_pin',
        'force-update',
        'v002',
        'v003',
        'migrations',
        'deploy:backend',
        'STRIPE_SECRET_KEY',
        'STRIPE_WEBHOOK_SECRET',
      ]) {
        expect(
          text,
          contains(anchor),
          reason: 'runbook must mention "$anchor"',
        );
      }
    });
  });

  group(
    'T-5: shipped halal_boyz backend bundle parity vs core_app template',
    () {
      test(
        'shipped rules and indexes are byte-identical to core_app templates',
        () {
          final sep = Platform.pathSeparator;
          final template = '${repoRoot.path}${sep}core_app';
          final shipped =
              '${repoRoot.path}${sep}apps${sep}halal_boyz${sep}backend';
          for (final name in const <String>[
            'firestore.rules',
            'storage.rules',
            'firestore.indexes.json',
          ]) {
            final templateFile = File('$template${sep}$name');
            final shippedFile = File('$shipped${sep}$name');
            expect(
              templateFile.existsSync(),
              isTrue,
              reason: 'template file $templateFile must exist',
            );
            expect(
              shippedFile.existsSync(),
              isTrue,
              reason: 'shipped file $shippedFile must exist',
            );
            expect(
              shippedFile.readAsStringSync(),
              templateFile.readAsStringSync(),
              reason:
                  'apps/halal_boyz/backend/$name must be byte-identical to '
                  'core_app/$name',
            );
          }
        },
      );
    },
  );

  group('T-6: RELEASE-1 signing gate regeneration parity (F-AUD2-15)', () {
    // Exact stock `flutter create` baseline captured by AUD-2
    // (tool_audit/aud2/c11_gradle_diff.txt, emit=1199B) - before the generator
    // applied any gate: debug-key release signing, Java 17, no desugaring.
    const stockBaseline = r'''plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "labs.carnama.halal_boyz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "labs.carnama.halalboys"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
''';

    final sep = Platform.pathSeparator;

    File stockGradleFile() {
      final app = Directory('${tempDir.path}${sep}stock_app');
      final file = File(
        '${app.path}${sep}android${sep}app${sep}build.gradle.kts',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(stockBaseline);
      return file;
    }

    File shippedGradleFile() => File(
      '${repoRoot.path}${sep}apps${sep}halal_boyz${sep}android${sep}app'
      '${sep}build.gradle.kts',
    );

    test('gate regeneration is byte-identical to the shipped gradle', () {
      final file = stockGradleFile();
      whitelabel.alignReleaseSigningGate(
        appPath: file.parent.parent.parent.path,
      );
      expect(
        file.readAsStringSync().replaceAll('\r\n', '\n'),
        shippedGradleFile().readAsStringSync().replaceAll('\r\n', '\n'),
        reason:
            'the generator must re-emit apps/halal_boyz/android/app/'
            'build.gradle.kts byte-for-byte (F-AUD2-15 drift closed)',
      );
    });

    test('a second run leaves the gated file byte-untouched (idempotent)', () {
      final file = stockGradleFile();
      final appPath = file.parent.parent.parent.path;
      whitelabel.alignReleaseSigningGate(appPath: appPath);
      final first = file.readAsStringSync();
      whitelabel.alignReleaseSigningGate(appPath: appPath);
      expect(file.readAsStringSync(), first);
    });

    test('output carries the fail-closed gate and never debug signing', () {
      final file = stockGradleFile();
      whitelabel.alignReleaseSigningGate(
        appPath: file.parent.parent.parent.path,
      );
      final text = file.readAsStringSync();
      for (final marker in const <String>[
        '_releaseSigningKeys',
        'signingConfigs.getByName("release")',
        'isCoreLibraryDesugaringEnabled = true',
        'coreLibraryDesugaring(',
      ]) {
        expect(
          text,
          contains(marker),
          reason: 'missing RELEASE-1 gate marker "$marker"',
        );
      }
      expect(
        text,
        isNot(contains('signingConfigs.getByName("debug")')),
        reason: 'a release build must never be debug-signed (RELEASE-1)',
      );
    });

    test('throws when the flutter create baseline no longer matches', () {
      final file = stockGradleFile();
      file.writeAsStringSync(
        stockBaseline.replaceFirst(
          '            signingConfig = signingConfigs.getByName("debug")\n',
          '',
        ),
      );
      expect(
        () => whitelabel.alignReleaseSigningGate(
          appPath: file.parent.parent.parent.path,
        ),
        throwsStateError,
        reason: 'fail-closed: an unrecognised baseline must stop the generator',
      );
    });

    test('throws on a half-applied gate instead of shipping it', () {
      final file = stockGradleFile();
      file.writeAsStringSync('val _releaseSigningKeys = listOf("storeFile")\n');
      expect(
        () => whitelabel.alignReleaseSigningGate(
          appPath: file.parent.parent.parent.path,
        ),
        throwsStateError,
        reason: 'a partially gated shell must never ship (fail-closed)',
      );
    });
  });
}

Directory _findRepoRoot() {
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    final sep = Platform.pathSeparator;
    final pubspec = File('${dir.path}${sep}pubspec.yaml');
    final core = Directory('${dir.path}${sep}packages${sep}core');
    if (pubspec.existsSync() && core.existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('repo root not found from ${Directory.current.path}');
}
