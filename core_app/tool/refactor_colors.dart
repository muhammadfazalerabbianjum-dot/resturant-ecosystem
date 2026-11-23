// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  int replaced = 0;

  for (final file in files) {
    if (file.path.contains('app_colors.dart')) continue;

    String content = file.readAsStringSync();

    // Perform replacements
    content = content.replaceAll('Colors.white', 'AppColors.background');
    content = content.replaceAll('Colors.black87', 'AppColors.textPrimary');
    content = content.replaceAll('Colors.black', 'AppColors.textPrimary');
    content = content.replaceAll(
      'Colors.grey.shade400',
      'AppColors.textSecondary',
    );
    content = content.replaceAll(
      'Colors.grey.shade800',
      'AppColors.textSecondary',
    );
    content = content.replaceAll('Colors.grey', 'AppColors.textSecondary');
    content = content.replaceAll('Colors.red', 'AppColors.error');
    content = content.replaceAll('Colors.green', 'AppColors.success');
    content = content.replaceAll('Colors.amber', 'AppColors.warning');
    content = content.replaceAll('Colors.transparent', 'AppColors.transparent');

    final original = file.readAsStringSync();
    if (content != original) {
      if (!content.contains('app_colors.dart')) {
        final lines = content.split('\n');
        final firstImportIdx = lines.indexWhere((l) => l.startsWith('import '));
        if (firstImportIdx != -1) {
          lines.insert(
            firstImportIdx,
            "import 'package:labs/core/theme/app_colors.dart';",
          );
          content = lines.join('\n');
        }
      }
      file.writeAsStringSync(content);
      replaced++;
      print('Fixed \${file.path}');
    }
  }
  print('Total files refactored for Law 3 compliance: $replaced');
}
