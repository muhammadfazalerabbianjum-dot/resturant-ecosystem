import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/src/cache/isar_schemas.dart';
import 'package:core/src/error_logger/logger_service.dart';
import 'package:core/src/network/firestore_client.dart';
import 'package:core/src/network/sync_queue.dart';

/// W8.9 (02-P2): on-device schema version of the Isar collections.
///
/// Bump this int whenever a `@collection` class in `isar_schemas.dart` changes
/// shape (property added/removed/retyped). On the next launch the version gate
/// in [IsarService._openFresh] detects the mismatch with the persisted pref
/// and surgically wipes the RESYNCABLE cache collections (menu items + carts)
/// — never the pending-operations/dead-letter queues — so the app resyncs
/// instead of crashing at `Isar.open` (the audit-02 SchemaException failure).
/// Fresh installs (no pref) adopt [kIsarSchemaVersion] without wiping: the
/// shipped schema IS this version's schema.
const int kIsarSchemaVersion = 1;

/// SharedPreferences key holding the on-device [kIsarSchemaVersion].
const String kIsarSchemaVersionPref = 'isar_schema_version';

class IsarService {
  /// W8.9 (04-P2-8): memoized shared services keyed by instance name.
  ///
  /// This replaces the old eager `_instance` singleton. The DOUBLE-OPEN RACE
  /// it removes: previously EVERY `IsarService()` construction ran
  /// `openDB()` in the constructor, and `openDB`'s guard
  /// (`Isar.instanceNames.isEmpty`) is TOCTOU-racy — two constructions
  /// back-to-back both observed an empty registry before either `Isar.open`
  /// resolved, and Isar's own `_checkOpen` made the loser throw
  /// `IsarError('Instance has already been opened.')` with that error
  /// PERMANENTLY memoized in the loser's `db` future (Isar 3.1.0+1,
  /// isar.dart:61-63). Now the open happens LAZILY (on first `db` read),
  /// is memoized per service, and every production call site resolves to
  /// the SAME [shared] service per name, so at most one open ever races.
  static final Map<String, IsarService> _shared = <String, IsarService>{};

  /// Returns the memoized shared [IsarService] for [name].
  ///
  /// THE unified public construction path (W8.9): every production call site
  /// must use this — never a bare generative `IsarService()`, which is
  /// reserved for test doubles that override `db` (they bypass opening
  /// entirely). The memoization plus the [Isar.getInstance] backstop inside
  /// [openDB] make a double-open impossible: even a stray duplicate service
  /// object returns the already-open Isar instead of crashing.
  factory IsarService.shared({String name = Isar.defaultName}) {
    return _shared.putIfAbsent(name, () => IsarService._(name));
  }

  final String instanceName;
  final LoggerService _logger;

  /// The memoized open future. `null` until first [db] read — the LAZY open
  /// that removes the constructor double-open race (see [shared]).
  Future<Isar>? _dbFuture;

  /// Set once per service instance when a schema recovery wipe has already
  /// been attempted, so a persistently-broken store cannot loop
  /// wipe→open→fail→wipe forever (fail-closed after one recovery).
  bool _recoveryAttempted = false;

  IsarService._(this.instanceName)
    : _logger = LoggerService(),
      _directoryOverride = null;

  // Cache limits
  static const int kMaxMenuItems = 500;
  static const int kMaxPendingOps = 100;
  static const Duration kMenuTtl = Duration(hours: 24);
  static const Duration kCartTtl = Duration(days: 7);

  /// Test constructor. With [dbFuture] the service never touches the real
  /// filesystem (the future is served directly); without one the lazy open
  /// applies and the service behaves like production — with [name] and
  /// [directoryOverride] replacing the production instance name and the
  /// `path_provider` documents directory (W8.9 T-3: real-Isar schema-version
  /// gate tests run against a temp directory without platform channels).
  IsarService.forTesting([
    Future<Isar>? dbFuture,
    LoggerService? logger,
    String? name,
    String? directoryOverride,
  ]) : instanceName = name ?? Isar.defaultName,
       _logger = logger ?? LoggerService(),
       _directoryOverride = directoryOverride {
    if (dbFuture != null) {
      _dbFuture = dbFuture;
    }
  }

