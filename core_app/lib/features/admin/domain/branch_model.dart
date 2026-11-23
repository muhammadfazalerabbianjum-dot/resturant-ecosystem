import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'branch_model.freezed.dart';
part 'branch_model.g.dart';

@freezed
abstract class BranchModel with _$BranchModel {
  const BranchModel._();

  const factory BranchModel({
    required String id,
    @Default('') String name,
    @Default('') String address,
    // WHY: GeoPoint stored as lat/lng doubles — GeoPoint is not JSON serializable
    @Default(0.0) double latitude,
    @Default(0.0) double longitude,
    @Default(5.0) double deliveryRadiusMiles,
    @Default(50) int capacity, // Added for reservation table capacity
    @Default(false) bool isDefault,
    @Default(true) bool isActive,
  }) = _BranchModel;

  factory BranchModel.fromJson(Map<String, dynamic> json) =>
      _$BranchModelFromJson(json);

  /// WHY: Firestore stores GeoPoint natively. We extract lat/lng here so the
  /// model itself is pure Dart (no Firestore SDK coupling in domain layer).
  factory BranchModel.fromDoc(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<dynamic, dynamic>);
    final gp = data['coordinates'] as GeoPoint?;
    data['id'] = doc.id;
    data['latitude'] = gp?.latitude ?? 0.0;
    data['longitude'] = gp?.longitude ?? 0.0;
    data.remove('coordinates');
    return BranchModel.fromJson(data);
  }

  /// WHY: Reconstructs the GeoPoint for writing back to Firestore.
  GeoPoint get coordinates => GeoPoint(latitude, longitude);
}
