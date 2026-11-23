import 'package:cloud_firestore/cloud_firestore.dart';

/// Converts Firestore [Timestamp], ISO-8601 [String] or epoch [int] → [DateTime].
/// Returns the current date/time if parsing fails — per spec fallback to now.
DateTime timestampToDateTime(Object json) {
  if (json is Timestamp) return json.toDate();
  if (json is String) {
    final parsed = DateTime.tryParse(json);
    return parsed ?? DateTime.now();
  }
  if (json is int) return DateTime.fromMillisecondsSinceEpoch(json);
  return DateTime.now();
}

/// Nullable variant of [timestampToDateTime].
DateTime? timestampToDateTimeNullable(Object? json) {
  if (json == null) return null;
  return timestampToDateTime(json);
}

/// Converts [DateTime] → Firestore [Timestamp].
Timestamp dateTimeToTimestamp(DateTime dt) => Timestamp.fromDate(dt);

/// Nullable variant.
Timestamp? dateTimeToTimestampNullable(DateTime? dt) =>
    dt == null ? null : Timestamp.fromDate(dt);
