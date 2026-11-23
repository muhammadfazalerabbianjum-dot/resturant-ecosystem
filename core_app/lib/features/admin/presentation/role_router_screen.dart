import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/admin/presentation/owner/owner_dashboard.dart';
import 'package:labs/features/admin/presentation/manager/manager_dashboard.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';
import 'package:labs/features/admin/presentation/delivery/delivery_dashboard.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/app/l10n/status_role_labels.dart';

class RoleRouterScreen extends ConsumerWidget {
  const RoleRouterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.goNamed(RouteNames.login);
      });
      return Semantics(
        label: loc.loadingUserRole,
        // E1 F3-09: the library loading preview replaces the raw spinner.
        child: Scaffold(
          body: Center(
            child: SkeletonLoader.block(width: double.infinity, height: 64),
          ),
        ),
      );
    }

    final userDataAsync = ref.watch(currentUserProvider);

    return userDataAsync.when(
      loading: () => Semantics(
        label: loc.loadingUserRole,
        child: Scaffold(
          body: Center(
            child: SkeletonLoader.block(width: double.infinity, height: 64),
          ),
        ),
      ),
      error: (e, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(loc.unableToVerifyRole)));
          context.goNamed(RouteNames.home);
        });
        return Semantics(
          label: loc.roleVerificationFailed,
          child: const Scaffold(body: SizedBox.shrink()),
        );
      },
      data: (userData) {
        if (userData == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(loc.unableToVerifyRole)));
            context.goNamed(RouteNames.home);
          });
          return Semantics(
            label: loc.roleVerificationFailed,
            child: const Scaffold(body: SizedBox.shrink()),
          );
        }

        final role = userData.role;

        return Semantics(
          label: loc.adminRoleLabel(userRoleLabel(loc, role)),
          child: switch (role) {
            UserRole.owner => const OwnerDashboard(),
            UserRole.manager => const ManagerDashboard(),
            UserRole.kitchen => const KitchenDashboard(),
            UserRole.delivery => const DeliveryDashboard(),
            UserRole.customer => const NoPermissionRedirect(),
          },
        );
      },
    );
  }
}
