import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/branch_model.dart';
import 'package:labs/features/location/presentation/pin_drop_map_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

class BranchEditor extends ConsumerStatefulWidget {
  final BranchModel? existing;
  const BranchEditor({super.key, this.existing});

  @override
  ConsumerState<BranchEditor> createState() => _BranchEditorState();
}

class _BranchEditorState extends ConsumerState<BranchEditor> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _address = TextEditingController(text: widget.existing?.address);
  late final _lat = TextEditingController(
    text: widget.existing?.coordinates.latitude.toString(),
  );
  late final _lng = TextEditingController(
    text: widget.existing?.coordinates.longitude.toString(),
  );
  late final _radius = TextEditingController(
    text: widget.existing?.deliveryRadiusMiles.toString() ?? '5.0',
  );
  bool _isDefault = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isDefault = widget.existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final data = {
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'coordinates': GeoPoint(
          double.tryParse(_lat.text) ?? 0,
          double.tryParse(_lng.text) ?? 0,
        ),
        'deliveryRadiusMiles': double.tryParse(_radius.text) ?? 5.0,
        'isDefault': _isDefault,
        'isActive': true,
      };
      await ref
          .read(adminDataServiceProvider)
          .saveBranch(data, existingId: widget.existing?.id);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    // E1: the BrandSheet chrome owns title + outer padding; the editor keeps
    // only the keyboard inset.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          BrandTextField(controller: _name, labelText: loc.name),
          BrandTextField(controller: _address, labelText: loc.address),
          Row(
            children: [
              Expanded(
                child: BrandTextField(
                  controller: _lat,
                  keyboardType: TextInputType.number,
                  labelText: loc.latitude,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BrandTextField(
                  controller: _lng,
                  keyboardType: TextInputType.number,
                  labelText: loc.longitude,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.pin_drop),
                tooltip: loc.pickOnMap,
                onPressed: () async {
                  final result = await Navigator.push<DeliveryLocationModel>(
                    context,
                    MaterialPageRoute(builder: (_) => const PinDropMapScreen()),
                  );
                  if (result != null) {
                    setState(() {
                      _lat.text = result.latitude.toStringAsFixed(6);
                      _lng.text = result.longitude.toStringAsFixed(6);
                      if (result.address.isNotEmpty) {
                        _address.text = result.address;
                      }
                    });
                  }
                },
              ),
            ],
          ),
          BrandTextField(
            controller: _radius,
            keyboardType: TextInputType.number,
            labelText: loc.deliveryRadiusMiles,
          ),
          SwitchListTile(
            title: Text(loc.defaultBranch),
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
          ),
          const SizedBox(height: 8),
          // E1: the save affordance is BrandButton's own loading state —
          // no hand-rolled spinner, no raw FilledButton.
          BrandButton(
            text: loc.saveBranch,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
