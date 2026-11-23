import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Injectable Cloud Functions handle for testability.
///
/// In production, this returns [FirebaseFunctions.instance].
///
/// In tests, override with a faked `firebase_functions` implementation:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     functionsProvider.overrideWithValue(fakeFunctions),
///   ],
///   child: ...,
/// )
/// ```
final functionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instance;
});
