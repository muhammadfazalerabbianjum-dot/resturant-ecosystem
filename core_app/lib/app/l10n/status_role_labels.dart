import 'package:core/core.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/l10n/app_localizations.dart';

/// Localized display labels for [OrderStatus] and [UserRole] (W9.2,
/// 05-P1-L10N-STRINGS): enum `.name` identifiers must never reach the UI —
/// in the Arabic locale they would render as raw English identifiers
/// (`confirmed`, `pickedUp`, `owner`). These exhaustive switches fail to
/// compile when a new enum value lacks a translation, so the map can never
/// silently fall back to `.name`.
String orderStatusLabel(AppLocalizations loc, OrderStatus status) =>
    switch (status) {
      OrderStatus.pending => loc.orderStatus_pending,
      OrderStatus.confirmed => loc.orderStatus_confirmed,
      OrderStatus.preparing => loc.orderStatus_preparing,
      OrderStatus.cooking => loc.orderStatus_cooking,
      OrderStatus.ready => loc.orderStatus_ready,
      OrderStatus.pickedUp => loc.orderStatus_pickedUp,
      OrderStatus.delivered => loc.orderStatus_delivered,
      OrderStatus.cancelled => loc.orderStatus_cancelled,
    };

String userRoleLabel(AppLocalizations loc, UserRole role) => switch (role) {
  UserRole.owner => loc.roleOwner,
  UserRole.manager => loc.roleManager,
  UserRole.kitchen => loc.roleKitchen,
  UserRole.delivery => loc.roleDelivery,
  UserRole.customer => loc.roleCustomer,
};
