// UI-13 (p21) phase E shared test scaffold — hermetic map tiles.
//
// `flutter_map`'s default `NetworkTileProvider` performs real network I/O under
// `flutter test` (the tile canvas is not hermetic), so every phase-E widget test
// and golden injects this provider: a valid in-memory 1x1 PNG, no socket.
//
// The private copy inside `pin_drop_map_screen_test.dart` is deliberately left
// untouched — that file's suite is green and out of this phase's edit scope
// (scope discipline); new phase-E files share this one instead.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// A 1x1 transparent PNG — a valid decode target with no network fetch.
final Uint8List kTransparentPngBytes = Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

/// Hermetic [TileProvider]: returns a valid in-memory image, no network I/O.
class NoNetworkTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(kTransparentPngBytes);
}
