import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:core/src/network/http_interceptor.dart';

/// PERF-1 (T-6) — SafeHttpLoggingInterceptor: the interceptor must NEVER
/// mutate the wire objects (same instance back), must log in debug/profile
/// (kDebugMode is true under test) with the Authorization header stripped
/// from the log line, and must follow the !kReleaseMode interception gate.
/// LoggerService writes to a mocked path_provider temp directory.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // A STABLE system-temp path: dropped (un-awaited) logger writes from the
    // interceptors may land after the test ends — never delete it per-test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  test(
    'interceptRequest returns the SAME request (never mutates the wire)',
    () async {
      final interceptor = SafeHttpLoggingInterceptor();
      final request =
          http.Request('POST', Uri.parse('https://api.example.com/v1/orders'))
            ..headers['Authorization'] = 'Bearer SECRET'
            ..headers['X-Trace'] = 'trace-1';

      final out = await interceptor.interceptRequest(request: request);

      expect(identical(out, request), isTrue);
      expect(
        out.headers['Authorization'],
        'Bearer SECRET',
        reason:
            'the request itself is untouched — only the LOG omits the '
            'Authorization header',
      );
    },
  );

  test(
    'interceptResponse returns the SAME response (4xx/5xx log their body)',
    () async {
      final interceptor = SafeHttpLoggingInterceptor();
      final ok = http.Response('ok', 200);
      final err = http.Response('server boom', 500);

      expect(
        identical(await interceptor.interceptResponse(response: ok), ok),
        isTrue,
      );
      expect(
        identical(await interceptor.interceptResponse(response: err), err),
        isTrue,
      );
    },
  );

  test('shouldIntercept follows the !kReleaseMode gate', () async {
    final interceptor = SafeHttpLoggingInterceptor();
    final request = http.Request(
      'GET',
      Uri.parse('https://api.example.com/ping'),
    );
    final response = http.Response('ok', 200);

    expect(
      await interceptor.shouldInterceptRequest(request: request),
      !kReleaseMode,
    );
    expect(
      await interceptor.shouldInterceptResponse(response: response),
      !kReleaseMode,
    );
  });
}
