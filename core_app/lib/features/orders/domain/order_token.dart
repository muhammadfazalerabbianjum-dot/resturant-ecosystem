/// Normalizes and truncates order IDs to a safe length (default: 8) to
/// prevent substring crashes on shorter strings, and returns them in uppercase.
String safeOrderToken(String id, [int len = 8]) {
  if (id.isEmpty) return '';
  return (id.length >= len ? id.substring(0, len) : id).toUpperCase();
}
