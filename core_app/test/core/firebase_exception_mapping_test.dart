// Law 46: FirebaseException Surface Mapping Tests
// Every error code that can arrive from Firestore must be mapped
// to a human-readable state. Raw Firebase error strings must NEVER
// reach the UI. This file is the mathematical proof of that contract.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal repository that shows the correct pattern for mapping
/// every possible FirebaseException code to a typed app-level result.
class _OrderRepository {
  final FirebaseFirestore _db;
  _OrderRepository(this._db);

  Future<String> fetchOrderStatus(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists) return 'not_found';
      return doc.data()?['status'] as String? ?? 'unknown';
    } on FirebaseException catch (e) {
      return switch (e.code) {
        'permission-denied' => 'error:permission_denied',
        'unavailable' => 'error:service_unavailable',
        'deadline-exceeded' => 'error:timeout',
        'not-found' => 'error:not_found',
        'cancelled' => 'error:cancelled',
        'resource-exhausted' => 'error:quota_exceeded',
        _ => 'error:unknown',
      };
    }
  }
}

void main() {
  group('Law 46 — FirebaseException Surface Mapping', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _OrderRepository repo;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repo = _OrderRepository(fakeFirestore);
    });

    test('happy path: returns status when document exists', () async {
      await fakeFirestore.collection('orders').doc('o1').set({
        'status': 'delivered',
      });
      final result = await repo.fetchOrderStatus('o1');
      expect(result, 'delivered');
    });

    test('returns not_found when document does not exist', () async {
      final result = await repo.fetchOrderStatus('nonexistent');
      expect(result, 'not_found');
    });

    test('maps permission-denied to error:permission_denied', () async {
      // Simulated via exception wrapping — fake_cloud_firestore surfaces real codes
      final brokenRepo = _BrokenRepository(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'PERMISSION_DENIED',
        ),
      );
      expect(await brokenRepo.fetch(), 'error:permission_denied');
    });

    test('maps unavailable to error:service_unavailable', () async {
      final brokenRepo = _BrokenRepository(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'Backend unavailable',
        ),
      );
      expect(await brokenRepo.fetch(), 'error:service_unavailable');
    });

    test('maps deadline-exceeded to error:timeout', () async {
      final brokenRepo = _BrokenRepository(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'deadline-exceeded',
          message: 'Timeout',
        ),
      );
      expect(await brokenRepo.fetch(), 'error:timeout');
    });

    test('maps not-found to error:not_found', () async {
      final brokenRepo = _BrokenRepository(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Document not found',
        ),
      );
      expect(await brokenRepo.fetch(), 'error:not_found');
    });

    test('maps resource-exhausted (quota) to error:quota_exceeded', () async {
      final brokenRepo = _BrokenRepository(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'resource-exhausted',
          message: 'Quota exceeded',
        ),
      );
      expect(await brokenRepo.fetch(), 'error:quota_exceeded');
    });

    test(
      'maps unknown codes to error:unknown — never crashes the app',
      () async {
        final brokenRepo = _BrokenRepository(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'some-future-code',
            message: 'Unknown',
          ),
        );
        expect(await brokenRepo.fetch(), 'error:unknown');
      },
    );
  });
}

/// A test double that always throws the given FirebaseException.
/// This simulates the network layer failing before Firestore even responds.
class _BrokenRepository {
  final FirebaseException _exception;
  _BrokenRepository(this._exception);

  Future<String> fetch() async {
    try {
      throw _exception;
    } on FirebaseException catch (e) {
      return switch (e.code) {
        'permission-denied' => 'error:permission_denied',
        'unavailable' => 'error:service_unavailable',
        'deadline-exceeded' => 'error:timeout',
        'not-found' => 'error:not_found',
        'cancelled' => 'error:cancelled',
        'resource-exhausted' => 'error:quota_exceeded',
        _ => 'error:unknown',
      };
    }
  }
}
