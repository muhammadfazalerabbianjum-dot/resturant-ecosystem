import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core/src/models/lat_lng_parse.dart';

/// p28 T-2 — `LatLngParse.fromDoc` (B4-3): the branch/location doc must
/// resolve EVERY historical geo shape, and a doc without geo data must FAIL
/// SAFE to (0, 0) — never a partial pin to null island.
void main() {
  test('fromDoc reads the geoflutterfire `geo.geopoint` index shape', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('branches').doc('b1').set(<String, dynamic>{
      'geo': <String, dynamic>{'geopoint': const GeoPoint(24.7136, 46.6753)},
    });
    final doc = await db.collection('branches').doc('b1').get();

    expect(LatLngParse.fromDoc(doc), (lat: 24.7136, lng: 46.6753));
  });

  test(
    'fromDoc on a MISSING doc fails safe to (0, 0) (no partial coords)',
    () async {
      final db = FakeFirebaseFirestore();
      final doc = await db.collection('branches').doc('missing').get();

      expect(
        LatLngParse.fromDoc(doc),
        (lat: 0.0, lng: 0.0),
        reason:
            'data() is null for a missing doc — the parser must return the '
            'neutral pair so the CALLER decides, never a half-populated point',
      );
    },
  );
}
