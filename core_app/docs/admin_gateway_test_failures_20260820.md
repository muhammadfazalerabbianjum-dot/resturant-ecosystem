# 🔴 Admin Gateway Test Failures — Root Cause Analysis

> **Date:** 2026-08-20 · **File:** `core_app/test/features/admin/admin_gateway_test.dart`
> **Status:** Pre-existing failures — **unrelated** to the Firestore rules changes.

---

## Summary

Two widget tests in `admin_gateway_test.dart` fail with `Found 0 widgets` errors. Both share the **same root cause**: the test's `GoRouter` is configured with `initialLocation: '/'` but the only registered route is `/admin-gateway`. Because `'/'` matches no route, `AdminGatewayScreen` is **never built**, so no `CircularProgressIndicator` or `"You do not have admin access."` text can ever be found.

---

## ❌ Test 1: `shows loading indicator when auth is loading` (line 19)

**Failure:**
```
Expected: exactly one matching candidate
Actual: _TypeWidgetFinder:<Found 0 widgets with type "CircularProgressIndicator": []>
```

**Root causes (in order of impact):**

1. **Routing mismatch (primary).** `GoRouter(initialLocation: '/')` does not match the registered `path: '/admin-gateway'`. The router renders a blank `404`-style screen, so `AdminGatewayScreen` (and its loading state) is never mounted.
2. **Empty stream completes immediately.** `Stream<User?>.empty()` emits a done event synchronously. Even with the correct route, the widget may transition through the loading state before the first `pump()` completes, so the `CircularProgressIndicator` is never observed. A `Completer<User?>`-backed stream (or `StreamController`) is needed to hold the loading state open.
3. **Missing `pumpAndSettle`/async pump.** After fixing the route, the test should use `await tester.pump()` (or `pumpAndSettle()`) after the stream emits to let the widget rebuild.

---

## ❌ Test 2: `shows admin access denied for customer role` (line 48)

**Failure:**
```
Expected: exactly one matching candidate
Actual: _TextWidgetFinder:<Found 0 widgets with text "You do not have admin access.": []>
```

**Root causes (in order of impact):**

1. **Routing mismatch (same as Test 1).** `initialLocation: '/'` does not match `/admin-gateway`, so `AdminGatewayScreen` is never built.
2. **No Firestore mock for role lookup.** Even with the correct route, `AdminGatewayScreen` reads the user's role from Firestore (via `userRole()`). No `FakeFirebaseFirestore` or provider override is provided, so the role can never resolve to `customer`. The test would need to seed a `users/{uid}` document with `role: 'customer'` (or override the role provider) for the "access denied" branch to render.
3. **`MockUser` lacks role metadata.** `MockUser(uid: 'owner1', email: 'owner@test.com')` only provides auth identity — it does not provide the Firestore role document the screen depends on.

---

## ✅ Recommended Fix (short Cline prompt)

> Fix the two failing widget tests in `core_app/test/features/admin/admin_gateway_test.dart`:
>
> 1. **Routing:** Change `GoRouter(initialLocation: '/')` to `initialLocation: '/admin-gateway'` so the widget under test is actually rendered.
> 2. **Test 1 (loading):** Replace `Stream<User?>.empty()` with a `StreamController<User?>` (or `Completer`-backed stream) so the loading state stays open; assert `CircularProgressIndicator` is shown; then close the controller in `tearDown`.
> 3. **Test 2 (customer denied):** Provide a `FakeFirebaseFirestore` (or override the role provider) seeded with `users/owner1 = { role: 'customer' }` so the screen resolves the role and renders `"You do not have admin access."`. Use `await tester.pumpAndSettle()` after the stream emits.
> 4. Run `flutter test test/features/admin/admin_gateway_test.dart` and confirm both tests pass.

---

## Impact on Firestore Rules Work

These two failures are **pre-existing** and **completely unrelated** to the `firestore.rules` changes. They are test-harness issues (routing + missing mocks), not security-rule regressions. The 25 emulator rules tests, `flutter analyze`, and the remaining 1,200+ unit/widget tests all pass.