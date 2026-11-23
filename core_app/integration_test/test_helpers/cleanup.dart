import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// CARNAMA CONSTITUTION Law 30: Deterministic test cleanup
///
/// Ensures zero test pollution by cleaning up Firebase state after each test.
/// Always use this in tearDown to guarantee clean state for next test.
class TestCleanup {
  /// Clean up current user and their Firestore document
  static Future<void> cleanCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Delete user document from Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
      } catch (e) {
        // Ignore cleanup errors - document may not exist
      }

      try {
        // Delete the auth user
        await user.delete();
      } catch (e) {
        // Ignore if already deleted
      }
    }

    // Sign out to ensure clean state
    await FirebaseAuth.instance.signOut();
  }

  /// Clean up specific user by UID
  static Future<void> cleanUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Clean up test data from specific collection
  static Future<void> cleanCollection(String collectionPath) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionPath)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Clean up all test data (comprehensive cleanup)
  static Future<void> cleanAll() async {
    await cleanCurrentUser();

    // Clean common test collections
    await Future.wait([
      cleanCollection('users'),
      cleanCollection('orders'),
      cleanCollection('reservation_locks'),
      cleanCollection('waitlists'),
    ]);
  }
}
