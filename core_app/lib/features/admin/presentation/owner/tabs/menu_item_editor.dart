import 'package:cached_network_image/cached_network_image.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/menu_item_model.dart';
import 'package:labs/features/menu/domain/dietary_codes.dart';
import 'package:labs/features/menu/presentation/widgets/dietary_badges.dart';
import 'package:labs/l10n/app_localizations.dart';

class MenuItemEditor extends ConsumerStatefulWidget {
  final MenuItemModel? existing;
  const MenuItemEditor({super.key, this.existing});

  @override
  ConsumerState<MenuItemEditor> createState() => _MenuItemEditorState();
}

/// A small section caption inside the editor sheet (the sheet owns the title).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

class _MenuItemEditorState extends ConsumerState<MenuItemEditor> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _price = TextEditingController(
    text: ((widget.existing?.priceCents ?? 0) / 100).toString(),
  );
  late final _desc = TextEditingController(text: widget.existing?.description);
  late final _imageUrl = TextEditingController(text: widget.existing?.imageUrl);
  late final _tags = TextEditingController(
    text: widget.existing?.tags.join(', '),
  );
  late final _notes = TextEditingController(
    text: widget.existing?.allergenNotes,
  );
  late final _halalBody = TextEditingController(
    text: widget.existing?.halalCertBody,
  );

  // P6-1 (D-052): codes, never free text.
  late final Set<String> _allergens = {...?widget.existing?.allergens};
  late final Set<String> _dietary = {...?widget.existing?.dietary};
  bool _halalCertified = false;
  DateTime? _halalExpiry;
  bool _isAvailable = true;
  bool _saving = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _isAvailable = widget.existing?.isAvailable ?? true;
    _halalCertified = widget.existing?.halalCertified ?? false;
    _halalExpiry = widget.existing?.halalCertExpiresAt?.toLocal();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _desc.dispose();
    _imageUrl.dispose();
    _tags.dispose();
    _notes.dispose();
    _halalBody.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    if (_uploadingImage) return;
    setState(() => _uploadingImage = true);
    try {
      final url = await CloudinaryUploadService.pickAndUploadImage();
      if (url != null && mounted) {
        setState(() => _imageUrl.text = url);
      }
    } catch (e, stack) {
      final logger = ref.read(loggerProvider);
      await logger.error(e, 'image_upload_failed', stack: stack);
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.imageUploadFailed)));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // D-051: the claim is an OWNER assertion, so a manager's save never
      // carries the three claim keys at all. Omitting them (rather than
      // sending false) leaves an existing certification untouched — a manager
      // correcting a price must not silently revoke it.
      final isOwner =
          ref.read(currentUserProvider).valueOrNull?.role == UserRole.owner;
      final data = {
        'name': _name.text.trim(),
        'priceCents': ((double.tryParse(_price.text.trim()) ?? 0.0) * 100)
            .round(),
        'description': _desc.text.trim(),
        'imageUrl': _imageUrl.text.trim(),
        'modifiers': widget.existing?.modifiers ?? [],
        'isAvailable': _isAvailable,
        'tags': _tags.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        // Sorted so the stored document is stable: an unstable array makes
        // every save look like a change to the audit trail.
        'allergens': _allergens.toList()..sort(),
        'dietary': _dietary.toList()..sort(),
        'allergenNotes': _notes.text.trim(),
        if (isOwner) ...{
          'halalCertified': _halalCertified,
          'halalCertBody': _halalCertified ? _halalBody.text.trim() : '',
          'halalCertExpiresAt': _halalCertified ? _halalExpiry?.toUtc() : null,
        },
        // Creation only: the customer home's global-menu query is
        // `where('branchId', isNull: true)`, which matches ONLY an explicit
        // null — an absent field never matches (verified live, 2026-10-06).
        // Rules C-3 make branchId immutable on update, so the key must be
        // written now or the item stays invisible to customers forever.
        if (widget.existing == null) 'branchId': null,
      };
      await ref
          .read(adminDataServiceProvider)
          .saveMenuItem(data, existingId: widget.existing?.id);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _isOwner(BuildContext context) =>
      ref.read(currentUserProvider).valueOrNull?.role == UserRole.owner;

  Future<void> _pickHalalExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _halalExpiry ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null && mounted) {
      setState(() => _halalExpiry = picked);
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
      // P6-1 added the dietary/allergen controls, which took the sheet past a
      // 600 px viewport (measured: 348 px overflow). A form that cannot be
      // scrolled cannot be completed, so the body scrolls and the sheet keeps
      // sizing to its content.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            BrandTextField(controller: _name, labelText: loc.name),
            BrandTextField(
              controller: _price,
              keyboardType: TextInputType.number,
              labelText: loc.price,
            ),
            BrandTextField(controller: _desc, labelText: loc.description),
            const SizedBox(height: 12),
            if (_imageUrl.text.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: _imageUrl.text,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // E1 F3-09: the image loading preview is the library skeleton.
                  placeholder: (_, __) =>
                      SkeletonLoader.block(width: double.infinity, height: 140),
                  errorWidget: (_, __, ___) => Container(
                    height: 140,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined, size: 40),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _uploadingImage ? null : _pickAndUploadImage,
              icon: _uploadingImage
                  // E1 F3-09: the library busy indicator in the icon slot.
                  ? const SkeletonLoader(width: 18, height: 18, borderRadius: 9)
                  : Icon(
                      _imageUrl.text.isEmpty
                          ? Icons.add_photo_alternate
                          : Icons.photo,
                    ),
              label: Text(
                _imageUrl.text.isEmpty ? loc.uploadImage : loc.changeImage,
              ),
            ),
            const SizedBox(height: 12),
            BrandTextField(
              controller: _tags,
              labelText: loc.tagsCommaSeparated,
            ),
            const SizedBox(height: 8),
            _SectionLabel(text: loc.dietaryLabel),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final code in kDietaryCodes)
                  FilterChip(
                    label: Text(dietaryLabelOf(loc, code)),
                    selected: _dietary.contains(code),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _dietary.add(code);
                      } else {
                        _dietary.remove(code);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionLabel(text: loc.allergensLabel),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final code in kAllergenCodes)
                  FilterChip(
                    label: Text(allergenLabelOf(loc, code)),
                    selected: _allergens.contains(code),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _allergens.add(code);
                      } else {
                        _allergens.remove(code);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            BrandTextField(
              controller: _notes,
              labelText: loc.dietaryNotesLabel,
            ),
            if (_isOwner(context)) ...[
              const Divider(),
              _SectionLabel(text: loc.halalCertificationSection),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(loc.halalCertified),
                value: _halalCertified,
                onChanged: (v) => setState(() => _halalCertified = v),
              ),
              if (_halalCertified) ...[
                BrandTextField(
                  controller: _halalBody,
                  labelText: loc.halalCertBodyLabel,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.halalCertExpiryLabel),
                  subtitle: Text(
                    _halalExpiry == null
                        ? '-'
                        : MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(_halalExpiry!),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.event_outlined),
                    onPressed: _pickHalalExpiry,
                  ),
                ),
                // An expired date is not an error to hide: the claim simply stops
                // rendering for customers, and the owner is told why.
                if (_halalExpiry != null &&
                    !_halalExpiry!.isAfter(DateTime.now()))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      loc.halalClaimExpired,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ],
            SwitchListTile(
              title: Text(loc.available),
              value: _isAvailable,
              onChanged: (v) => setState(() => _isAvailable = v),
            ),
            const SizedBox(height: 8),
            // E1: the save affordance is BrandButton's own loading state —
            // no hand-rolled spinner, no raw FilledButton.
            BrandButton(
              text: loc.save,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
