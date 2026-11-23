import 'dart:io';

import 'package:flutter/painting.dart' show debugNetworkImageHttpClientProvider;
import 'package:flutter_test/flutter_test.dart';

import 'network_blocker.dart';

/// ROUTER-3 T-4 — canary for the network-blocker harness (W2.8, 07-P1-6).
///
/// Proves transport isolation at the `dart:io` `HttpClient` layer: every
/// outbound request from a widget test must throw [NetworkBlockedException]
/// once [blockAllNetwork] is installed (the global `flutter_test_config.dart`
/// installs it for every test file), and the [blockNetworkImages] variant must
/// block the Flutter image transport independently of [HttpOverrides].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ROUTER-3 T-4: network blocker canary', () {
    test('HttpClient() is intercepted after blockAllNetwork', () {
      blockAllNetwork();
      expect(HttpOverrides.current, isNotNull);
      expect(HttpClient(), isA<HttpClient>());
    });

    test(
      'outbound HttpClient().getUrl throws NetworkBlockedException',
      () async {
        blockAllNetwork();
        await expectLater(
          HttpClient().getUrl(Uri.parse('https://example.com/probe')),
          throwsA(isA<NetworkBlockedException>()),
        );
      },
    );

    test(
      'every verb on the blocked client throws NetworkBlockedException',
      () async {
        blockAllNetwork();
        final client = HttpClient();
        const uri = 'https://example.com/x';
        final parsed = Uri.parse(uri);
        await expectLater(
          client.postUrl(parsed),
          throwsA(isA<NetworkBlockedException>()),
        );
        await expectLater(
          client.putUrl(parsed),
          throwsA(isA<NetworkBlockedException>()),
        );
        await expectLater(
          client.deleteUrl(parsed),
          throwsA(isA<NetworkBlockedException>()),
        );
        await expectLater(
          client.headUrl(parsed),
          throwsA(isA<NetworkBlockedException>()),
        );
        await expectLater(
          client.openUrl('PATCH', parsed),
          throwsA(isA<NetworkBlockedException>()),
        );
        await expectLater(
          client.get('example.com', 443, '/x'),
          throwsA(isA<NetworkBlockedException>()),
        );
        await expectLater(
          client.open('POST', 'example.com', 443, '/x'),
          throwsA(isA<NetworkBlockedException>()),
        );
      },
    );

    test('blockNetworkImages() blocks the NetworkImage transport', () async {
      // Remove THIS harness's all-network override so the test proves the
      // IMAGE-layer hook is what refuses the fetch — not the global override.
      restoreNetwork();
      expect(isNetworkBlocked(), isFalse);

      blockNetworkImages();
      expect(debugNetworkImageHttpClientProvider, isNotNull);
      final client = debugNetworkImageHttpClientProvider!();
      expect(client, isA<HttpClient>());
      await expectLater(
        client.getUrl(Uri.parse('https://example.com/img.png')),
        throwsA(isA<NetworkBlockedException>()),
      );

      restoreNetworkImages();
      expect(debugNetworkImageHttpClientProvider, isNull);
    });

    test('restoreNetwork() removes the global blocker', () {
      blockAllNetwork();
      expect(isNetworkBlocked(), isTrue);
      restoreNetwork();
      expect(isNetworkBlocked(), isFalse);
      expect(debugNetworkImageHttpClientProvider, isNull);
    });
  });
}
