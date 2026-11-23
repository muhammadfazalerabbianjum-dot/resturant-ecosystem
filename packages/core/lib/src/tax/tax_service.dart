import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/src/config/core_config.dart';
import 'package:core/src/error_logger/logger_service.dart';
import 'package:core/src/network/network_retry.dart';

/// Calls the `calculateTax` Cloud Function to compute tax.
/// This is the **only** source of truth for tax calculation.
/// Throws on failure — the caller MUST abort checkout (fail-closed, Law 8).
class TaxService {
  final FirebaseFunctions? _injectedFn;
  final LoggerService _logger;

  TaxService({FirebaseFunctions? functions, LoggerService? logger})
    : _injectedFn = functions,
      _logger = logger ?? LoggerService();

  FirebaseFunctions get _fn => _injectedFn ?? FirebaseFunctions.instance;

  /// Returns [TaxResult] for the given state code and subtotal.
  /// Always calls the Cloud Function — no client-side tax calculation.
  ///
  /// [clientId] is the per-app identifier required by the Cloud Function to
  /// look up the client's own tax rate table (multi-app white-label, Law 3).
  /// Defaults to the value injected via [CoreConfigHolder] at app startup.
  Future<TaxResult> calculate({
    required String stateCode,
    required int subtotalCents,
    String? clientId,
  }) async {
    try {
      // QUEUE-2 (P-3): `calculateTax` is a pure read — transient failures
      // (2G networks, function cold starts) are retried with bounded
      // classified backoff. Fail-closed on final failure is unchanged.
      final result = await NetworkRetry.withExponentialBackoff(
        () => _fn.httpsCallable('calculateTax').call({
          'stateCode': stateCode,
          'subtotalCents': subtotalCents,
          'clientId': clientId ?? CoreConfigHolder.instance.clientId,
        }),
      );
      final data = result.data as Map<String, dynamic>;
      return TaxResult(
        taxCents: (data['taxCents'] as num).toInt(),
        rate: (data['rate'] as num).toDouble(),
        stateCode: data['stateCode'] as String,
      );
    } catch (e, stack) {
      try {
        await _logger.error(
          e,
          'TaxService_calculate failed for stateCode: $stateCode, subtotalCents: $subtotalCents',
          stack: stack,
        );
      } catch (_) {
        // WHY (p26 T-2): the default sink may be unavailable on this host
        // (e.g. no path_provider plugin under `flutter test`) — a logging
        // failure must never replace the fail-closed business error the
        // caller is about to receive (Law 8; same pattern as
        // LoggerService.error's Crashlytics guard).
      }
      rethrow; // FAIL-CLOSED — caller aborts; never silently charge $0 tax
    }
  }
}

class TaxResult {
  final int taxCents;
  final double rate;
  final String stateCode;

  const TaxResult({
    required this.taxCents,
    required this.rate,
    required this.stateCode,
  });

  String get rateLabel => '${(rate * 100).toStringAsFixed(2)}%';
}
