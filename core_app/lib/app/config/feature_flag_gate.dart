import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feature_flags_service.dart';

/// Hides [child] while the client feature flag [flag] is off.
///
/// WHY (p37 T-2, D-P37-1 = BRANCH A): the six Firestore feature flags were
/// documented but inert — each now gates a real production control. Resolution
/// is default-TRUE while the `settings/featureFlags` stream is loading or the
/// doc is absent, so shipped clients (flags on in `client_config.json`) and
/// every golden baseline render unchanged; an explicit `false` in that doc
/// removes the control on the next snapshot.
class FlagGate extends ConsumerWidget {
  const FlagGate({super.key, required this.flag, required this.child});

  /// The flag id (matches `settings/featureFlags` keys / `_defaultFlags`).
  final String flag;

  /// The control to remove from the tree when [flag] is off.
  final Widget child;

  /// Point-in-time resolution for non-widget sites (the onboarding tour push):
  /// the same default-TRUE rule as [build], via `read` so a one-shot check in
  /// an event handler never subscribes.
  static bool isEnabled(WidgetRef ref, String flag) =>
      ref.read(featureFlagsProvider).valueOrNull?.isEnabled(flag) ?? true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref.watch(featureFlagsProvider).valueOrNull?.isEnabled(flag) ?? true;
    if (!enabled) return const SizedBox.shrink();
    return child;
  }
}
