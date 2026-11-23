import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Injectable Firestore provider for testability.
///
/// In production, this returns [FirebaseFirestore.instance].
/// In tests, override with `fake_cloud_firestore`:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     firestoreProvider.overrideWithValue(fakeFirestore),
///   ],
///   child: ...
/// )
/// ```
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});
