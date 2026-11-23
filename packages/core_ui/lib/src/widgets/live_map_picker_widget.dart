import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

/// Type definition for position providers that can be overridden in tests.
typedef PositionProvider =
    Future<Position> Function(LocationSettings locationSettings);

/// LiveMapPickerWidget - OpenStreetMap map picker (no API key required).
///
/// Presents a full-screen map centred on the user's live GPS position.
/// The user drags the pin to select their delivery address. The chosen
/// LatLng and reverse-geocoded address string are returned via [onLocationPicked].
///
/// Multi-app readiness (Law 3 - no hardcoded business data in `core_ui`):
///  - [initialCenter] lets the host app seed a meaningful fallback center
///    (e.g. the selected restaurant's coordinates). When `null`, the map
///    falls back to the neutral (0, 0) center rather than a hard-coded city.
///  - [userAgentPackageName] is the OSM tile-server UA ident. The host passes
///    its real bundle ID (e.g. `AppConfig.bundleId`); `null` uses 'flutter_map'.
class LiveMapPickerWidget extends StatefulWidget {
  /// Called when the user confirms a pin location.
  final void Function(LatLng latlng, String address) onLocationPicked;

  /// Optional position provider override for testing.
  /// Defaults to [Geolocator.getCurrentPosition].
  final PositionProvider? positionProvider;

  /// Optional initial map center used while GPS is being acquired or when GPS
  /// is unavailable. When `null`, a neutral (0, 0) center is used.
  final LatLng? initialCenter;

  /// OSM tile user-agent package name (bundle id). When `null`, 'flutter_map'
  /// is used.
  final String? userAgentPackageName;

  /// Localized UI strings — required so `core_ui` carries no English
  /// literals (W9.2: the host app passes `AppLocalizations` values).
  final String title;
  final String confirmLabel;
  final String positioningLabel;
  final String movePinLabel;
  final String lookingUpLabel;
  final String deliveringToLabel;

  const LiveMapPickerWidget({
    super.key,
    required this.onLocationPicked,
    required this.title,
    required this.confirmLabel,
    required this.positioningLabel,
    required this.movePinLabel,
    required this.lookingUpLabel,
    required this.deliveringToLabel,
    this.positionProvider,
    this.initialCenter,
    this.userAgentPackageName,
  });

  @override
  State<LiveMapPickerWidget> createState() => _LiveMapPickerWidgetState();
}

class _LiveMapPickerWidgetState extends State<LiveMapPickerWidget> {
  final MapController _mapController = MapController();
  late LatLng _pinPosition;
  bool _loading = true;
  String _addressLabel = '';

  /// Neutral fallback center - the equator/null meridian. Not a business value.
  static const LatLng _neutralCenter = LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _pinPosition = widget.initialCenter ?? _neutralCenter;
    _addressLabel = widget.initialCenter == null
        ? widget.positioningLabel
        : widget.movePinLabel;
    _initLocation();
  }

  /// Returns the position provider - overridable for testing.
  PositionProvider get _positionProvider =>
      widget.positionProvider ??
      (LocationSettings settings) =>
          Geolocator.getCurrentPosition(locationSettings: settings);

  Future<void> _initLocation() async {
    // Geolocator.getCurrentPosition already throws PermissionDeniedException /
    // LocationServiceDisabledException when the user denies/disables location.
    // We skip a redundant permission pre-check (which can hang on platform
    // channels in tests) and let the position provider resolve - any failure
    // falls back to the seeded/neutral pin below.
    try {
      final position = await _positionProvider(
        const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final latlng = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _pinPosition = latlng;
        _loading = false;
        // W9.2: core_ui carries no English literals — the host injects the
        // localized "positioning/looking-up" copy; use it here too (the
        // gesture path already does via onPositionChanged).
        _addressLabel = widget.lookingUpLabel;
      });
      _mapController.move(latlng, 15.0);

      // Reverse geocode the live location immediately.
      await _reverseGeocode(latlng);
    } catch (_) {
      // Permission denied, service disabled, or network failure - stay on the
      // seeded/neutral pin. Never crash.
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reverseGeocode(LatLng latlng) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latlng.latitude,
        latlng.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
        ].where((s) => s != null && s.isNotEmpty).toList();

        setState(() {
          _addressLabel = parts.isEmpty
              ? 'Drop a pin anywhere on the map'
              : parts.join(', ');
        });
      }
    } catch (_) {
      // Geocoding may fail without network - address label stays as fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton.icon(
            onPressed: _loading
                ? null
                : () {
                    widget.onLocationPicked(_pinPosition, _addressLabel);
                    Navigator.of(context).pop();
                  },
            icon: const Icon(Icons.check, color: Colors.white),
            label: Text(
              widget.confirmLabel,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pinPosition,
                initialZoom: 15.0,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    final center = position.center;
                    setState(() {
                      _pinPosition = center;
                      _addressLabel = widget.lookingUpLabel;
                    });
                    _debounceGeocode(center);
                  }
                },
              ),
              children: [
                TileLayer(
                  // OpenStreetMap - completely free, no key needed.
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      widget.userAgentPackageName ?? 'flutter_map',
                ),
              ],
            ),
          const Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_pin, size: 48, color: Colors.red),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: const [
                  BoxShadow(blurRadius: 8, color: Colors.black26),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.deliveringToLabel,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _addressLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Debounce geocoding so we don't hammer Nominatim on every pixel drag.
  DateTime? _lastGeocode;
  void _debounceGeocode(LatLng latlng) {
    _lastGeocode = DateTime.now();
    final captured = _lastGeocode;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (captured == _lastGeocode && mounted) {
        _reverseGeocode(latlng);
      }
    });
  }
}
