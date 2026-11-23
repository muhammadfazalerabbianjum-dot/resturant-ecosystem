#!/bin/bash
# Law 13: APK Size Measurement
flutter build apk --release --obfuscate --split-debug-info=build/symbols
ls -lh build/app/outputs/flutter-apk/app-release.apk
