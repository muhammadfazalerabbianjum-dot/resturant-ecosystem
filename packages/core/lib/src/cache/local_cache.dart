/// P2-1a (D-050) — the local-cache seam.
///
/// WHY this file exists at all: `AuthRepository` used to call
/// `IsarService.shared().clearAll()` directly on sign-out, which made the auth
/// repository — and therefore everything that imports it — unbuildable on the
/// web (`isar_community` declares no web platform; measured in
/// `checkpoints/P2-00.md`). The sign-out obligation is still real: the P0-07
/// cross-user leak is prevented by wiping the previous user's cached rows
/// before the next sign-in.
///
/// So the OBLIGATION stays and the IMPLEMENTATION moves behind this interface.
/// This file deliberately imports nothing: an implementer may be Isar (mobile),
/// nothing at all (the thin web shell), or a future store.
library;

/// Local, device-side cache that a signed-in session depends on.
///
/// Construction is **required**, never defaulted (the same ruling P1-4 7f
/// applied to `TenantClaimReader`): a construction site that forgets to state
/// its cache must fail to compile rather than silently skip the wipe.
abstract class LocalCache {
  /// Removes every cached row belonging to the signing-out user.
  ///
  /// Must be safe to call when nothing is cached (idempotent), because sign-out
  /// happens on fresh installs too.
  Future<void> clearAll();
}

/// A cache that stores nothing, and therefore has nothing to clear.
///
/// **Only correct for surfaces that never cache.** The thin shell (P2-1a) holds
/// no local rows, so there is nothing to leak; a surface that starts caching
/// must implement [LocalCache] over its own store rather than reuse this.
class NoOpLocalCache implements LocalCache {
  const NoOpLocalCache();

  @override
  Future<void> clearAll() async {}
}
