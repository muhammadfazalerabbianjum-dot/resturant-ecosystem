import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// STATE-3 T-1 — Thumb URL corpus (master W8.8 guard).
///
/// Proves the [cloudinaryThumb] pass-through/insert contract on real URL
/// shapes: insert exactly once after the FIRST `/upload/`, double-insert
/// guard for already-transformed URLs, and untouched pass-through for
/// signed-delivery and non-Cloudinary URLs.
void main() {
  group('cloudinaryThumb T-1 URL corpus', () {
    test('inserts w_,q_auto,f_auto after /upload/ of a raw secure_url', () {
      const url =
          'https://res.cloudinary.com/carnama/image/upload/v1721000000/menu/latte.jpg';
      expect(
        cloudinaryThumb(url, width: 400),
        'https://res.cloudinary.com/carnama/image/upload/'
        'w_400,q_auto,f_auto/v1721000000/menu/latte.jpg',
      );
    });

    test('double-insert guard: already-transformed URL passes through', () {
      const url =
          'https://res.cloudinary.com/carnama/image/upload/'
          'w_400,q_auto,f_auto/v1721000000/menu/latte.jpg';
      expect(cloudinaryThumb(url, width: 400), url);
    });

    test('double-insert guard: a different transform also passes through', () {
      const url =
          'https://res.cloudinary.com/carnama/image/upload/c_fill,h_200/v1/x.jpg';
      expect(cloudinaryThumb(url, width: 100), url);
    });

    test('signed-delivery URL passes through untouched', () {
      const url =
          'https://res.cloudinary.com/carnama/image/upload/'
          's--AbCdEf123456--/v1721000000/private/receipt.jpg';
      expect(cloudinaryThumb(url, width: 100), url);
    });

    test('non-Cloudinary URL without /upload/ passes through', () {
      const url = 'https://cdn.example.com/images/latte.jpg';
      expect(cloudinaryThumb(url, width: 100), url);
    });

    test(
      'non-Cloudinary URL bearing /upload/ in its path is NOT corrupted',
      () {
        const url = 'https://cdn.example.com/upload/latte.jpg';
        expect(cloudinaryThumb(url, width: 100), url);
      },
    );

    test('non-upload Cloudinary delivery type (fetch) passes through', () {
      const url =
          'https://res.cloudinary.com/carnama/image/fetch/https://example.com/a.jpg';
      expect(cloudinaryThumb(url, width: 100), url);
    });

    test(
      'inserts after the FIRST /upload/ only when the public id repeats it',
      () {
        const url =
            'https://res.cloudinary.com/carnama/image/upload/v1/my/upload/path.jpg';
        expect(
          cloudinaryThumb(url, width: 150),
          'https://res.cloudinary.com/carnama/image/upload/'
          'w_150,q_auto,f_auto/v1/my/upload/path.jpg',
        );
      },
    );

    test('applies the requested width per call site (400/150/100)', () {
      const url = 'https://res.cloudinary.com/carnama/image/upload/v2/i.jpg';
      expect(
        cloudinaryThumb(url, width: 400).contains('w_400,q_auto,f_auto'),
        isTrue,
      );
      expect(
        cloudinaryThumb(url, width: 150).contains('w_150,q_auto,f_auto'),
        isTrue,
      );
      expect(
        cloudinaryThumb(url, width: 100).contains('w_100,q_auto,f_auto'),
        isTrue,
      );
    });

    test('rejects a non-positive width (fail-closed, no 0px transform)', () {
      const url = 'https://res.cloudinary.com/carnama/image/upload/v1/x.jpg';
      expect(() => cloudinaryThumb(url, width: 0), throwsArgumentError);
      expect(() => cloudinaryThumb(url, width: -5), throwsArgumentError);
    });
  });
}
