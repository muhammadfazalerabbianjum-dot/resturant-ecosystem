import 'dart:async' show unawaited;

import 'package:core/core.dart' show kGdprAnalyticsConsentKey;
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CORE-COV core_ui additions: real behavior tests for the previously-untested
/// UI modules — EmptyStateWidget, SkeletonLoader, BrandButton,
/// GlobalErrorWidget, the GDPR consent dialog (unified canonical key), and the
/// shared palette/dimension constants. Pure widget tests — no new deps.
void main() {
  group('EmptyStateWidget', () {
    testWidgets('renders title + subtitle, and the CTA fires exactly once', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EmptyStateWidget(
            icon: Icons.info_outline,
            title: 'No orders yet',
            subtitle: 'Your orders appear here',
            ctaText: 'Order now',
            onCtaPressed: () => pressed++,
          ),
        ),
      );

      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.text('Your orders appear here'), findsOneWidget);

      await tester.tap(find.text('Order now'));
      await tester.pump();
      expect(pressed, 1);
    });

    testWidgets('omits the CTA button when no action is supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmptyStateWidget(
            icon: Icons.info_outline,
            title: 'Empty',
            subtitle: 'Nothing here',
          ),
        ),
      );

      expect(find.text('Empty'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });

  group('SkeletonLoader', () {
    test('factories expose explicit dimensions and radii', () {
      expect(SkeletonLoader.block(width: 120, height: 40).width, 120.0);
      expect(SkeletonLoader.block(width: 120, height: 40).height, 40.0);
      expect(SkeletonLoader.listTile().height, 72.0);
      expect(SkeletonLoader.card(height: 220).height, 220.0);
      expect(SkeletonLoader.block(width: 1, height: 1).borderRadius, 8.0);
    });

    testWidgets('renders a shim container of the requested size', (
      tester,
    ) async {
      await tester.pumpWidget(
        // Center loosens the screen-tight constraints so the explicit
        // width/height of the shim is what lays out (a plain `home:` child
        // receives TIGHT 800x600 constraints and the shim would expand).
        MaterialApp(
          home: Center(child: SkeletonLoader.block(width: 80, height: 24)),
        ),
      );

      expect(find.byType(Container), findsOneWidget);
      expect(find.byType(Shimmer), findsOneWidget);
      expect(tester.getSize(find.byType(Container)), const Size(80, 24));
    });
  });

  group('BrandButton', () {
    testWidgets('an enabled tap fires the pressed callback once', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BrandButton(text: 'Checkout', onPressed: () => pressed++),
        ),
      );

      await tester.tap(find.text('Checkout'));
      await tester.pump();
      await tester.pump();

      expect(pressed, 1);
    });
    testWidgets('loading disables the press and renders a spinner', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BrandButton(
            text: 'Paying',
            onPressed: () => pressed++,
            isLoading: true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // While loading the label is intentionally replaced by the spinner —
      // there is exactly ONE tap path (the ElevatedButton) and it is disabled.
      expect(find.text('Paying'), findsNothing);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(pressed, 0);
    });

    testWidgets('a null callback renders a disabled button (no-op tap)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: BrandButton(text: 'Unavailable')),
      );

      await tester.tap(find.text('Unavailable'));
      await tester.pump();
      // No crash, nothing to fire.
    });
  });

  group('GlobalErrorWidget', () {
    final details = FlutterErrorDetails(
      exception: StateError('payment failed'),
      stack: StackTrace.current,
      library: 'test',
    );

    testWidgets('falls back to the exception + canonical fallback body', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: GlobalErrorWidget(errorDetails: details)),
      );

      expect(find.textContaining('payment failed'), findsOneWidget);
      expect(find.text(kGlobalErrorFallbackBody), findsOneWidget);
    });

    testWidgets('localized title/body win when supplied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlobalErrorWidget(
            errorDetails: details,
            title: 'العربية title',
            body: 'A localized body',
          ),
        ),
      );

      expect(find.text('العربية title'), findsOneWidget);
      expect(find.text('A localized body'), findsOneWidget);
    });
  });

  group('AppColors / AppDimensions constants', () {
    test('brand slots are distinct from the neutral chrome', () {
      expect(AppColors.primary, isNot(AppColors.background));
      expect(AppColors.primary, isNot(AppColors.error));
      expect(AppColors.textPrimary, isNot(AppColors.textSecondary));
      expect(AppColors.surface, AppColors.background);
      expect(AppColors.primary.a, 1.0);
    });

    test('dimension tokens are positive and ordered', () {
      expect(AppDimensions.paddingS, 8.0);
      expect(AppDimensions.paddingM, 16.0);
      expect(AppDimensions.radiusM, 12.0);
      expect(AppDimensions.paddingM, greaterThan(AppDimensions.paddingS));
    });
  });
  group('GdprConsentDialog — unified canonical key (W9.8)', () {
    test('undecided consent reports false + not decided', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await GdprConsentDialog.hasConsent(), isFalse);
      expect(await GdprConsentDialog.isConsentDecided(), isFalse);
    });

    testWidgets('a stored decision suppresses the prompt', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kGdprAnalyticsConsentKey: false,
      });

      await _pumpDialog(tester, expectShown: false);
    });

    testWidgets(
      'Accept persists to the CANONICAL key and broadcasts on the stream',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final streamValues = <bool>[];
        final sub = GdprConsentDialog.onConsentChangedStream.listen(
          streamValues.add,
        );
        addTearDown(() => sub.cancel());

        await _pumpDialog(tester);

        await tester.tap(find.text('Accept'));
        await tester.pump(const Duration(milliseconds: 50));

        expect(await GdprConsentDialog.isConsentDecided(), isTrue);
        expect(await GdprConsentDialog.hasConsent(), isTrue);
        expect(streamValues, <bool>[true]);
      },
    );

    testWidgets('Decline is a durable opt-out (never re-prompted)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final streamValues = <bool>[];
      final sub = GdprConsentDialog.onConsentChangedStream.listen(
        streamValues.add,
      );
      addTearDown(() => sub.cancel());

      await _pumpDialog(tester);

      await tester.tap(find.text('Decline'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(await GdprConsentDialog.isConsentDecided(), isTrue);
      expect(await GdprConsentDialog.hasConsent(), isFalse);
      expect(streamValues, <bool>[false]);
    });
  });
}

/// Pumps a home whose builder requests the consent dialog, then asserts the
/// dialog's show/omission contract.
Future<void> _pumpDialog(WidgetTester tester, {bool expectShown = true}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          unawaited(GdprConsentDialog.showIfNeeded(context));
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));

  if (expectShown) {
    expect(find.text('Data & Privacy'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  } else {
    expect(find.text('Data & Privacy'), findsNothing);
  }
}
