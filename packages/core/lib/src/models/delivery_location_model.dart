import 'package:freezed_annotation/freezed_annotation.dart';

part 'delivery_location_model.freezed.dart';
part 'delivery_location_model.g.dart';

@freezed
abstract class DeliveryLocationModel with _$DeliveryLocationModel {
  const DeliveryLocationModel._();

  const factory DeliveryLocationModel({
    required double latitude,
    required double longitude,
    @Default('') String address,
  }) = _DeliveryLocationModel;

  factory DeliveryLocationModel.fromJson(Map<String, dynamic> json) =>
      _$DeliveryLocationModelFromJson(json);

  /// WHY: isValid guards against the default 0,0 null-island coordinate
  /// that geolocator returns before a real GPS fix is acquired.
  bool get isValid => latitude != 0 || longitude != 0;

  /// WHY: Native Google Maps app navigation deeplink.
  /// Opens turn-by-turn navigation directly in Google Maps on Android.
  String get googleMapsUrl => 'google.navigation:q=$latitude,$longitude';

  /// WHY: Web fallback for iOS or devices without Google Maps installed.
  String get googleMapsWebUrl =>
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
}
