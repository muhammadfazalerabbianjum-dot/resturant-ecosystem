import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';

/// Pins the Isar community native core for core_app test isolates.
///
/// Deliberately mirrors `packages/core/test/helpers/isar_native.dart` (test
/// helpers are not importable across packages). `flutter test` sets each
/// tester's CWD to this package dir, so `Isar.open`'s default library lookup
/// finds nothing (Windows error 126); the repo-root `isar.dll` is the OLD
/// 3.1.0+1 binary which the 3.3.2 runtime rejects at the version handshake.
/// Resolution goes through `.dart_tool/package_config.json` → the
/// lockfile-pinned `isar_community_flutter_libs` binary. No network
/// (`download: false`). p34 A-fix.
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
