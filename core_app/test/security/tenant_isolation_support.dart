// Shared machinery for the P0-8 generated cross-tenant suite.
//
// The generated file calls [crossTenantCase] once per Firestore collection. A
// PENDING-TENANCY row produces three SKIPPED tests carrying the reason (visible
// in the runner output — a skip is not silence); an ACTIVE row produces three
// real assertions against the emulator:
//
//   1. tenant A is DENIED read on tenant B's seeded document;
//   2. tenant A is DENIED a write on tenant B's seeded document;
//   3. tenant A is ALLOWED to read its OWN document (when one exists).
//
// Assertion 3 exists because 1 and 2 alone are satisfied by rules that deny
// everything. A `tenantOk()` typo that always returns false would score 28/28
// while taking the live app's menu down with it — an outage dressed as a
// security win. The allow control is what makes a lockdown fail the gate.
//
// Assertions 1 and 2 run against documents the probe SEEDED at ids the registry
// names. Reading a random path is not a proof: a missing document is denied
// because there is no `resource`, whatever the other tenant really holds.
//
// ── Why this talks HTTP over a Socket, not through cloud_firestore ──────────
// Two hard constraints in this repo, both verified the hard way:
//   * `cloud_firestore` cannot run here: `flutter test` executes in
//     flutter_tester, where firebase_core's platform channel does not exist, so
//     `Firebase.initializeApp` throws before any rule is evaluated.
//   * `dart:io`'s HttpClient cannot run here either: `test/flutter_test_config.dart`
//     installs the repo's all-network blocker for every file under `test/`, and
//     its documented escape hatch (`restoreNetwork`) returns to flutter_test's
//     own 400-returning mock. The file forbids a blanket `HttpOverrides` bypass,
//     and `dart test` is unavailable (flutter_test pins test_api 0.7.9; every
//     compatible `test` needs an analyzer major this workspace cannot take).
//
// So the suite speaks the emulator's REST protocol over a plain socket, which
// is the same interface gate (d)'s rules_probe.mjs uses. It is deliberately
// narrow: loopback hosts only, one request per connection, `Connection: close`,
// and a body cap. It exists to put the security-rules engine directly under the
// assertion, with nothing between the test and the rule decision.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const String kPendingTenancy = 'PENDING-TENANCY';
const String kActiveCase = 'ACTIVE';
const String kAllowSameTenant = 'allow';

/// Principals seeded by `tool/tenant_isolation_probe.mjs` inside gate (j).
const String kTenantAEmail = 'tenant-a@probe.local';
const String kTenantAPassword = 'probe-password-a';

/// The owner of tenant A. Owner-only collections (`admins`, the audit logs)
/// cannot be probed with a customer token: that token is denied by role, so the
/// test would pass without ever exercising tenant scope. This principal exists
/// so those rows assert something.
const String kOwnerAEmail = 'owner-a@probe.local';
const String kOwnerAPassword = 'probe-password-owner';

const String kPrincipalTenantA = 'tenant-a';
const String kPrincipalOwnerA = 'owner-a';
const String kDefaultProject = 'demo-carnama-gate';

const Duration _kTimeout = Duration(seconds: 15);
const int _kMaxBodyBytes = 1 << 20;

