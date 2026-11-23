import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart'
    show UserRole, firestoreProvider, FirebaseExceptionMapper;
import 'package:core_ui/core_ui.dart';
import 'package:labs/features/reservations/domain/reservation_model.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';
import 'package:url_launcher/url_launcher.dart';

/// Presentation-only seating status for a booking badge (UI-10 D1).
///
/// Reads ONLY the booking's start time — no state machine, no listener, no
/// timer is involved (L16). The three states are the real ones an operator
/// cares about while the tab shows the live window (bookings from the last
/// hour onward):
///
/// * [TileStatus.failed]  — the seat time has already passed,
/// * [TileStatus.pending] — the guest is arriving (within the next half hour),
/// * [TileStatus.ok]      — the booking is comfortably ahead.
TileStatus reservationStatusFor(DateTime startTime, {required DateTime now}) {
  final untilStart = startTime.difference(now);
  if (untilStart.isNegative) return TileStatus.failed;
  if (untilStart <= const Duration(minutes: 30)) return TileStatus.pending;
  return TileStatus.ok;
}

/// Default stream factory for reservations – can be overridden in tests.
Stream<QuerySnapshot<Map<String, dynamic>>> defaultReservationsStream(
  FirebaseFirestore firestore,
) {
  final now = DateTime.now();
  final localAnchor = DateTime.utc(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  );
  return firestore
      .collection('reservations')
      .orderBy('startTime', descending: false)
      .where(
        'startTime',
        isGreaterThan: Timestamp.fromDate(
          localAnchor.subtract(const Duration(hours: 1)),
        ),
      )
      // B4-4: the date-window filter already bounds the result set; the old
      // `.limit(50)` silently truncated busy days. No magic cap.
      .snapshots();
}

/// W8.5 (04-P1-STREAM): the DEFAULT (production) data path is ONE provider
/// subscription that survives widget rebuilds — the Firestore stream is no
/// longer constructed inside `build()`. The
/// [AdminReservationsTab.reservationsStream] constructor seam stays for
/// tests/overrides (a build-built stream there is a test-only path).
final reservationsProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
      return defaultReservationsStream(ref.watch(firestoreProvider));
    });

/// Shown inside Owner and Manager dashboards to view and manage incoming reservations.
class AdminReservationsTab extends ConsumerWidget {
  /// Optional stream override for testing. Defaults to [defaultReservationsStream].
  final Stream<QuerySnapshot<Map<String, dynamic>>>? reservationsStream;

