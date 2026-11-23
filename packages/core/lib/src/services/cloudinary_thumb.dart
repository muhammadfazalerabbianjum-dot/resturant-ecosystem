/// Cloudinary CDN transform helper (STATE-3 / audit 04-P1-IMG).
///
/// Inserts `w_<w>,q_auto,f_auto` immediately after the FIRST `/upload/`
/// segment of a Cloudinary upload-delivery URL so list sites download a
/// CDN-sized thumbnail instead of the full-resolution original
/// (`memCacheWidth` caps only the decode; without this transform the network
/// bytes and disk-cache entries are still the originals).
///
/// Pass-through contract (never rewrite what the helper does not own):
/// - non-Cloudinary hosts — a foreign CDN URL is returned untouched even if
///   its path happens to contain `/upload/`;
/// - non-upload delivery types (`fetch/`, `sprite/`, …) — no `/upload/`;
/// - signed-delivery URLs (`/upload/s--<signature>--/…`) — inserting
///   transforms would invalidate the signature;
/// - URLs already carrying a transform segment after `/upload/` — the
///   insert-exactly-once guard, so repeated wrapping is a no-op.
///
/// This function is pure: no I/O, no config, no clock — safe to call in
/// build paths and to unit-test over a URL corpus.
String cloudinaryThumb(String url, {required int width}) {
  if (width <= 0) {
    throw ArgumentError.value(width, 'width', 'must be positive');
  }
  const uploadMarker = '/upload/';
  final markerIndex = url.indexOf(uploadMarker);
  // Not an upload-delivery URL (foreign CDN path, fetch/sprite types, …).
  if (markerIndex < 0) return url;

  // Only rewrite Cloudinary delivery hosts — never a foreign CDN URL.
  final host = Uri.tryParse(url)?.host ?? '';
  if (!(host == 'cloudinary.com' || host.endsWith('.cloudinary.com'))) {
    return url;
  }

  final rest = url.substring(markerIndex + uploadMarker.length);
  // Signed delivery: `s--<signature>--` directly after `/upload/`.
  if (rest.startsWith('s--')) return url;
  // Insert-exactly-once guard: a transform segment (e.g. `c_fill,w_100`,
  // `q_auto`) already follows `/upload/` — leave the URL untouched.
  if (_transformSegmentPattern.hasMatch(rest)) return url;

  final insertAt = markerIndex + uploadMarker.length;
  // The transform string is its own URL segment: `/upload/<transforms>/<rest>`
  // — the trailing slash keeps the version segment / public id a separate
  // segment (`…/upload/w_400,q_auto,f_auto/v1721000000/…`).
  return url.replaceRange(insertAt, insertAt, 'w_$width,q_auto,f_auto/');
}

/// A Cloudinary transform segment directly after `/upload/`:
/// `param_value,…` (e.g. `w_400`, `c_fill,h_200`). Version segments
/// (`v1721000000/…`) and public ids without `_` never match, so raw
/// secure_urls (which always lead with the version segment) are transformed
/// exactly once.
final RegExp _transformSegmentPattern = RegExp(r'^[a-z]+_[^/,]');