/// Declares the cross-tenant and same-tenant cases for one collection.
void crossTenantCase({
  required String collection,
  required String status,
  required String why,
  required String readPath,
  required String writePath,
  required String readDocId,
  required String writeDocId,
  required String allowDocId,
  required String sameTenant,
  required String sameTenantWhy,
  String parentDocId = '',
  String allowParentDocId = '',
  String createBodyJson = '',
  String createDocId = '',
  String principal = kPrincipalTenantA,
}) {
  final Object pendingSkip = status == kPendingTenancy
      ? 'PENDING-TENANCY [$collection]: $why'
      : false;
  final Object allowSkip = status == kPendingTenancy
      ? 'PENDING-TENANCY [$collection]: $why'
      : sameTenant == kAllowSameTenant
      ? false
      : 'NO SAME-TENANT CONTROL [$collection]: $sameTenantWhy';

  group(collection, () {
    test('tenant A cannot READ tenant B data ($readPath)', () async {
      await expectCrossTenantDenied(
        collection: collection,
        pathTemplate: readPath,
        docId: readDocId,
        write: false,
        parentId: parentDocId,
        principal: principal,
      );
    }, skip: pendingSkip);

    test('tenant A cannot WRITE tenant B data ($writePath)', () async {
      await expectCrossTenantDenied(
        collection: collection,
        pathTemplate: writePath,
        docId: writeDocId,
        write: true,
        parentId: parentDocId,
        principal: principal,
      );
    }, skip: pendingSkip);

    test('tenant A CAN read its own $collection document', () async {
      await expectSameTenantAllowed(
        collection: collection,
        pathTemplate: readPath,
        docId: allowDocId,
        parentId: allowParentDocId,
        principal: principal,
      );
    }, skip: allowSkip);

    // D-039: a create differs from a read in both directions. The allow case
    // proves a legitimate tenant-A create still succeeds (an over-lock that
    // denies every real create would otherwise score as "isolated"), and the
    // denial proves the same body with another tenant's id is refused.
    if (createBodyJson.isNotEmpty) {
      test('tenant A CAN create its own $collection document', () async {
        await expectSameTenantCreateAllowed(
          collection: collection,
          pathTemplate: readPath,
          docId: createDocId.isNotEmpty ? createDocId : 'iso_new_$collection',
          bodyJson: createBodyJson,
          parentId: allowParentDocId,
        );
      }, skip: pendingSkip);

      test(
        'tenant A cannot CREATE a $collection document for tenant B',
        () async {
          await expectCrossTenantCreateDenied(
            collection: collection,
            pathTemplate: readPath,
            docId:
                '${allowDocId.isEmpty ? 'iso_new_$collection' : allowDocId}_b',
            bodyJson: createBodyJson,
            parentId: allowParentDocId,
          );
        },
        skip: pendingSkip,
      );
    }
  });
}

/// One HTTP response read off a loopback socket.
class _Response {
  _Response(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

/// Emulator endpoints and tenant A's ID token, resolved once per process.
class TenantProbe {
  TenantProbe._(
    this._firestoreHostPort,
    this._project,
    this._tokens,
    this._uid,
  );

  final String _firestoreHostPort;
  final String _project;
  final Map<String, String> _tokens;
  final String _uid;

  /// The ID token for a principal. Fails loudly rather than defaulting to
  /// tenant A: a silent fallback would make an owner row assert with a customer
  /// token and pass for the wrong reason.
  String tokenFor(String principal) {
    final String? token = _tokens[principal];
    if (token == null) {
      fail(
        'TenantProbe: no signed-in token for principal "$principal" '
        '(have: ${_tokens.keys.join(', ')}).',
      );
    }
    return token;
  }

  static TenantProbe? _instance;

  static TenantProbe get instance {
    final TenantProbe? probe = _instance;
    if (probe == null) {
      fail(
        'TenantProbe is not ready. Run the suite through gate (j): '
        '`node ../tool/tenant_isolation_probe.mjs` — it exports the emulator '
        'hosts and seeds the tenants.',
      );
    }
    return probe;
  }

  static String get tenantAUid => instance._uid;

  /// Signs tenant A in against the auth emulator and keeps its ID token, whose
  /// custom claims (tenantId, roles) are what the rules read.
  static Future<TenantProbe> connect() async {
    if (_instance != null) return _instance!;

    final String? firestoreHost =
        Platform.environment['FIRESTORE_EMULATOR_HOST'];
    final String? authHost =
        Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
    final String project =
        Platform.environment['GCLOUD_PROJECT'] ?? kDefaultProject;

    if (firestoreHost == null ||
        firestoreHost.isEmpty ||
        authHost == null ||
        authHost.isEmpty) {
      fail(
        'TenantProbe.connect: FIRESTORE_EMULATOR_HOST / '
        'FIREBASE_AUTH_EMULATOR_HOST are not set. Run the suite through gate '
        '(j): `node ../tool/tenant_isolation_probe.mjs`.',
      );
    }

    Future<Map<String, dynamic>> signIn(String email, String password) async {
      final _Response res = await _http(
        authHost,
        'POST',
        '/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword'
            '?key=probe-api-key',
        headers: <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'email': email,
          'password': password,
          // Boolean, not "true": the emulator rejects a string here with
          // INVALID_ARGUMENT ("/returnSecureToken must be boolean").
          'returnSecureToken': true,
        }),
      );
      if (res.statusCode != 200) {
        fail(
          'TenantProbe.connect: sign-in failed for $email (${res.statusCode}): '
          '${res.body}. The probe must create the user and mint its claims '
          'before the suite runs.',
        );
      }
      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      if (body['idToken'] is! String || body['localId'] is! String) {
        fail(
          'TenantProbe.connect: sign-in for $email returned no idToken/localId.',
        );
      }
      return body;
    }

    final Map<String, dynamic> customerA = await signIn(
      kTenantAEmail,
      kTenantAPassword,
    );
    final Map<String, dynamic> ownerA = await signIn(
      kOwnerAEmail,
      kOwnerAPassword,
    );

    _instance = TenantProbe._(firestoreHost, project, <String, String>{
      kPrincipalTenantA: customerA['idToken'] as String,
      kPrincipalOwnerA: ownerA['idToken'] as String,
    }, customerA['localId'] as String);
    return _instance!;
  }
}

