import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/a11y/text_scale_clamp.dart';
import 'package:labs/features/auth/presentation/login_screen.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_tracker_steps_widget.dart';
import 'package:labs/l10n/app_localizations.dart';

/// UX-2 T-4 (05-P2-A11Y-TEXTSCALE): the clamp is a REAL behavior contract —
/// OS scales above [kMaxSupportedTextScale] are clamped, 2.0x passes through
/// unchanged, and the real screens survive 2.0x without RenderFlex overflow.
void main() {
  group('ClampedTextScale — clamp math', () {
    testWidgets(
      'an OS scale of 3.2 is clamped to exactly kMaxSupportedTextScale (2.0)',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 3.2;
        addTearDown(
          () => tester.platformDispatcher.textScaleFactorTestValue = 1.0,
        );
        double probed = -1;
        await tester.pumpWidget(
          ClampedTextScale(
            child: Builder(
              builder: (context) {
                probed = MediaQuery.textScalerOf(context).scale(100);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(
          probed,
          200.0,
          reason: '3.2x OS scale must clamp to 2.0x effective',
        );
      },
    );

    testWidgets('2.0x passes through unchanged (the supported ceiling)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(
        () => tester.platformDispatcher.textScaleFactorTestValue = 1.0,
      );
      double probed = -1;
      await tester.pumpWidget(
        ClampedTextScale(
          child: Builder(
            builder: (context) {
              probed = MediaQuery.textScalerOf(context).scale(100);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(probed, 200.0, reason: '2.0x is fully supported, not clamped');
    });

    testWidgets('1.0x passes through unchanged', (tester) async {
      double probed = -1;
      await tester.pumpWidget(
        ClampedTextScale(
          child: Builder(
            builder: (context) {
              probed = MediaQuery.textScalerOf(context).scale(100);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(probed, 100.0);
    });
  });

  group('Real screens — T-4 no overflow at 2.0x text scale', () {
    testWidgets('LoginScreen renders without overflow at 2.0x', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(
        () => tester.platformDispatcher.textScaleFactorTestValue = 1.0,
      );
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LoginScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('OrderTrackerStepsWidget renders without overflow at 2.0x', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(
        () => tester.platformDispatcher.textScaleFactorTestValue = 1.0,
      );
      final order = OrderModel(
        id: 'ord123',
        customerId: 'user1',
        totalCents: 1500,
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: OrderTrackerStepsWidget(
              order: order,
              currentStatus: OrderStatus.preparing,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