  /// Test-only directory replacement for [openDB] (null = production
  /// `path_provider` resolution).
  final String? _directoryOverride;

  /// Test constructor wrapping an ALREADY-OPEN Isar (e.g. an in-memory
  /// instance created by the test itself). Equivalent to
  /// `IsarService.forTesting(Future.value(isar))`.
  factory IsarService.forTestingWithIsar(Isar isar, [LoggerService? logger]) =>
      IsarService.forTesting(Future.value(isar), logger);

  /// The open Isar instance, opening lazily on first read.
  ///
  /// The future is memoized, so concurrent readers await ONE open. Test
  /// doubles may either override the getter or ASSIGN this property.
  Future<Isar> get db {
    var future = _dbFuture;
    if (future == null) {
      future = openDB();
      _dbFuture = future;
    }
    return future;
  }

  set db(Future<Isar> value) => _dbFuture = value;

  /// Opens (or attaches to) the Isar instance for [instanceName].
  ///
  /// Idempotent and race-safe:
  ///  1. Backstop — if the instance is ALREADY open in this process
  ///     ([Isar.getInstance]), return it (heals even a stray duplicate
  ///     service object; W8.9 keeps this guard as backstop).
  ///  2. Otherwise open with the full schema set + the W8.9 schema-version
  ///     gate and TTL eviction.
  ///  3. If the open fails with a SCHEMA-classified error (store written by
  ///     an incompatible/foreign schema — the audit-02 brick), wipe this
  ///     instance's files and retry ONCE, loudly logged. Any other error
  ///     rethrows unchanged (fail-closed).
  Future<Isar> openDB() async {
    try {
      final existing = Isar.getInstance(instanceName);
      if (existing != null) {
        return existing;
      }
      final dirPath =
          _directoryOverride ?? (await getApplicationDocumentsDirectory()).path;
      try {
        return await _openFresh(dirPath);
      } catch (e, stack) {
        // Self-heal the residual construction race: if the loser of a
        // concurrent open hit Isar's 'already been opened' guard, the
        // winner's instance is registered by now — return it.
        final raced = Isar.getInstance(instanceName);
        if (raced != null &&
            e is IsarError &&
            e.message.contains('already been opened')) {
          return raced;
        }
        if (_recoveryAttempted || !_isSchemaRecoverable(e)) {
          rethrow;
        }
        _recoveryAttempted = true;
        // W8.9 (02-P2): loud, greppable recovery log — the store on disk was
        // written by an incompatible schema and cannot be opened at all. The
        // ONLY possible recovery is deleting this instance's files and
        // starting fresh: cache collections resync from Firestore; the
        // pending-operation queue is part of the SAME file and is lost with
        // it (logged here). The deterministic version gate in [_openFresh]
        // is the path that PRESERVES pending ops when the schema change is
        // known (our own version bump).
        await _logger.error(
          e,
          'IsarService_SCHEMA_RECOVERY_file_wipe (instance: $instanceName)',
          stack: stack,
        );
        await wipeAndReopen(directory: dirPath);
        return await _openFresh(dirPath);
      }
    } catch (e, stack) {
      await _logger.error(e, 'IsarService_openDB failed', stack: stack);
      rethrow;
    }
  }

