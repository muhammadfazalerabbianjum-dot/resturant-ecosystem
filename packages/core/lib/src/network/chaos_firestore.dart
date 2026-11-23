import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Write-intercepting proxy around [FirebaseFirestore] for chaos/stress testing.
///
/// Usage (test only — never enable in production):
/// ```dart
/// ChaosFirestore.enableChaosMode = true;
/// ```
class ChaosFirestore {
  final FirebaseFirestore _delegate;
  final double failureRate;

  static bool enableChaosMode = false;
  static final _rng = Random();

  ChaosFirestore(this._delegate, {this.failureRate = 0.1});

  void _maybeThrow() {
    if (enableChaosMode && _rng.nextDouble() < failureRate) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'chaos-injected',
        message: '[ChaosFirestore] Injected failure for testing',
      );
    }
  }

  /// Returns a document proxy that faults on write.
  ChaosDocumentRef doc(String path) =>
      ChaosDocumentRef(_delegate.doc(path), _maybeThrow);

  /// Returns a collection proxy that faults on write.
  ChaosCollectionRef collection(String path) =>
      ChaosCollectionRef(_delegate.collection(path), _maybeThrow);

  /// Returns a batch proxy that faults on commit.
  ChaosBatch batch() => ChaosBatch(_delegate.batch(), _maybeThrow);

  Future<T> runTransaction<T>(
    TransactionHandler<T> updateFunction, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    _maybeThrow();
    return _delegate.runTransaction(
      updateFunction,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
}

/// Public proxy around [DocumentReference] — faults before writes.
class ChaosDocumentRef {
  final DocumentReference<Map<String, dynamic>> ref;
  final void Function() _maybeThrow;

  ChaosDocumentRef(this.ref, this._maybeThrow);

  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) {
    _maybeThrow();
    return ref.set(data, options);
  }

  Future<void> update(Map<Object, Object?> data) {
    _maybeThrow();
    return ref.update(data);
  }

  Future<void> delete() {
    _maybeThrow();
    return ref.delete();
  }

  String get id => ref.id;
  String get path => ref.path;
}

/// Public proxy around [CollectionReference] — faults before writes.
class ChaosCollectionRef {
  final CollectionReference<Map<String, dynamic>> ref;
  final void Function() _maybeThrow;

  ChaosCollectionRef(this.ref, this._maybeThrow);

  Future<DocumentReference<Map<String, dynamic>>> add(
    Map<String, dynamic> data,
  ) {
    _maybeThrow();
    return ref.add(data);
  }

  ChaosDocumentRef doc([String? path]) =>
      ChaosDocumentRef(ref.doc(path), _maybeThrow);

  String get id => ref.id;
  String get path => ref.path;
}

/// Public batch proxy — faults at commit time.
class ChaosBatch {
  final WriteBatch _batch;
  final void Function() _maybeThrow;

  ChaosBatch(this._batch, this._maybeThrow);

  Future<void> commit() {
    _maybeThrow();
    return _batch.commit();
  }

  void delete(dynamic document) {
    final docRef = document is ChaosDocumentRef ? document.ref : document;
    _batch.delete(docRef as DocumentReference);
  }

  void set<T>(dynamic document, T data, [SetOptions? options]) {
    final docRef = document is ChaosDocumentRef ? document.ref : document;
    _batch.set(docRef as DocumentReference<T>, data, options);
  }

  void update(dynamic document, Map<Object, Object?> data) {
    final docRef = document is ChaosDocumentRef ? document.ref : document;
    _batch.update(docRef as DocumentReference, data);
  }
}
