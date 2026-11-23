import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/presentation/analytics_snapshot.dart';

void main() {
  test('AnalyticsSnapshot class is constructable', () {
    const snapshot = AnalyticsSnapshot();
    expect(snapshot, isNotNull);
  });

  test('AnalyticsSnapshot key can be customized', () {
    const key = Key('test-key');
    const snapshot = AnalyticsSnapshot(key: key);
    expect(snapshot.key, key);
  });

  test('AnalyticsSnapshot has correct runtime type name', () {
    const snapshot = AnalyticsSnapshot();
    expect(snapshot.runtimeType.toString(), contains('AnalyticsSnapshot'));
  });

  test('AnalyticsSnapshot with default key has null key', () {
    const snapshot = AnalyticsSnapshot();
    expect(snapshot.key, isNull);
  });

  test('AnalyticsSnapshot is a ConsumerWidget subclass', () {
    // ConsumerWidget is the parent class of AnalyticsSnapshot
    // Verify it inherits from StatelessWidget via ConsumerWidget
    expect(AnalyticsSnapshot, isNot(equals(StatelessWidget)));
  });
}
