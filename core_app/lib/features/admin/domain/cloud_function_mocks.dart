import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/app/config/demo_config.dart';

// OFFLINE_FALLBACK: Local daemon implementations of Cloud Functions that are
// not yet deployed. Gated behind kDemoMode so production NEVER runs these
// mocks — real Cloud Functions handle these in production.
final cloudFunctionMocksProvider = Provider.autoDispose((ref) {
  final service = CloudFunctionMocksService(
    ref,
    firestore: ref.watch(firestoreProvider),
    logger: ref.watch(loggerProvider),
  );
  if (kDemoMode) {
    service.startDaemons();
  }
  ref.onDispose(() => service.stopDaemons());
  return service;
});

class CloudFunctionMocksService {
  final Ref _ref;
  final FirebaseFirestore _db;
  final LoggerService _logger;

  CloudFunctionMocksService(
    this._ref, {
    required FirebaseFirestore firestore,
    required LoggerService logger,
  }) : _db = firestore,
       _logger = logger;

  bool _isRunning = false;
  Timer? _abandonmentCron;
  Timer? _lockTTLTimer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _auditSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _notificationSubscription;

  void startDaemons() {
    if (_isRunning) return;
    _isRunning = true;
    unawaited(
      _logger.info({'daemon': 'start'}, 'Starting Local Cloud Function Mocks'),
    );

    _lockTTLTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => enforceReservationLockTTL(),
    );

    _abandonmentCron = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(scanAbandonedDriversNow()),
    );

    _listenToNotificationQueue();
    _listenToMenuAuditLogs();
  }

  void stopDaemons() {
    _isRunning = false;
    _abandonmentCron?.cancel();
    _lockTTLTimer?.cancel();
    _auditSubscription?.cancel();
    _notificationSubscription?.cancel();
    unawaited(
      _logger.info({'daemon': 'stop'}, 'Stopped Local Cloud Function Mocks'),
    );
  }

  Future<void> enforceReservationLockTTL() async {
    try {
      final now = Timestamp.now();
      final expiredLocks = await _db
          .collection('reservation_locks')
          .where('expiresAt', isLessThanOrEqualTo: now)
          .get();
      if (expiredLocks.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in expiredLocks.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      unawaited(
        _logger.info({
          'daemon': 'lock_ttl',
          'count': expiredLocks.docs.length,
        }, 'Cleared ${expiredLocks.docs.length} expired reservation locks'),
      );
    } catch (e, stack) {
      unawaited(
        _logger.error(e, 'cloudFunctionMocks_lock_ttl_failed', stack: stack),
      );
    }
  }

  /// Scans for driver-assigned orders where the driver's location heartbeat went
  /// stale (15+ minutes) and unassigns those drivers, putting the orders back to
  /// `ready`. Publicly invocable so an operator (or a test) can trigger a sweep
  /// immediately; returns the number of drivers unassigned.
  Future<int> scanAbandonedDriversNow() async {
    try {
      final now = DateTime.now();
      final fifteenMinsAgo = now.subtract(const Duration(minutes: 15));
      final cutoffTimestamp = Timestamp.fromDate(fifteenMinsAgo);
      final acceptedOrders = await _db
          .collection('orders')
          .where('status', isEqualTo: 'accepted')
          .get();
      final batch = _db.batch();
      int unassignedCount = 0;
      for (final order in acceptedOrders.docs) {
        final data = order.data();
        final driverId = data['assignedDriverId'] as String?;
        if (driverId != null && driverId.isNotEmpty) {
          final driverLoc = await _db
              .collection('driverLocations')
              .doc(driverId)
              .get();
          if (driverLoc.exists) {
            final locData = driverLoc.data();
            final updatedAt = locData?['updatedAt'] as Timestamp?;
            if (updatedAt != null && updatedAt.compareTo(cutoffTimestamp) < 0) {
              batch.update(order.reference, {
                'assignedDriverId': null,
                'status': 'ready',
                'systemNote': 'Driver unassigned due to 15m inactivity.',
              });
              unassignedCount++;
            }
          }
        }
      }
      if (unassignedCount > 0) {
        await batch.commit();
        unawaited(
          _logger.info({
            'daemon': 'driver_abandonment',
            'count': unassignedCount,
          }, 'Unassigned $unassignedCount stale drivers'),
        );
      }
      return unassignedCount;
    } catch (e, stack) {
      unawaited(
        _logger.error(
          e,
          'cloudFunctionMocks_driver_abandonment_failed',
          stack: stack,
        ),
      );
      rethrow;
    }
  }

  void _listenToNotificationQueue() {
    _notificationSubscription = _db
        .collection('notification_queue')
        .snapshots()
        .listen(
          (snapshot) async {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                if (data == null) continue;
                final targetUid = data['targetUid'] as String?;
                final title = data['title'] as String?;
                if (targetUid == null || title == null) {
                  await change.doc.reference.delete();
                  continue;
                }
                final thirtySecsAgo = Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(seconds: 30)),
                );
                final recent = await _db
                    .collection('notifications')
                    .doc(targetUid)
                    .collection('items')
                    .where('title', isEqualTo: title)
                    .where('createdAt', isGreaterThan: thirtySecsAgo)
                    .get();
                if (recent.docs.isEmpty) {
                  await _db
                      .collection('notifications')
                      .doc(targetUid)
                      .collection('items')
                      .add({
                        'title': title,
                        'body': data['body'] ?? '',
                        'route': data['route'],
                        'isRead': false,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                  unawaited(
                    _logger.info({
                      'daemon': 'push',
                      'targetUid': targetUid,
                    }, 'Processed push notification to $targetUid'),
                  );
                } else {
                  unawaited(
                    _logger.info({
                      'daemon': 'push_debounce',
                      'targetUid': targetUid,
                    }, 'Debounced duplicate notification to $targetUid'),
                  );
                }
                await change.doc.reference.delete();
              }
            }
          },
          onError: (Object e, StackTrace? stack) {
            unawaited(
              _logger.error(
                e,
                'cloudFunctionMocks_push_debounce_failed',
                stack: stack ?? StackTrace.current,
              ),
            );
          },
        );
  }

  void _listenToMenuAuditLogs() {
    _auditSubscription = _db
        .collection('menus')
        .snapshots()
        .listen(
          (snapshot) async {
            final currentUser = _ref.read(authStateProvider).value;
            if (currentUser == null) return;
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.modified) {
                final data = change.doc.data();
                final newPrice = data?['priceCents'];
                final name = data?['name'] as String? ?? 'unknown';
                await _db.collection('audit_log').add({
                  'action': 'MENU_MODIFY',
                  'collection': 'menus',
                  'docId': change.doc.id,
                  'actorUid': currentUser.uid,
                  'actorEmail': currentUser.email,
                  'timestamp': FieldValue.serverTimestamp(),
                  'note':
                      'Menu item $name was modified. Current price cents: ${newPrice is num ? newPrice : 0}',
                });
                unawaited(
                  _logger.info({
                    'daemon': 'audit_log',
                  }, 'Generated IAM Audit Log'),
                );
              }
            }
          },
          onError: (Object e, StackTrace? stack) {
            unawaited(
              _logger.error(
                e,
                'cloudFunctionMocks_audit_log_failed',
                stack: stack ?? StackTrace.current,
              ),
            );
          },
        );
  }
}
