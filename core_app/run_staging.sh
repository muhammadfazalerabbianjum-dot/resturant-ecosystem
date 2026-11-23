#!/bin/bash
export $(grep -v '^#' .env.staging | xargs)
flutter clean
flutter pub get
flutter run --flavor staging --dart-define=FIREBASE_OPTIONS_PATH=$FIREBASE_OPTIONS_PATH --profile
