// ignore_for_file: avoid_print
import 'dart:io';

/// Installs the git pre-push hook for Law 21 compliance.
/// Run via: dart tool/install_hooks.dart
void main() {
  final hookSource = File('.git/hooks/pre-push');

  if (!Directory('.git/hooks').existsSync()) {
    print('❌ Not a git repository, or .git/hooks missing.');
    exit(1);
  }

  const hookContent = '''#!/bin/sh
# ============================================================
# CARNAMA Constitution — Law 21: Pre-Push Hook (Mandatory)
# ============================================================
set -e
echo "🔒 [Law 21] Running pre-push constitutional checks..."

echo "→ [1/4] Checking code format (dart format)..."
dart format --set-exit-if-changed . 2>&1

echo "→ [2/4] Running static analysis (flutter analyze)..."
flutter analyze --fatal-infos --fatal-warnings 2>&1

echo "→ [3/4] Running core unit tests (test/core/ test/wiring/)..."
flutter test test/core/ test/wiring/ --reporter compact 2>&1

echo "→ [4/4] Running widget tests (test/widget/)..."
flutter test test/widget/ --reporter compact 2>&1

echo "✅ [Law 21] All pre-push checks passed. Safe to push."
''';

  hookSource.writeAsStringSync(hookContent);

  // Make the hook executable (Linux/macOS)
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['+x', hookSource.path]);
  }

  print('✅ [Law 21] Git pre-push hook installed successfully.');
}
