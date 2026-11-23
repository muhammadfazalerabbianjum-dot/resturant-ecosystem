import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';

class PromoCodeResult {
  final bool isValid;
  final int discountCents;
  final String? message;
  const PromoCodeResult({
    required this.isValid,
    this.discountCents = 0,
    this.message,
  });
}

/// Server-authoritative promo validation (B1, P0-2).
///
/// The discount is computed by the Cloud Function `applyPromo`, which reads
/// `promoCodes/{code}` + `promo_usage/{code}_{uid}` server-side and returns
/// the authoritative discount. The client NEVER reads promoCodes directly and
/// NEVER sends a discount value (a hostile client cannot inflate a discount).
/// Usage is tracked by the server at CHARGE time (idempotent, uid-scoped).
class PromoCodeService {
  final FirebaseFunctions _functions;
  final LoggerService _logger;

  PromoCodeService(this._functions, this._logger);

  Future<PromoCodeResult> validate(String code, int cartTotalCents) async {
    try {
      final trimmed = code.trim().toUpperCase();
      if (trimmed.isEmpty) {
        return const PromoCodeResult(isValid: false, message: 'Enter a code');
      }

      final callable = _functions.httpsCallable('applyPromo');
      // QUEUE-2 (P-3): `applyPromo` is a pure read — transient failures are
      // retried with bounded classified backoff. Server rejections like
      // `failed-precondition` (promo exhausted) are permanent codes and
      // surface immediately to the catch below (no retry burn).
      final response = await NetworkRetry.withExponentialBackoff(
        () => callable.call({
          'code': trimmed,
          'cartSubtotalCents': cartTotalCents,
        }),
      );
      final data = response.data as Map<String, dynamic>;
      final valid = data['valid'] == true;
      return PromoCodeResult(
        isValid: valid,
        discountCents: ((data['discountCents'] as num?)?.toInt() ?? 0),
        message: valid ? 'Code applied!' : 'Code rejected',
      );
    } on FirebaseFunctionsException catch (e) {
      // Server-provided message (e.g. "Promo code has been fully redeemed").
      await _logger.error(e, 'PromoCodeService_validate');
      return PromoCodeResult(
        isValid: false,
        message: (e.message ?? '').trim().isEmpty ? 'Code rejected' : e.message,
      );
    } catch (e, stack) {
      await _logger.error(e, 'PromoCodeService_validate', stack: stack);
      return const PromoCodeResult(
        isValid: false,
        message: 'Error checking code',
      );
    }
  }
}
