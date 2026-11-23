import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart'
    show LoggerService, firestoreProvider, loggerProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/location_model.dart';

/// B4-4: the `locations` list is a bounded, curated set — the cap exists to
/// protect the map/UI from pathological data, not to be a hidden business rule.
const int kLocationQueryLimit = 50;

final locationRepositoryProvider = Provider.autoDispose<LocationRepository>((
  ref,
) {
  return LocationRepository(
    ref.watch(firestoreProvider),
    ref.read(loggerProvider),
  );
});

final locationsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(locationRepositoryProvider).getLocations();
});

class LocationRepository {
  final FirebaseFirestore _firestore;
  final LoggerService _logger;

  LocationRepository(this._firestore, this._logger);

  Future<List<LocationModel>> getLocations() async {
    try {
      final snapshot = await _firestore
          .collection('locations')
          .limit(kLocationQueryLimit)
          .get();
      return snapshot.docs.map((doc) {
        return LocationModel.fromDoc(
          doc,
          onMissingField: (field, id) {
            // B4-4: honest, traced warning — a missing display field is a setup
            // gap, not something to paper over with a fabricated label.
            unawaited(
              _logger.warn(
                StateError('locations/$id missing "$field"'),
                'LocationRepository.getLocations missing field',
              ),
            );
          },
        );
      }).toList();
    } catch (e, stack) {
      await _logger.error(e, 'getLocations failed', stack: stack);
      rethrow;
    }
  }
}
