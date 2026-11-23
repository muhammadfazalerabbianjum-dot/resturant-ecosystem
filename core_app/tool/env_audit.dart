// ignore_for_file: avoid_print
import 'dart:io';

/// Phase 11 / 15 Privacy Compliance
/// Pre-commit/Pre-push hook to violently reject any commit containing
/// hardcoded `.env` files or obvious API keys (`sk_live_`, `AIza`, etc.)
/// committed into the repository or `lib/` folder.
void main() {
  print('🔒 Running Environment & Secrets Audit (Laws 16 & Privacy)...');

  // 1. Ensure .env is NOT tracked
  final gitStatus = Process.runSync('git', ['ls-files', '.env']);
  if (gitStatus.stdout.toString().trim().isNotEmpty) {
    print(
      '🚨 FATAL (Law 16): .env file is tracked in Git. Remove it immediately.',
    );
    exit(1);
  }

  // 2. Scan lib/ for hardcoded keys (Stripe 'sk_live_', Firebase 'AIzaSy')
  final scanResult = Process.runSync('git', [
    'grep',
    '-iE',
    'sk_live_|AIzaSy|sk_test_',
    'lib/',
  ]);
  if (scanResult.stdout.toString().trim().isNotEmpty) {
    print('🚨 FATAL (Law 16): Hardcoded API Keys detected in source code!');
    print(scanResult.stdout);
    print('Move all keys to an untracked .env file and use flutter_dotenv.');
    exit(1);
  }

  print('✅ Environment Audit: No leaked keys detected.');
}
