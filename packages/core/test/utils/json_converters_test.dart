// PERF-10 T-8 — direct behavioral coverage for the Firestore timestamp
// converters. WIRED-UNTESTED before this wave: every model's fromJson passes
// through these helpers, yet no test pinned the malformed-input fallbacks.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('timestampToDateTime', () {
    test('Firestore Timestamp -> the same instant', () {
      final dt = DateTime.utc(2026, 8, 14, 9, 30);
      expect(timestampToDateTime(Timestamp.fromDate(dt)).toUtc(), dt);
    });

    test('ISO-8601 string -> parsed instant', () {
      expect(
        timestampToDateTime('2026-08-14T09:30:00.000Z').toUtc(),
        DateTime.utc(2026, 8, 14, 9, 30),
      );
    });

    test('epoch int -> millisecondsSinceEpoch instant', () {
      final ms = DateTime.utc(2026, 8, 14, 9, 30).millisecondsSinceEpoch;
      expect(timestampToDateTime(ms).toUtc(), DateTime.utc(2026, 8, 14, 9, 30));
    });

    test('malformed string falls back to now and never throws', () {
      final before = DateTime.now();
      final parsed = timestampToDateTime('not-a-date');
      final after = DateTime.now();
      expect(parsed.isBefore(before), isFalse);
      expect(parsed.isAfter(after), isFalse);
    });

    test('unexpected types fall back to now and never throw', () {
      for (final bad in <Object>[
        3.5,
        true,
        <String, dynamic>{'seconds': 1},
        <Object>[],
      ]) {
        final before = DateTime.now();
        final parsed = timestampToDateTime(bad);
        final after = DateTime.now();
        expect(
          parsed.isBefore(before),
          isFalse,
          reason: '${bad.runtimeType} must fall back to now',
        );
        expect(parsed.isAfter(after), isFalse);
      }
    });
  });

  group('timestampToDateTimeNullable', () {
    test('null stays null (no fallback-to-now for absent fields)', () {
      expect(timestampToDateTimeNullable(null), isNull);
    });

    test('non-null values delegate to timestampToDateTime', () {
      final ms = DateTime.utc(2026, 1, 2).millisecondsSinceEpoch;
      expect(
        timestampToDateTimeNullable(ms)?.toUtc(),
        DateTime.utc(2026, 1, 2),
      );
    });
  });

  group('dateTimeToTimestamp', () {
    test('round-trips through timestampToDateTime', () {
      final dt = DateTime.utc(2026, 8, 14, 9, 30);
      expect(timestampToDateTime(dateTimeToTimestamp(dt)).toUtc(), dt);
    });

    test('nullable variant: null -> null, value -> Timestamp', () {
      expect(dateTimeToTimestampNullable(null), isNull);
      final dt = DateTime.utc(2026, 8, 14);
      expect(dateTimeToTimestampNullable(dt)?.toDate().toUtc(), dt);
    });
  });
}
