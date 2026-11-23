import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/app/l10n/status_role_labels.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/l10n/app_localizations.dart';

class OwnerUsersTab extends ConsumerStatefulWidget {
  const OwnerUsersTab({super.key});
  @override
  ConsumerState<OwnerUsersTab> createState() => _OwnerUsersTabState();
}

class _OwnerUsersTabState extends ConsumerState<OwnerUsersTab> {
  final List<UserModel> _users = [];
  DocumentSnapshot? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final adminService = ref.read(adminDataServiceProvider);
    final page = await adminService.loadUsers(startAfter: _lastDoc);
    if (mounted) {
      setState(() {
        _loading = false;
        if (page.items.length < 20) _hasMore = false;
        if (page.items.isNotEmpty) {
          _lastDoc = page.lastDoc; // ← STORE cursor for next page
          _users.addAll(page.items);
        }
      });
    }
  }

  Future<void> _updateRole(String uid, UserRole role) async {
    final adminService = ref.read(adminDataServiceProvider);
    try {
      await adminService.updateUserRole(uid, role);
    } catch (e) {
      // W8.1(b): mapped snackbar + fire-and-forget log (mirrors
      // kitchen_dashboard._updateStatus) — never a silent failure.
      unawaited(
        ref.read(loggerProvider).error(e, 'updateUserRole failed for $uid'),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FirebaseExceptionMapper.map(e))));
      }
      return;
    }
    if (!mounted) return; // W8.1(a): guard the async gap
    // W8.1(c): refresh from Firestore — the manual UserModel mirror-edit is
    // gone (it dropped every field outside id/email/name/role/branchId).
    final fresh = await adminService.loadUser(uid);
    if (!mounted) return;
    setState(() {
      final idx = _users.indexWhere((u) => u.id == uid);
      if (idx != -1 && fresh != null) {
        _users[idx] = fresh;
      }
    });
  }

  Future<void> _showAssignBranchSheet(
    BuildContext context,
    UserModel user,
  ) async {
    final loc = AppLocalizations.of(context);
    final adminService = ref.read(adminDataServiceProvider);
    final branches = await adminService.loadBranches();
    if (branches.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.noBranchesFound)));
      }
      return;
    }
    String? selectedId = user.branchId;
    if (!context.mounted) return;
    // E1 F3-13: the raw sheet becomes the library BrandSheet (E-DEC
    // moneyConfirming: false — a branch assignment is not a money
    // confirmation; the barrier stays dismissable exactly as today, L14).
    await BrandSheet.show(
      context,
      barrierDismissible: true,
      builder: (ctx) => BrandSheet(
        title: loc.assignBranchFor(user.displayTitle),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: loc.branches,
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(loc.noBranchAssigned),
                  ),
                  ...branches.map(
                    (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ),
                ],
                onChanged: (v) => setModalState(() => selectedId = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await adminService.updateUserBranch(user.id, selectedId);
                    } catch (e) {
                      // W8.1(b): mapped snackbar + logged — never silent.
                      unawaited(
                        ref
                            .read(loggerProvider)
                            .error(e, 'updateUserBranch failed for ${user.id}'),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(FirebaseExceptionMapper.map(e)),
                          ),
                        );
                      }
                      return;
                    }
                    if (!mounted) return; // W8.1(a): guard the async gap
                    // W8.1(c): refresh from Firestore — the manual UserModel
                    // mirror-edit is gone (drifted from the server doc).
                    final fresh = await adminService.loadUser(user.id);
                    if (!mounted) return;
                    setState(() {
                      final idx = _users.indexWhere((u) => u.id == user.id);
                      if (idx != -1 && fresh != null) {
                        _users[idx] = fresh;
                      }
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(loc.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.allUsers)),
      body: ListView.separated(
        padding: const EdgeInsets.only(
          left: 12,
          top: 12,
          right: 12,
          bottom: 90,
        ),
        itemCount: _users.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == _users.length) {
            return Center(
              child: _loading
                  ? SkeletonLoader.block(width: 120, height: 40)
                  : TextButton(onPressed: _loadMore, child: Text(loc.loadMore)),
            );
          }
          final u = _users[i];
          final currentUser = ref.read(authStateProvider).value;
          final isMe = currentUser?.uid == u.id;
          // E1 F3-10: management rows are the library SettingTile (the
          // CircleAvatar monogram is superseded by the tile's leading icon).
          return SettingTile(
            icon: Icons.person_outline,
            title: u.displayTitle,
            subtitle: loc.roleBranchLine(
              userRoleLabel(loc, u.role),
              u.branchId ?? loc.noBranchAssigned,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.store_outlined),
                  tooltip: loc.assignBranch,
                  onPressed: isMe
                      ? null
                      : () => _showAssignBranchSheet(context, u),
                ),
                DropdownButton<UserRole>(
                  value: u.role,
                  items: UserRole.values
                      .where((r) => r != UserRole.owner || isMe)
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(userRoleLabel(loc, r)),
                        ),
                      )
                      .toList(),
                  onChanged: isMe
                      ? null
                      : (r) {
                          if (r != null) _updateRole(u.id, r);
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
