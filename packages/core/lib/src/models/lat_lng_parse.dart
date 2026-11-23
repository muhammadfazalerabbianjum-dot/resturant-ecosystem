import 'package:cloud_firestore/cloud_firestore.dart';

/// Single source of truth for parsing geographic coordinates from a Firestore
/// document (B4-3).
///
/// Mirrors the defensive spirit of [GeoPointConverter] but covers EVERY shape
/// the codebase has used over time, so a branch/location is never silently
/// pinned to the null-island (0,0) just because the document uses a different
/// key layout. Accepted shapes, in priority order:
///
/// 1. `geo.geopoint` -> `GeoPoint` (the `geoflutterfire_plus` index shape —
///    `branch_service.nearestBranch` query returns docs with THIS shape).
/// 2. `coordinates` as a `GeoPoint`, as a `[lng, lat]` list, or as a
///    `{latitude, longitude}` (or `{lat, lng}`) object.
/// 3. top-level `lat`/`lng` (or `latitude`/`longitude`).
///
/// When no shape matches, returns `(0, 0)` — the caller decides whether to
/// surface/log a warning. This keeps the parser pure and testable.
abstract final class LatLngParse {
  const LatLngParse._();

  /// Parses [doc]'s geo fields into a normalized `(latitude, longitude)` pair.
  static ({double lat, double lng}) fromDoc(DocumentSnapshot doc) {
    final data = doc.data();
    if (data is! Map<String, dynamic>) return (lat: 0, lng: 0);
    return fromMap(data);
  }

  /// Parses a raw Firestore map into a normalized `(latitude, longitude)` pair.
  static ({double lat, double lng}) fromMap(Map<String, dynamic> data) {
    // 1. geoflutterfire_plus index shape: `geo: { geopoint: GeoPoint }`.
    final geo = data['geo'];
    if (geo is Map) {
      final geopoint = geo['geopoint'];
      if (geopoint is GeoPoint) {
        return (lat: geopoint.latitude, lng: geopoint.longitude);
      }
    }

    // 2. `coordinates` key — GeoPoint, [lng, lat], or {lat/latitude, lng/longitude}.
    final coordinates = data['coordinates'];
    if (coordinates is GeoPoint) {
      return (lat: coordinates.latitude, lng: coordinates.longitude);
    }
    if (coordinates is List && coordinates.length >= 2) {
      final lng = _toDouble(coordinates[0]);
      final lat = _toDouble(coordinates[1]);
      if (lat != null && lng != null) return (lat: lat, lng: lng);
    }
    if (coordinates is Map) {
      final lat = _toDouble(coordinates['latitude'] ?? coordinates['lat']);
      final lng = _toDouble(coordinates['longitude'] ?? coordinates['lng']);
      if (lat != null && lng != null) return (lat: lat, lng: lng);
    }

    // 3. Top-level `lat`/`lng` (or `latitude`/`longitude`).
    final lat = _toDouble(data['lat'] ?? data['latitude']);
    final lng = _toDouble(data['lng'] ?? data['longitude']);
    if (lat != null && lng != null) return (lat: lat, lng: lng);

    return (lat: 0, lng: 0);
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
