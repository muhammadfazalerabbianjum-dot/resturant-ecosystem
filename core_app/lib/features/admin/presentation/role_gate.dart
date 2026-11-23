import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/l10n/app_localizations.dart';

/// W2.9 / 01-P2-1 — defense-in-depth role gate.
///
/// Renders [builder] only when the signed-in user's role is in [allowedRoles];
/// otherwise renders [NoPermissionRedirect]. Firestore Security Rules remain
/// the authoritative access control; this only removes wrong-role screen
/// chrome for users who reach a gated surface by URL/direct navigation.
class RoleGate extends ConsumerWidget {
  const RoleGate({
    super.key,
    required this.allowedRoles,
    required this.builder,
  });

  /// Roles allowed to see the gated surface.
  final Set<UserRole> allowedRoles;

  /// Builds the gated surface once the signed-in role is authorized.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => Scaffold(
        // E1 F3-09: the library loading preview replaces the raw spinner.
        body: Center(
          child: SkeletonLoader.block(width: double.infinity, height: 64),
        ),
      ),
      error: (_, _) => const Scaffold(
        body: Center(child: Text('Unable to verify role. Please try again.')),
      ),
      data: (user) {
        final role = user?.role ?? UserRole.customer;
        if (!allowedRoles.contains(role)) {
          return const NoPermissionRedirect();
        }
        return builder(context);
      },
    );
  }
}

/// Shared no-permission redirect (extracted from the former
/// `_NoPermissionRedirect` in `role_router_screen.dart`): shows a brief
/// permission SnackBar and navigates to home. Renders a progress scaffold so
/// the transition never flashes a blank frame.
class NoPermissionRedirect extends StatefulWidget {
  const NoPermissionRedirect({super.key});

  @override
  State<NoPermissionRedirect> createState() => _NoPermissionRedirectState();
}

class _NoPermissionRedirectState extends State<NoPermissionRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).noAdminPermission)),
      );
      context.goNamed(RouteNames.home);
    });
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).noAdminPermission,
    // E1 F3-09: progress scaffold = the library loading preview.
    child: Scaffold(
      body: Center(
        child: SkeletonLoader.block(width: double.infinity, height: 64),
      ),
    ),
  );
}
