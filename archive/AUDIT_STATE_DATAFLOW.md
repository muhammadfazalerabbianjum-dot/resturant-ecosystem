# CARNAMA LABS — STATE MANAGEMENT, PROVIDERS & DATA FLOW AUDIT PROMPT

**Spec date:** 2026-08-31 · The authoritative prompt to verify EVERY Riverpod provider, stream
subscription, lifecycle hook, and state transition in the Carnama Labs template (`core_app`) and
domain package (`packages/core`).

**Source of truth = the CURRENT codebase.** This prompt performs NO code changes.

---

## 0. HARD GATES — any violation fails the audit

1. **Truth over documents.** Done ONLY when code proves it.
2. **No stubs / fake success / AI slop.** "Provider exists" must mean it is CORRECTLY disposed,
   correctly scoped, and correctly consumed.
3. **No hallucination.** Every claim cites `file:line` of CURRENT source.
4. **Completeness.** Every provider, every stream, every listener, every setState. Exhaustive.
5. **No escapes.** No skipping, no sampling.
6. **Production-grade or not at all.** A leaked stream subscription, an unguarded setState after
   await, or a provider holding stale tenant data is a FINDING.

---

## 1. SCOPE

### 1.1 Provider Inventory & Correctness

**Files to audit:**
- EVERY file defining a Riverpod provider (grep `Provider(`, `FutureProvider(`, `StreamProvider(`,
  `StateNotifierProvider(`, `ChangeNotifierProvider(`, `NotifierProvider(`, `family`)
- `core_app/lib/features/cart/presentation/cart_provider.dart`
- `core_app/lib/features/orders/presentation/order_provider.dart`
- `core_app/lib/features/menu/presentation/merged_menu_provider.dart`
- `packages/core/lib/src/**` (all providers in the domain package)

**Verify:**
- [ ] Full provider inventory table: name, type, file:line, scope (autoDispose?), consumers
- [ ] Every provider holding per-tenant data (cart, orders, menu) is INVALIDATED on:
  (a) logout, (b) login, (c) clientId change — grep for `invalidate(` at auth transitions
- [ ] `autoDispose` used where appropriate (screen-scoped providers); long-lived providers justified
- [ ] No provider performs side effects (writes to Firestore) inside its build/read — side effects
  belong in Notifier methods or services
- [ ] `family` providers: are params from untrusted input? (user-controlled keys = unbounded cache)
- [ ] Error states: every FutureProvider/AsyncValue consumer handles error + loading — grep
  `.when(` and check for missing `error:` branches (or `.valueOrNull` misuse)

### 1.2 Stream Subscription Hygiene

**Files to audit:**
- EVERY file with `.snapshots(`, `.listen(`, `StreamSubscription`, `ref.listen`, `WidgetsBinding
  .instance.addObserver`

**Verify:**
- [ ] Every `StreamSubscription` is stored in a field and `cancel()`ed in `dispose()`
- [ ] Every `ref.listen` in a ConsumerState is closed/cancelled on dispose
- [ ] Firestore `.snapshots()` listeners: cancelled when screen pops (or document why kept alive)
- [ ] No `.listen(` without an assignment to a cancellable subscription
- [ ] Timer/periodic (`Timer(`, `Timer.periodic`) — cancelled in dispose
- [ ] Animation controllers — disposed; TickerProviderStateMixin count matches controller count
- [ ] `WidgetsBindingObserver` — `didChangeAppLifecycleState` handlers registered exactly once,
  never duplicated on re-entry

### 1.3 setState / mounted Discipline

**Files to audit:**
- EVERY `StatefulWidget` in `core_app/lib` and `packages/core/lib` (grep `setState(`, `mounted`)

**Verify:**
- [ ] Every `setState` after an `await` is guarded by `if (!mounted) return;` — list EVERY
  unguarded instance (known: owner_dashboard.dart:390-397 from UI wiring audit — find the rest)
- [ ] No setState called from provider callbacks after the widget may have unmounted
- [ ] `context.mounted` used across async gaps when navigating (`Navigator.of(context)` after await)
- [ ] `dispose()` nulls out controllers it owns (TextEditingController, ScrollController, FocusNode,
  PageController, AnimationController) — every field disposed exactly once

### 1.4 Data Flow Integrity (backend → provider → UI)

**Files to audit:**
- `core_app/lib/features/orders/**` (order lifecycle state machine)
- `core_app/lib/features/cart/**`
- `packages/core/lib/src/models/**` (model deserialization defensiveness)
- `packages/core/lib/src/firestore/**` (paths, converters)

**Verify:**
- [ ] Order state machine: legal transitions only (placed → accepted → preparing → ready →
  delivered/cancelled). Extract the transition table from code; flag illegal transitions.
- [ ] Deserialization: every model `fromJson` handles missing/null fields defensively (no `!`
  force-unwrap on nullable JSON keys) — every `data['x']!` is a FINDING with impact
- [ ] Model defaults match server defaults (tax-inclusive vs exclusive, cents vs dollars)
- [ ] Currency: all money fields are INTEGER minor units (cents) end-to-end — flag any double
  arithmetic on money
- [ ] Duplicate prevention: order submission carries a client-generated idempotency key so retry
  after timeout cannot double-charge
- [ ] Optimistic updates: which updates are optimistic? What is the rollback path on failure?
- [ ] Race conditions: two devices mutating the same order (kitchen + customer app) — is
  Firestore `.runTransaction(` used where required? List every transaction AND every
  read-modify-write done without one (each is a FINDING)

---

## 2. DELIVERABLE

Write findings to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` (same format as other audit prompts:
Verdict + P0/P1/P2 counts → per-item PASS/FAIL with file:line → issue table → fix plan → honest
limitations). The provider inventory table and stream-subscription table MUST be complete.

**Report ONLY. No code changes. No fixes.**

---

## 3. PROMPT SELF-CHECK before submission

- [ ] Provider inventory covers 100% of providers in both core_app and packages/core?
- [ ] Every setState-after-await instance listed (file:line), guarded or not?
- [ ] Every stream subscription listed with its cancel site (or flagged as leak)?
- [ ] Order transition table extracted from code, not from docs?
- [ ] No runtime claim without a test reference?

---

## DELIVERABLE — MASTER REPORT APPEND (mandatory, in this order)

1. APPEND to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` under "Consolidated Findings" the
   canonical block defined there — including the **Proven Best-Fit Solution table**: for EVERY
   P0/P1, enumerate ≥2 candidate fixes, evaluate each against THIS codebase (conventions, DI,
   existing helpers, white-label impact), declare the winner with file:line evidence that rules out
   the alternatives, and state the regression risk + guard. A fix is "best" only when proven.
2. Flip your row in the master's "Audit Prompt Index" (⬜ NOT RUN → ✅ DONE — PASS/FAIL) and in the
   "Master Verdict" table.
3. Keep detailed evidence in your per-domain report file; the master gets the consolidated block.
4. No library additions unless an equivalent pattern already exists in the codebase.

**Report ONLY. No code changes. No fixes.**

---

**END OF PROMPT — Begin audit when instructed. Do not start without explicit user command.**