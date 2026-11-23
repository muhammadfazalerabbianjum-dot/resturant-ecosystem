import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sets up common platform channel mocks required by most widget tests.
///
/// Call this in `setUpAll` of any test file that uses:
/// - `geolocator` (location)
/// - `path_provider` (file storage)
/// - `firebase_messaging` (push notifications)
/// - `shared_preferences`
/// - `google_sign_in`
/// - `sign_in_with_apple`
///
/// Usage:
/// ```dart
/// setUpAll(() {
///   TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
///     ..setMockMethodCallHandler(channel, handler);
/// });
/// ```
Future<void> setupPlatformMocks() async {
  // SharedPreferences mock
  SharedPreferences.setMockInitialValues({});

  // Geolocator mock
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/geolocator'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'checkPermission':
              return 3; // LocationPermission.always
            case 'requestPermission':
              return 3;
            case 'getCurrentPosition':
              return <double>[37.7749, -122.4194, 0.0, 0.0];
            default:
              return null;
          }
        },
      );

  // Path provider mock
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return '/tmp/test_documents';
          }
          return null;
        },
      );

  // Firebase Messaging mock
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_messaging'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'requestPermission') {
            return {'authorizationStatus': 1};
          }
          if (methodCall.method == 'getToken') {
            return 'test_fcm_token';
          }
          if (methodCall.method == 'deleteToken') {
            return null;
          }
          if (methodCall.method == 'getInitialMessage') {
            return null;
          }
          return null;
        },
      );

  // Google Sign-In mock
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/google_sign_in'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'signIn') {
            return {
              'email': 'test@example.com',
              'idToken': 'test_id_token',
              'displayName': 'Test User',
            };
          }
          if (methodCall.method == 'signOut') {
            return null;
          }
          if (methodCall.method == 'isSignedIn') {
            return false;
          }
          return null;
        },
      );

  // Sign in with Apple mock
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'signIn') {
            return {
              'userIdentifier': 'apple_test_uid',
              'email': 'apple@test.com',
              'givenName': 'Apple',
              'familyName': 'User',
              'identityToken': 'test_apple_id_token',
              'authorizationCode': 'test_auth_code',
            };
          }
          return null;
        },
      );
}

/// Tears down platform mocks to prevent test pollution.
Future<void> tearDownPlatformMocks() async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/geolocator'),
        null,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_messaging'),
        null,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/google_sign_in'),
        null,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple'),
        null,
      );
}
