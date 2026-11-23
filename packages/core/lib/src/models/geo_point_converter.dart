import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GeoPointConverter implements JsonConverter<GeoPoint, dynamic> {
  const GeoPointConverter();

  @override
  GeoPoint fromJson(dynamic json) {
    if (json is GeoPoint) return json;
    if (json is Map<String, dynamic>) {
      return GeoPoint(
        (json['latitude'] as num?)?.toDouble() ?? 0.0,
        (json['longitude'] as num?)?.toDouble() ?? 0.0,
      );
    }
    return const GeoPoint(0, 0);
  }

  @override
  dynamic toJson(GeoPoint object) => object;
}
