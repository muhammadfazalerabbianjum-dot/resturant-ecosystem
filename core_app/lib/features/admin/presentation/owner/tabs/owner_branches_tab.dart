import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/branch_model.dart';
import 'package:labs/features/admin/presentation/owner/tabs/branch_editor.dart';
import 'package:labs/features/admin/presentation/owner/tabs/confirm_destructive_dialog.dart';
import 'package:labs/l10n/app_localizations.dart';

class OwnerBranchesTab extends ConsumerWidget {
  const OwnerBranchesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final adminService = ref.read(adminDataServiceProvider);
    final stream = adminService.streamBranches();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.branches),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: loc.addBranch,
            onPressed: () => _showBranchEditor(context, null, ref),
          ),
        ],
      ),
      body: StreamBuilder<List<BranchModel>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(
              child: SkeletonLoader.block(width: double.infinity, height: 64),
            );
          }
          final branches = snap.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: branches.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final b = branches[i];
              // E1 F3-10: management rows are the library SettingTile.
              return SettingTile(
                icon: Icons.storefront_outlined,
                title: b.name,
                subtitle: b.address,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (b.isDefault)
                      Chip(
                        label: Text(loc.defaultBranch),
                        backgroundColor: BrandColors.of(context).success,
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: loc.editBranch,
                      onPressed: () => _showBranchEditor(context, b, ref),
                    ),
                    IconButton(
                      tooltip: loc.deleteBranch,
                      icon: Icon(
                        Icons.delete,
                        color: BrandColors.of(context).error,
                      ),
                      onPressed: () async {
                        final ok = await confirmDestructive(
                          context,
                          loc.deleteBranchTitle,
                          loc.deleteBranchConfirm,
                        );
                        if (ok != true || !context.mounted) return;
                        await _deleteBranch(context, b.id, ref);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showBranchEditor(
    BuildContext context,
    BranchModel? existing,
    WidgetRef ref,
  ) {
    final loc = AppLocalizations.of(context);
    // E1 F3-13: the raw sheet becomes the library BrandSheet. E-DEC
    // (moneyConfirming: false) — branch geography is not a money confirmation,
    // so the barrier stays dismissable exactly as it is today (L14).
    BrandSheet.show(
      context,
      barrierDismissible: true,
      builder: (_) => BrandSheet(
        title: existing == null ? loc.addBranch : loc.editBranch,
        child: BranchEditor(existing: existing),
      ),
    );
  }

  Future<void> _deleteBranch(
    BuildContext context,
    String branchId,
    WidgetRef ref,
  ) async {
    final loc = AppLocalizations.of(context);
    final adminService = ref.read(adminDataServiceProvider);
    final canDelete = await adminService.deleteBranch(branchId);
    if (!context.mounted) return;
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.cannotDeleteBranchWithPendingOrders)),
      );
    }
  }
}
