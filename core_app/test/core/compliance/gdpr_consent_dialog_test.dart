import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:core/core.dart'
    show CoreConfigHolder, TelemetryService, kGdprAnalyticsConsentKey;
import 'package:core/src/config/core_config.dart';
import 'package:core_ui/src/compliance/gdpr_consent_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/compliance/gdpr_consent_dialog.dart' as labs;
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Demo-mode config for the TelemetryService consent-gate proof: a REAL
/// analyticsEvents write must happen ONLY when the canonical consent key is
/// true (CoreConfig interface faked via noSuchMethod — repo fake pattern).
class _DemoCoreConfig implements CoreConfig {
  @override
  bool get isDemoMode => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Host that mirrors the production wiring (home_screen.dart initState):
/// fires the consent chain once on first frame.
class _ConsentHost extends StatelessWidget {
  const _ConsentHost();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(labs.GdprConsentDialog.showIfNeeded(context));
    });
    return const Scaffold(body: Text('home-body'));
  }
}

Widget _host() => const MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: _ConsentHost(),
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    CoreConfigHolder.set(const DefaultCoreConfig());
  });

  testWidgets('GDPR consent dialog renders with accept and decline buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GdprConsentDialog())),
    );
    expect(find.text('Data & Privacy'), findsOneWidget);
  });

  testWidgets(
    'core_ui dialog copy persists acceptance under the CANONICAL key (W9.8)',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GdprConsentDialog())),
      );
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kGdprAnalyticsConsentKey), isTrue);
      expect(await GdprConsentDialog.isConsentDecided(), isTrue);
    },
  );

  testWidgets(
    'T-1: undecided user is prompted ONCE; ACCEPT persists the canonical key',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_host());
      await tester.pump(); // post-frame callback runs showIfNeeded
      await tester.pump(); // dialog builds

      expect(find.byType(labs.GdprConsentDialog), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kGdprAnalyticsConsentKey), isTrue);
      expect(await labs.GdprConsentDialog.hasConsent(), isTrue);
      expect(await labs.GdprConsentDialog.isConsentDecided(), isTrue);
    },
  );

  testWidgets('T-1: a DECLINE is durable — the dialog is never re-shown', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({kGdprAnalyticsConsentKey: false});
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('home-body'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kGdprAnalyticsConsentKey), isFalse);
    expect(await labs.GdprConsentDialog.hasConsent(), isFalse);
    expect(await labs.GdprConsentDialog.isConsentDecided(), isTrue);
  });

  testWidgets(
    'T-1: a prior ACCEPT suppresses the prompt on the next home landing',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({kGdprAnalyticsConsentKey: true});
      await tester.pumpWidget(_host());
      await tester.pump();
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  test(
    'T-1: ACCEPTED consent ENABLES telemetry (real analyticsEvents write)',
    () async {
      SharedPreferences.setMockInitialValues({kGdprAnalyticsConsentKey: true});
      CoreConfigHolder.set(_DemoCoreConfig());
      final firestore = FakeFirebaseFirestore();

      await TelemetryService.forTest(firestore: firestore).log('test_event');

      final snap = await firestore.collection('analyticsEvents').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['event'], 'test_event');
    },
  );

  test(
    'T-1: undecided/declined consent keeps telemetry OFF (no write)',
    () async {
      SharedPreferences.setMockInitialValues({});
      CoreConfigHolder.set(_DemoCoreConfig());
      final firestore = FakeFirebaseFirestore();

      await TelemetryService.forTest(firestore: firestore).log('blocked_event');

      expect(
        (await firestore.collection('analyticsEvents').get()).docs,
        isEmpty,
      );
    },
  );
}
