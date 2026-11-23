import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

const String _clientConfigAsset = 'assets/client_config.json';

/// Documented placeholder fragments (mirrors the generator's validate()
/// gate, W6.1). A shell must never boot Firebase with a placeholder
/// credential, so the same vocabulary is rejected at runtime.
final RegExp _placeholderKeyPattern = RegExp(
  'REPLACE_ME|changeme|<your',
  caseSensitive: false,
);

/// The result of loading `assets/client_config.json`.
///
/// [config] is the decoded JSON object, or the empty map (the shell's
/// in-code defaults layer — every downstream consumer carries its own safe
/// fallbacks) when the asset is missing or malformed. [error] is the
/// recorded load error, or null on success (W6.3).
typedef LoadedClientConfig = ({Map<String, dynamic> config, Object? error});

/// Reads `assets/client_config.json` WITHOUT ever throwing (W6.3: core's
/// try/catch fallback pattern). A missing/malformed asset degrades to the
/// defaults layer with the error recorded, so the boot path can fail CLOSED
/// with an honest error screen instead of crashing.
Future<LoadedClientConfig> loadClientConfig({
  Future<String> Function(String assetKey)? readAsset,
}) async {
  try {
    final reader = readAsset ?? rootBundle.loadString;
    final raw = await reader(_clientConfigAsset);
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return (config: decoded, error: null);
    }
    return (
      config: const <String, dynamic>{},
      error: StateError(
        'client_config.json: root must be a JSON object, '
        'got ${decoded.runtimeType}',
      ),
    );
  } catch (error) {
    return (config: const <String, dynamic>{}, error: error);
  }
}

/// True when the platform's Firebase API key is present and is not a
/// documented placeholder (W6.1 shell fail-fast gate) — evaluated against
/// the RAW config map (the resolved FirebaseOptions are merged by the
/// shared bootstrap, which delegates this same vocabulary check).
bool firebaseKeyConfigured(Map<String, dynamic> config) {
  final environment = config['environment'];
  if (environment is! Map<String, dynamic>) {
    return false;
  }
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final key =
      environment[isAndroid ? 'firebaseAndroidApiKey' : 'firebaseIosApiKey'];
  return key is String &&
      key.trim().isNotEmpty &&
      !_placeholderKeyPattern.hasMatch(key);
}
