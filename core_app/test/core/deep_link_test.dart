import 'package:flutter_test/flutter_test.dart';

// Assuming DeepLinkService static router translations:
String resolveMockPath(String urlStr) {
  final uri = Uri.parse(urlStr);
  var path = uri.path;
  if (path.isEmpty || path == '/') path = '/';
  final query = uri.queryParameters;

  if (path.startsWith('/menu/item/')) {
    final itemId = path.split('/').last;
    return '/menu/item/$itemId';
  } else if (path.startsWith('/menu')) {
    final category = query['category'] ?? '';
    return '/menu${category.isNotEmpty ? "?category=$category" : ""}';
  } else if (path.startsWith('/cart')) {
    final promoCode = query['promo'] ?? '';
    return '/cart${promoCode.isNotEmpty ? "?promo=$promoCode" : ""}';
  } else if (path.startsWith('/reservation')) {
    return '/reservation';
  } else if (path != '/') {
    return '/';
  }
  return path;
}

void main() {
  group('Deep Link Translation Engine — F4', () {
    test('Resolves empty or root paths to home /', () {
      expect(resolveMockPath('https://carnama.com'), '/');
      expect(resolveMockPath('https://carnama.com/'), '/');
      expect(resolveMockPath('carnama://'), '/');
    });

    test('Resolves unknown paths to home /', () {
      expect(resolveMockPath('https://carnama.com/unknown/path'), '/');
    });

    test('Appends category parameter for menu deep links', () {
      expect(
        resolveMockPath('https://carnama.com/menu?category=Pizza'),
        '/menu?category=Pizza',
      );
      expect(resolveMockPath('https://carnama.com/menu'), '/menu');
    });

    test('Extracts itemId from item deep links', () {
      expect(
        resolveMockPath('https://carnama.com/menu/item/XYZ123'),
        '/menu/item/XYZ123',
      );
    });

    test('Appends promo parameter for cart deep links', () {
      expect(
        resolveMockPath('https://carnama.com/cart?promo=SAVE20'),
        '/cart?promo=SAVE20',
      );
      expect(resolveMockPath('https://carnama.com/cart'), '/cart');
    });

    test('Resolves reservation deep links correctly', () {
      expect(
        resolveMockPath('https://carnama.com/reservation'),
        '/reservation',
      );
    });
  });
}
