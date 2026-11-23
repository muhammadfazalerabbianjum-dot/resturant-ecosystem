# BATCH 3 — DI HYGIENE + DEAD CODE + SUPPRESSIONS + DEMO COLLECTIONS · Major/Minor (no P0)

**Pre-read `IMPLEMENTATION_PROMPT.md`** FIRST.

## PROBLEM
| # | Evidence (current source) | Issue |
|---|---|---|
| P1 | `core_app/lib/app/config/restaurant_config_service.dart:8,17,25` | `FirebaseFirestore.instance` used directly (bypasses `firestoreProvider` DI + testability). Grep gate `FirebaseFirestore.instance` in feature code = 3. |
| P2 | `order_model.dart:44`, `packages/core/lib/src/auth/user_model.dart:29`, `packages/core/lib/src/presence/presence_model.dart:15` | Three hand-written `// ignore: invalid_annotation_target`. Gate `// ignore` in hand-written files = 0 expected. |
| P3 | `order_repository.dart:86-125` | `submitOrderAtomically` referenced ONLY by itself + tests (`test/idempotency_test.dart`, `chaos_checkout_test.dart`); sends flat `order.toJson()` (payload mismatch → would fail `createOrder`). Dead path, worse: a misleading decoy. |
| P4 | `cloud_function_mocks.dart:169,187,195,248` | Demo writes `notification_queue`, `notifications`, `audit_logs` — collections with NO rules match. |

## SOLUTION
1. **DI.** Add `restaurantConfigRepositoryProvider` (or make the existing functions providers)
   that take `FirebaseFirestore` from `ref.watch(firestoreProvider)`. Move stream/save/patch to
   a class; update ALL callers (grep-verify). Delete the top-level direct-instance functions or
   keep only provider-wrapped ones.
2. **Remove the 3 hand-written `// ignore`.** Restructure so the annotations are unnecessary
   (move freezed annotation targets; use explicit `@JsonKey`/casts) — or, if genuinely required
   by code-gen, record an owner-approved exception with file:line and a line-scoped suppression
   that keeps the file gate honest. Gate bar: 0 `// ignore` in hand-written files after this
   batch (generated `.freezed/.g` excluded).
3. **`submitOrderAtomically`:** verify with grep it is `only-self-reference = dead`. If dead:
   DELETE it and its dedicated tests, replacing with a real test via
   `CheckoutService.createOrder` payload contract (the production path). If kept (owner
   decision): align payload to the callable contract `{paymentIntentId, order, userId,
   idempotencyKey}` and add a behavior test.
4. **Demo collection rules** (extend the B0 suite):
   - `match /notifications/{userId}` + `/notifications/{userId}/items/{id}`: read/write self-only;
     items subcollection mirror.
   - `match /notification_queue/{id}`: owner/manager read; write `if false` (server + demo mock
     already write; demo writes must be owner-gated) — record decision.
   - `match /audit_logs/{id}`: `allow read: if isOwner(); allow write: if false;`
   - Extend the T-E tests in the B0 rules suite for these three: deny anon, deny non-owner
     write, owner read ok.

## TESTS
| Test | Asserts |
|---|---|
| T-D1 | `restaurantConfigRepository` reads/writes via injected fake DB (no `FirebaseFirestore.instance`) |
| T-D2 | `// ignore` grep in hand-written files = 0 (command + output recorded) |
| T-D3 | dead `submitOrderAtomically` gone OR rewritten to callable contract + behavior test proving payload shape |
| T-D4 | rules suite: notifications self-read ok / other denied; audit_logs owner read ok / write denied; notification_queue owner-only |

## GATES (must ALL pass)
- [ ] `Select-String -Recurse -Path core_app/lib -Pattern 'FirebaseFirestore.instance'` → 0 (feature scope).
- [ ] hand-written `// ignore` grep (generated excluded) → 0.
- [ ] `flutter test` (core_app + core/core_ui) → green (U-NOBREAK).
- [ ] RULES-EMUL still green incl. new T-D4 cases.
- [ ] Gate set U; B3 addendum appended.

## RESIDUALS (honest)
- If a `// ignore` is genuinely code-gen-required, record it as an owner-decision exception WITH
  a scoped lint suppression and keep the file-level gate intact; do not hide it.

**END OF BATCH 3.** Not closed until Gates green + addendum appended.