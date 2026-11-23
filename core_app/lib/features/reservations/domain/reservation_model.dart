import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reservation_model.freezed.dart';
part 'reservation_model.g.dart';

@freezed
abstract class ReservationModel with _$ReservationModel {
  const ReservationModel._();

  const factory ReservationModel({
    required String id,
    @Default('') String userId,
    @Default('') String branchId,
    @Default('Guest') String customerName,
    @Default('—') String customerPhone,
    required DateTime startTime,
    @Default(1) int partySize,
    String? notes,
  }) = _ReservationModel;

  factory ReservationModel.fromJson(Map<String, dynamic> json) =>
      _$ReservationModelFromJson(json);

  /// WHY: Reconstructs the Firestore Timestamp for writing.
  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'branchId': branchId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'startTime': Timestamp.fromDate(startTime),
    'partySize': partySize,
    if (notes != null) 'notes': notes,
  };
}
