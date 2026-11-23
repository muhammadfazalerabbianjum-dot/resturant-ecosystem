// ignore_for_file: avoid_print
import 'dart:io';

/// APK Size + Frame Rate Budget Enforcer – Phase 9.1
/// Fails the pipeline if the release APK exceeds the defined size budget.
/// Run AFTER `flutter build apk --release --split-per-abi`.
Future<void> main() async {
  const maxApkSizeMb = 35.0; // Hard ceiling in MB

  // Check APK size
  final apkDir = Directory('build/app/outputs/flutter-apk/');
  if (!apkDir.existsSync()) {
    print(
      '[BLOCKER] APK directory not found. Run flutter build apk --release first.',
    );
    exit(1);
  }

  final apks = apkDir.listSync().whereType<File>().where(
    (f) => f.path.endsWith('.apk') && f.path.contains('release'),
  );

  bool budgetExceeded = false;
  for (final apk in apks) {
    final sizeMb = apk.lengthSync() / (1024 * 1024);
    final name = apk.path.split(Platform.pathSeparator).last;
    if (sizeMb > maxApkSizeMb) {
      print(
        '❌ BUDGET EXCEEDED: $name is ${sizeMb.toStringAsFixed(1)}MB (limit: ${maxApkSizeMb}MB)',
      );
      budgetExceeded = true;
    } else {
      print('✅ $name: ${sizeMb.toStringAsFixed(1)}MB (within budget)');
    }
  }

  if (budgetExceeded) {
    print('\nAction: Run `flutter build apk --analyze-size` to find culprits.');
    exit(1);
  }

  print('\n✅ All APKs within size budget.');
}
