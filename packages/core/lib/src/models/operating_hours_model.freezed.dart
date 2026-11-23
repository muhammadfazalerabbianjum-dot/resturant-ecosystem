// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'operating_hours_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$DayHours {
  bool get isOpen => throw _privateConstructorUsedError;
  String get openTime => throw _privateConstructorUsedError;
  String get closeTime => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $DayHoursCopyWith<DayHours> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DayHoursCopyWith<$Res> {
  factory $DayHoursCopyWith(DayHours value, $Res Function(DayHours) then) =
      _$DayHoursCopyWithImpl<$Res, DayHours>;
  @useResult
  $Res call({bool isOpen, String openTime, String closeTime});
}

/// @nodoc
class _$DayHoursCopyWithImpl<$Res, $Val extends DayHours>
    implements $DayHoursCopyWith<$Res> {
  _$DayHoursCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isOpen = null,
    Object? openTime = null,
    Object? closeTime = null,
  }) {
    return _then(
      _value.copyWith(
            isOpen: null == isOpen
                ? _value.isOpen
                : isOpen // ignore: cast_nullable_to_non_nullable
                      as bool,
            openTime: null == openTime
                ? _value.openTime
                : openTime // ignore: cast_nullable_to_non_nullable
                      as String,
            closeTime: null == closeTime
                ? _value.closeTime
                : closeTime // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DayHoursImplCopyWith<$Res>
    implements $DayHoursCopyWith<$Res> {
  factory _$$DayHoursImplCopyWith(
    _$DayHoursImpl value,
    $Res Function(_$DayHoursImpl) then,
  ) = __$$DayHoursImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool isOpen, String openTime, String closeTime});
}

/// @nodoc
class __$$DayHoursImplCopyWithImpl<$Res>
    extends _$DayHoursCopyWithImpl<$Res, _$DayHoursImpl>
    implements _$$DayHoursImplCopyWith<$Res> {
  __$$DayHoursImplCopyWithImpl(
    _$DayHoursImpl _value,
    $Res Function(_$DayHoursImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isOpen = null,
    Object? openTime = null,
    Object? closeTime = null,
  }) {
    return _then(
      _$DayHoursImpl(
        isOpen: null == isOpen
            ? _value.isOpen
            : isOpen // ignore: cast_nullable_to_non_nullable
                  as bool,
        openTime: null == openTime
            ? _value.openTime
            : openTime // ignore: cast_nullable_to_non_nullable
                  as String,
        closeTime: null == closeTime
            ? _value.closeTime
            : closeTime // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$DayHoursImpl extends _DayHours {
  const _$DayHoursImpl({
    this.isOpen = true,
    this.openTime = '09:00',
    this.closeTime = '22:00',
  }) : super._();

  @override
  @JsonKey()
  final bool isOpen;
  @override
  @JsonKey()
  final String openTime;
  @override
  @JsonKey()
  final String closeTime;

  @override
  String toString() {
    return 'DayHours(isOpen: $isOpen, openTime: $openTime, closeTime: $closeTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DayHoursImpl &&
            (identical(other.isOpen, isOpen) || other.isOpen == isOpen) &&
            (identical(other.openTime, openTime) ||
                other.openTime == openTime) &&
            (identical(other.closeTime, closeTime) ||
                other.closeTime == closeTime));
  }

  @override
  int get hashCode => Object.hash(runtimeType, isOpen, openTime, closeTime);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DayHoursImplCopyWith<_$DayHoursImpl> get copyWith =>
      __$$DayHoursImplCopyWithImpl<_$DayHoursImpl>(this, _$identity);
}

abstract class _DayHours extends DayHours {
  const factory _DayHours({
    final bool isOpen,
    final String openTime,
    final String closeTime,
  }) = _$DayHoursImpl;
  const _DayHours._() : super._();

  @override
  bool get isOpen;
  @override
  String get openTime;
  @override
  String get closeTime;
  @override
  @JsonKey(ignore: true)
  _$$DayHoursImplCopyWith<_$DayHoursImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$OperatingHoursModel {
  DayHours get monday => throw _privateConstructorUsedError;
  DayHours get tuesday => throw _privateConstructorUsedError;
  DayHours get wednesday => throw _privateConstructorUsedError;
  DayHours get thursday => throw _privateConstructorUsedError;
  DayHours get friday => throw _privateConstructorUsedError;
  DayHours get saturday => throw _privateConstructorUsedError;
  DayHours get sunday => throw _privateConstructorUsedError;
  bool get holidayModeEnabled => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $OperatingHoursModelCopyWith<OperatingHoursModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OperatingHoursModelCopyWith<$Res> {
  factory $OperatingHoursModelCopyWith(
    OperatingHoursModel value,
    $Res Function(OperatingHoursModel) then,
  ) = _$OperatingHoursModelCopyWithImpl<$Res, OperatingHoursModel>;
  @useResult
  $Res call({
    DayHours monday,
    DayHours tuesday,
    DayHours wednesday,
    DayHours thursday,
    DayHours friday,
    DayHours saturday,
    DayHours sunday,
    bool holidayModeEnabled,
  });

  $DayHoursCopyWith<$Res> get monday;
  $DayHoursCopyWith<$Res> get tuesday;
  $DayHoursCopyWith<$Res> get wednesday;
  $DayHoursCopyWith<$Res> get thursday;
  $DayHoursCopyWith<$Res> get friday;
  $DayHoursCopyWith<$Res> get saturday;
  $DayHoursCopyWith<$Res> get sunday;
}

/// @nodoc
class _$OperatingHoursModelCopyWithImpl<$Res, $Val extends OperatingHoursModel>
    implements $OperatingHoursModelCopyWith<$Res> {
  _$OperatingHoursModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? monday = null,
    Object? tuesday = null,
    Object? wednesday = null,
    Object? thursday = null,
    Object? friday = null,
    Object? saturday = null,
    Object? sunday = null,
    Object? holidayModeEnabled = null,
  }) {
    return _then(
      _value.copyWith(
            monday: null == monday
                ? _value.monday
                : monday // ignore: cast_nullable_to_non_nullable
                      as DayHours,
            tuesday: null == tuesday
                ? _value.tuesday
                : tuesday // ignore: cast_nullable_to_non_nullable
                      as DayHours,
            wednesday: null == wednesday
                ? _value.wednesday
                : wednesday // ignore: cast_nullable_to_non_nullable
                      as DayHours,
            thursday: null == thursday
                ? _value.thursday
                : thursday // ignore: cast_nullable_to_non_nullable
                      as DayHours,
            friday: null == friday
                ? _value.friday
                : friday // ignore: cast_nullable_to_non_nullable
                      as DayHours,
            saturday: null == saturday
                ? _value.saturday
                : saturday // ignore: cast_nullable_to_non_nullable
                      as DayHours,
            sunday: null == sunday
                ? _value.sunday
                : sunday // ignore: cast_nullable_to_non_nullable
                      as DayHours,
            holidayModeEnabled: null == holidayModeEnabled
                ? _value.holidayModeEnabled
                : holidayModeEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }

  @override
  @pragma('vm:prefer-inline')
  $DayHoursCopyWith<$Res> get monday {
    return $DayHoursCopyWith<$Res>(_value.monday, (value) {
      return _then(_value.copyWith(monday: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $DayHoursCopyWith<$Res> get tuesday {
    return $DayHoursCopyWith<$Res>(_value.tuesday, (value) {
      return _then(_value.copyWith(tuesday: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $DayHoursCopyWith<$Res> get wednesday {
    return $DayHoursCopyWith<$Res>(_value.wednesday, (value) {
      return _then(_value.copyWith(wednesday: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $DayHoursCopyWith<$Res> get thursday {
    return $DayHoursCopyWith<$Res>(_value.thursday, (value) {
      return _then(_value.copyWith(thursday: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $DayHoursCopyWith<$Res> get friday {
    return $DayHoursCopyWith<$Res>(_value.friday, (value) {
      return _then(_value.copyWith(friday: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $DayHoursCopyWith<$Res> get saturday {
    return $DayHoursCopyWith<$Res>(_value.saturday, (value) {
      return _then(_value.copyWith(saturday: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $DayHoursCopyWith<$Res> get sunday {
    return $DayHoursCopyWith<$Res>(_value.sunday, (value) {
      return _then(_value.copyWith(sunday: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$OperatingHoursModelImplCopyWith<$Res>
    implements $OperatingHoursModelCopyWith<$Res> {
  factory _$$OperatingHoursModelImplCopyWith(
    _$OperatingHoursModelImpl value,
    $Res Function(_$OperatingHoursModelImpl) then,
  ) = __$$OperatingHoursModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    DayHours monday,
    DayHours tuesday,
    DayHours wednesday,
    DayHours thursday,
    DayHours friday,
    DayHours saturday,
    DayHours sunday,
    bool holidayModeEnabled,
  });

  @override
  $DayHoursCopyWith<$Res> get monday;
  @override
  $DayHoursCopyWith<$Res> get tuesday;
  @override
  $DayHoursCopyWith<$Res> get wednesday;
  @override
  $DayHoursCopyWith<$Res> get thursday;
  @override
  $DayHoursCopyWith<$Res> get friday;
  @override
  $DayHoursCopyWith<$Res> get saturday;
  @override
  $DayHoursCopyWith<$Res> get sunday;
}

/// @nodoc
class __$$OperatingHoursModelImplCopyWithImpl<$Res>
    extends _$OperatingHoursModelCopyWithImpl<$Res, _$OperatingHoursModelImpl>
    implements _$$OperatingHoursModelImplCopyWith<$Res> {
  __$$OperatingHoursModelImplCopyWithImpl(
    _$OperatingHoursModelImpl _value,
    $Res Function(_$OperatingHoursModelImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? monday = null,
    Object? tuesday = null,
    Object? wednesday = null,
    Object? thursday = null,
    Object? friday = null,
    Object? saturday = null,
    Object? sunday = null,
    Object? holidayModeEnabled = null,
  }) {
    return _then(
      _$OperatingHoursModelImpl(
        monday: null == monday
            ? _value.monday
            : monday // ignore: cast_nullable_to_non_nullable
                  as DayHours,
        tuesday: null == tuesday
            ? _value.tuesday
            : tuesday // ignore: cast_nullable_to_non_nullable
                  as DayHours,
        wednesday: null == wednesday
            ? _value.wednesday
            : wednesday // ignore: cast_nullable_to_non_nullable
                  as DayHours,
        thursday: null == thursday
            ? _value.thursday
            : thursday // ignore: cast_nullable_to_non_nullable
                  as DayHours,
        friday: null == friday
            ? _value.friday
            : friday // ignore: cast_nullable_to_non_nullable
                  as DayHours,
        saturday: null == saturday
            ? _value.saturday
            : saturday // ignore: cast_nullable_to_non_nullable
                  as DayHours,
        sunday: null == sunday
            ? _value.sunday
            : sunday // ignore: cast_nullable_to_non_nullable
                  as DayHours,
        holidayModeEnabled: null == holidayModeEnabled
            ? _value.holidayModeEnabled
            : holidayModeEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$OperatingHoursModelImpl extends _OperatingHoursModel {
  const _$OperatingHoursModelImpl({
    this.monday = const DayHours(),
    this.tuesday = const DayHours(),
    this.wednesday = const DayHours(),
    this.thursday = const DayHours(),
    this.friday = const DayHours(),
    this.saturday = const DayHours(openTime: '10:00', closeTime: '23:00'),
    this.sunday = const DayHours(openTime: '10:00', closeTime: '21:00'),
    this.holidayModeEnabled = false,
  }) : super._();

  @override
  @JsonKey()
  final DayHours monday;
  @override
  @JsonKey()
  final DayHours tuesday;
  @override
  @JsonKey()
  final DayHours wednesday;
  @override
  @JsonKey()
  final DayHours thursday;
  @override
  @JsonKey()
  final DayHours friday;
  @override
  @JsonKey()
  final DayHours saturday;
  @override
  @JsonKey()
  final DayHours sunday;
  @override
  @JsonKey()
  final bool holidayModeEnabled;

  @override
  String toString() {
    return 'OperatingHoursModel(monday: $monday, tuesday: $tuesday, wednesday: $wednesday, thursday: $thursday, friday: $friday, saturday: $saturday, sunday: $sunday, holidayModeEnabled: $holidayModeEnabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OperatingHoursModelImpl &&
            (identical(other.monday, monday) || other.monday == monday) &&
            (identical(other.tuesday, tuesday) || other.tuesday == tuesday) &&
            (identical(other.wednesday, wednesday) ||
                other.wednesday == wednesday) &&
            (identical(other.thursday, thursday) ||
                other.thursday == thursday) &&
            (identical(other.friday, friday) || other.friday == friday) &&
            (identical(other.saturday, saturday) ||
                other.saturday == saturday) &&
            (identical(other.sunday, sunday) || other.sunday == sunday) &&
            (identical(other.holidayModeEnabled, holidayModeEnabled) ||
                other.holidayModeEnabled == holidayModeEnabled));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
    sunday,
    holidayModeEnabled,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$OperatingHoursModelImplCopyWith<_$OperatingHoursModelImpl> get copyWith =>
      __$$OperatingHoursModelImplCopyWithImpl<_$OperatingHoursModelImpl>(
        this,
        _$identity,
      );
}

abstract class _OperatingHoursModel extends OperatingHoursModel {
  const factory _OperatingHoursModel({
    final DayHours monday,
    final DayHours tuesday,
    final DayHours wednesday,
    final DayHours thursday,
    final DayHours friday,
    final DayHours saturday,
    final DayHours sunday,
    final bool holidayModeEnabled,
  }) = _$OperatingHoursModelImpl;
  const _OperatingHoursModel._() : super._();

  @override
  DayHours get monday;
  @override
  DayHours get tuesday;
  @override
  DayHours get wednesday;
  @override
  DayHours get thursday;
  @override
  DayHours get friday;
  @override
  DayHours get saturday;
  @override
  DayHours get sunday;
  @override
  bool get holidayModeEnabled;
  @override
  @JsonKey(ignore: true)
  _$$OperatingHoursModelImplCopyWith<_$OperatingHoursModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
