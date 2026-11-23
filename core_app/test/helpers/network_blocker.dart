/// Transport isolation for widget tests (ROUTER-3 / W2.8, 07-P1-6).
///
/// Every `dart:io` outbound HTTP request made from a widget test is replaced
/// with a typed failure so a test can never silently hit the real network or
/// become order-dependent on a real HTTP response.
///
/// Two levers are provided:
/// - [blockAllNetwork] — installs an [HttpOverrides] whose [HttpClient] throws
///   [NetworkBlockedException] on every request. This covers ALL outbound HTTP
///   from `dart:io` (including Flutter's `NetworkImage`/`Image.network`,
///   which obtains its client through `HttpClient()`).
/// - [blockNetworkImages] — a narrower variant that blocks ONLY the Flutter
///   `NetworkImage` transport via `debugNetworkImageHttpClientProvider`.
///   It is the documented escape hatch for a test that intentionally replaces
///   [HttpOverrides] with a permissive client (e.g. a local `HttpServer`
///   mock for non-image traffic) while still refusing remote image fetches —
///   never a blanket bypass of [blockAllNetwork].
///
/// The canary assertions live in `network_blocker_test.dart`.
library;

import 'dart:io';

import 'package:flutter/painting.dart' show debugNetworkImageHttpClientProvider;

/// Thrown by the blocked [HttpClient] for any outbound request attempt.
class NetworkBlockedException implements Exception {
  const NetworkBlockedException([this.uri]);

  /// The URL the test tried to reach, when known.
  final Uri? uri;

  @override
  String toString() {
    final target = uri == null ? '' : ' (attempted: $uri)';
    return 'NetworkBlockedException$target: outbound HTTP is disabled in '
        'widget tests (test/helpers/network_blocker.dart).';
  }
}

/// Returns an [HttpClient] whose every outbound request fails closed with
/// [NetworkBlockedException].
HttpClient createBlockedHttpClient() => _BlockedHttpClient();

/// The [HttpOverrides] installed by [blockAllNetwork].
class _NetworkBlockingHttpOverrides extends HttpOverrides {
  _NetworkBlockingHttpOverrides();

  @override
  HttpClient createHttpClient(SecurityContext? context) => _BlockedHttpClient();
}

HttpOverrides? _savedHttpOverrides;

/// Whether the strict all-network blocker is currently installed.
///
/// Note: `flutter_test`'s binding pre-installs its own `_MockHttpOverrides`
/// (which serves 400s); [isNetworkBlocked] is true only when THIS harness's
/// typed blocker ([NetworkBlockedException]) is the active override.
bool isNetworkBlocked() =>
    HttpOverrides.current is _NetworkBlockingHttpOverrides;

/// Installs the strict all-network blocker for the current test process.
///
/// Idempotent: installing twice keeps the original saved override, so
/// [restoreNetwork] always restores whatever was active before the FIRST
/// install (in `flutter test` that is the framework's own `_MockHttpOverrides`,
/// which still refuses real connections — with a plain 400 instead of the
/// typed [NetworkBlockedException]).
void blockAllNetwork() {
  if (isNetworkBlocked()) return;
  _savedHttpOverrides = HttpOverrides.current;
  HttpOverrides.global = _NetworkBlockingHttpOverrides();
}

/// Restores the [HttpOverrides] that were active before [blockAllNetwork] and
/// uninstalls the image-layer hook from [blockNetworkImages].
void restoreNetwork() {
  HttpOverrides.global = _savedHttpOverrides;
  _savedHttpOverrides = null;
  restoreNetworkImages();
}

/// Blocks ONLY the Flutter `NetworkImage` transport (see the file doc):
/// every `Image.network`/`CachedNetworkImage`/`NetworkImage` fetch is served
/// by a client that throws [NetworkBlockedException].
void blockNetworkImages() {
  debugNetworkImageHttpClientProvider = createBlockedHttpClient;
}

/// [HttpClient] implementation whose every request method fails closed with
/// [NetworkBlockedException]. Configuration setters are harmless no-ops — no
/// connection can ever be established because every request entry point
/// throws before touching the network.
class _BlockedHttpClient implements HttpClient {
  _BlockedHttpClient();

  @override
  bool autoUncompress = false;

  @override
  Duration? connectionTimeout;

  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  int? maxConnectionsPerHost;

  @override
  String? userAgent;

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) {}

  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
    f,
  ) {}

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )?
    f,
  ) {}

  @override
  set findProxy(String Function(Uri url)? f) {}

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) {}

  @override
  set keyLog(Function(String line)? callback) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      Future<HttpClientRequest>.error(NetworkBlockedException(url));

  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      Future<HttpClientRequest>.error(NetworkBlockedException(url));

  @override
  Future<HttpClientRequest> postUrl(Uri url) =>
      Future<HttpClientRequest>.error(NetworkBlockedException(url));

  @override
  Future<HttpClientRequest> putUrl(Uri url) =>
      Future<HttpClientRequest>.error(NetworkBlockedException(url));

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) =>
      Future<HttpClientRequest>.error(NetworkBlockedException(url));

  @override
  Future<HttpClientRequest> headUrl(Uri url) =>
      Future<HttpClientRequest>.error(NetworkBlockedException(url));

  @override
  Future<HttpClientRequest> patchUrl(Uri url) =>
      Future<HttpClientRequest>.error(NetworkBlockedException(url));

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) => Future<HttpClientRequest>.error(
    NetworkBlockedException(_uri(host, port, path)),
  );

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      Future<HttpClientRequest>.error(
        NetworkBlockedException(_uri(host, port, path)),
      );

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      Future<HttpClientRequest>.error(
        NetworkBlockedException(_uri(host, port, path)),
      );

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      Future<HttpClientRequest>.error(
        NetworkBlockedException(_uri(host, port, path)),
      );

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      Future<HttpClientRequest>.error(
        NetworkBlockedException(_uri(host, port, path)),
      );

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      Future<HttpClientRequest>.error(
        NetworkBlockedException(_uri(host, port, path)),
      );

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      Future<HttpClientRequest>.error(
        NetworkBlockedException(_uri(host, port, path)),
      );

  @override
  void close({bool force = false}) {}

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) {}

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) {}

  static Uri _uri(String host, int port, String path) =>
      Uri(scheme: 'http', host: host, port: port, path: path);
}

/// Removes the image-layer hook installed by [blockNetworkImages].
void restoreNetworkImages() {
  debugNetworkImageHttpClientProvider = null;
}
