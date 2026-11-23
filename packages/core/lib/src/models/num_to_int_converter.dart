import 'package:freezed_annotation/freezed_annotation.dart';

class NumToIntConverter implements JsonConverter<int, dynamic> {
  const NumToIntConverter();

  @override
  int fromJson(dynamic json) {
    // BANKER'S ROUNDING for fractional cents (Law 3): never truncate.
    if (json is num) return json.round();
    if (json is String) return num.tryParse(json)?.round() ?? 0;
    return 0;
  }

  @override
  dynamic toJson(int object) => object;
}