/// Attempts one operation as tenant A against a tenant-B document and fails
/// unless the backend denies it.
Future<void> expectCrossTenantDenied({
  required String collection,
  required String pathTemplate,
  required String docId,
  required bool write,
  String parentId = '',
  String principal = kPrincipalTenantA,
}) async {
  // Connect on first real assertion, never at load time: a tag-filtered run
  // must not need an emulator just because this file was loaded.
  final TenantProbe probe = await TenantProbe.connect();
  final String docPath = resolvePath(pathTemplate, docId, parentId: parentId);
  final String operation = write ? 'write' : 'read';
  final String resource = _documentsPath(probe, docPath);

  final _Response res = write
      ? await _http(
          probe._firestoreHostPort,
          'PATCH',
          '$resource?updateMask.fieldPaths=p08Probe',
          headers: <String, String>{
            'authorization': 'Bearer ${probe.tokenFor(principal)}',
            'content-type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'fields': <String, dynamic>{
              'p08Probe': <String, dynamic>{'booleanValue': true},
            },
          }),
        )
      : await _http(
          probe._firestoreHostPort,
          'GET',
          resource,
          headers: <String, String>{
            'authorization': 'Bearer ${probe.tokenFor(principal)}',
          },
        );

  if (res.statusCode == 403) return;
  if (res.statusCode == 200) {
    fail(
      'CROSS-TENANT LEAK: tenant A was ALLOWED to $operation "$docPath" '
      '($collection). The rules do not isolate tenants.',
    );
  }
  fail(
    'CROSS-TENANT $operation on "$docPath" ($collection) returned '
    '${res.statusCode} instead of 403. Isolation is not proven — a missing '
    'emulator, an unsigned request or a bad document id looks exactly like '
    'this. Body: ${res.body}',
  );
}

/// Reads tenant A's OWN document and fails unless the rules allow it.
///
/// A missing document is a failure, not a pass: reading an unseeded path
/// returns 200 with no fields, which would let a broken seed look like a
/// working allow control.
Future<void> expectSameTenantAllowed({
  required String collection,
  required String pathTemplate,
  required String docId,
  String parentId = '',
  String principal = kPrincipalTenantA,
}) async {
  final TenantProbe probe = await TenantProbe.connect();
  final String docPath = resolvePath(pathTemplate, docId, parentId: parentId);

  final _Response res = await _http(
    probe._firestoreHostPort,
    'GET',
    _documentsPath(probe, docPath),
    headers: <String, String>{
      'authorization': 'Bearer ${probe.tokenFor(principal)}',
    },
  );

  if (res.statusCode == 403) {
    fail(
      'SAME-TENANT DENIED: tenant A cannot read its own "$docPath" '
      '($collection). Either the rules deny a legitimate read (the lockdown '
      'failure this control exists to catch) or isolation is scoped wrong.',
    );
  }
  if (res.statusCode != 200) {
    fail(
      'SAME-TENANT CONTROL ERROR: reading "$docPath" ($collection) returned '
      '${res.statusCode}. Body: ${res.body}',
    );
  }

  final Map<String, dynamic> body =
      jsonDecode(res.body) as Map<String, dynamic>;
  final Map<String, dynamic>? fields = body['fields'] as Map<String, dynamic>?;
  if (fields == null || fields.isEmpty) {
    fail(
      'SAME-TENANT CONTROL MISSING: "$docPath" ($collection) has no fields. '
      'The probe must seed tenant A\'s document at the registry-named id — an '
      'absent document proves nothing about the rules.',
    );
  }
}

