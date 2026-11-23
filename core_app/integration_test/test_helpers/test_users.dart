import 'package:firebase_auth/firebase_auth.dart';

import 'emulator_bootstrap.dart';

/// CARNAMA CONSTITUTION Law 30: Deterministic test user factory
///
/// Creates test users with specific roles for integration testing.
/// All users are created in the emulator and cleaned up automatically.
class TestUserFactory {
  static int _counter = 0;

  /// Generate unique test email to avoid conflicts
  static String _uniqueEmail(String prefix) {
    _counter++;
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_$_counter@test.carnama.com';
  }

  /// Create a test user with specified role
  /// Returns UserCredential for the created user
  static Future<UserCredential> createUser({
    required String role,
    String? branchId,
  }) async {
    final email = _uniqueEmail(role);
    const password = 'TestPass123!';

    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    // p34 cluster A: rules L400 evaluates isAppVerified() (emulator tokens
    // carry no `app_id` claim -> evaluation error) and rules L411-L415 allow
    // client role-doc creation ONLY as 'customer'. Provision the way
    // production does: claim first (Auth admin REST), then the role doc
    // (emulator-admin create). See test_helpers/emulator_bootstrap.dart.
    await grantAppIdClaim(credential.user!);
    await seedUserRoleDoc(
      uid: credential.user!.uid,
      email: email,
      role: role,
      branchId: branchId,
    );

    return credential;
  }

  /// Create admin user
  static Future<UserCredential> createAdmin({String? branchId}) {
    return createUser(role: 'admin', branchId: branchId);
  }

  /// Create owner user
  static Future<UserCredential> createOwner({String? branchId}) {
    return createUser(role: 'owner', branchId: branchId);
  }

  /// Create manager user
  static Future<UserCredential> createManager({String? branchId}) {
    return createUser(role: 'manager', branchId: branchId);
  }

  /// Create kitchen user
  static Future<UserCredential> createKitchen({String? branchId}) {
    return createUser(role: 'kitchen', branchId: branchId);
  }

  /// Create customer user
  static Future<UserCredential> createCustomer({String? branchId}) {
    return createUser(role: 'customer', branchId: branchId);
  }

  /// Create delivery driver user
  static Future<UserCredential> createDriver({String? branchId}) {
    return createUser(role: 'delivery', branchId: branchId);
  }

  /// Reset counter (useful for test isolation)
  static void resetCounter() {
    _counter = 0;
  }
}
