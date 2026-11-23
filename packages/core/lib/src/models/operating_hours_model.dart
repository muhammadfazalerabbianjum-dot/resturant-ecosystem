import 'package:freezed_annotation/freezed_annotation.dart';

part 'operating_hours_model.freezed.dart';

/// Operating hours for a single day.
@freezed
abstract class DayHours with _$DayHours {
  const DayHours._();

  const factory DayHours({
    @Default(true) bool isOpen,
    @Default('09:00') String openTime,
    @Default('22:00') String closeTime,
  }) = _DayHours;

  factory DayHours.fromMap(Map<String, dynamic> map) => DayHours(
    isOpen: map['isOpen'] as bool? ?? true,
    openTime: map['openTime'] as String? ?? '09:00',
    closeTime: map['closeTime'] as String? ?? '22:00',
  );

  Map<String, dynamic> toMap() => {
    'isOpen': isOpen,
    'openTime': openTime,
    'closeTime': closeTime,
  };
}

/// Full week operating hours for a branch.
/// Firestore path: branches/{branchId}/operatingHours (single doc)
@freezed
abstract class OperatingHoursModel with _$OperatingHoursModel {
  const OperatingHoursModel._();

  const factory OperatingHoursModel({
    @Default(DayHours()) DayHours monday,
    @Default(DayHours()) DayHours tuesday,
    @Default(DayHours()) DayHours wednesday,
    @Default(DayHours()) DayHours thursday,
    @Default(DayHours()) DayHours friday,
    @Default(DayHours(openTime: '10:00', closeTime: '23:00')) DayHours saturday,
    @Default(DayHours(openTime: '10:00', closeTime: '21:00')) DayHours sunday,
    @Default(false) bool holidayModeEnabled,
  }) = _OperatingHoursModel;

  factory OperatingHoursModel.fromMap(Map<String, dynamic> data) {
    // WHY: Type-check safely — `data[day] as Map` CRASHES if the raw value
    // is not a Map (corrupt doc, schema drift). Null-safe parse returns a
    // closed day instead of throwing (Law 25).
    DayHours parse(String day) {
      final value = data[day];
      if (value is! Map) return const DayHours();
      return DayHours.fromMap(Map<String, dynamic>.from(value));
    }

    return OperatingHoursModel(
      monday: parse('monday'),
      tuesday: parse('tuesday'),
      wednesday: parse('wednesday'),
      thursday: parse('thursday'),
      friday: parse('friday'),
      saturday: parse('saturday'),
      sunday: parse('sunday'),
      holidayModeEnabled: data['holidayModeEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'monday': monday.toMap(),
    'tuesday': tuesday.toMap(),
    'wednesday': wednesday.toMap(),
    'thursday': thursday.toMap(),
    'friday': friday.toMap(),
    'saturday': saturday.toMap(),
    'sunday': sunday.toMap(),
    'holidayModeEnabled': holidayModeEnabled,
  };

  /// Day label + hours for UI iteration.
  List<(String, DayHours)> get entries => [
    ('Monday', monday),
    ('Tuesday', tuesday),
    ('Wednesday', wednesday),
    ('Thursday', thursday),
    ('Friday', friday),
    ('Saturday', saturday),
    ('Sunday', sunday),
  ];
}
