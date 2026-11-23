import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/app/config/feature_flags_service.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';

/// Manages the runtime-editable feature flags stored in Firestore
/// `settings/featureFlags`. The owner toggles flags here and the change is
/// persisted immediately — no redeploy required (Law 27 / §0.3).
///
/// The canonical source of truth is `FeatureFlagsService` (reads
/// `settings/featureFlags`). This screen writes back to the same document so
/// the rest of the app picks up the change reactively via `featureFlagsProvider`.
class TierFlagManagerScreen extends ConsumerStatefulWidget {
  const TierFlagManagerScreen({super.key});

  @override
  ConsumerState<TierFlagManagerScreen> createState() =>
      _TierFlagManagerScreenState();
}

class _TierFlagManagerScreenState extends ConsumerState<TierFlagManagerScreen> {
  Map<String, dynamic> _flags = const {};
  bool _saving = false;
  bool _formPopulated = false;

  @override
  Widget build(BuildContext context) {
    return RoleGate(
      allowedRoles: const {UserRole.owner},
      builder: (_) => _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final flagsAsync = ref.watch(featureFlagsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(loc.tierFlagManager)),
      body: flagsAsync.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) =>
              SkeletonLoader.block(width: double.infinity, height: 56),
        ),
        error: (e, stack) {
          ref
              .read(loggerProvider)
              .error(e, 'tier_flags_load_failed', stack: stack);
          return Center(child: Text('${loc.error}: $e'));
        },
        data: (service) {
          // Populate the editor once from the Firestore source of truth.
          // Guarded by [_formPopulated] so a user's in-progress edits are
          // never clobbered by a provider re-emit (the local edit only hits
          // Firestore on Save).
          if (!_formPopulated) {
            _formPopulated = true;
            _flags = Map<String, dynamic>.from(service.flags);
          }
          if (_flags.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.flag_outlined,
              title: loc.noFeatureFlagsConfigured,
              subtitle: '',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ..._flags.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SettingTile(
                    icon: Icons.tune,
                    title: entry.key,
                    trailing: Switch.adaptive(
                      value: entry.value as bool? ?? false,
                      onChanged: (value) {
                        setState(() => _flags[entry.key] = value);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              BrandButton(
                text: loc.save,
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Persist to the canonical featureFlags document. The rest of the app
      // reacts via `featureFlagsProvider` — no redeploy needed.
      await ref
          .read(firestoreProvider)
          .collection('settings')
          .doc('featureFlags')
          .set(_flags, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).featureFlagsSaved)),
      );
    } catch (e, stack) {
      await ref
          .read(loggerProvider)
          .error(e, 'tier_flags_save_failed', stack: stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).saveFailedWithError(e.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
