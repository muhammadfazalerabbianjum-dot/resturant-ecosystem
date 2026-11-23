/// P2-1a (D-050) — the Isar-backed [LocalCache].
///
/// Kept in its OWN file so that importing the seam
/// (`local_cache.dart`) never drags Isar into an import graph. `AuthRepository`
/// imports the seam; `app_bootstrap.dart` — which already runs on a platform
/// where Isar exists — imports this.
library;

import 'isar_service.dart';
import 'local_cache.dart';

/// The mobile cache: delegates to the process-wide [IsarService].
class IsarLocalCache implements LocalCache {
  const IsarLocalCache();

  @override
  Future<void> clearAll() => IsarService.shared().clearAll();
}
