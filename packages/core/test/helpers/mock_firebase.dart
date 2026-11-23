import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mocktail/mocktail.dart';

/// CORE-COV mocktail seams shared by the packages/core suites. Every Firebase
/// platform singleton stays UNCONFIGURED in these tests — the classes under
/// test receive the mocks through their documented constructor injection
/// points only (never `FirebaseX.instance`).
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseUser extends Mock implements User {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockUserCredential extends Mock implements UserCredential {}

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockCallableResult extends Mock implements HttpsCallableResult<dynamic> {}

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class MockNotificationSettings extends Mock implements NotificationSettings {}

class MockCrashReporter extends Mock implements CrashReporter {}

/// Test seam for [FirebaseFunctionsException] whose constructor is
/// `@protected`: subclassing is the documented way to fabricate the typed
/// exception (protected members are visible to subclasses).
class TestFunctionsException extends FirebaseFunctionsException {
  TestFunctionsException(String code) : super(code: code, message: 'test');
}
