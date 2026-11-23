/// Stripe Terminal NFC / Bluetooth Tap-to-Pay placeholder.
///
/// TODO_DEPLOY: Full Stripe Terminal SDK requires:
///   1. Add `stripe_terminal` to pubspec.yaml (iOS/Android native plugin)
///   2. Request Bluetooth + Location permissions
///   3. Configure a Stripe Terminal Location in the Dashboard
///   4. Generate a ConnectionToken via a backend Cloud Function
///
/// This service provides the interface contract so the rest of the codebase
/// can reference it today, and the SDK can be dropped in without refactoring.
/// It is NOT a stub of production behavior: it performs no fake success and
/// never claims a payment charged — it always returns `success: false` with a
/// clear error until the real SDK is wired in.
class NfcTerminalService {
  static NfcTerminalService? _instance;
  static NfcTerminalService get instance =>
      _instance ??= NfcTerminalService._();
  NfcTerminalService._();

  bool _initialized = false;

  /// Initialise the Stripe Terminal SDK.
  /// Call once from the driver/POS screen's initState.
  Future<void> initialize({
    required Future<String> Function() fetchConnectionToken,
  }) async {
    if (_initialized) return;
    // TODO_DEPLOY: Deferred StripeTerminal instantiation (requires native
    // plugin + location permissions). No-op today; the real implementation
    // drops in behind this same interface without UI changes.
    _initialized = true;
  }

  /// Discover and connect to the nearest Bluetooth terminal reader.
  /// Returns null — a documented "no reader" state, NOT a fake success.
  Future<TerminalReader?> discoverReader() async {
    // TODO_DEPLOY: Deferred StripeTerminal bluetooth discovery.
    // Returns null (no reader) until the SDK is wired — Law 4 graceful
    // degradation instead of UnimplementedError crash.
    return null;
  }

  /// Collect and process an in-person payment for [amountCents].
  Future<TerminalPaymentResult> collectPayment({
    required String paymentIntentClientSecret,
    required int amountCents,
  }) async {
    // TODO_DEPLOY: Deferred StripeTerminal execution. Returns a clear
    // failure (NOT a fake success) so callers can never treat an unprocessed
    // in-person payment as charged.
    return const TerminalPaymentResult(
      success: false,
      error: 'NFC Terminal: SDK not yet integrated (TODO_DEPLOY)',
    );
  }
}

class TerminalReader {
  final String serialNumber;
  final String deviceType;
  const TerminalReader({required this.serialNumber, required this.deviceType});
}

class TerminalPaymentResult {
  final bool success;
  final String? error;
  final String? chargeId;
  const TerminalPaymentResult({
    required this.success,
    this.error,
    this.chargeId,
  });
}