  /// Opens the instance and applies the schema-version gate + TTL eviction.
  Future<Isar> _openFresh(String directory) async {
    final isar = await Isar.open(
      [
        IsarMenuItemSchema,
        IsarCartSchema,
        IsarPendingOperationSchema,
        IsarDeadLetterSchema,
      ],
      directory: directory,
      name: instanceName,
      inspector: !const bool.fromEnvironment('INTEGRATION_TEST'),
    );

    // W8.9 (02-P2): schema-version gate. A KNOWN version transition (our own
    // bump) surgically wipes ONLY the resyncable cache collections —
    // NEVER the pending-operations / dead-letter queues — then stamps the
    // new version. Fresh installs (no pref) just adopt the current version.
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(kIsarSchemaVersionPref);
      if (stored != null && stored != kIsarSchemaVersion) {
        await isar.writeTxn(() async {
          await isar.isarMenuItems.clear();
          await isar.isarCarts.clear();
        });
        await _logger.info({
          'from': stored,
          'to': kIsarSchemaVersion,
          'instance': instanceName,
        }, 'IsarService_SCHEMA_VERSION_cache_wiped');
      }
      if (stored != kIsarSchemaVersion) {
        await prefs.setInt(kIsarSchemaVersionPref, kIsarSchemaVersion);
      }
    } catch (e, stack) {
      // The gate must never brick the open: version-pref failures are
      // logged and skipped — the error-classified recovery in [openDB]
      // still covers an actually-incompatible store.
      await _logger.error(
        e,
        'IsarService_schema_version_gate failed',
        stack: stack,
      );
    }

