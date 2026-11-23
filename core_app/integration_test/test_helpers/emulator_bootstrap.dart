import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:core/core.dart' show kGdprAnalyticsConsentKey;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// CARNAMA CONSTITUTION Law 30: Firebase Emulator Integration Testing
///
/// Single source of truth for emulator binding. All integration tests MUST use
/// this helper to guarantee emulator-only testing (zero production hits).
///
/// Usage:
///   await bootstrapEmulators();
///   // Now safe to perform Firebase operations
Future<void> bootstrapEmulators() async {
  // p34 T-2: first-boot GDPR consent (GdprConsentDialog) is a NON-dismissible
  // modal barrier - every suite that boots the app stalls behind it with the
  // login form unreachable (first real run: green_r2_admin_navfix2.txt dump).
  // Seed a returning user's ACCEPTED decision before app.main() so the form
  // is interactive. In-memory store = zero device pollution (Law 30).
  SharedPreferences.setMockInitialValues({kGdprAnalyticsConsentKey: true});

  // Law 30: Initialize Firebase once — BARE init, deliberately.
  //
  // On Android the google-services gradle plugin (app/build.gradle.kts:39)
  // ships FirebaseInitProvider, which creates the NATIVE default app from
  // google-services.json BEFORE any Dart runs. firebase_core's
  // initializeApp (method_channel_firebase.dart, firebase_core_platform_
  // interface 8.0.0) first calls _initializeCore() — syncing that native
  // default into appInstances — and then, if caller options differ from it
  // (apiKey compared), throws [core/duplicate-app]. Passing lane options
  // here therefore cannot re-target the default app; it only crashes
  // (red: green_r2_realtime_greenv5.txt (setUpAll) duplicate-app).
  //
  // Bare init returns the native default — the identity every previously
  // GREEN on-device run used (v13 +1, admin navfix5 "All tests passed").
  // Law 30 holds by CONNECTION, not by options: the binds below hard-point
  // 127.0.1.1:8080/:9099 with a fail-fast host assert, `adb reverse`
  // tunnels the emulator, and no e2e suite calls Functions — so
  // production resturants-8547d is unreachable by construction
  // (WHITE_LABEL_p34_e2e_seed.md §0). The harness and app.main() share the
  // same default instance, so app and test data are always one namespace.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  // Law 30: Bind exclusively to emulator - NEVER production
  // Using 127.0.1.1 for consistency across all tests
  // This avoids Android 10.0.2.2 translation issues on physical devices
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.1.1', 8080);
  await FirebaseAuth.instance.useAuthEmulator('127.0.1.1', 9099);

  // Verify emulator binding (fail fast if not connected)
  final firestoreSettings = FirebaseFirestore.instance.settings;
  if (!(firestoreSettings.host?.contains('127.0.1.1') ?? false)) {
    throw Exception(
      'FAILED: Firestore not bound to emulator. Host: ${firestoreSettings.host}',
    );
  }

  // p34 T-2: seed the device as a RETURNING user. A fresh install carries
  // `onboarding_completed=false`, so splash (splash_screen.dart:96-97) routes
  // to the onboarding screen — which has zero TextFields — and every
  // login-flow assertion died with `Bad state: No element` on the first-ever
  // device run (tool_uilib/p34_e2e/green_r2_full_run.txt). The suites were
  // written against an "INTEGRATION_TEST bypass" in splash that never existed
  // (admin_e2e_flow_test.dart:47); this seeds the real SharedPreferences key
  // instead. Harness-only (§2-IN): no lib/ change, production first-run
  // behaviour untouched, and no suite asserts first-run state (verified —
  // runtime_smoke accepts either screen, setup_wizard expects login too).
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_completed', true);

  // p34 T-2: deterministic STARTING STATE for the whole battery. Test data
  // left by a previous suite/run (or a failed mid-test cleanup) changes what
  // the app renders on boot — a leftover `menus` doc flipped home from its
  // empty-state (restaurant_menu shortcut) into a populated feed and this
  // suite's selector found 0 widgets (red: green_r2_realtime_greenv7.txt
  // L204-205, cascade from green_r2_realtime_greenv6.txt's failed cleanup).
  // Runs AFTER init + binds (needs the default app's projectId); emulator
  // data hygiene only — rules untouched, no production path (Law 30).
  await emulatorAdminDeleteAllDocuments(collection: 'menus');
}

// ─── p34 cluster A: emulator-legitimate user provisioning ─────────────────────
//
// Two HOST-SIDE REST calls, both against the local emulator only (Law 30 —
// these addresses are the adb-reverse loopback the SDK itself binds above).
// Rules stay authoritative (Law 12): nothing here edits firestore.rules, and
// neither bypass exists in production.
//
// 1. grantAppIdClaim — production ID tokens carry an `app_id` claim; the Auth
//    emulator mints none, so `isAppVerified()` (firestore.rules) hit an
//    EVALUATION ERROR at L400 on every write (first e2e run:
//    tool_uilib/p34_e2e/red_r2_first_run.txt). The emulator's admin REST
//    (Authorization: Bearer owner) attaches the claim the production Auth
//    backend would mint — same trust model the node rules battery uses.
//
// 2. seedUserRoleDoc — rules L411-L415 allow client creation of a users/{uid}
//    doc ONLY with role 'customer' (C-1: "NO e2e backdoor"). Owner/manager/
//    kitchen/delivery docs are provisioned in production by Admin SDK
//    (seed scripts); the emulator-admin document create is this harness's
//    equivalent. Client writes still hit the REAL rules afterwards.

