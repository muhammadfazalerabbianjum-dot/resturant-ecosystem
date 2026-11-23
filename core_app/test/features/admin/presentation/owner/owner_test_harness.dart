import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/l10n/app_localizations.dart';

import '../../../../helpers/test_helpers.dart';
import '../../../../support/tenant_claim_fakes.dart';

/// p28 lane B — shared pump harness for the owner-tab interaction tests.
///
/// WHY: five new test files exercise the owner tabs/editors; the provider
/// override set must be identical across them (otherwise coverage varies by
/// file and the per-file LH==LF receipts become meaningless). This is the
/// exact override set p22's adoption sweep proved green, plus an escape
/// hatch for per-test provider overrides.
void setUpOwnerFirebase() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
}

List<Override> _ownerOverrides(FirebaseFirestore firestore) {
  final authStream = Stream<User?>.value(
    MockUser(uid: 'owner-p28', email: 'owner@test.com'),
  );
  return <Override>[
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => authStream),
    currentUserProvider.overrideWith(
      (ref) async => const UserModel(id: 'owner-p28', role: UserRole.owner),
    ),
    adminDataServiceProvider.overrideWithValue(
      AdminDataService(
        firestore: firestore,
        logger: FakeLogger(),
        tenantClaim: const FixedTenantClaim(),
      ),
    ),
    ordersAcceptingProvider.overrideWith((ref) => Stream<bool>.value(true)),
    panicSwitchServiceProvider.overrideWithValue(
      PanicSwitchService(
        firestore: firestore,
        tenantClaim: const FixedTenantClaim(),
      ),
    ),
    loggerProvider.overrideWithValue(FakeLogger()),
  ];
}

/// Renders [child] as the home body (tabs — they never pop their route).
Widget ownerHarness(
  FirebaseFirestore firestore,
  Widget child, {
  List<Override> extraOverrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[..._ownerOverrides(firestore), ...extraOverrides],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// Pushes the editor under test onto its OWN route.
///
/// WHY: the editors call `Navigator.pop(context)` on save — the way they
/// close inside the production BrandSheet. Popping a home route would empty
/// the whole tree mid-test; a pushed route pops cleanly, so the "sheet
/// closed" assertion behaves exactly like production.
Widget ownerLauncherHarness(
  FirebaseFirestore firestore, {
  required String openLabel,
  required Widget Function() buildSubject,
  List<Override> extraOverrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[..._ownerOverrides(firestore), ...extraOverrides],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(body: buildSubject()),
                ),
              );
            },
            child: Text(openLabel),
          ),
        ),
      ),
    ),
  );
}
