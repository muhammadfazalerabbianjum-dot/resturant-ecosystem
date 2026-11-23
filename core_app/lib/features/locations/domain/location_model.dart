import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart' show LatLngParse;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_model.freezed.dart';
part 'location_model.g.dart';

@freezed
class LocationModel with _$LocationModel {
  const LocationModel._();

  const factory LocationModel({
    required String id,
    required String name,
    required double lat,
    required double lng,
    required String address,
    required String openHours,
  }) = _LocationModel;

  factory LocationModel.fromJson(Map<String, dynamic> json) =>
      _$LocationModelFromJson(json);

  /// Normalized parse from a Firestore document (B4-3).
  ///
  /// Coordinates go through the single shared [LatLngParse] helper so every
  /// real shape (`geo.geopoint`, `coordinates` GeoPoint / [lng,lat] /
  /// {latitude,longitude}, or top-level `lat`/`lng`) resolves identically —
  /// a location is never silently pinned to (0,0) by a schema mismatch.
  ///
  /// Missing `name` / `openHours` fall back to the honest "—" placeholder
  /// (never a fabricated label like 'Branch' / '9am - 10pm').
  factory LocationModel.fromDoc(
    DocumentSnapshot doc, {
    void Function(String field, String locationId)? onMissingField,
  }) {
    final data = doc.data() as Map? ?? const {};
    final map = Map<String, dynamic>.from(data);
    final coords = LatLngParse.fromMap(map);

    String? name = map['name'] as String?;
    String? openHours = map['openHours'] as String?;
    if (name == null || name.trim().isEmpty) {
      name = '—';
      onMissingField?.call('name', doc.id);
    }
    if (openHours == null || openHours.trim().isEmpty) {
      openHours = '—';
      onMissingField?.call('openHours', doc.id);
    }

    return LocationModel(
      id: doc.id,
      name: name,
      lat: coords.lat,
      lng: coords.lng,
      address: (map['address'] as String?) ?? '',
      openHours: openHours,
    );
  }
}