String _documentsPath(TenantProbe probe, String docPath) =>
    '/v1/projects/${probe._project}/databases/(default)/documents/$docPath';

/// Creates a document as tenant A and fails unless the backend allows it.
///
/// The body is the registry's fixture with `tenantId` rewritten to the caller's
/// own tenant, i.e. exactly what a correct client sends. A 403 here is the
/// over-lock failure: the rules deny a write the app cannot work without.
Future<void> expectSameTenantCreateAllowed({
  required String collection,
  required String pathTemplate,
  required String docId,
  required String bodyJson,
  String parentId = '',
  String principal = kPrincipalTenantA,
}) async {
  final _Response res = await _create(
    pathTemplate: pathTemplate,
    docId: docId,
    bodyJson: bodyJson,
    parentId: parentId,
    principal: principal,
    tenantId: 'tenant_a',
  );
  if (res.statusCode == 200) return;
  if (res.statusCode == 403) {
    fail(
      'SAME-TENANT CREATE DENIED: tenant A cannot create "$docId" '
      '($collection). The rules deny a legitimate create — an over-lock is a '
      'failure, not a lockdown. Body: ${res.body}',
    );
  }
  fail(
    'SAME-TENANT CREATE ERROR: "$docId" ($collection) returned '
    '${res.statusCode} instead of 200. Body: ${res.body}',
  );
}

/// Creates the same document with tenant B's id and fails unless it is denied.
Future<void> expectCrossTenantCreateDenied({
  required String collection,
  required String pathTemplate,
  required String docId,
  required String bodyJson,
  String parentId = '',
  String principal = kPrincipalTenantA,
}) async {
  final _Response res = await _create(
    pathTemplate: pathTemplate,
    docId: docId,
    bodyJson: bodyJson,
    parentId: parentId,
    principal: principal,
    tenantId: 'tenant_b',
  );
  if (res.statusCode == 403) return;
  if (res.statusCode == 200) {
    fail(
      'CROSS-TENANT CREATE: tenant A was ALLOWED to create "$docId" '
      '($collection) stamped with tenant B. A client can mint another '
      'tenant\'s data.',
    );
  }
  fail(
    'CROSS-TENANT CREATE: "$docId" ($collection) returned '
    '${res.statusCode} instead of 403 — an already-existing id returns 409, '
    'which proves nothing. Body: ${res.body}',
  );
}

Future<_Response> _create({
  required String pathTemplate,
  required String docId,
  required String bodyJson,
  required String parentId,
  required String tenantId,
  String principal = kPrincipalTenantA,
}) async {
  final TenantProbe probe = await TenantProbe.connect();
  final String docPath = resolvePath(pathTemplate, docId, parentId: parentId);
  final int slash = docPath.lastIndexOf('/');
  final String collectionPath = docPath.substring(0, slash);
  final String documentId = docPath.substring(slash + 1);
  final Map<String, dynamic> decoded =
      jsonDecode(bodyJson) as Map<String, dynamic>;
  // A fixture cannot hard-code the uid (each emulator run mints its own), so a
  // `{uid}` placeholder is resolved to tenant A's principal - the same
  // substitution the registry uses for self-keyed document ids.
  final Map<String, dynamic> body =
      _substitutePrincipal(decoded, probe._uid) as Map<String, dynamic>;
  body['tenantId'] = tenantId;
  return _http(
    probe._firestoreHostPort,
    'POST',
    '${_documentsPath(probe, collectionPath)}'
        '?documentId=${Uri.encodeQueryComponent(documentId)}',
    headers: <String, String>{
      'authorization': 'Bearer ${probe.tokenFor(principal)}',
      'content-type': 'application/json',
    },
    body: jsonEncode(<String, dynamic>{'fields': _encodeFields(body)}),
  );
}

