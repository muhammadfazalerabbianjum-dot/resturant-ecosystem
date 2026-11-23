import 'package:labs/app/tenancy/tenant_claim.dart';

/// A [TenantClaimReader] that always answers with one tenant.
///
/// Shared so that a test constructing a tenant-scoped service does not have to
/// re-invent the fake — and, more importantly, so the tenant a test runs under
/// is visible at the call site instead of being an implicit fallback.
class FixedTenantClaim implements TenantClaimReader {
  const FixedTenantClaim([this.tenantId = 'tenant_a']);

  /// `null` models a signed-out / pre-claim caller.
  final String? tenantId;

  @override
  Future<String?> read({bool forceRefresh = false}) async => tenantId;
}
