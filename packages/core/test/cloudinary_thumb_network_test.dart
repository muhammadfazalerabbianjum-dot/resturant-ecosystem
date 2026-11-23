import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// STATE-3 T-2 — Thumb bytes << original (master W8.8 guard: "one
/// integration assert that thumbnail bytes ≪ original bytes").
///
/// REAL network integration: fetches the Cloudinary demo cloud's public
/// `sample` asset once as the raw original and once through the production
/// [cloudinaryThumb] helper, and asserts the CDN actually serves a smaller
/// payload for the transformed URL. This proves the exact transform string
/// the helper emits is valid Cloudinary delivery syntax — not just that the
/// URL changed.
void main() {
  // Cloudinary's canonical public demo asset (stable public id, demo cloud).
  const originalUrl = 'https://res.cloudinary.com/demo/image/upload/sample.jpg';

  test(
    'cloudinaryThumb URL serves fewer bytes than the original URL',
    () async {
      final client = http.Client();
      final original = await client
          .get(Uri.parse(originalUrl))
          .timeout(const Duration(seconds: 30));
      expect(
        original.statusCode,
        200,
        reason: 'original asset must be fetchable',
      );

      final thumbUrl = cloudinaryThumb(originalUrl, width: 100);
      // The helper must have inserted the transform after /upload/.
      expect(thumbUrl, contains('/upload/w_100,q_auto,f_auto/'));

      final thumb = await client
          .get(Uri.parse(thumbUrl))
          .timeout(const Duration(seconds: 30));
      expect(thumb.statusCode, 200, reason: 'thumb asset must be fetchable');
      expect(
        thumb.bodyBytes.length,
        lessThan(original.bodyBytes.length),
        reason:
            'CDN thumbnail (w_100) must be smaller than the original; '
            'original=${original.bodyBytes.length}B thumb=${thumb.bodyBytes.length}B',
      );
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