/// Firestore REST field encoding. Ints and doubles are distinct types in the
/// rule engine, so an int sent as a double would fail a shape clause for a
/// reason that has nothing to do with tenancy.
dynamic _substitutePrincipal(dynamic value, String uid) {
  if (value is String) {
    return value.replaceAll('{uid}', uid);
  }
  if (value is Map) {
    // Rebuild rather than .map(): jsonDecode yields Map<String, dynamic>, but
    // .map() returns Map<dynamic, dynamic>, which fails the cast at the call
    // site with a type error that looks nothing like the fixture problem.
    final Map<String, dynamic> out = <String, dynamic>{};
    value.forEach((dynamic k, dynamic v) {
      out[k.toString()] = _substitutePrincipal(v, uid);
    });
    return out;
  }
  if (value is List) {
    return value.map((dynamic v) => _substitutePrincipal(v, uid)).toList();
  }
  return value;
}

Map<String, dynamic> _encodeFields(Map<String, dynamic> fields) {
  final Map<String, dynamic> out = <String, dynamic>{};
  fields.forEach((String key, dynamic value) {
    out[key] = _encodeValue(value);
  });
  return out;
}

Map<String, dynamic> _encodeValue(dynamic value) {
  if (value == null) return <String, dynamic>{'nullValue': null};
  if (value is bool) return <String, dynamic>{'booleanValue': value};
  if (value is int) return <String, dynamic>{'integerValue': '$value'};
  if (value is double) return <String, dynamic>{'doubleValue': value};
  if (value is String) return <String, dynamic>{'stringValue': value};
  if (value is List) {
    return <String, dynamic>{
      'arrayValue': <String, dynamic>{
        'values': value.map(_encodeValue).toList(),
      },
    };
  }
  if (value is Map) {
    return <String, dynamic>{
      'mapValue': <String, dynamic>{
        'fields': _encodeFields(value.cast<String, dynamic>()),
      },
    };
  }
  fail('encodeValue: unsupported fixture value ${value.runtimeType}');
}

/// Substitutes the registry's placeholders.
///
/// `{id}` is the seeded document id. Some collections key the document on the
/// principal (`carts/{uid}`, `users/{uid}`), so their registry ids are `{uid}`
/// (tenant A) and `{uid_b}` (tenant B, exported by the probe). Without that, a
/// self-keyed denial would pass because of the uid check and prove nothing
/// about tenancy.
String resolvePath(String pathTemplate, String docId, {String parentId = ''}) {
  final String uidA = TenantProbe.tenantAUid;
  final String uidB = Platform.environment['TENANT_B_UID'] ?? '';
  if ((docId.contains('{uid') || parentId.contains('{uid')) && uidB.isEmpty) {
    fail(
      'resolvePath: TENANT_B_UID is not set by the probe '
      '(docId "$docId", parentId "$parentId").',
    );
  }
  String sub(String value) =>
      value.replaceAll('{uid_b}', uidB).replaceAll('{uid}', uidA);
  // The parent segment must be resolved first: a nested row's parent is itself
  // a seeded document id (and may be principal-keyed, e.g. notifications/{uid}).
  return pathTemplate
      .replaceAll('{parentId}', sub(parentId))
      .replaceAll('{id}', sub(docId));
}

/// Sends one HTTP/1.1 request to a LOOPBACK emulator and returns the response.
///
/// `Connection: close` means the server ends the stream, so the whole response
/// can be read without implementing keep-alive. Both Content-Length and chunked
/// bodies are handled, because the emulator uses either.
Future<_Response> _http(
  String hostPort,
  String method,
  String path, {
  Map<String, String> headers = const <String, String>{},
  String? body,
}) async {
  final int colon = hostPort.lastIndexOf(':');
  if (colon <= 0) fail('_http: host:port expected, got "$hostPort"');
  final String host = hostPort.substring(0, colon);
  final int port = int.parse(hostPort.substring(colon + 1));

  if (host != '127.0.0.1' && host != 'localhost' && host != '::1') {
    fail(
      '_http: refusing "$host" — this suite only talks to the local emulator.',
    );
  }

  final List<int> payload = utf8.encode(body ?? '');
  final StringBuffer head = StringBuffer()
    ..write('$method $path HTTP/1.1\r\n')
    ..write('Host: $hostPort\r\n')
    ..write('Connection: close\r\n')
    ..write('Accept: application/json\r\n');
  headers.forEach((String k, String v) => head.write('$k: $v\r\n'));
  head
    ..write('Content-Length: ${payload.length}\r\n')
    ..write('\r\n');

  final Socket socket = await Socket.connect(host, port, timeout: _kTimeout);
  socket.add(utf8.encode(head.toString()));
  socket.add(payload);
  await socket.flush();

  final List<int> raw = await _readResponse(socket);
  socket.destroy();

  final int split = _indexOfSequence(raw, const <int>[13, 10, 13, 10]);
  if (split < 0) fail('_http: malformed response from $hostPort$path');
  final String headerText = utf8.decode(raw.sublist(0, split));
  final List<int> bodyBytes = raw.sublist(split + 4);

  final List<String> lines = headerText.split('\r\n');
  final List<String> status = lines.first.split(' ');
  if (status.length < 2) fail('_http: malformed status line "${lines.first}"');
  final int statusCode = int.parse(status[1]);

  final bool chunked = lines
      .skip(1)
      .any(
        (String l) =>
            l.toLowerCase().startsWith('transfer-encoding:') &&
            l.toLowerCase().contains('chunked'),
      );

  return _Response(
    statusCode,
    chunked ? _dechunk(bodyBytes) : utf8.decode(bodyBytes),
  );
}

