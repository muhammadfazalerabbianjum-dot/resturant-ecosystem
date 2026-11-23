import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/l10n/app_localizations.dart';
import '../data/reservations_repository.dart';
import '../domain/reservation_model.dart';
import '../../../app/tenancy/tenant_claim.dart';

final reservationsRepositoryProvider =
    Provider.autoDispose<ReservationsRepository>((ref) {
      return ReservationsRepository(
        ref.watch(firestoreProvider),
        ref.read(loggerProvider),
      );
    });

/// Resolves the branch capacity from Firestore `branches/{id}`.
/// Falls back to a safe default when the branch doc is missing or unreadable.
///
/// The capacity fallback is intentionally conservative (50) so the
/// reservation flow still works offline — but it is now LOGGED with the
/// reason and the returned value so silent capacity surprises are traceable
/// (B4-2).
Future<int> _resolveBranchCapacity(
  FirebaseFirestore firestore,
  String branchId,
  LoggerService logger,
) async {
  const int offlineFallbackCapacity = 50; // OFFLINE_FALLBACK
  try {
    final doc = await firestore.collection('branches').doc(branchId).get();
    if (!doc.exists) {
      await logger.warn(
        StateError('branches/$branchId missing'),
        'reservation capacity fallback used (missing branch doc)',
      );
      return offlineFallbackCapacity;
    }
    final capacity = (doc.data()?['capacity'] as num?)?.toInt();
    if (capacity == null) {
      await logger.warn(
        StateError('branches/$branchId has no "capacity" field'),
        'reservation capacity fallback used (missing capacity field)',
      );
    }
    return capacity ?? offlineFallbackCapacity;
  } catch (e, stack) {
    await logger.warn(
      e,
      'reservation capacity fallback used for branches/$branchId',
      stack: stack,
    );
    return offlineFallbackCapacity;
  }
}

/// Resolves the branch id for a reservation.
///
/// B4-2: a branch id must NEVER be a hardcoded string literal in a screen.
/// Order of resolution:
///  1. [currentBranchIdProvider] (the real, user-selected/auto-detected branch)
///  2. the client config's declared default branch id
///     ([AppConfig.defaultBranchId], NOT `'main'`/`'default'`)
///  3. null when neither is set — the caller fails closed instead of
///     silently writing a reservation under a made-up branch id.
String? _resolveBranchId(WidgetRef ref, LoggerService logger) {
  final current = ref.read(currentBranchIdProvider);
  if (current != null) return current;
  final configuredDefault = AppConfig.defaultBranchId;
  if (configuredDefault.isNotEmpty) {
    unawaited(
      logger.warn(
        StateError(
          'currentBranchIdProvider was null; using configured default branch '
          '"$configuredDefault"',
        ),
        'reservation branch fallback used',
      ),
    );
    return configuredDefault;
  }
  return null;
}

class ReservationScreen extends ConsumerStatefulWidget {
  const ReservationScreen({super.key, this.initialStartTime});

  /// Optional override for the form's initial date-time. Used by tests to
  /// exercise the past-time guard without driving the platform date picker.
  final DateTime? initialStartTime;

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _partySizeController = TextEditingController(text: '2');
  final _uuid = const Uuid();
  DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final seeded = widget.initialStartTime;
    if (seeded != null) {
      _startTime = seeded;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _partySizeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // P8(W3) re-entrancy fence: the disabled button alone cannot stop a
    // double-submit — two taps in the same frame both land before the
    // rebuild, and the party-size field's onFieldSubmitted calls _submit()
    // DIRECTLY, bypassing the disabled button. Each unfenced submit built a
    // fresh reservation id and called requestSlot concurrently (the slot
    // transaction still refuses the duplicate lock, but the customer gets a
    // misleading "no capacity" and the second write attempt is real work).
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    // M1: reject past datetimes before submitting.
    if (!_startTime.isAfter(DateTime.now())) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.reservationPastTime)));
      return;
    }

    setState(() => _submitting = true);

    final userId = ref.read(currentUserIdProvider) ?? '';
    final branchId = _resolveBranchId(ref, ref.read(loggerProvider));
    if (branchId == null) {
      // B4-2: never create a reservation under a made-up branch — fail closed
      //         with a clean, user-visible error when no branch can be resolved.
      //
      // PERF-7 review fix: this early return happens AFTER `_submitting = true`
      // set the button into its spinner state, so it MUST clear the flag — the
      // old code left the button permanently disabled/spinning after the
      // fail-closed error (the user could never retry).
      if (!mounted) return;
      setState(() => _submitting = false);
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.reservationRequiresBranch)));
      return;
    }
    final firestore = ref.read(firestoreProvider);
    final capacity = await _resolveBranchCapacity(
      firestore,
      branchId,
      ref.read(loggerProvider),
    );

    final reservation = ReservationModel(
      id: _uuid.v4(),
      userId: userId,
      branchId: branchId,
      customerName: _nameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      startTime: _startTime,
      partySize: int.tryParse(_partySizeController.text) ?? 1,
    );

    try {
      // D-039: the create rule compares `tenantId` to the caller's claim.
      final String? tenantId = await ref.read(tenantClaimProvider).read();
      if (!mounted) return;
      if (tenantId == null) {
        final AppLocalizations loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.error)));
        return;
      }
      final success = await ref
          .read(reservationsRepositoryProvider)
          .requestSlot(reservation, capacity, tenantId: tenantId);
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.reservationConfirmed)));
        context.pop();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.reservationNoCapacity)));
      }
    } catch (e, stack) {
      await ref
          .read(loggerProvider)
          .error(e, 'reservation_submit_failed', stack: stack);
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.reservationFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickTime() async {
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startTime.isAfter(now)
          ? _startTime
          : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time == null) return;

    final candidate = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    );

    // M1: reject a past time on today's date.
    if (!candidate.isAfter(now)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.reservationPastTime)));
      }
      return;
    }

    setState(() {
      _startTime = candidate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.reservations)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // UI-10 D2 / L12.3: the surface enters through the shared stagger.
        child: StaggeredEntrance(
          children: [
            Semantics(
              label: loc.reservations,
              header: true,
              child: SectionHeader(title: loc.reservations),
            ),
            Gap.v16,
            // UI-10 D2: the form sits on the token card (L12 surface + radius).
            BrandCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      // UX-2 (05-P2-UX-KEYBOARD): actionable keyboard.
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                      decoration: InputDecoration(
                        labelText: loc.reservationName,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? loc.reservationNameRequired
                          : null,
                    ),
                    Gap.v(12),
                    TextFormField(
                      controller: _phoneController,
                      // UX-2: phone autofill + actionable keyboard.
                      autofillHints: const [AutofillHints.telephoneNumber],
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                      decoration: InputDecoration(
                        labelText: loc.reservationPhone,
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? loc.reservationPhoneRequired
                          : null,
                    ),
                    Gap.v(12),
                    TextFormField(
                      controller: _partySizeController,
                      // UX-2: the keyboard's done key submits the reservation.
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: loc.reservationPartySize,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1 || n > 20) {
                          return loc.reservationPartySizeRange;
                        }
                        return null;
                      },
                    ),
                    Gap.v(12),
                    OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        loc.reservationTime(
                          DateFormat(
                            'yyyy-MM-dd HH:mm',
                            loc.localeName,
                          ).format(_startTime.toLocal()),
                        ),
                      ),
                    ),
                    Gap.v24,
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(loc.reservationNew),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
