import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';

/// Pins the Isar community native core for test isolates (p34 A-fix).
///
/// `flutter test` spawns one tester process per test FILE with CWD set to the
/// package directory — NOT the workspace root — so `Isar.open`'s default
/// `initializeCoreBinary()` finds no desktop library (Windows error 126).
/// The repo-root `isar.dll` that used to mask this on the CWD search path is
/// the OLD isar 3.1.0+1 binary; the community 3.3.2 runtime REJECTS it at the
/// core-version handshake ("Incorrect Isar Core version"), so it must not be
/// loaded either.
///
/// This helper resolves `isar_community_flutter_libs` through
/// `.dart_tool/package_config.json` (the exact version pubspec.lock pinned)
/// and loads its platform binary through the PUBLIC `Isar.initializeIsarCore`
/// API. `download: false` forbids network fetches — CI uses the
/// package-shipped binary only.
Future<void> ensureIsarCoreForTests() async {
  var dir = Directory.current;
  File? configFile;
  for (var depth = 0; depth < 6; depth++) {
    final candidate = File(
      '${dir.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}package_config.json',
    );
    if (candidate.existsSync()) {
      configFile = candidate;
      break;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  if (configFile == null) {
    throw StateError(
      '.dart_tool/package_config.json not found walking up from '
      '${Directory.current.path}; run flutter pub get at the workspace root',
    );
  }

  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final packages = config['packages'] as List<dynamic>;
  String? rootUriString;
  for (final package in packages) {
    final entry = package as Map<String, dynamic>;
    if (entry['name'] == 'isar_community_flutter_libs') {
      rootUriString = entry['rootUri'] as String;
      break;
    }
  }
  if (rootUriString == null) {
    throw StateError(
      'isar_community_flutter_libs missing from ${configFile.path}; '
      'run flutter pub get at the workspace root',
    );
  }

  final rootUri = configFile.uri.resolve(rootUriString);
  final String binaryRelative;
  if (Platform.isWindows) {
    binaryRelative = 'windows/libisar.dll';
  } else if (Platform.isMacOS) {
    binaryRelative = 'macos/libisar.dylib';
  } else if (Platform.isLinux) {
    binaryRelative = 'linux/libisar.so';
  } else {
    throw StateError('Unsupported host platform: ${Platform.operatingSystem}');
  }

  final binary = File(
    '${rootUri.toFilePath()}${Platform.pathSeparator}'
    '${binaryRelative.replaceAll('/', Platform.pathSeparator)}',
  );
  if (!binary.existsSync()) {
    throw StateError('Isar core binary missing: ${binary.path}');
  }

  await Isar.initializeIsarCore(
    libraries: <Abi, String>{Abi.current(): binary.path},
    download: false,
  );
}
