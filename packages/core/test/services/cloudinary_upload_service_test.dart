// PERF-10 T-8 — direct behavioral coverage for the Cloudinary unsigned upload
// service (WIRED-UNTESTED before this wave: instantiated nowhere, asserted
// nowhere). The HTTP leg runs through the documented test seam
// (`debugClientOverride` + `uploadToCloudinaryForTest`) with a MockClient —
// zero network I/O, no new dependency (`package:http/testing.dart` ships with
// the `http` package already in core's pubspec).
import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A [CoreConfig] that pins the white-label Cloudinary identity the service
/// must read (Law 3 — never a hardcoded account).
class _TestConfig implements CoreConfig {
  _TestConfig({this.cloudName = 'wl-cloud', this.preset = 'wl_preset'});

  final String cloudName;
  final String preset;

  @override
  bool get isDemoMode => false;

  @override
  String get clientId => 'com.example.wl';

  @override
  String get cloudinaryCloudName => cloudName;

  @override
  String get cloudinaryUploadPreset => preset;

  @override
  List<String> get ownerEmails => const [];

  @override
  String get kitchenLanEndpoint => 'http://127.0.0.1:8080/api/orders';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late http.Request captured;

  MockClient okClient() => MockClient((request) async {
    captured = request;
    return http.Response(
      jsonEncode({
        'secure_url':
            'https://res.cloudinary.com/wl-cloud/image/upload/v1/menu/latte.jpg',
      }),
      200,
    );
  });

  setUp(() {
    CoreConfigHolder.set(_TestConfig());
    CloudinaryUploadService.debugClientOverride = null;
  });

  tearDown(() {
    CloudinaryUploadService.debugClientOverride = null;
    CoreConfigHolder.set(const DefaultCoreConfig());
  });

  group('CloudinaryUploadService', () {
    test(
      'POSTs to the injected cloud name and returns secure_url (200)',
      () async {
        CloudinaryUploadService.debugClientOverride = okClient();

        final url = await CloudinaryUploadService.uploadToCloudinaryForTest(
          const [1, 2, 3, 4],
          'latte.jpg',
        );

        expect(
          url,
          'https://res.cloudinary.com/wl-cloud/image/upload/v1/menu/latte.jpg',
        );
        expect(captured.method, 'POST');
        expect(
          captured.url.toString(),
          'https://api.cloudinary.com/v1_1/wl-cloud/image/upload',
        );
      },
    );

    test("multipart carries THIS build's preset, filename and bytes", () async {
      CloudinaryUploadService.debugClientOverride = okClient();

      await CloudinaryUploadService.uploadToCloudinaryForTest(
        utf8.encode('PNGDATA'),
        'burger.png',
      );

      final body = captured.body;
      expect(body, contains('name="upload_preset"'));
      expect(
        body,
        contains('wl_preset'),
        reason: 'preset is config, not literal',
      );
      expect(body, contains('name="file"'));
      expect(body, contains('filename="burger.png"'));
      expect(
        body,
        contains('PNGDATA'),
        reason: 'the picked bytes must be sent',
      );
      expect(
        captured.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
    });

    test(
      'non-200 throws fail-loud with status + body (UI snackbar path)',
      () async {
        CloudinaryUploadService.debugClientOverride = MockClient(
          (request) async => http.Response('quota exceeded', 420),
        );

        await expectLater(
          CloudinaryUploadService.uploadToCloudinaryForTest(const [1], 'x.jpg'),
          throwsA(
            predicate(
              (e) =>
                  e.toString().contains('Cloudinary upload failed: 420') &&
                  e.toString().contains('quota exceeded'),
            ),
          ),
        );
      },
    );

    test(
      '200 without secure_url fails loud (never a silent null URL)',
      () async {
        CloudinaryUploadService.debugClientOverride = MockClient(
          (request) async => http.Response(jsonEncode({'public_id': 'x'}), 200),
        );

        await expectLater(
          CloudinaryUploadService.uploadToCloudinaryForTest(const [1], 'x.jpg'),
          throwsA(isA<TypeError>()),
        );
      },
    );

    test(
      'target + preset follow a different injected white-label identity',
      () async {
        CoreConfigHolder.set(
          _TestConfig(cloudName: 'halal-boyz', preset: 'hb_unsigned'),
        );
        CloudinaryUploadService.debugClientOverride = okClient();

        await CloudinaryUploadService.uploadToCloudinaryForTest(const [
          1,
        ], 'x.jpg');

        expect(captured.url.path, '/v1_1/halal-boyz/image/upload');
        expect(captured.body, contains('hb_unsigned'));
      },
    );

    test(
      'pickAndUploadImage surfaces a picker failure to the caller',
      () async {
        // No platform plugin is registered under `flutter test`, so the picker
        // throws — the service must re-wrap (never swallow) so the UI can show
        // its snackbar.
        await expectLater(
          CloudinaryUploadService.pickAndUploadImage(),
          throwsA(
            predicate(
              (e) =>
                  e is Exception &&
                  e.toString().contains('Image selection failed'),
            ),
          ),
        );
      },
    );
  });
}
