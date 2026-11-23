/// Shared currency display helpers.
///
/// FIX-B3 / AUD1-02: this file no longer implements money rendering. Both
/// helpers are one-line delegates to `package:core_ui`'s money renderer —
/// the single CLDR-conformant rule set (W9.3's "canonical formatter" is now
/// a thin delegate; the duplicated symbol map and the `$-1.50` sign compose
/// were deleted, so no second rule set remains to drift).
///
/// UI-8 (p18) T-3 (L2 money-display parity, display-only): the delegate
/// gained ONE seam — an optional [locale]. `ar` renders per CLDR `ar`
/// currency patterns via `intl`'s bundled NumberSymbols (RTL mark, amount,
/// NBSP, symbol; minus before the amount; fraction digits from CLDR
/// minorDigits), with symbols still coming from the ONE `moneySymbolFor`
/// map. Every other locale — and the default when [locale] is omitted —
/// keeps today's byte-identical output.
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:core_ui/core_ui.dart';
import 'package:intl/intl.dart';

/// Maps a currency code (from `RestaurantConfigModel.currency`) to its
/// display symbol — delegates to the ONE symbol map in `package:core_ui`
/// (AUD1-02). Null/empty codes fall back to `$`; unknown codes render a
/// `CODE ` prefix (fail-closed, never a wrong hardcoded currency).
String currencySymbolFor(String? code) => moneySymbolFor(code);

/// The ONE currency precedence rule (p37 T-3): runtime doc → config seed →
/// `USD`.
///
/// WHY: `client_config.json` carries a `currency` block that nothing read
/// (R3), while the money path fell straight back to a hardcoded `'USD'`. The
/// owner-set Firestore doc (`settings/restaurantConfig.currency`) must always
/// win; the config block is the seed for a brand-new project; `USD` is the
/// last resort. Callers pass the raw doc value — null while the stream is
/// loading counts as absent — and `AppConfig.currencyCode` via the app layer.
String resolveCurrencyCode({String? fromDoc, String? fromConfig}) {
  final doc = fromDoc?.trim();
  if (doc != null && doc.isNotEmpty) return doc;
  final config = fromConfig?.trim();
  if (config != null && config.isNotEmpty) return config;
  return 'USD';
}

// The min-int sentinel is NOT re-declared here (P2-1a): `isMinInt` from
// `package:core_ui` is the one portable rule, imported below. A second literal
// would reintroduce the dart2js defect this card exists to remove.

/// Formats an integer cent value with the configured currency symbol and,
/// for `ar`, per CLDR `ar` currency patterns (T-3).
///
/// - [locale] omitted → the ambient locale is resolved as
///   `Intl.defaultLocale ?? platform locale`. The app never sets
///   `Intl.defaultLocale` (audited), and the `MaterialApp` sets no explicit
///   `locale:` (it follows the device), so at runtime this is the device
///   locale — which IS the app locale. Tests pin `Intl.defaultLocale` for
///   deterministic ambient checks.
/// - `en` (or any locale that is not `ar`) → byte-identical to today:
///   one-line delegation to the single renderer `moneyCents` (L2 parity —
///   asserted across the full 14-row matrix in
///   `test/app/config/money_cldr_parity_test.dart`).
/// - `ar*` → `intl`'s CLDR currency pattern for the tag (`\u200F#,##0.00\u00A0¤`
///   family: RTL mark, NBSP before the symbol, minus BEFORE the amount
///   when negative), symbol from the ONE `moneySymbolFor` map (trailing
///   separator space trimmed — the NBSP provides the gap), fraction digits
///   from CLDR minorDigits via the currency name (JPY/KRW stay 0-decimal).
///   `int.min` still fails closed to [kMoneyRenderPlaceholder] — never a
///   fabricated number.
///
/// Display-only (0.10): integer cents and money math are untouched; this
/// only changes the rendered string.
String formatCurrencyCents(int cents, {String? currencyCode, String? locale}) {
  final ambient =
      locale ??
      Intl.defaultLocale ??
      PlatformDispatcher.instance.locale.toString();
  final tag = ambient.toLowerCase().replaceAll('-', '_');
  if (!tag.startsWith('ar')) {
    // en + every unsupported locale: byte-identical current behavior.
    return moneyCents(cents, currencyCode: currencyCode);
  }
  if (isMinInt(cents)) {
    // T-5 fail-closed in ar too — delegate so exactly one rule decides.
    return moneyCents(cents, currencyCode: currencyCode);
  }
  final normalized = (currencyCode ?? '').trim().toUpperCase();
  // The map's trailing space exists only for the symbol-first en compose;
  // the CLDR pattern supplies an NBSP gap, so trim it here.
  final symbol = moneySymbolFor(currencyCode).trimRight();
  final formatter = NumberFormat.currency(
    locale: tag,
    name: normalized.isEmpty ? null : normalized,
    symbol: symbol,
  );
  return formatter.format(cents / 100);
}
