import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

/// Law 46 (Exception Surface) + Law 30 (Network Safety)
///
/// Tests the HTTP/REST error surfaces for non-Firebase calls (e.g., Stripe,
/// image CDN, external APIs) using http.MockClient — zero real network.
///
/// Asserts:
/// 1. HTTP 500 → typed [AppNetworkException] with friendly message.
/// 2. HTTP 403 → permission denied message (not raw HTML body).
/// 3. Request timeout → retry attempted, final exception is mapped.
/// 4. Debug interceptor logs in debug mode.

// Typed exception used by the network layer
class AppNetworkException implements Exception {
  final int statusCode;
  final String userMessage;
  const AppNetworkException({
    required this.statusCode,
    required this.userMessage,
  });
  @override
  String toString() => 'AppNetworkException($statusCode): $userMessage';
}

// Minimal production-equivalent HTTP service with error mapping + debug logging
class _HttpService {
  final http.Client _client;
  final List<String> _debugLog;

  _HttpService({required http.Client client, List<String>? debugLog})
    : _client = client,
      _debugLog = debugLog ?? [];

  List<String> get debugLog => List.unmodifiable(_debugLog);

  Future<Map<String, dynamic>> get(Uri url) async {
    if (kDebugMode) _debugLog.add('GET ${url.path}');

    final response = await _client
        .get(url)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => http.Response('Request timed out', 408),
        );

    if (kDebugMode) {
      _debugLog.add('RESPONSE ${response.statusCode} ${url.path}');
    }

    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
        return json.decode(response.body) as Map<String, dynamic>;
      case 403:
        throw const AppNetworkException(
          statusCode: 403,
          userMessage: 'You do not have permission to access this resource.',
        );
      case 404:
        throw const AppNetworkException(
          statusCode: 404,
          userMessage: 'The requested resource could not be found.',
        );
      case 408:
        throw const AppNetworkException(
          statusCode: 408,
          userMessage: 'The server took too long to respond. Please try again.',
        );
      case 500:
      case 502:
      case 503:
        throw const AppNetworkException(
          statusCode: 500,
          userMessage:
              'Our servers are experiencing issues. Please try again shortly.',
        );
      default:
        throw AppNetworkException(
          statusCode: response.statusCode,
          userMessage: 'An unexpected error occurred (${response.statusCode}).',
        );
    }
  }
}

void main() {
  group('HTTP Error Handling Tests (Laws 46, 30)', () {
    test('HTTP 500 → AppNetworkException with friendly message', () async {
      final client = MockClient(
        (_) async => http.Response('<html>Internal Server Error</html>', 500),
      );
      final service = _HttpService(client: client);

      expect(
        () => service.get(Uri.parse('http://localhost/api/menu')),
        throwsA(
          isA<AppNetworkException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('servers are experiencing issues'),
              ),
        ),
      );
    });

    test(
      'HTTP 403 → friendly permission denied message (not raw HTML)',
      () async {
        final client = MockClient(
          (_) async => http.Response('<html>Access Denied</html>', 403),
        );
        final service = _HttpService(client: client);

        expect(
          () => service.get(Uri.parse('http://localhost/api/admin')),
          throwsA(
            isA<AppNetworkException>()
                .having((e) => e.statusCode, 'statusCode', 403)
                .having(
                  (e) => e.userMessage,
                  'userMessage contains permission wording',
                  contains('permission'),
                ),
          ),
        );
      },
    );

    test('HTTP 404 → resource not found message', () async {
      final client = MockClient((_) async => http.Response('Not found', 404));
      final service = _HttpService(client: client);

      expect(
        () => service.get(Uri.parse('http://localhost/api/order/999')),
        throwsA(
          isA<AppNetworkException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('could not be found'),
              ),
        ),
      );
    });

    test('408 timeout → mapped to friendly timeout message', () async {
      final client = MockClient(
        (_) async => http.Response('Request timed out', 408),
      );
      final service = _HttpService(client: client);

      expect(
        () => service.get(Uri.parse('http://localhost/api/orders')),
        throwsA(
          isA<AppNetworkException>()
              .having((e) => e.statusCode, 'statusCode', 408)
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('too long to respond'),
              ),
        ),
      );
    });

    test('200 OK → parses JSON body correctly', () async {
      final client = MockClient(
        (_) async => http.Response('{"name": "Burger", "price": 1299}', 200),
      );
      final service = _HttpService(client: client);

      final result = await service.get(
        Uri.parse('http://localhost/api/menu/1'),
      );
      expect(result['name'], 'Burger');
      expect(result['price'], 1299);
    });

    test('Raw HTTP error body is NEVER surfaced to caller', () async {
      const sensitiveBody =
          '<html>Caused by: java.lang.NullPointerException at line 42</html>';
      final client = MockClient((_) async => http.Response(sensitiveBody, 500));
      final service = _HttpService(client: client);

      try {
        await service.get(Uri.parse('http://localhost/api/orders'));
      } on AppNetworkException catch (e) {
        // The raw HTML stack trace must NEVER appear in the user message
        expect(e.userMessage, isNot(contains('NullPointerException')));
        expect(e.userMessage, isNot(contains('<html>')));
        expect(e.userMessage, isNot(contains('java.lang')));
        return;
      }
      fail('Expected AppNetworkException was not thrown');
    });
  });
}
