import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core/core.dart';
import 'package:rxdart/rxdart.dart';

/// QUEUE-1 (W5.1(b)(2)) — flushes the offline queue when connectivity is
/// RESTORED.
///
/// The connectivity result stream is debounced (default 5 s) so a flapping
/// radio (2G edge, wifi→cell handover) can never spam `processQueue`. The
/// trigger fires only on the offline→online EDGE: the app-start flush already
/// covers the boot-time online case, so a first "online" emission at startup
/// must NOT double-flush. `processQueue` is idempotent and fail-closed, so a
/// missed edge at worst delays a flush to the next trigger / periodic task —
/// never loses data (documented QUEUE-1 residual).
///
/// Composition-root service: the production stream is
/// `Connectivity().onConnectivityChanged`; tests inject a controlled stream.
class ConnectivitySyncTrigger {
  ConnectivitySyncTrigger({
    required SyncQueue syncQueue,
    Stream<List<ConnectivityResult>>? connectivityStream,
    Duration debounce = const Duration(seconds: 5),
  }) : _syncQueue = syncQueue,
       _stream = connectivityStream ?? Connectivity().onConnectivityChanged,
       _debounce = debounce;

  final SyncQueue _syncQueue;
  final Stream<List<ConnectivityResult>> _stream;
  final Duration _debounce;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Last known reachability. Starts OPTIMISTIC (online) so the boot-time
  /// "online" emission does not double-flush with the app-start trigger.
  bool _wasOnline = true;

  /// Begins listening. Idempotent until [dispose].
  void start() {
    _subscription ??= _stream.debounceTime(_debounce).listen((results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      if (isOnline && !_wasOnline) {
        unawaited(_syncQueue.processQueue());
      }
      _wasOnline = isOnline;
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
