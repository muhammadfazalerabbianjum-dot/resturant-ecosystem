import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'promotion_model.freezed.dart';
part 'promotion_model.g.dart';

@freezed
abstract class PromotionModel with _$PromotionModel {
  const PromotionModel._();

  const factory PromotionModel({
    required String id,
    @Default('') String imageUrl,
    String? title,
    String? subtitle,
    String? actionUrl,
    @Default(true) bool isActive,
    @Default(99) int priority,
    DateTime? createdAt,
  }) = _PromotionModel;

  factory PromotionModel.fromJson(Map<String, dynamic> json) =>
      _$PromotionModelFromJson(json);

  factory PromotionModel.fromDoc(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<dynamic, dynamic>);
    data['id'] = doc.id;
    if (data['createdAt'] is String) {
      // json_serializable handles Iso strings automatically if configured, but let's be safe
    } else if (data['createdAt'] is Timestamp) {
      data['createdAt'] = (data['createdAt'] as Timestamp)
          .toDate()
          .toIso8601String();
    }
    return PromotionModel.fromJson(data);
  }
}
