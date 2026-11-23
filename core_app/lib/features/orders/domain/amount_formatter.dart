import 'package:core_ui/core_ui.dart';

/// Formats cents into a currency format using the appropriate currency symbol.
///
/// FIX-B3 / AUD1-02: thin delegate to the single source of truth
/// (`moneyCents` in `package:core_ui`). The intl `NumberFormat` path was
/// deleted — its `dh12.50` / `Riyal12.50` / lowercase-code and sign
/// divergences were AUD1-02's findings, and two screens could render one
/// amount differently.
///
/// W9.3 (05-P1-L10N-MONEY): the silent `USD` default stays RETIRED — callers
/// MUST pass the client's configured currency code explicitly, so an AED/SAR
/// white-label client can never silently render USD prices.
String formatAmount(int cents, String currencyCode) =>
    moneyCents(cents, currencyCode: currencyCode);
