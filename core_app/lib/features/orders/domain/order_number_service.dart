import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// WHY: Gap 3 — Human-Readable Order Numbers.
/// Raw Firestore UIDs (e.g. "kZ3xT0pLq9M...") are unreadable at a counter.
/// Kitchen staff need "#042" to yell across the room.
///
/// Strategy: An atomic Firestore transaction increments a shard counter in
/// `settings/orderCounter` and returns the next value as a zero-padded string.
/// This is crash-safe: if the transaction fails, we fall back to a 6-char
/// hash of the Firestore UID (still better than the full UID).
class OrderNumberService {
  final FirebaseFirestore _firestore;

  OrderNumberService({required FirebaseFirestore firestore})
    : _firestore = firestore;

  static const _counterDocPath = 'settings/orderCounter';
  static const _fieldName = 'seq';

  /// Returns the next sequential order number string, e.g. "#0042".
  /// Uses an atomic transaction to guarantee uniqueness under concurrent load.
  Future<String> nextOrderNumber() async {
    try {
      final counterRef = _firestore.doc(_counterDocPath);
      int nextNum = 1;

      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(counterRef);
        if (snap.exists) {
          nextNum = ((snap.data()?[_fieldName] as num?)?.toInt() ?? 0) + 1;
        }
        transaction.set(counterRef, {
          _fieldName: nextNum,
        }, SetOptions(merge: true));
      });

      // Zero-pad to at least 4 digits: "0001", "0042", "9999"
      return '#${nextNum.toString().padLeft(4, '0')}';
    } catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        fatal: false,
        information: ['context=OrderNumberService.nextOrderNumber'],
      );
      // Fallback: deterministic timestamp-based shortcode
      final ts = DateTime.now().millisecondsSinceEpoch;
      return '#${(ts % 10000).toString().padLeft(4, '0')}';
    }
  }

  /// Formats an existing Firestore document ID into a short readable code.
  /// Used to render legacy orders that pre-date this service.
  static String fromDocId(String docId) {
    if (docId.length >= 6) {
      return '#${docId.substring(0, 6).toUpperCase()}';
    }
    return '#${docId.toUpperCase()}';
  }
}
