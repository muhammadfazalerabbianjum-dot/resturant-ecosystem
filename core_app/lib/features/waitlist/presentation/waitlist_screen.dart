import 'package:flutter/material.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/app/config/feature_flag_gate.dart';
import 'package:labs/features/waitlist/data/waitlist_repository.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';

class WaitlistScreen extends ConsumerStatefulWidget {
  const WaitlistScreen({super.key});

  @override
  ConsumerState<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends ConsumerState<WaitlistScreen> {
  int _partySize = 2;
  bool _joining = false;

  /// The branch this screen is bound to. Null means no branch is resolvable —
  /// joining fails closed with a clear message instead of a fake success
  /// under a made-up branch id (B4-2).
  String? get _branchId =>
      resolveEffectiveBranchId(ref, ref.read(loggerProvider));

  Future<void> _join() async {
    if (_joining) return;
    setState(() {
      _joining = true;
    });
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw Exception('Not signed in');
      final branchId = _branchId;
      if (branchId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).waitlistJoinFailed),
            ),
          );
        }
        return;
      }
      // B4-8/B4-9: the repository now returns the REAL result of the join —
      // joined / alreadyJoined / full / error — and assigns a per-branch
      // monotonic order in the same transaction. Double-taps cannot duplicate
      // (deterministic key) and re-joins are no longer fake successes.
      final result = await ref
          .read(waitlistRepositoryProvider)
          .joinWaitlist(
            branchId: branchId,
            userId: userId,
            partySize: _partySize,
          );
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      final message = switch (result) {
        WaitlistJoinResult.joined => loc.waitlistSuccess,
        WaitlistJoinResult.alreadyJoined => loc.alreadyOnWaitlist,
        WaitlistJoinResult.full => loc.waitlistFull,
        WaitlistJoinResult.error => loc.waitlistJoinFailed,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FirebaseExceptionMapper.map(e))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final branchId = ref.watch(currentBranchIdProvider) ?? _branchId;
    // B4-8 → PERF-9 T-2: the position is the take-a-ticket ordinal —
    // `position = myTicket − nowServing − 1` people ahead, computed locally
    // from two READABLE docs (own guest doc + branches/{bid}/waitlist_meta).
    // The old list-query path is DENIED by the rules for customers once 2+
    // users are queued (B-2) and was removed. The display shows the 1-based
    // line number: ordinal = peopleAhead + 1.
    final positionAsync = branchId != null && userId != null
        ? ref.watch(
            waitlistPositionProvider((branchId: branchId, userId: userId)),
          )
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(loc.waitlist)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        // UI-10 D2 / L12.3: the surface enters through the shared stagger.
        child: StaggeredEntrance(
          children: [
            Semantics(
              label: loc.waitlist,
              header: true,
              child: SectionHeader(title: loc.waitlist),
            ),
            Gap.v16,
            if (positionAsync != null)
              positionAsync.when(
                // UI-10 D1: the live ordinal is a StatTile metric. The value is
                // the SAME localized string the text row rendered (L14).
                data: (position) => position >= 0
                    ? Semantics(
                        label: loc.youAreNumberInLine('${position + 1}'),
                        child: StatTile(
                          icon: Icons.confirmation_number_outlined,
                          label: loc.youreInLine,
                          value: loc.youAreNumberInLine('${position + 1}'),
                        ),
                      )
                    // -1 == not on the list: render nothing, never a fake rank.
                    : const SizedBox.shrink(),
                // The ordinal is a local read of two docs; both non-data states
                // stay intentionally inert (L5 fail-safe) — a shimmer here would
                // leave the live-queue suite's pumpAndSettle non-terminating.
                loading: () => const SizedBox.shrink(),
                error: (e, stack) => const SizedBox.shrink(),
              )
            else
              const SizedBox.shrink(),
            Gap.v16,
            Semantics(
              label: loc.partySizeSelector,
              child: BrandCard(
                child: Column(
                  children: [
                    Text(
                      loc.partySizeSelector,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Gap.v8,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _partySize > 1
                              ? () => setState(() => _partySize--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '$_partySize',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        IconButton(
                          onPressed: _partySize < 12
                              ? () => setState(() => _partySize++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Gap.v24,
            // P37 T-2: joining the waitlist is gated by `waitlist`.
            FlagGate(
              flag: 'waitlist',
              child: Semantics(
                label: loc.joinWaitlist,
                button: true,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _joining ? null : _join,
                    child: Text(_joining ? loc.joining : loc.joinWaitlist),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