    // Evict stale cache on startup (unchanged: menu TTL + menu cap +
    // pending-ops cap).
    await evictStaleCache(isar);
    return isar;
  }

  /// Evicts stale cached items based on TTL and max-document limits.
  Future<void> evictStaleCache([Isar? database]) async {
    try {
      final db = database ?? await this.db;
      await db.writeTxn(() async {
        // Delete stale menu items (older than 24h)
        final staleMenu = await db.isarMenuItems.where().findAll();
        final now = DateTime.now();
        final cutoff = now.subtract(kMenuTtl);
        final toDeleteMenu = staleMenu
            .where((e) => e.cachedAt.isBefore(cutoff))
            .map((e) => e.id)
            .toList();
        if (toDeleteMenu.isNotEmpty) {
          await db.isarMenuItems.deleteAll(toDeleteMenu);
        }

        // Skipped: cart eviction requires build_runner-generated IsarCartSchema

        // Enforce max document limits
        final menuCount = await db.isarMenuItems.count();
        if (menuCount > kMaxMenuItems) {
          final allMenu = await db.isarMenuItems.where().findAll();
          allMenu.sort((a, b) => a.cachedAt.compareTo(b.cachedAt));
          final toDelete = allMenu
              .take(menuCount - kMaxMenuItems)
              .map((e) => e.id)
              .toList();
          if (toDelete.isNotEmpty) await db.isarMenuItems.deleteAll(toDelete);
        }

        final pendingCount = await db.isarPendingOperations.count();
        if (pendingCount > kMaxPendingOps) {
          final toDelete = await db.isarPendingOperations
              .where()
              .sortByTimestamp()
              .limit(pendingCount - kMaxPendingOps)
              .findAll();
          await db.isarPendingOperations.deleteAll(
            toDelete.map((e) => e.id).toList(),
          );
        }
      });
    } catch (e, stack) {
      await _logger.error(
        e,
        'IsarService_evictStaleCache failed',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Whether [error] classifies as a schema/store-compatibility failure that
  /// [openDB]'s recovery path may repair by wiping the instance files.
  ///
  /// Isar 3.1.0+1 surfaces every native open failure (including the schema
  /// mismatch of a store written by a different schema generation) as an
  /// `IsarError` thrown from the open port (isar native/isar_core.dart
  /// :172-185), with the diagnostic text in [IsarError.message]. The matcher
  /// is deliberately conservative: anything that does not look schema- or
  /// corruption-related rethrows unchanged.
  bool _isSchemaRecoverable(Object error) {
    final message = error.toString().toLowerCase();
    const markers = [
      'schema',
      'corrupt',
      'incompatible',
      'mismatch',
      'invalid file',
      'version',
    ];
    return markers.any(message.contains);
  }

  /// Closes (if open) and deletes THIS instance's on-disk files.
  ///
  /// Only files named `<instanceName>.isar` / `<instanceName>.isar.lock` in
  /// [directory] are touched (Isar 3.1.0+1 native naming) — other instances
  /// sharing the directory are unaffected. Used exclusively by the
  /// schema-recovery path in [openDB].
  Future<void> wipeAndReopen({required String directory}) async {
    final existing = Isar.getInstance(instanceName);
    if (existing != null) {
      try {
        await existing.close(deleteFromDisk: true);
      } catch (e, stack) {
        await _logger.error(
          e,
          'IsarService_wipeAndReopen_close failed',
          stack: stack,
        );
      }
    }
    final dir = Directory(directory);
    if (!await dir.exists()) {
      return;
    }
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final base = entity.uri.pathSegments.last;
      if (base == '$instanceName.isar' || base == '$instanceName.isar.lock') {
        try {
          await entity.delete();
        } catch (e, stack) {
          await _logger.error(
            e,
            'IsarService_wipeAndReopen_delete failed ($base)',
            stack: stack,
          );
        }
      }
    }
  }

  /// Purges ALL user-scoped cached data in ONE atomic transaction.
  ///
  /// WHY: P0-07 cross-user data leak — `clearAll()` is called on sign-out
  /// (auth_repository.dart) to stop the next user inheriting the previous
  /// user's cached cart lines and failed operations. Every collection is
  /// cleared inside a single [db] `writeTxn`, so any mid-transaction fault
  /// rolls the purge back (fail-closed) instead of leaving data half-cleared.
  ///
  /// [atomicityProbe] is a testing seam inserted AFTER the first clear and
  /// BEFORE the rest, so a probe that throws exercises the rollback path:
  /// nothing reaches disk until the whole transaction commits.
  Future<void> clearAll({Future<void> Function()? atomicityProbe}) async {
    try {
      final database = await db;
      await database.writeTxn(() async {
        await database.isarPendingOperations.clear();
        if (atomicityProbe != null) {
          await atomicityProbe();
        }
        await database.isarMenuItems.clear();
        await database.isarCarts.clear();
        await database.isarDeadLetters.clear();
      });
    } catch (e, stack) {
      await _logger.error(e, 'IsarService_clearAll failed', stack: stack);
      rethrow;
    }
  }

  Future<List<IsarPendingOperation>> getPendingOrders({int limit = 20}) async {
    try {
      final database = await db;
      final ops = await database.isarPendingOperations
          .where()
          .limit(limit)
          .findAll();
      return ops;
    } catch (e, stack) {
      await _logger.error(
        e,
        'IsarService_getPendingOrders failed',
        stack: stack,
      );
      rethrow;
    }
  }

  Future<void> markOrdersSynced(List<dynamic> orderIds) async {
    try {
      final database = await db;
      await database.writeTxn(() async {
        final all = await database.isarPendingOperations.where().findAll();
        for (final op in all) {
          if (orderIds.contains(op.id)) {
            await database.isarPendingOperations.delete(op.id);
          }
        }
      });
    } catch (e, stack) {
      await _logger.error(
        e,
        'IsarService_markOrdersSynced failed',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Synchronises pending operations by delegating to the real [IsarSyncQueue].
  ///
  /// The queue performs ACTUAL Firestore transmission and deletes the op only
  /// on success. This replaces the previous fake "Simulate transmit" branch
  /// that silently deleted pending operations without transmitting them
  /// (Law 43: Anti-Shortcut).
  Future<void> syncPendingOperations() async {
    try {
      // DELEGATE to the real sync queue — actual Firestore transmission.
      final queue = IsarSyncQueue(
        this,
        _logger,
        firestore: FirestoreQueueWriter(FirestoreClient.instance.db),
      );
      await queue.processQueue();
    } catch (e, stack) {
      await _logger.error(
        e,
        'IsarService_syncPendingOperations failed',
        stack: stack,
      );
      rethrow;
    }
  }
}
