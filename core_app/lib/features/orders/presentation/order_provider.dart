import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import '../data/order_repository.dart';
import '../domain/order_model.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(
    ref.watch(firestoreProvider),
    ref.read(loggerProvider),
    functions: ref.watch(functionsProvider),
  );
});

final userOrdersProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
  final auth = ref.watch(authStateProvider);
  // Auth has not produced its first value yet → the honest transient
  // loading state (the screen shows its skeleton for this instant only).
  if (!auth.hasValue && !auth.hasError) return const Stream.empty();
  final authError = auth.error;
  if (!auth.hasValue && authError != null) {
    // Fail closed (Law 8 / METHOD §2.3): an auth failure surfaces as the
    // screen's error state — never a silent eternal skeleton.
    return Stream<List<OrderModel>>.error(
      authError,
      auth.stackTrace ?? StackTrace.current,
    );
  }
  final user = auth.valueOrNull;
  // Signed out → an empty history IS the truth: the provider must COMPLETE
  // with [] so Order History shows its empty state. The previous
  // `Stream.empty()` emitted nothing and pinned the provider in loading
  // forever — the endless skeleton seen on the emulator (screenshot 21).
  if (user == null) return Stream<List<OrderModel>>.value(const []);
  return ref.watch(orderRepositoryProvider).getUserOrders(user.uid);
});
