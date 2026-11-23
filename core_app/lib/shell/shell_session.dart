/// P2-1a — the shell's composition root, separated from its UI.
///
/// WHY: the card's proof is "boots, signs in, reports the tenant claim, and one
/// bounded read returns THAT tenant's rows". Those facts are printed by this
/// class as a boot trace (D-058) and can be asked of the emulators from outside
/// (`node tool/shell_proof.mjs verify`), so neither the UI nor a test file needs
/// to re-implement the boot to prove it.
// The deep `package:core/src/...` imports below are D-050's requirement (use
// individual core modules, never the barrel). See main.dart's note.
// ignore_for_file: implementation_imports
library;

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:core/src/auth/auth_repository.dart'
    show
        AuthRepository,
        authRepositoryProvider,
        createPlatformAuthRepository,
        usePlatformAuthEmulator;
import 'package:core/src/cache/local_cache.dart' show NoOpLocalCache;
import 'package:core/src/error_logger/logger_provider.dart' show loggerProvider;
import 'package:core/src/error_logger/logger_service.dart' show LoggerService;
import 'package:core/src/network/firestore_client.dart' show FirestoreClient;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/app/tenancy/tenant_claim.dart' show tenantClaimProvider;

import 'shell_config.dart';

/// One row of the bounded menu read.
class ShellMenuRow {
  const ShellMenuRow({
    required this.id,
    required this.name,
    required this.priceCents,
  });

  final String id;
  final String name;
  final int? priceCents;
}

/// Everything the shell's one screen needs, resolved ONCE per sign-in: the
/// tenant claim and that tenant's first page of rows.
///
/// WHY one object instead of two futures in the widget tree: the read must
/// happen at BOOT, not when a frame happens to build. A browser tab that is
/// hidden throttles frames to zero, and a screen that only fetches in `build`
/// then never fetches at all (measured: the console trace stopped at `claim`).
/// Prefetching is also the right counter behaviour: the screen opens with data.
class ShellSnapshot {
  const ShellSnapshot({required this.tenantId, required this.rows});

  final String? tenantId;
  final List<ShellMenuRow> rows;

  bool get hasTenant => tenantId != null && tenantId!.isNotEmpty;
}

class ShellSession {
  ShellSession._(this._container, this._config, this._db, this._logger);

  final ProviderContainer _container;
  final ShellConfig _config;

  /// The same Firestore handle the container's repositories use, kept here so
  /// the read below has one dependency that tests could substitute.
  final FirebaseFirestore _db;
  final LoggerService _logger;

  ProviderContainer get container => _container;

  AuthRepository get auth => _container.read(authRepositoryProvider);

