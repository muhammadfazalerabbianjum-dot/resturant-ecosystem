# P6-1 — items 1–3 progress: the halal claim is owner-only (rules slice)

Session: 2026-11-13 · Branch `cline/p32-golden-gates` · card `docs/queue-P6.md`
P6-1 · decisions D-051 (claim authority), D-052 (vocabulary).

This checkpoint covers **the rules slice plus the vocabulary research**. The
model fields, the editor controls, the customer badges and the l10n keys are
**not done** — see §6.

---

## 1. RED — the harness proved the hole before anything was fixed

`core_app/test/rules/firestore_rules_test.js` gained five cases, fixtures seeded
with `withSecurityRulesDisabled` so each case measures the write lane rather than
fixture setup:

| Case | Assertion |
| --- | --- |
| p61-T1 | manager sets `dietary` on an own-branch item → ALLOW |
| p61-T2 | **manager** sets `halalCertified` → DENY |
| p61-T3 | **owner** sets `halalCertified` (+ body, expiry) → ALLOW |
| p61-T4 | manager sets `allergenNotes` → ALLOW |
| p61-T5 | customer sets `dietary` → DENY |

Run against the **unchanged** rules:

```
  ✅ p61-T1: manager sets dietary → ALLOW
  ❌ p61-T2: manager sets halalCertified → DENY — Expected request to fail, but it succeeded.
  ✅ p61-T3: owner sets halalCertified → ALLOW
  ✅ p61-T4: manager sets allergenNotes → ALLOW
  ✅ p61-T5: customer sets dietary → DENY
rules-harness: 169 passed, 57 failed, 56 in baseline, 1 new.
```

The failure is the point of the card: a branch manager could make a halal claim.
T1/T3/T4 passing in the same run is what stops the later rule from "passing" by
denying everything.

## 2. GREEN — one condition on each write path

`core_app/firestore.rules` (`menus` create and update) gained:

```
(!request.resource.data.diff(resource.data).affectedKeys()
   .hasAny(['halalCertified', 'halalCertBody', 'halalCertExpiresAt']) ||
 isOwner())
```

and on create the equivalent `keys().hasAny(...) || isOwner()`. Dietary facts and
`allergenNotes` are deliberately untouched: they stay on the existing lane
(owner, or manager scoped to their own branch).

```
  ✅ p61-T1 … p61-T5: all ALLOW/DENY as specified
rules-harness: 170 passed, 56 failed, 56 in baseline, 0 new.
```

## 3. Gates

`node tool/gate.mjs check --only=d,j,k` — receipt
`checkpoints/gate-20261113T135423Z.md`:

| Gate | Result |
| --- | --- |
| d emulator-rules | PASS 52.9 s |
| j tenant-isolation-emulator | PASS 133.4 s |
| k rules-harness | PASS 36.2 s |

Baseline unchanged at 56 known failures and **0 new**, so the five new cases did
not displace anything. No new collection was added, so the generator stays in
sync and the `menus` isolation row is untouched.

## 4. Vocabulary — research changed the list before it shipped

`docs/RESEARCH-DRAFT-dietary-regulatory.md` was filled in from CFIA and Health
Canada pages (five government sources agreeing). Two errors in the earlier
proposal were corrected while nothing was stored:

1. `cereals_gluten` conflated **wheat** (a priority allergen) with **gluten**
   (a declaration covering barley, oats, rye, triticale, wheat). They are now two
   codes: `wheat_triticale` and `gluten`.
2. `celery` and `lupin` were EU obligations and are **removed** — Canada does not
   list them.

Final: **13 declaration codes** (12 allergen groups + gluten) and **6 dietary
codes**; full text in `docs/DIETARY-VOCABULARY.md`, amended decision D-052.

Also established: the federal declaration duty applies to **prepackaged** food,
not to food served in a restaurant. This feature is voluntary trust, so the badge
copy is a declaration by the restaurant, never a safety guarantee. Confidence
high on the federal scope, medium on "no province requires a printed menu
statement" (sampled, not surveyed).

## 5. What this does NOT prove

- **No client is protected yet.** The rules restrict the *fields*, but no model,
  editor or badge exists, so nothing writes them and nothing shows them. The
  card's customer-facing acceptance items (4–6) are unmet.
- **No model round-trip.** `MenuItemModel` (both projections) still has no such
  fields; adding them requires `freezed` regeneration, which is the repo's known
  risk area (`core_app/pubspec.yaml` D-P34-1 note: the generator toolchain is
  pinned off). That is the next step and it is not started.
- **No l10n.** The 13 + 6 label keys do not exist in `app_en.arb`/`app_ar.arb`, so
  the parity gate has nothing to check yet.
- **Rules-only enforcement.** A direct Admin-SDK write (console, backfill) can
  still set a claim. That is true of every rule in the repo and is not a hole
  this card introduces, but it is stated rather than implied.

## 6. State of the card

| Acceptance item | Status |
| --- | --- |
| 1 model round-trip + legacy docs | NOT STARTED (needs codegen) |
| 2 one pinned vocabulary | doc fixed; constant + pin NOT STARTED |
| 3 rules both directions | **DONE** — RED then GREEN above |
| 4 badges + expired-claim case | NOT STARTED |
| 5 filter (3 chips + 13-code sheet) | NOT STARTED |
| 6 l10n en+ar | NOT STARTED |
| 7 no money movement | holds so far — no payment/ledger file touched |
| 8 tenancy unchanged | holds — no new collection, gates (i)/(j) clean |
