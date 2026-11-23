// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('lib directory not found');
    exit(1);
  }

  bool passed = true;
  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    final content = file.readAsStringSync();
    if (content.contains('.collection(\'users\').doc(') &&
        content.contains('.set({')) {
      if (!content.contains("'role':") || !content.contains("'email':")) {
        print(
          '❌ Schema Violation in ${file.path}: Found users.set() missing required schema constraints.',
        );
        passed = false;
      }
    }

    if (content.contains('.collection(\'orders\').doc(') &&
        content.contains('.set({')) {
      if (!content.contains("'customerId':")) {
        print(
          '❌ Schema Violation in ${file.path}: Found orders.set() missing customerId.',
        );
        passed = false;
      }
    }
  }

  if (!passed) {
    print('Failed Firestore Schema Analysis.');
    exit(1);
  }

  print('✅ Schema Analysis Passed.');
}
