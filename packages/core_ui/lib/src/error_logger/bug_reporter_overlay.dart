import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'logs_screen.dart';

class BugReporterOverlay extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Build-mode seam (P4-?? / B6-2). Defaults to DEBUG/PROFILE builds so the
  /// internal [LogsScreen] (raw logs + stack traces) is NEVER reachable by end
  /// users in a release build. Explicitly settable so tests can exercise the
  /// release behavior without a real `kReleaseMode` build.
  final bool debugShowBugReporter;

  const BugReporterOverlay({
    required this.child,
    this.navigatorKey,
    this.debugShowBugReporter = kDebugMode || kProfileMode,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!debugShowBugReporter) {
      // B6-2: No FAB, no LogsScreen access in release — just the app.
      return child;
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          Positioned(
            right: 16,
            bottom: 32, // Elevated slightly above default FAB positions
            child: Material(
              type: MaterialType.transparency,
              child: FloatingActionButton(
                heroTag: 'global_bug_reporter_fab',
                onPressed: () {
                  showModalBottomSheet(
                    context: navigatorKey?.currentContext ?? context,
                    isScrollControlled: true,
                    builder: (ctx) => const Padding(
                      padding: EdgeInsets.only(top: 50.0),
                      child: Scaffold(body: LogsScreen()),
                    ),
                  );
                },
                child: const Icon(Icons.bug_report),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
