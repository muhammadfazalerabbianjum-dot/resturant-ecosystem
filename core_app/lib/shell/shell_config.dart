/// P2-1a — the shell's build-time configuration.
///
/// Kept apart from `main.dart` so the emulator proof can construct the SAME
/// configuration the entrypoint uses, instead of a parallel copy that could
/// drift (the exact failure mode D-050 rejected a second app package for).
///
/// The web Firebase app is not registered yet (human-only console action), so
/// the values arrive through `--dart-define`. A missing one is a NAMED error,
/// never a half-configured app.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class ShellConfig {
  const ShellConfig({
    required this.apiKey,
    required this.projectId,
    required this.appId,
    required this.messagingSenderId,
    this.authDomain = '',
    this.useEmulators = false,
    this.emulatorHost = 'localhost',
    this.firestorePort = 8080,
    this.authPort = 9099,
    this.menuReadLimit = 20,
    this.emulatorSignInEmail = '',
    this.emulatorSignInPassword = '',
  });

  final String apiKey;
  final String projectId;
  final String appId;
  final String messagingSenderId;
  final String authDomain;
  final bool useEmulators;
  final String emulatorHost;
  final int firestorePort;
  final int authPort;

  /// How many rows one read may return. A counter screen shows a page, not a
  /// table; an unbounded read is a cost bug (P2-1's hard constraints).
  final int menuReadLimit;

  /// Emulator-only convenience: when both are set AND [useEmulators] is true,
  /// the shell signs itself in at boot so the emulator proof can be observed in
  /// a real browser without typing into a canvas.
  ///
  /// WHY this is not a credential leak: [autoSignIn] refuses to fire unless the
  /// build is an emulator build, and these values live in `--dart-define` for a
  /// throwaway demo project. A production build cannot reach this path.
  final String emulatorSignInEmail;
  final String emulatorSignInPassword;

  bool get autoSignIn =>
      useEmulators &&
      emulatorSignInEmail.isNotEmpty &&
      emulatorSignInPassword.isNotEmpty;

  /// The `--dart-define` values this build was compiled with.
  factory ShellConfig.fromEnvironment() => const ShellConfig(
    apiKey: String.fromEnvironment('FIREBASE_WEB_API_KEY'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    appId: String.fromEnvironment('FIREBASE_WEB_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    useEmulators: bool.fromEnvironment('USE_EMULATORS'),
    emulatorHost: String.fromEnvironment(
      'EMULATOR_HOST',
      defaultValue: 'localhost',
    ),
    firestorePort: int.fromEnvironment(
      'FIRESTORE_EMULATOR_PORT',
      defaultValue: 8080,
    ),
    authPort: int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099),
    emulatorSignInEmail: String.fromEnvironment('EMULATOR_SIGN_IN_EMAIL'),
    emulatorSignInPassword: String.fromEnvironment('EMULATOR_SIGN_IN_PASSWORD'),
  );

  /// The defines that MUST be present. Empty means the build is usable.
  List<String> get missingParameters => <String>[
    if (apiKey.isEmpty) 'FIREBASE_WEB_API_KEY',
    if (projectId.isEmpty) 'FIREBASE_PROJECT_ID',
    if (appId.isEmpty) 'FIREBASE_WEB_APP_ID',
    // firebase_core requires it (non-nullable), so a build without it cannot
    // construct FirebaseOptions at all.
    if (messagingSenderId.isEmpty) 'FIREBASE_MESSAGING_SENDER_ID',
  ];

  FirebaseOptions get firebaseOptions => FirebaseOptions(
    apiKey: apiKey,
    projectId: projectId,
    appId: appId,
    messagingSenderId: messagingSenderId,
    authDomain: authDomain.isEmpty ? null : authDomain,
  );
}
