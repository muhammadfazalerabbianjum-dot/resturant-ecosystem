// ignore_for_file: avoid_print
import 'dart:io';

/// Fastlane Asset Generation Tool
///
/// This script automatically scaffolds the required App Store / Google Play
/// Fastlane directory structure so you can just drop screenshots into
/// the dynamically built folders for automated zero-touch publishing via Fastlane.
void main() {
  print('==================================================');
  print('🚀 FASTLANE STORE DIRECTORY GENERATOR');
  print('==================================================');

  final fastlaneDirs = [
    // iOS App Store Meta
    'ios/fastlane/metadata/en-US',
    'ios/fastlane/screenshots/en-US',
    // Android Play Store Meta
    'android/fastlane/metadata/android/en-US',
    'android/fastlane/metadata/android/en-US/images/phoneScreenshots',
    'android/fastlane/metadata/android/en-US/images/sevenInchScreenshots',
    'android/fastlane/metadata/android/en-US/images/icon',
    'android/fastlane/metadata/android/en-US/images/featureGraphic',
  ];

  for (final dir in fastlaneDirs) {
    final directory = Directory(dir);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
      print('✅ Created: $dir');
    } else {
      print('⏭️ Exists: $dir');
    }
  }

  // Generate stub txt files for Fastlane
  _writeStub(
    'android/fastlane/metadata/android/en-US/title.txt',
    'Carnama Best Burgers',
  );
  _writeStub(
    'android/fastlane/metadata/android/en-US/short_description.txt',
    'The quickest delivery and reservations in town.',
  );
  _writeStub('ios/fastlane/metadata/en-US/name.txt', 'Carnama Best Burgers');
  _writeStub(
    'ios/fastlane/metadata/en-US/subtitle.txt',
    'Quickest delivery in town.',
  );

  print('\n✅ Fastlane structure injected.');
  print(
    'Next Steps: Drop your generated screenshots into the fastlane/screenshots directories then run "fastlane supply"',
  );
}

void _writeStub(String path, String data) {
  final file = File(path);
  if (!file.existsSync()) {
    file.writeAsStringSync(data);
  }
}
