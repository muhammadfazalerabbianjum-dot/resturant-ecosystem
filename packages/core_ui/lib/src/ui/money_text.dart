/// Shared money formatter for integer-cent amounts (multi-app, config-aware).
///
/// Multi-app (Law 3): the active currency code and symbol come from the
/// restaurant's runtime config — never a hardcoded all-app symbol. Money is
/// integer cents everywhere in the codebase; this helper is display-only and
/// never touches the money math.
///
/// FIX-B3 / AUD1-02: this file is THE single source of truth for money
/// rendering. `formatCurrencyCents` (app config) and `formatAmount` (admin
/// dashboards) are one-line delegates to [moneyCents] — no second symbol map
/// or sign rule exists anywhere (grep proof: `tool_fix/b3/b3_report.md`).
///
/// Rules (CLDR-conformant; owner decision D-1):
/// - negative amounts render the minus BEFORE the symbol: `-$1.50`
/// - currency codes are trimmed and upper-cased (`usd` resolves to USD's
///   `$`, it never renders as a literal `usd ` prefix)
/// - JPY/KRW render zero decimals (CLDR `minorDigits=0`), rounded half away
///   from zero
/// - unknown codes fail closed to a `CODE ` prefix; null/empty codes keep
///   the documented `$` fallback
/// - a malformed cents value (`int.min`, the one value whose `.abs()`
///   overflows a two's-complement int) fails closed to
///   [kMoneyRenderPlaceholder] — never a fabricated number (T-5)
library;

/// Maps a 3-letter ISO currency code to its conventional display symbol.
///
/// The ONE currency-symbol rule set in the fleet (AUD1-02): every formatter
/// resolves symbols through here. Unknown codes fall back to a `CODE `
/// prefix so a new white-label app never inherits another app's symbol.
const Map<String, String> _kCurrencySymbols = {
  'USD': r'$',
  'CAD': r'CA$',
  'AUD': r'A$',
  'EUR': '€',
  'GBP': '£',
  'JPY': r'¥',
  'KRW': r'₩',
  'AED': 'AED ',
  'SAR': 'SAR ',
};

/// CLDR `minorDigits=0` currencies: whole units only, no fraction digits.
const Set<String> _kZeroDecimalCurrencies = {'JPY', 'KRW'};

/// Fail-closed render placeholder (T-5): shown instead of a fabricated
/// number when the cents value cannot be rendered faithfully.
const String kMoneyRenderPlaceholder = '—';

/// True for the one `int` whose `.abs()` overflows a two's-complement 64-bit
/// int (minInt64), false for every other value.
///
/// P2-1a: this is a PREDICATE, not a literal constant. `-9223372036854775807 - 1`
/// is exact on the VM but not representable under dart2js, where the comparison
/// was false for every real value and therefore silently disabled the T-5
/// fail-closed path (`checkpoints/P2-00.md`). `v != 0 && v == -v` needs no such
/// constant: on the VM it is true only for minInt64; on the web every value is
/// a double, where `-v == v` implies `v == 0`, so it is false throughout —
/// correct, because minInt64 cannot occur there. Both truth tables were
/// measured in `checkpoints/P2-00.md` §8.
///
/// Public so `currency_format.dart` reuses THIS rule instead of owning a second
/// copy of the sentinel (one rule set — L2).
bool isMinInt(int v) => v != 0 && v == -v;

/// The display symbol for [code], preferring an explicit [currencySymbol].
///
/// Public seam (AUD1-02): `currencySymbolFor` in core_app delegates here so
/// the fleet keeps exactly one symbol map.
String moneySymbolFor(String? code, {String? currencySymbol}) {
  if (currencySymbol != null && currencySymbol.isNotEmpty) {
    return currencySymbol;
  }
  final normalized = (code ?? '').trim().toUpperCase();
  if (normalized.isEmpty) return r'$';
  final known = _kCurrencySymbols[normalized];
  if (known != null) return known;
  // No known symbol and no explicit one: fail closed with a "CODE " prefix
  // rather than a hardcoded currency that could be wrong for another app.
  return '$normalized ';
}

/// Inserts thousands-grouping commas (US-style) into a non-negative integer.
String _groupThousands(int value) {
  final digits = value.abs().toString();
  if (digits.length <= 3) return digits;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Formats an integer-cent amount with the active currency config — the
/// single CLDR-conformant money renderer (D-1: `-$1.50`).
///
/// Consumes [currencyCode] (e.g. 'USD') and an optional explicit
/// [currencySymbol] from the client config. Negative signs are handled here
/// (minus before the symbol); callers must NOT prepend their own sign for a
/// value that may be negative.
String moneyCents(int cents, {String? currencyCode, String? currencySymbol}) {
  // T-5 fail-closed: minInt64 is the one value whose .abs() overflows — an
  // abs-based render would fabricate digits (pre-fix: `$--92,233,720,…`).
  if (isMinInt(cents)) return kMoneyRenderPlaceholder;

  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final symbol = moneySymbolFor(currencyCode, currencySymbol: currencySymbol);
  final normalizedCode = (currencyCode ?? '').trim().toUpperCase();

  if (_kZeroDecimalCurrencies.contains(normalizedCode)) {
    // CLDR minorDigits=0: whole units, rounded half away from zero.
    // (Computed without `abs + 50` so maxInt cents cannot overflow.)
    final truncated = abs ~/ 100;
    final remainder = abs % 100;
    final whole = remainder >= 50 ? truncated + 1 : truncated;
    return '$sign$symbol${_groupThousands(whole)}';
  }

  final whole = abs ~/ 100;
  final minor = abs % 100;
  return '$sign$symbol${_groupThousands(whole)}.${minor.toString().padLeft(2, '0')}';
}