  /// Boots Firebase, points it at the emulator when asked, and builds the ONE
  /// composition root this shell has (the same provider seams the mobile app
  /// overrides — only the cache differs: this shell holds no rows, so it states
  /// `NoOpLocalCache` explicitly rather than silently skipping the wipe).
  static Future<ShellSession> boot(ShellConfig config) async {
    _trace('boot: initializeApp');
    await Firebase.initializeApp(options: config.firebaseOptions);
    _trace('boot: app ready');

    if (config.useEmulators) {
      // The SDK-level emulator switches. Both are no-ops against production.
      await usePlatformAuthEmulator(config.emulatorHost, config.authPort);
      _trace('boot: auth emulator bound');
      FirestoreClient.instance.db.useFirestoreEmulator(
        config.emulatorHost,
        config.firestorePort,
      );
      _trace('boot: firestore emulator bound');
    }

    final logger = LoggerService();
    await logger.init();
    _trace('boot: logger ready');

    final container = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithValue(logger),
        authRepositoryProvider.overrideWith(
          (ref) => createPlatformAuthRepository(
            firestore: FirestoreClient.instance.db,
            logger: logger,
            cache: const NoOpLocalCache(),
          ),
        ),
      ],
    );

    _trace('boot: container built');
    return ShellSession._(
      container,
      config,
      FirestoreClient.instance.db,
      logger,
    );
  }

  Future<void> signIn(String email, String password) async {
    _trace('signIn: begin');
    _snapshot = null; // a different user is a different tenant
    await auth.signInWithEmailAndPassword(email, password);
    _trace('signIn: done ${auth.currentUser?.email}');
  }

  ShellSnapshot? _resolved;
  Future<ShellSnapshot>? _snapshot;

  /// The already-resolved snapshot, if [snapshot] finished. Lets the UI render
  /// synchronously instead of flashing a spinner over data it already has.
  ShellSnapshot? get resolved => _resolved;

  /// Claim, then ONE bounded tenant-scoped read. Cached until the next sign-in.
  Future<ShellSnapshot> snapshot() => _snapshot ??= _loadSnapshot();

  Future<ShellSnapshot> _loadSnapshot() async {
    // Named `claim`, not `tenantId`: the method of that name would shadow it.
    final claim = await tenantId();
    if (claim == null || claim.isEmpty) {
      // Fail closed: no claim means `tenantOk()` denies everything, so the read
      // is not even attempted.
      return _resolved = ShellSnapshot(tenantId: claim, rows: const []);
    }
    try {
      final rows = await menuRows(claim);
      return _resolved = ShellSnapshot(tenantId: claim, rows: rows);
    } catch (e, stack) {
      // Law 11: a failed read is recorded, never only rendered. The UI still
      // gets the failure — the log does not replace the message on screen.
      await _logger.error(e, 'shell_menu_read', stack: stack);
      rethrow;
    }
  }

  Future<void> signOut() async {
    _snapshot = null;
    _resolved = null;
    await auth.signOut();
  }

  String? get signedInEmail => auth.currentUser?.email;

  /// The tenant claim, FORCE-REFRESHED: a session that cached a claim set before
  /// the token was minted would report null and deny every write downstream.
  Future<String?> tenantId() async {
    _trace('claim: reading');
    final id = await _container
        .read(tenantClaimProvider)
        .read(forceRefresh: true);
    _trace('claim: $id');
    return id;
  }

  /// ONE bounded read, scoped to the caller's tenant.
  ///
  /// WHY the `where` clause is not optional: Firestore rules are filters only
  /// in appearance. `allow read: if tenantOk()` compares `resource.data`, so an
  /// unconstrained collection query cannot be proven safe and is rejected with
  /// `permission-denied` — the query must carry the constraint the rule tests.
  /// (Measured: the unconstrained version failed in the emulator proof.)
  Future<List<ShellMenuRow>> menuRows(String tenantId) async {
    final watch = Stopwatch()..start();
    final snapshot = await _db
        .collection('menus')
        .where('tenantId', isEqualTo: tenantId)
        .limit(_config.menuReadLimit)
        .get();
    _trace(
      'read: ${snapshot.docs.length} row(s) in ${watch.elapsedMilliseconds}ms '
      'for $tenantId → ${snapshot.docs.map((d) => d.data()['name']).toList()}',
    );
    return [
      for (final doc in snapshot.docs)
        ShellMenuRow(
          id: doc.id,
          name: (doc.data()['name'] as String?) ?? doc.id,
          priceCents: _asInt(doc.data()['priceCents']),
        ),
    ];
  }

  /// Firestore hands back `int` for integer fields, but a legacy row may carry a
  /// whole-number `double`; anything else (string, Timestamp, null, a fractional
  /// double) is "unknown", never a guess.
  static int? _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is double && raw.isFinite && raw == raw.roundToDouble()) {
      return raw.round();
    }
    return null;
  }
}

/// Boot-phase tracing. Kept because a silent boot is undebuggable: the web shell
/// has no log file, so the console IS the only place a boot can be witnessed.
void _trace(String message) {
  // ignore: avoid_print
  print('[shell] $message');
}