  const AdminReservationsTab({super.key, this.reservationsStream});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoleGate(
      allowedRoles: const {UserRole.owner, UserRole.manager},
      builder: (_) => _buildTab(context, ref),
    );
  }

  Widget _buildTab(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    // W8.5: the production data path watches the provider (single
    // subscription, rebuild-safe). The injected-stream seam (tests/dashboard
    // overrides) keeps its legacy StreamBuilder plumbing so those callers
    // never require a live Firebase instance.
    if (reservationsStream != null) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: reservationsStream,
        builder: (context, snapshot) {
          return _renderReservations(
            context,
            loc: loc,
            theme: theme,
            waiting: snapshot.connectionState == ConnectionState.waiting,
            errorText: snapshot.hasError
                ? '${loc.error}: ${snapshot.error}'
                : null,
            docs: snapshot.data?.docs ?? const [],
          );
        },
      );
    }

    final resAsync = ref.watch(reservationsProvider);
    return resAsync.when(
      loading: () => _renderReservations(
        context,
        loc: loc,
        theme: theme,
        waiting: true,
        docs: const [],
      ),
      // W8.5 fail-visible: production stream errors surface through the
      // repo's mapper instead of the empty state.
      error: (e, _) => _renderReservations(
        context,
        loc: loc,
        theme: theme,
        waiting: false,
        errorText: FirebaseExceptionMapper.map(e),
        docs: const [],
      ),
      data: (snap) => _renderReservations(
        context,
        loc: loc,
        theme: theme,
        waiting: false,
        docs: snap.docs,
      ),
    );
  }

  Widget _renderReservations(
    BuildContext context, {
    required AppLocalizations loc,
    required ThemeData theme,
    required bool waiting,
    String? errorText,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  }) {
    if (waiting) {
      // L12: the loading preview is the tile-skeleton set (UI-10 D2), matching
      // the wireframe footprint of the card list below.
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TileSkeletons.menu(),
            Gap.v8,
            TileSkeletons.menu(),
            Gap.v8,
            TileSkeletons.menu(),
          ],
        ),
      );
    }

    if (errorText != null) {
      return Center(child: Text(errorText));
    }

    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            Gap.v16,
            Text(
              loc.noUpcomingReservations,
              style: TextStyle(
                fontSize: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      separatorBuilder: (_, __) => Gap.v8,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = Map<String, dynamic>.from(
          doc.data() as Map<dynamic, dynamic>,
        );
        data['id'] = doc.id;
        // Normalise Timestamp to ISO-8601 string for json_serializable
        final ts = data['startTime'];
        if (ts is Timestamp) {
          data['startTime'] = ts.toDate().toIso8601String();
        }
        final reservation = ReservationModel.fromJson(data);

        final localeCode = Localizations.localeOf(context).toString();
        // The DATE only — the seat TIME now lives in the seating badge below,
        // which keeps the row inside a 360dp card at every text scale (a
        // date+time string overflowed the legacy row by 107px in the golden
        // harness before this split).
        final formattedDate = DateFormat(
          'EEE, MMM d',
          // B4-5: format in the ACTIVE app locale so non-English
          // operators read dates in their own language.
          localeCode,
        ).format(reservation.startTime.toLocal());
        // UI-10 D1: the badge carries the SEATING TIME with the seating state
        // as its tone — the derived status is presentation-only (L16).
        final seatingTime = loc.reservationTime(
          DateFormat(
            'h:mm a',
            localeCode,
          ).format(reservation.startTime.toLocal()),
        );
        final seatingStatus = reservationStatusFor(
          reservation.startTime,
          now: DateTime.now(),
        );

        return BrandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date badge — E1 F3-15: BrandCard supplies the token-radius
                  // shell, so no raw decorated Container remains.
                  BrandCard(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat(
                              'd',
                              Localizations.localeOf(context).toString(),
                            ).format(reservation.startTime.toLocal()),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            DateFormat(
                              'MMM',
                              Localizations.localeOf(context).toString(),
                            ).format(reservation.startTime.toLocal()),
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Gap.h16,

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reservation.customerName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Gap.v(4),
                        Row(
                          children: [
                            Icon(
                              Icons.event,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            Gap.h(4),
                            // Flexible: a long localized weekday/month at 3x text
                            // scale ellipsizes instead of overflowing the row.
                            Expanded(
                              child: Text(
                                formattedDate,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Gap.v(4),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            Gap.h(4),
                            Expanded(
                              child: Text(
                                loc.guestsCount(
                                  reservation.partySize.toString(),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (reservation.notes != null) ...[
                          Gap.v(6),
                          Text(
                            loc.reservationNotes(reservation.notes!),
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Call button
                  if (reservation.customerPhone.isNotEmpty &&
                      reservation.customerPhone != '—')
                    IconButton(
                      tooltip: loc.callCustomer(reservation.customerName),
                      icon: Icon(Icons.phone, color: theme.colorScheme.primary),
                      onPressed: () async {
                        final uri = Uri(
                          scheme: 'tel',
                          path: reservation.customerPhone,
                        );
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                    ),
                ],
              ),
              Gap.v(12),
              // UI-10 D1: the seating state as a StatusTile badge — tone from the
              // frozen tri-state table, label localized. It spans the card width so
              // a long localized time can never overflow a narrow card.
              StatusTile(status: seatingStatus, label: seatingTime),
            ],
          ),
        );
      },
    );
  }
}
