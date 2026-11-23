import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads the tenant this client acts as from the ID token claim (D-035).
///
/// WHY the claim and not the config: `tenantOk()`/`tenantOkCreate()` compare a
/// write to `request.auth.token.tenantId`. A payload stamped from anything else
/// can disagree with the rules, and a disagreement is not a security hole but an
/// outage - every order create is denied.
abstract class TenantClaimReader {
  /// The caller's `tenantId` claim, or null when the token carries none.
  Future<String?> read({bool forceRefresh = false});
}

/// Firebase-backed reader, cached for the session.
class TenantClaim implements TenantClaimReader {
  TenantClaim(this._auth);

  final FirebaseAuth _auth;
  String? _cached;

  @override
  Future<String?> read({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached;
    final User? user = _auth.currentUser;
    if (user == null) return null;
    final IdTokenResult result = await user.getIdTokenResult(forceRefresh);
    final Object? value = result.claims?['tenantId'];
    if (value is String && value.trim().isNotEmpty) {
      _cached = value;
      return value;
    }
    return null;
  }

  void reset() => _cached = null;
}

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final tenantClaimProvider = Provider<TenantClaimReader>(
  (ref) => TenantClaim(ref.watch(firebaseAuthProvider)),
);

/// The caller's tenant, for providers that must await it before reading.
///
/// `TenantClaimReader.read()` is async and cached, so watching this future costs
/// one token read per session; `tenantClaimProvider` stays the sync seam.
final tenantIdProvider = FutureProvider<String?>(
  (ref) => ref.watch(tenantClaimProvider).read(),
);

/// The claim, or a [StateError] naming the caller (D-035 / D-057).
///
/// ONE implementation because the check has to fail identically everywhere. A
/// tenant-scoped Firestore list read with no tenant constraint is DENIED by
/// `tenantOk()` (rules are not filters — measured in P2-1a: constrained 200/2
/// rows, unconstrained 403), and a write with no claim has no correct target
/// document. Both failures must be loud: an empty board, or a document named
/// from a guess, is indistinguishable from a tenant that genuinely has no data.
String _tenantOrThrow(String? tenantId, String caller) {
  if (tenantId == null || tenantId.trim().isEmpty) {
    throw StateError('$caller needs a tenantId claim; this session has none');
  }
  return tenantId;
}

/// Resolves and caches the tenant a scoped read/write must carry.
///
/// Services hold one of these instead of a `TenantClaimReader?` field plus their
/// own copy of the null-check: the reader is created lazily (a service may be
/// constructed before Firebase is initialised in tests) and reused, so the token
/// is read once per session, not once per query.
class TenantScope {
  TenantScope([this._reader]);

  TenantClaimReader? _reader;

  /// The caller's tenant, or a [StateError] naming [caller].
  Future<String> require(String caller) async {
    final TenantClaimReader reader = _reader ??= TenantClaim(
      FirebaseAuth.instance,
    );
    return _tenantOrThrow(await reader.read(), caller);
  }
}

/// The same check for Riverpod callers, which read the claim through
/// [tenantIdProvider] rather than owning a reader.
Future<String> requireTenantIdFromRef(Ref ref, String caller) async =>
    _tenantOrThrow(await ref.watch(tenantIdProvider.future), caller);
