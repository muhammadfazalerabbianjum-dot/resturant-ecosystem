import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// Reads `settings/featureFlags` from Firestore — admin-edited via
/// TierFlagManagerScreen. TRUTH since p37 T-2 (D-P37-1 branch A): consumed by
/// FlagGate (`app/config/feature_flag_gate.dart:26-32`), which gates six
/// production controls (smartReorder, waitlist, promoCode, deliveryTracking,
/// loyaltyPoints, tourMode — see the WIRED-BY `features.flags` row in
/// `test/tool/config_key_disposition_test.dart`). The config-file surface
/// (`AppConfig.featureEnabled`) stays inert — p33 T-1, D-P33-1 default.
/// Pin: `test/config/flag_surface_truth_test.dart`.
class FeatureFlagsService {
  static const _defaultFlags = {
    'smartReorder': true,
    'loyaltyPoints': true,
    'tourMode': true,
    'waitlist': true,
    // D-2 (register row F3-05): `referrals` was removed from the default set
    // by UI-13 (p21) — an unknown flag resolves fail-closed to `false`.
    'deliveryTracking': true,
    'promoCode': true,
  };

  final Map<String, dynamic> _flags;
  FeatureFlagsService(this._flags);

  /// The full raw flag map (for admin editing). Unmodifiable to prevent
  /// accidental mutation of the source-of-truth snapshot.
  Map<String, dynamic> get flags => Map.unmodifiable(_flags);

  bool isEnabled(String flag) =>
      _flags[flag] as bool? ?? _defaultFlags[flag] ?? false;
}

final featureFlagsProvider = StreamProvider<FeatureFlagsService>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('settings')
      .doc('featureFlags')
      .snapshots()
      .map((snap) => FeatureFlagsService(snap.data() ?? {}));
});
