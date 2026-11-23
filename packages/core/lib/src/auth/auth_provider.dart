import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/src/auth/auth_repository.dart';
import 'package:core/src/auth/user_model.dart';

// keepAlive
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

// keepAlive
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.isAnonymous) return null;
  return ref.watch(authRepositoryProvider).getUserData(user.uid);
});

/// Single source of truth for the current user's UID.
/// Use this instead of `FirebaseAuth.instance.currentUser?.uid` in any widget or provider.
/// Returns null if the user is not signed in.
// keepAlive
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});
