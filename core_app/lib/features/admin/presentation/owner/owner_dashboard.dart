import 'dart:ui';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/reservations/presentation/admin_reservations_tab.dart';
import 'package:labs/features/admin/presentation/analytics_snapshot.dart';
import 'package:labs/features/admin/presentation/setup/restaurant_setup_screen.dart';
import 'package:labs/features/admin/presentation/setup/tier_flag_manager_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';
import 'package:labs/features/admin/presentation/owner/tabs/owner_overview_tab.dart';
import 'package:labs/features/admin/presentation/owner/tabs/owner_orders_tab.dart';
import 'package:labs/features/admin/presentation/owner/tabs/owner_users_tab.dart';
import 'package:labs/features/admin/presentation/owner/tabs/owner_branches_tab.dart';
import 'package:labs/features/admin/presentation/owner/tabs/owner_menu_tab.dart';

class OwnerDashboard extends ConsumerStatefulWidget {
  const OwnerDashboard({super.key});

  @override
  ConsumerState<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends ConsumerState<OwnerDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return RoleGate(
      allowedRoles: const {UserRole.owner},
      builder: (_) => _buildDashboard(context),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final loc = AppLocalizations.of(context);

    // Check auth state reactively - no user means we cannot reach dashboard
    final authUser = ref.watch(authStateProvider).valueOrNull;
    if (authUser == null) {
      return Scaffold(
        body: EmptyStateWidget(
          icon: Icons.store_mall_directory_outlined,
          title: loc.ownerUnavailable,
          subtitle: loc.failedToAuthenticateOwner,
        ),
      );
    }

    final tabs = [
      const OverviewTab(),
      const OwnerOrdersTab(),
      const OwnerUsersTab(),
      const OwnerBranchesTab(),
      const OwnerMenuTab(),
      const AnalyticsSnapshot(),
      const TierFlagManagerScreen(),
      const AdminReservationsTab(),
      const RestaurantSetupScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: tabs[_selectedIndex],
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: NavigationBar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.8),
            elevation: 0,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard),
                label: loc.overview,
              ),
              NavigationDestination(
                icon: const Icon(Icons.receipt_long),
                label: loc.allOrders,
              ),
              NavigationDestination(
                icon: const Icon(Icons.people),
                label: loc.branchUsers,
              ),
              NavigationDestination(
                icon: const Icon(Icons.store),
                label: loc.branches,
              ),
              NavigationDestination(
                icon: const Icon(Icons.restaurant_menu),
                label: loc.globalMenu,
              ),
              NavigationDestination(
                icon: const Icon(Icons.bar_chart),
                label: loc.analytics,
              ),
              NavigationDestination(
                icon: const Icon(Icons.layers),
                label: loc.tiers,
              ),
              NavigationDestination(
                icon: const Icon(Icons.table_restaurant),
                label: loc.bookings,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings),
                label: loc.setup,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
