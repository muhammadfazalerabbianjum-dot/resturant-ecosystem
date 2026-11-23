import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/l10n/app_localizations.dart';

/// Admin gateway — role-verified access to the admin surface.
///
/// This is the staff landing page reached via `/admin-gateway`: there is NO
/// secret PIN / 20-tap entry. The security decision is made SERVER-SIDE by
/// Firestore Security Rules against the authenticated user's role. The client
/// only reads the role: staff roles (owner/manager/kitchen/delivery) are
/// routed to the role-aware dashboard; everyone else is denied.
class AdminGatewayScreen extends ConsumerWidget {
  const AdminGatewayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);

    return authState.when(
      // E1 F3-09: the library loading preview replaces the raw spinner.
      loading: () => Scaffold(
        body: Center(
          child: SkeletonLoader.block(width: double.infinity, height: 64),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(loc.adminGateway)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(loc.gatewayAuthError),
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.goNamed(RouteNames.login);
          });
          return Scaffold(
            body: Center(
              child: SkeletonLoader.block(width: double.infinity, height: 64),
            ),
          );
        }
        return _buildUserData(context, ref, loc, user);
      },
    );
  }

  Widget _buildUserData(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations loc,
    User user,
  ) {
    final userDataAsync = ref.watch(currentUserProvider);

    return userDataAsync.when(
      loading: () => Scaffold(
        body: Center(
          child: SkeletonLoader.block(width: double.infinity, height: 64),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(loc.adminGateway)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              loc.gatewayRoleVerificationFailed,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (userData) {
        final role = userData?.role ?? UserRole.customer;
        final isAdminRole = role.isBackOfficeRole;

        if (isAdminRole) {
          // Authorized — route to the role-aware dashboard.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.goNamed(RouteNames.roleRouter);
          });
          return Scaffold(
            body: Center(
              child: SkeletonLoader.block(width: double.infinity, height: 64),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(loc.adminGateway)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    loc.gatewayNoAdminAccess,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  BrandButton(
                    text: loc.backToHome,
                    onPressed: () => context.goNamed(RouteNames.home),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