const String _emulatorHost = '127.0.1.1';

Future<(int, String)> _emulatorPost(
  String url,
  String body, {
  required bool ownerAuth,
  String method = 'POST',
}) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl(method, Uri.parse(url));
    req.headers.contentType = ContentType.json;
    if (ownerAuth) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
    }
    if (body.isNotEmpty) req.write(body);
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    return (resp.statusCode, text);
  } finally {
    client.close(force: true);
  }
}

// ─── p34 T-2: emulator-admin document writes (owner token) ──────────────────
//
// The harness's stand-in for the production Admin SDK: a test that needs a
// HEADLESS server-side write (e.g. realtime_update_test's "headless write
// triggers live UI update") performs it here instead of as an unauthenticated
// client - which firestore.rules correctly denies (Law 12: rules stay
// authoritative; same trust model as the node rules battery). The change
// still lands in the emulator and fires every live listener, which is exactly
// what the suites assert. Neither helper exists in production code.

Map<String, dynamic> _toRestValue(Object? value) {
  if (value == null) return {'nullValue': null};
  if (value is String) return {'stringValue': value};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': value.toString()};
  if (value is double) return {'doubleValue': value};
  if (value is List) {
    return {
      'arrayValue': {'values': value.map(_toRestValue).toList()},
    };
  }
  throw ArgumentError('emulator-admin REST cannot encode ${value.runtimeType}');
}

String _docsUrl(String projectId) =>
    'http://$_emulatorHost:8080/v1/projects/$projectId'
    '/databases/(default)/documents';

/// Creates [fields] in [collection] via the emulator-admin REST and returns
/// the new document's ID (last segment of the server-assigned name).
Future<String> emulatorAdminCreateDocument({
  required String collection,
  required Map<String, Object?> fields,
  String? documentId,
}) async {
  final projectId = FirebaseFirestore.instance.app.options.projectId;
  final query = documentId == null ? '' : '?documentId=$documentId';
  final (status, text) = await _emulatorPost(
    '${_docsUrl(projectId)}/$collection$query',
    jsonEncode({
      'fields': {for (final e in fields.entries) e.key: _toRestValue(e.value)},
    }),
    ownerAuth: true,
  );
  if (status != 200) {
    throw StateError(
      'emulator-admin create $collection failed: '
      'HTTP $status $text',
    );
  }
  final name = (jsonDecode(text) as Map<String, dynamic>)['name'] as String;
  return name.split('/').last;
}

/// PATCHes [fields] into documents/[collection]/[documentId] via the
/// emulator-admin REST (updateMask = exactly the fields passed).
Future<void> emulatorAdminUpdateDocument({
  required String collection,
  required String documentId,
  required Map<String, Object?> fields,
}) async {
  final projectId = FirebaseFirestore.instance.app.options.projectId;
  final mask = fields.keys
      .map((k) => 'updateMask.fieldPaths=${Uri.encodeComponent(k)}')
      .join('&');
  final (status, text) = await _emulatorPost(
    '${_docsUrl(projectId)}/$collection/$documentId?$mask',
    jsonEncode({
      'fields': {for (final e in fields.entries) e.key: _toRestValue(e.value)},
    }),
    ownerAuth: true,
    method: 'PATCH',
  );
  if (status != 200) {
    throw StateError(
      'emulator-admin update $collection/$documentId failed: '
      'HTTP $status $text',
    );
  }
}

/// DELETEs documents/[collection]/[documentId] via the emulator-admin REST.
Future<void> emulatorAdminDeleteDocument({
  required String collection,
  required String documentId,
}) async {
  final projectId = FirebaseFirestore.instance.app.options.projectId;
  final (status, text) = await _emulatorPost(
    '${_docsUrl(projectId)}/$collection/$documentId',
    '',
    ownerAuth: true,
    method: 'DELETE',
  );
  if (status != 200 && status != 404) {
    throw StateError(
      'emulator-admin delete $collection/$documentId failed: '
      'HTTP $status $text',
    );
  }
}

