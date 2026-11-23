import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:labs/app/tenancy/tenant_settings.dart';

class OperatingHoursScreen extends ConsumerStatefulWidget {
  final String? branchId;
  final String? branchName;
  const OperatingHoursScreen({super.key, this.branchId, this.branchName});

  @override
  ConsumerState<OperatingHoursScreen> createState() =>
      _OperatingHoursScreenState();
}

class _OperatingHoursScreenState extends ConsumerState<OperatingHoursScreen> {
  OperatingHoursModel _hours = const OperatingHoursModel();
  bool _loading = true;
  bool _saving = false;

  /// D-038: the default week lives at
  /// `settings/${tenantId}_defaultOperatingHours`, so the tenant is needed before
  /// the reference can even be named. A branch override stays branch-scoped.
  Future<DocumentReference> _ref() async {
    // B5-5: Use DI Firestore — no direct static Firestore instance access
    final db = ref.read(firestoreProvider);
    if (widget.branchId != null) {
      return db
          .collection('branches')
          .doc(widget.branchId)
          .collection('config')
          .doc('operatingHours');
    }
    final String? tenantId = await ref.read(tenantClaimProvider).read();
    if (tenantId == null) {
      throw StateError(
        'cannot name the default hours without a tenantId claim',
      );
    }
    return db
        .collection('settings')
        .doc(settingsDocId(tenantId, 'defaultOperatingHours'));
  }

  @override
  void initState() {
    super.initState();
    // initState runs before the first build frame; use addPostFrameCallback
    // so ref is fully available when _load fires (ConsumerState pattern).
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final snap = await (await _ref()).get();
      if (snap.exists && mounted) {
        setState(() {
          _hours = OperatingHoursModel.fromMap(
            snap.data() as Map<String, dynamic>,
          );
        });
      }
    } catch (e, stack) {
      // B5-5: Use injected loggerProvider — no bare LoggerService()
      await ref
          .read(loggerProvider)
          .error(e, 'OperatingHoursScreen_load', stack: stack);
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${loc.failedToLoad}: ${FirebaseExceptionMapper.map(e)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await (await _ref()).set(_hours.toMap(), SetOptions(merge: true));
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.savedSuccessfully)));
      }
    } catch (e, stack) {
      // B5-5: DI logger
      await ref
          .read(loggerProvider)
          .error(e, 'OperatingHoursScreen_save', stack: stack);
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${loc.failedToSave}: ${FirebaseExceptionMapper.map(e)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Updates a single day's [DayHours] via the freezed copyWith.
  void _updateDay(String dayKey, DayHours Function(DayHours) update) {
    setState(() {
      _hours = switch (dayKey) {
        'Monday' => _hours.copyWith(monday: update(_hours.monday)),
        'Tuesday' => _hours.copyWith(tuesday: update(_hours.tuesday)),
        'Wednesday' => _hours.copyWith(wednesday: update(_hours.wednesday)),
        'Thursday' => _hours.copyWith(thursday: update(_hours.thursday)),
        'Friday' => _hours.copyWith(friday: update(_hours.friday)),
        'Saturday' => _hours.copyWith(saturday: update(_hours.saturday)),
        'Sunday' => _hours.copyWith(sunday: update(_hours.sunday)),
        _ => _hours,
      };
    });
  }

  Future<void> _pickTime(String dayKey, String field) async {
    final current = _hours.entries.firstWhere((e) => e.$1 == dayKey).$2;
    final initialTime = field == 'open'
        ? _parseTime(current.openTime)
        : _parseTime(current.closeTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null) return;
    _updateDay(
      dayKey,
      (d) => field == 'open'
          ? d.copyWith(openTime: _formatTime(picked))
          : d.copyWith(closeTime: _formatTime(picked)),
    );
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length == 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return RoleGate(
      allowedRoles: const {UserRole.owner},
      builder: (_) => _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.operatingHours)),
      body: _loading
          ? Semantics(
              label: loc.loadingOperatingHours,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: 7,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, __) =>
                    SkeletonLoader.block(width: double.infinity, height: 64),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionHeader(title: loc.operatingHours),
                const SizedBox(height: 16),
                ..._hours.entries.map((entry) {
                  final day = entry.$1;
                  final dayHours = entry.$2;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BrandCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                day,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: dayHours.isOpen,
                              onChanged: (v) =>
                                  _updateDay(day, (d) => d.copyWith(isOpen: v)),
                            ),
                            const SizedBox(width: 8),
                            if (dayHours.isOpen) ...[
                              Expanded(
                                child: TextButton(
                                  onPressed: () => _pickTime(day, 'open'),
                                  child: Text(dayHours.openTime),
                                ),
                              ),
                              const Text('–'),
                              Expanded(
                                child: TextButton(
                                  onPressed: () => _pickTime(day, 'close'),
                                  child: Text(dayHours.closeTime),
                                ),
                              ),
                            ] else
                              Expanded(
                                child: Text(
                                  loc.closed,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Semantics(
                  label: loc.saveOperatingHours,
                  button: true,
                  child: BrandButton(
                    text: _saving ? loc.saving : loc.save,
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ),
    );
  }
}
