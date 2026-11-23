import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:core/src/error_logger/logger_provider.dart';
import 'package:core/src/error_logger/logger_service.dart';
import 'package:core/src/models/lat_lng_parse.dart';
import 'package:core/src/providers/firestore_provider.dart';

const _kBranchPrefKey = 'selected_branch_id';
const _kManualLocationKey = 'is_manual_location';

/// Minimal model carrying the branch identity we need
class BranchInfo {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double deliveryRadiusMiles;
  final bool isDefault;

  const BranchInfo({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.deliveryRadiusMiles,
    this.isDefault = false,
  });

  factory BranchInfo.fromDoc(DocumentSnapshot doc) {
    final d = doc.data();
    if (d is! Map<String, dynamic>) {
      return BranchInfo(
        id: doc.id,
        name: '—',
        lat: 0,
        lng: 0,
        deliveryRadiusMiles: 0,
      );
    }
    final coords = LatLngParse.fromMap(d);
    // B4-3: a shared parser normalizes every real geo shape so a branch
    // is never silently pinned to null-island (0,0) just because the doc shape differs.
    return BranchInfo(
      id: doc.id,
      name: (d['name'] as String?)?.trim().isNotEmpty == true
          ? d['name'] as String
          : '—',
      lat: coords.lat,
      lng: coords.lng,
      deliveryRadiusMiles:
          (d['deliveryRadiusMiles'] as num?)?.toDouble() ?? 5.0,
      isDefault: d['isDefault'] as bool? ?? false,
    );
  }
}

// ── Provider ─────────────────────────────────────────────────────────
final branchServiceProvider = Provider<BranchService>((ref) {
  return BranchService(
    ref.watch(firestoreProvider),
    logger: ref.read(loggerProvider),
  );
});

// ── Service ───────────────────────────────────────────────────────────
class BranchService {
  final FirebaseFirestore _db;
  final LoggerService _logger;

  /// Optional override for tests: if provided, `nearestBranch` uses this
  /// list instead of calling GeoCollectionReference (which requires a real
  /// Firestore implementation with geohash indexing).
  final Future<List<DocumentSnapshot>> Function(double lat, double lng)?
  fetchBranchesOverride;

  BranchService(
    this._db, {
    required LoggerService logger,
    this.fetchBranchesOverride,
  }) : _logger = logger;

  /// Haversine formula — returns distance in miles between two coordinates.
  static double distanceMiles(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 3958.8; // Earth radius miles
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;

  /// Loads nearby branches from Firestore and returns the nearest one.
  Future<BranchInfo?> nearestBranch(double userLat, double userLng) async {
    try {
      List<DocumentSnapshot> docs;

      if (fetchBranchesOverride != null) {
        // Test injection path — bypasses GeoCollectionReference
        docs = await fetchBranchesOverride!(userLat, userLng);
      } else {
        final center = GeoFirePoint(GeoPoint(userLat, userLng));
        final geoCollection = GeoCollectionReference(
          _db.collection('branches'),
        );

        // Fetch documents strictly within 50.0 km (~31 miles)
        docs = await geoCollection.fetchWithin(
          center: center,
          radiusInKm: 50.0,
          field: 'geo',
          geopointFrom: (data) {
            if (data['geo'] is Map) {
              final geo = data['geo'] as Map<String, dynamic>;
              if (geo['geopoint'] is GeoPoint) {
                return geo['geopoint'] as GeoPoint;
              }
            }
            if (data['coordinates'] is GeoPoint) {
              return data['coordinates'] as GeoPoint;
            }
            return const GeoPoint(0, 0);
          },
          strictMode: true,
        );
      }

      BranchInfo? nearest;
      double minDist = double.infinity;

      for (final doc in docs) {
        final branch = BranchInfo.fromDoc(doc);
        final d = distanceMiles(userLat, userLng, branch.lat, branch.lng);
        if (d < minDist) {
          minDist = d;
          nearest = branch;
        }
      }
      return nearest;
    } catch (e, stack) {
      await _logger.error(
        e,
        'BranchService_nearestBranch failed',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Returns true if [userLat]/[userLng] is within the branch's delivery radius.
  bool isWithinRadius(BranchInfo branch, double userLat, double userLng) {
    final d = distanceMiles(userLat, userLng, branch.lat, branch.lng);
    return d <= branch.deliveryRadiusMiles;
  }

  /// Persists the selected branch to shared prefs so it survives restarts.
  Future<void> persistSelectedBranch(
    String branchId, {
    bool isManual = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kBranchPrefKey, branchId);
      await prefs.setBool(_kManualLocationKey, isManual);
    } catch (e, stack) {
      await _logger.error(
        e,
        'BranchService_persistSelectedBranch failed',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Reads the last-persisted branch from shared prefs (may be null).
  Future<String?> loadPersistedBranch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_kBranchPrefKey);
      return id;
    } catch (e, stack) {
      await _logger.error(
        e,
        'BranchService_loadPersistedBranch failed',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Checks if the user manually selected their branch.
  Future<bool> isManualLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kManualLocationKey) ?? false;
    } catch (e, stack) {
      await _logger.error(
        e,
        'BranchService_isManualLocation failed',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Requests permission and returns the device position if granted.
  /// Returns null if permission is denied or service is off.
  Future<Position?> currentPosition() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception(
          '[BranchService] GPS fix timed out after 10 seconds',
        ),
      );
    } catch (e, stack) {
      await _logger.error(
        e,
        'BranchService_currentPosition failed',
        stack: stack,
      );
      rethrow;
    }
  }
}
