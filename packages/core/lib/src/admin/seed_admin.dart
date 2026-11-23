import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/src/config/core_config.dart';

/// Seeds the owner role for configured owner emails on first run.
///
/// Reads `CoreConfigHolder.instance.ownerEmails` (injected by the app layer
/// via `CoreConfig.set`) and grants each matching Firestore user the `owner`
/// role. Idempotent — re-running simply re-asserts the same role (Law 9).
Future<void> seedInitialAdmin() async {
  final ownerEmails = CoreConfigHolder.instance.ownerEmails;
  if (ownerEmails.isEmpty) return;

  final firestore = FirebaseFirestore.instance;

  final users = await firestore
      .collection('users')
      .where('email', whereIn: ownerEmails)
      .limit(ownerEmails.length)
      .get();

  if (users.docs.isEmpty) return;

  final batch = firestore.batch();
  for (final doc in users.docs) {
    batch.update(doc.reference, {
      'role': 'owner',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}
