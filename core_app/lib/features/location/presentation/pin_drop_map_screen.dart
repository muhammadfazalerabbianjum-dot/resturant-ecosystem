import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/l10n/app_localizations.dart';
import '../../locations/data/location_repository.dart';
import '../../locations/domain/location_model.dart';

class PinDropMapScreen extends ConsumerStatefulWidget {
  const PinDropMapScreen({super.key, this.tileProvider});

  /// Injectable tile provider (test seam, mirrors `AdminReservationsTab
  /// .reservationsStream`). Defaults to the real OSM [NetworkTileProvider] —
  /// tests inject a provider that returns images without network access.
  final TileProvider? tileProvider;

  /// Resolves the initial map center from the first Firestore `locations`
  /// document (runtime-editable, multi-app ready). Falls back to the neutral
  /// center when no location is configured yet. Pure & testable.
  static LatLng initialCenterFor(List<LocationModel> locations) {
    const neutral = LatLng(0, 0);
    if (locations.isEmpty) return neutral;
    final first = locations.first;
    if (first.lat == 0.0 && first.lng == 0.0) return neutral;
    return LatLng(first.lat, first.lng);
  }

  @override
  ConsumerState<PinDropMapScreen> createState() => _PinDropMapScreenState();
}

class _PinDropMapScreenState extends ConsumerState<PinDropMapScreen> {
  LatLng? _picked;
  final MapController _mapController = MapController();

  /// Neutral fallback center — the equator/null meridian. Not a business value.
  static const LatLng _neutralCenter = LatLng(0, 0);

  Future<void> _pickCurrentLocation() async {
    final loc = AppLocalizations.of(context);
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _picked = LatLng(pos.latitude, pos.longitude));
      _mapController.move(_picked!, 14);
    } catch (e, stack) {
      await ref
          .read(loggerProvider)
          .error(e, 'pin_drop_location_failed', stack: stack);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.couldNotGetLocation)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final locationsAsync = ref.watch(locationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(loc.selectLocation)),
      body: locationsAsync.when(
        // UI-13 (p21 H2, F3-09): while `locationsProvider` resolves, the map
        // body shows the library loading placeholder. Behaviour and error
        // handling are untouched — the `error`/`data` branches below are L31
        // (p21 §2: location flows stay exactly as they are).
        loading: () => Center(
          child: SkeletonLoader.block(
            width: 240,
            height: 180,
            borderRadius: 16,
          ),
        ),
        error: (e, stack) => _buildMap(_neutralCenter),
        data: (locations) =>
            _buildMap(PinDropMapScreen.initialCenterFor(locations)),
      ),
    );
  }

  Widget _buildMap(LatLng initialCenter) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // UI-13 (p21) phase E — brand chrome (InfoBanner hint + BrandButton CTA)
    // around the UNCHANGED map. L31: the `FlutterMap` surface, the tap→pin
    // flow, the Confirm pop contract, `_pickCurrentLocation`'s error handling
    // (awaited logger + localized SnackBar) and the `tileProvider` seam are all
    // byte-identical to pre-adoption; the library `LiveMapPickerWidget` stays
    // the separate checkout host rather than a second map implementation here.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: InfoBanner(
            tone: InfoTone.info,
            child: Text(loc.tapMapToSelect),
          ),
        ),
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 14,
              onTap: (tapPos, latLng) => setState(() => _picked = latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: AppConfig.bundleId,
                tileProvider: widget.tileProvider ?? NetworkTileProvider(),
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_pin,
                        color: theme.colorScheme.error,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: BrandButton(
            text: _picked == null ? loc.useMyLocation : loc.confirm,
            // L31: the same two callbacks as pre-adoption, unchanged.
            onPressed: _picked == null
                ? _pickCurrentLocation
                : () {
                    context.pop(
                      DeliveryLocationModel(
                        latitude: _picked!.latitude,
                        longitude: _picked!.longitude,
                      ),
                    );
                  },
          ),
        ),
      ],
    );
  }
}
