import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/feature_flag_gate.dart';
import 'package:labs/app/config/feature_flags_service.dart';

/// P37 T-2 (D-P37-1 = BRANCH A) — production flag gates.
///
/// R2 (WHITE_LABEL_p37_nine_push.md §1): the six Firestore feature flags were
/// documented but had ZERO real call sites at HEAD. This grep-pin proves each
/// flag gates a real production control in `core_app/lib`. The FlagGate
/// contract (default-true, false => control absent, admin stream flip
/// reflects on next pump) is pinned in the companion group below.
void main() {
  // (source file under core_app/lib, flag literal that must appear there —
  // dart format may split `FlagGate(` from `flag:`, so match the literal).
  const gates = <(String, String)>[
    (
      'features/tracking/presentation/delivery_tracker_screen.dart',
      "flag: 'deliveryTracking'",
    ),
    (
      'features/tracking/presentation/delivery_tracker_screen.dart',
      "flag: 'smartReorder'",
    ),
    ('features/waitlist/presentation/waitlist_screen.dart', "flag: 'waitlist'"),
    (
      'features/checkout/presentation/checkout_screen.dart',
      "flag: 'promoCode'",
    ),
    (
      'features/profile/presentation/profile_screen.dart',
      "flag: 'loyaltyPoints'",
    ),
    (
      'features/onboarding/presentation/onboarding_screen.dart',
      "FlagGate.isEnabled(ref, 'tourMode')",
    ),
  ];

  group('P37 T-2 grep-pin: each flag gates a production control', () {
    test('all six flag gates are present in core_app/lib', () {
      final missing = <String>[];
      for (final (path, marker) in gates) {
        final file = File('${Directory.current.path}/lib/$path');
        expect(file.existsSync(), isTrue, reason: 'source missing: $path');
        final src = file.readAsStringSync();
        if (!src.contains(marker) || !src.contains('FlagGate')) {
          missing.add('$path -> $marker');
        }
      }
      expect(
        missing,
        isEmpty,
        reason: 'flags with no production gate (RED proof): $missing',
      );
    });
  });

  group('FlagGate contract (p37 T-2, D-P37-1 branch A)', () {
    // The five widget-gate flags (tourMode is imperative — tested below).
    const gateFlags = [
      'smartReorder',
      'waitlist',
      'promoCode',
      'deliveryTracking',
      'loyaltyPoints',
    ];

    Widget hostFor(String flag, Map<String, dynamic> docFlags) => ProviderScope(
      // UniqueKey: a second pumpWidget must rebuild the container so the new
      // override stream is actually subscribed (element reuse would keep the
      // previous scope's flag state alive).
      key: UniqueKey(),
      overrides: [
        featureFlagsProvider.overrideWith(
          (ref) =>
              Stream<FeatureFlagsService>.value(FeatureFlagsService(docFlags)),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: FlagGate(flag: flag, child: const Text('CTRL')),
        ),
      ),
    );

    for (final flag in gateFlags) {
      testWidgets(
        '$flag: default doc keeps the control, explicit false removes it',
        (tester) async {
          await tester.pumpWidget(hostFor(flag, <String, dynamic>{}));
          await tester.pump(); // Stream.value lands -> rebuild
          expect(
            find.text('CTRL'),
            findsOneWidget,
            reason: 'absent doc => default-true (shipped behavior)',
          );
          await tester.pumpWidget(
            hostFor(flag, <String, dynamic>{flag: false}),
          );
          await tester.pump(); // Stream.value lands -> rebuild
          expect(
            find.text('CTRL'),
            findsNothing,
            reason: 'settings/featureFlags[$flag]=false => control absent',
          );
        },
      );
    }

    testWidgets(
      'admin flip in settings/featureFlags hides the control on next pump',
      (tester) async {
        final controller = StreamController<FeatureFlagsService>();
        addTearDown(controller.close);
        controller.add(FeatureFlagsService(<String, dynamic>{}));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              featureFlagsProvider.overrideWith((ref) => controller.stream),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: FlagGate(flag: 'loyaltyPoints', child: Text('CTRL')),
              ),
            ),
          ),
        );
        expect(find.text('CTRL'), findsOneWidget, reason: 'flag on by default');
        controller.add(
          FeatureFlagsService(<String, dynamic>{'loyaltyPoints': false}),
        );
        await tester.pump();
        expect(
          find.text('CTRL'),
          findsNothing,
          reason: 'admin flip must reflect on the next frame',
        );
      },
    );

    testWidgets(
      'tourMode: FlagGate.isEnabled follows the same default-true rule',
      (tester) async {
        bool? lastResolved;
        Future<void> resolveWith(Map<String, dynamic> docFlags) async {
          bool? resolved;
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(), // fresh container per resolution
              overrides: [
                featureFlagsProvider.overrideWith(
                  (ref) => Stream<FeatureFlagsService>.value(
                    FeatureFlagsService(docFlags),
                  ),
                ),
              ],
              child: Consumer(
                builder: (context, ref, _) {
                  ref.watch(featureFlagsProvider);
                  resolved = FlagGate.isEnabled(ref, 'tourMode');
                  return const SizedBox();
                },
              ),
            ),
          );
          await tester.pump(); // let the stream value land -> rebuild
          expect(resolved, isNotNull);
          lastResolved = resolved;
        }

        await resolveWith(<String, dynamic>{'tourMode': false});
        expect(lastResolved, isFalse, reason: 'doc false must win');
        await resolveWith(<String, dynamic>{});
        expect(lastResolved, isTrue, reason: 'absent doc => default-true');
      },
    );
  });
}
