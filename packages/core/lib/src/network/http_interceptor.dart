import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:core/src/error_logger/logger_service.dart';

/// Phase 13 / Network & API Layer Safety (Law 10 & 46 Constraints)
///
/// Intercepts every HTTP request/response to log payloads/endpoints.
/// CRITICAL: `kReleaseMode` check guarantees zero network telemetry
/// is ever leaked to stdout in production builds.

class SafeHttpLoggingInterceptor implements HttpInterceptor {
  @override
  FutureOr<BaseRequest> interceptRequest({required BaseRequest request}) {
    if (kDebugMode || kProfileMode) {
      debugPrint('➡️ [HTTP REQ] ${request.method} ${request.url}');
      final safeHeaders = Map<String, String>.from(request.headers)
        ..remove('Authorization');
      debugPrint('➡️ [HTTP HEADERS] $safeHeaders');
      LoggerService().info({
        'method': request.method,
        'url': request.url.toString(),
      }, 'HTTP Request');
    }
    return request;
  }

  @override
  FutureOr<BaseResponse> interceptResponse({required BaseResponse response}) {
    if (kDebugMode || kProfileMode) {
      debugPrint('⬅️ [HTTP RES] [${response.statusCode}]');
      if (response is Response && response.statusCode >= 400) {
        debugPrint('⬅️ [HTTP ERR BODY] ${response.body}');
      }
      if (response is Response && response.statusCode >= 400) {
        LoggerService().error('HTTP ${response.statusCode}', 'HttpError');
      } else {
        LoggerService().info({
          'statusCode': response.statusCode,
        }, 'HTTP Response');
      }
    }
    return response;
  }

  @override
  FutureOr<bool> shouldInterceptRequest({required BaseRequest request}) =>
      !kReleaseMode;

  @override
  FutureOr<bool> shouldInterceptResponse({required BaseResponse response}) =>
      !kReleaseMode;
}
