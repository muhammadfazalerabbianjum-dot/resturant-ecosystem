import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/auth/presentation/login_screen.dart';

import 'golden_test_helper.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  // Silence GoogleFonts "font not found locally" errors — expected when
  // allowRuntimeFetching is false and fonts aren't bundled in test assets.
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    if (msg.contains('GoogleFonts') || msg.contains('font')) return;
    FlutterError.presentError(details);
  };

  testWidgets('LoginScreen Golden Test', (tester) async {
    // Lock to a standard Android HD viewport so goldens are device-agnostic.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapForGolden(const LoginScreen()));

    // Use fixed pumps instead of pumpAndSettle to avoid hanging on
    // async font timers that Google Fonts would enqueue.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('baselines/login_screen_baseline.png'),
    );
  });
}
