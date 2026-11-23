import 'package:cloud_firestore/cloud_firestore.dart';

/// WHY: Prevents stale cart pricing exploits (Phase 3 Gap 1).
/// A user caches a cart at $10, owner raises the price to $15 while
/// the cart sits open, then checks out at the old $10 price.
///
/// How it works:
/// - Before any checkout write, this service fetches the live `menus/{id}`
///   document for EVERY cart item.
/// - If the live price differs OR the item no longer exists / is unpublished,
///   it returns a [CartValidationResult] with a detailed human-readable message.
/// - The checkout presenter MUST call validate() and abort on any failure.

class CartValidationFailure {
  final String itemId;
  final String itemName;
  final String reason;
  const CartValidationFailure({
    required this.itemId,
    required this.itemName,
    required this.reason,
  });
}

sealed class CartValidationResult {
  const CartValidationResult();
}

class CartValidationSuccess extends CartValidationResult {
  const CartValidationSuccess();
}

class CartValidationFailed extends CartValidationResult {
  final List<CartValidationFailure> failures;
  const CartValidationFailed(this.failures);
}

class CartValidatorService {
  final FirebaseFirestore _firestore;

  CartValidatorService({required FirebaseFirestore firestore})
    : _firestore = firestore;

  /// Validates every [cartItems] entry against the live Firestore menu.
  ///
  /// [cartItems] must be a list of maps with at least:
  ///   { 'id': String, 'name': String, 'priceCents': int }
  Future<CartValidationResult> validate(
    List<Map<String, dynamic>> cartItems,
  ) async {
    final failures = <CartValidationFailure>[];

    // Batch reads: Firestore supports up to 10 doc reads per call.
    // We chunk into groups of 10 for safe batching.
    final chunks = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < cartItems.length; i += 10) {
      chunks.add(
        cartItems.sublist(
          i,
          i + 10 > cartItems.length ? cartItems.length : i + 10,
        ),
      );
    }

    for (final chunk in chunks) {
      final futures = chunk.map((item) {
        final id = item['id'] as String;
        return _firestore.collection('menus').doc(id).get();
      }).toList();

      final docs = await Future.wait(futures);

      for (var i = 0; i < docs.length; i++) {
        final cartItem = chunk[i];
        final doc = docs[i];
        final id = cartItem['id'] as String;
        final name = cartItem['name'] as String? ?? 'Unknown Item';
        final cachedPrice = cartItem['priceCents'] as int? ?? 0;

        // 1. GHOST CHECK — item no longer exists at all
        if (!doc.exists) {
          failures.add(
            CartValidationFailure(
              itemId: id,
              itemName: name,
              reason: '$name has been removed from the menu.',
            ),
          );
          continue;
        }

        final data = doc.data()!;

        // 2. AVAILABILITY CHECK — item has been unpublished
        final isAvailable = data['isAvailable'] as bool? ?? true;
        if (!isAvailable) {
          failures.add(
            CartValidationFailure(
              itemId: id,
              itemName: name,
              reason: '$name is temporarily unavailable.',
            ),
          );
          continue;
        }

        // 3. PRICE DRIFT CHECK — price changed since cart was opened
        final livePrice = (data['priceCents'] as num?)?.toInt() ?? 0;
        if (livePrice != cachedPrice) {
          final diff = ((livePrice - cachedPrice) / 100).toStringAsFixed(2);
          final direction = livePrice > cachedPrice ? 'increased' : 'decreased';
          failures.add(
            CartValidationFailure(
              itemId: id,
              itemName: name,
              reason:
                  '$name price $direction by $diff. Please review your cart.',
            ),
          );
        }
      }
    }

    if (failures.isEmpty) return const CartValidationSuccess();
    return CartValidationFailed(failures);
  }
}