String _dechunk(List<int> bytes) {
  final BytesBuilder out = BytesBuilder();
  int i = 0;
  while (i < bytes.length) {
    final int lineEnd = _indexOfSequence(bytes.sublist(i), const <int>[13, 10]);
    if (lineEnd < 0) break;
    final String sizeLine = utf8.decode(bytes.sublist(i, i + lineEnd)).trim();
    final int size = int.parse(sizeLine.split(';').first, radix: 16);
    i += lineEnd + 2;
    if (size == 0) break;
    out.add(bytes.sublist(i, i + size));
    i += size + 2;
  }
  return utf8.decode(out.toBytes());
}

/// Reads one response without waiting for the socket to close.
///
/// The emulator keeps the connection alive even when the request says
/// `Connection: close`, so reading to EOF stalls for the whole timeout — that
/// was the first run's symptom, every assertion failing after exactly 15 s.
/// Stop as soon as the headers AND the declared body have arrived.
Future<List<int>> _readResponse(Socket socket) async {
  final Completer<List<int>> done = Completer<List<int>>();
  final List<int> buffer = <int>[];
  late StreamSubscription<List<int>> sub;
  sub = socket.listen(
    (List<int> chunk) {
      buffer.addAll(chunk);
      if (buffer.length > _kMaxBodyBytes) {
        if (!done.isCompleted) {
          done.completeError(
            StateError('response exceeded $_kMaxBodyBytes bytes'),
          );
        }
        sub.cancel();
        return;
      }
      if (!done.isCompleted && _responseComplete(buffer)) {
        done.complete(List<int>.of(buffer));
        sub.cancel();
      }
    },
    onError: (Object error, StackTrace stack) {
      if (!done.isCompleted) done.completeError(error, stack);
    },
    onDone: () {
      if (!done.isCompleted) done.complete(List<int>.of(buffer));
    },
    cancelOnError: true,
  );
  return done.future.timeout(
    _kTimeout,
    onTimeout: () {
      sub.cancel();
      throw StateError('timed out waiting for a complete HTTP response');
    },
  );
}

bool _responseComplete(List<int> bytes) {
  final int headerEnd = _indexOfSequence(bytes, const <int>[13, 10, 13, 10]);
  if (headerEnd < 0) return false;
  final String head = utf8.decode(bytes.sublist(0, headerEnd)).toLowerCase();
  final int bodyStart = headerEnd + 4;
  if (head.contains('transfer-encoding:') && head.contains('chunked')) {
    // A zero-length chunk plus the blank line terminates a chunked body.
    return _indexOfSequence(bytes.sublist(bodyStart), const <int>[
          48,
          13,
          10,
          13,
          10,
        ]) >=
        0;
  }
  final RegExpMatch? length = RegExp(
    r'content-length:\s*(\d+)',
  ).firstMatch(head);
  if (length == null) return false;
  return bytes.length >= bodyStart + int.parse(length.group(1)!);
}

int _indexOfSequence(List<int> haystack, List<int> needle) {
  for (int i = 0; i + needle.length <= haystack.length; i++) {
    bool match = true;
    for (int j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  return -1;
}