/// Lists every document in [collection] (REST, paginated) and deletes each
/// via [emulatorAdminDeleteDocument] — the suite-start data reset called by
/// [bootstrapEmulators]. Throws on list failure (never silently "succeeds"
/// with data still present); delete is 404-tolerant so a partially wiped
/// collection still converges to empty.
Future<void> emulatorAdminDeleteAllDocuments({
  required String collection,
}) async {
  final projectId = FirebaseFirestore.instance.app.options.projectId;
  final base = '${_docsUrl(projectId)}/$collection';
  var pageToken = '';
  var deleted = 0;
  do {
    final url = pageToken.isEmpty
        ? '$base?pageSize=300'
        : '$base?pageSize=300&pageToken=$pageToken';
    final (status, text) = await _emulatorPost(
      url,
      '',
      ownerAuth: true,
      method: 'GET',
    );
    if (status != 200) {
      throw StateError(
        'emulator-admin list $collection failed: HTTP $status $text',
      );
    }
    final json = jsonDecode(text) as Map<String, dynamic>;
    final docs =
        (json['documents'] as List<Object?>?)?.cast<Map<String, dynamic>>() ??
        const [];
    for (final doc in docs) {
      final name = doc['name'] as String;
      await emulatorAdminDeleteDocument(
        collection: collection,
        documentId: name.split('/').last,
      );
      deleted++;
    }
    pageToken = (json['nextPageToken'] as String?) ?? '';
  } while (pageToken.isNotEmpty);
  if (deleted > 0) {
    // Visible in the receipt so a "clean" boot is provably a reset boot.
    debugPrint(
      'emulatorAdminDeleteAllDocuments($collection): removed $deleted',
    );
  }
}

/// Attaches the `app_id` claim to [user] via the Auth emulator's admin REST,
/// then force-refreshes so subsequent SDK requests carry it.
Future<void> grantAppIdClaim(User user) async {
  final idToken = await user.getIdToken();
  final appId = Firebase.app().options.appId;
  final (status, text) = await _emulatorPost(
    'http://$_emulatorHost:9099/identitytoolkit.googleapis.com/v1/'
    'accounts:update?key=any',
    jsonEncode({
      'idToken': idToken,
      'localId': user.uid,
      'returnSecureToken': true,
      'customAttributes': jsonEncode({'app_id': appId}),
    }),
    ownerAuth: true,
  );
  if (status != 200) {
    throw StateError(
      'emulator app_id claim grant failed for ${user.uid}: '
      'HTTP $status $text',
    );
  }
  await user.getIdToken(true);
}

/// Seeds settings/ownerInfo with [ownerEmail] through the emulator-admin
/// REST. firestore.rules:47-51 identifies the owner BY EMAIL in this doc
/// (`isOwner()` = settings/ownerInfo.ownerEmail == request.auth.token.email),
/// so without it every owner-gated write - including the setup screen's
/// config save (isAppVerified() && isOwner()) - is denied
/// (red: green_r2_setupfix10.txt - Save failed: permission-denied).
/// Emulator-only (Law 30); production ownerInfo is provisioned at deploy.
Future<void> seedOwnerInfo({required String ownerEmail}) async {
  final projectId = FirebaseFirestore.instance.app.options.projectId;
  final now = DateTime.now().toUtc().toIso8601String();
  final timestamp = now.endsWith('Z') ? now : '${now}Z';
  final (status, text) = await _emulatorPost(
    '${_docsUrl(projectId)}/settings?documentId=ownerInfo',
    jsonEncode({
      'fields': {
        'ownerEmail': {'stringValue': ownerEmail},
        'updatedAt': {'timestampValue': timestamp},
      },
    }),
    ownerAuth: true,
  );
  if (status != 200) {
    throw StateError(
      'emulator ownerInfo seed failed for $ownerEmail: HTTP $status $text',
    );
  }
}

/// Creates users/{uid} with [role] through the emulator-admin document
/// create (see (2) above). Fresh uid per test — a duplicate would 409.
Future<void> seedUserRoleDoc({
  required String uid,
  required String email,
  required String role,
  String? branchId,
  String? name,
}) async {
  final projectId = FirebaseFirestore.instance.app.options.projectId;
  final now = DateTime.now().toUtc().toIso8601String();
  final timestamp = now.endsWith('Z') ? now : '${now}Z';
  final fields = <String, Object?>{
    'email': email,
    'role': role,
    if (branchId != null) 'branchId': branchId,
    if (name != null) 'name': name,
    'createdAt': timestamp,
  };
  final (status, text) = await _emulatorPost(
    'http://$_emulatorHost:8080/v1/projects/$projectId'
    '/databases/(default)/documents/users?documentId=$uid',
    jsonEncode({
      'fields': {for (final e in fields.entries) e.key: _toRestValue(e.value)},
    }),
    ownerAuth: true,
  );
  if (status == 409) {
    // Idempotent re-seed: the auth emulator reuses uids after a tearDown
    // user-delete, so a long battery can re-issue a uid whose users/{uid}
    // doc (deleted auth users do NOT cascade-delete their role doc) still
    // exists from an earlier suite (red: green_r2_full_battery_v4.txt
    // "emulator ownerInfo seed failed ... HTTP 409 entity already exists").
    // PATCH the same fields instead of failing — same emulator-admin trust
    // model as the create; production rules are untouched either way.
    await emulatorAdminUpdateDocument(
      collection: 'users',
      documentId: uid,
      fields: fields,
    );
    return;
  }
  if (status != 200) {
    throw StateError(
      'emulator role-doc seed failed for $uid ($role): HTTP $status $text',
    );
  }
}
