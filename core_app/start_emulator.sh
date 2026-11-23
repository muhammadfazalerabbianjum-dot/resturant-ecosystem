#!/bin/bash
# Script to launch Firebase Emulators and run tests against them.
echo "Starting Firebase Emulators..."
firebase emulators:start &
EMULATOR_PID=$!

echo "Waiting for emulators to boot..."
sleep 15

echo "Running Flutter tests..."
flutter test

echo "Stopping Emulators..."
kill $EMULATOR_PID
