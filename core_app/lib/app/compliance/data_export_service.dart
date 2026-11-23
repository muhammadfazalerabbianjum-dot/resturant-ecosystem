import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

final dataExportServiceProvider = Provider<DataExportService>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return DataExportService(
    firestore: ref.watch(firestoreProvider),
    // Law 12/DI: the export reads the auth user through the repository at
    // CALL time (sign-out between provider build and export stays correct),
    // never through the SDK.
    currentUser: () => authRepository.currentUser,
    logger: ref.read(loggerProvider),
  );
});

/// GDPR-compliant data export service.
///
/// Fetches all user data from Firestore and compiles it into a JSON file
/// that can be shared/downloaded. Only returns data belonging to the
/// authenticated user (Article 20 - Right to Data Portability).
///
/// P4-04 (LAW 11): NO silent catches. A GDPR export that silently drops
/// sections is a compliance violation — every failure is logged to
/// Crashlytics and rethrown so the caller can surface the error.
class DataExportService {
  final FirebaseFirestore _firestore;

  /// Call-time auth-user seam (Law 12/DI): the provider wires
  /// `() => repository.currentUser`, tests wire a fixed user. `User` itself
  /// comes from core's auth surface, so no SDK import lives in this file.
  final User? Function() _currentUser;
  final LoggerService _logger;

  /// D-057: every tenant-scoped LIST read must carry the tenant constraint.
  final TenantScope _scope;

  /// Injectable [FirebaseFunctions] (tests); defaults to the production
  /// instance. Used by the W9.10 server export section.
  final FirebaseFunctions? _functions;

  /// Test seam: produces the LOCAL device-data summary (W9.10 section 9).
  /// Defaults to the real Isar + SharedPreferences implementation.
  final Future<Map<String, dynamic>> Function()? _localSummary;

  DataExportService({
    required FirebaseFirestore firestore,
    required User? Function() currentUser,
    required LoggerService logger,
    FirebaseFunctions? functions,
    Future<Map<String, dynamic>> Function()? localSummary,
    TenantClaimReader? tenantClaim,
  }) : _firestore = firestore,
       _currentUser = currentUser,
       _logger = logger,
       _functions = functions,
       _localSummary = localSummary,
       _scope = TenantScope(tenantClaim);

  /// Fetches all user data and returns it as a formatted JSON string.
  Future<String> exportUserData() async {
    final user = _currentUser();
    if (user == null) {
      throw Exception('User must be signed in to export data.');
    }

    final uid = user.uid;
    final data = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'userId': uid,
      'email': user.email,
    };

    // 1. User document
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        data['userProfile'] = userDoc.data();
      }
    } catch (e, stack) {
      await _logger.error(e, 'data_export_user_profile_failed', stack: stack);
      rethrow;
    }

    // 2. Orders
    try {
      final tenantId = await _scope.require('The data export');
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('tenantId', isEqualTo: tenantId)
          .where('customerId', isEqualTo: uid)
          .get();
      data['orders'] = ordersSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e, stack) {
      await _logger.error(e, 'data_export_orders_failed', stack: stack);
      rethrow;
    }

    // 3. Loyalty
    try {
      final loyaltyDoc = await _firestore.collection('loyalty').doc(uid).get();
      if (loyaltyDoc.exists) {
        data['loyalty'] = loyaltyDoc.data();
      }
    } catch (e, stack) {
      await _logger.error(e, 'data_export_loyalty_failed', stack: stack);
      rethrow;
    }

    // 4. Reservations
    try {
      final reservationsSnapshot = await _firestore
          .collection('reservations')
          .where('tenantId', isEqualTo: await _scope.require('The data export'))
          .where('userId', isEqualTo: uid)
          .get();
      data['reservations'] = reservationsSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e, stack) {
      await _logger.error(e, 'data_export_reservations_failed', stack: stack);
      rethrow;
    }

    // 5. Cart (current state)
    try {
      final cartDoc = await _firestore.collection('carts').doc(uid).get();
      if (cartDoc.exists) {
        data['cart'] = cartDoc.data();
      }
    } catch (e, stack) {
      await _logger.error(e, 'data_export_cart_failed', stack: stack);
      rethrow;
    }

    // 6. Presence data
    try {
      final presenceDoc = await _firestore
          .collection('presence')
          .doc(uid)
          .get();
      if (presenceDoc.exists) {
        data['presence'] = presenceDoc.data();
      }
    } catch (e, stack) {
      await _logger.error(e, 'data_export_presence_failed', stack: stack);
      rethrow;
    }

    // 7. Waitlist entries
    try {
      final waitlistSnapshot = await _firestore
          .collection('waitlist')
          .where('tenantId', isEqualTo: await _scope.require('The data export'))
          .where('userId', isEqualTo: uid)
          .get();
      data['waitlistEntries'] = waitlistSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e, stack) {
      await _logger.error(e, 'data_export_waitlist_failed', stack: stack);
      rethrow;
    }

    // 8. Server-only collections (W9.10 / 06-P1-7): promo_usage,
    //    reservation_locks, notifications/{uid}/items, driverLocations,
    //    deliveries (by order ids) and analyticsEvents are rules-gated
    //    server-side — a direct client query would be DENIED. The read-only
    //    `exportMyData` callable mirrors the Art.17 erasure set
    //    (collectUserDocs) minus deletion, so the export is exactly as
    //    complete as the erasure. Bounded retry like the erasure callable.
    try {
      final callable = (_functions ?? FirebaseFunctions.instance).httpsCallable(
        'exportMyData',
      );
      final result = await NetworkRetry.withExponentialBackoff(
        () => callable.call(),
      );
      data['serverExport'] = result.data;
    } catch (e, stack) {
      await _logger.error(e, 'data_export_server_failed', stack: stack);
      rethrow;
    }

    // 9. Local device data (Art.20 completeness): the on-device state the
    //    app itself created — Isar cache collection counts + the
    //    SharedPreferences keys present on this install.
    try {
      data['localData'] = await (_localSummary ?? _defaultLocalSummary)();
    } catch (e, stack) {
      await _logger.error(e, 'data_export_local_failed', stack: stack);
      rethrow;
    }

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Real local-device summary: Isar collection counts + preference keys.
  Future<Map<String, dynamic>> _defaultLocalSummary() async {
    final isar = await IsarService.shared().db;
    final prefs = await SharedPreferences.getInstance();
    return {
      'isar': {
        'menuItems': await isar.isarMenuItems.count(),
        'carts': await isar.isarCarts.count(),
        'pendingOperations': await isar.isarPendingOperations.count(),
        'deadLetters': await isar.isarDeadLetters.count(),
      },
      'preferences': {
        'keys': prefs.getKeys().toList()..sort(),
        'onboardingCompleted': prefs.getBool('onboarding_completed') ?? false,
        'gdprAnalyticsConsentDecided':
            prefs.getBool(kGdprAnalyticsConsentKey) != null,
      },
    };
  }

  /// Exports user data to a temporary JSON file and opens the share sheet.
  ///
  /// W9.2: the share-sheet subject/body are passed in by the caller
  /// (localized at the call site) — this service layer has no
  /// [AppLocalizations] access of its own.
  Future<void> exportAndShare({
    required String shareSubject,
    required String shareText,
  }) async {
    final jsonString = await exportUserData();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/carnama_data_export.json');
    await file.writeAsString(jsonString);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: shareSubject,
        text: shareText,
      ),
    );
  }

  /// Exports user data and returns it as a JSON string (for programmatic use).
  Future<String> exportAsJsonString() async {
    return exportUserData();
  }
}
