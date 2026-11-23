# P1-4 STEP 4 — card 5 (branches and its subcollections)

Two commits, split as the owner directed: machinery first, rules second.

## 5a — machinery only (`315e486c`)

The registry gained nested rows (`branches/menu_overrides`, `branches/config`,
`branches/waitlist_meta`, `notifications/items`) plus literal rows, the generator
classifies paths by their **segments** instead of their indentation, and the
probe seeds two-level paths (parent document first, then the child).

**A real completeness hole surfaced while doing it.** The old parser keyed rows
on four-space `match` lines, and these two blocks are SIBLINGS at four spaces:

    match /notifications/{userId} { ... }
    match /notifications/{userId}/items/{itemId} { ... }

so both collapsed onto the single row `notifications` — gate (i) reported
completeness over a rule path it had never seen. The same classifier then found
three literal settings documents (`settings/restaurantConfig`, `settings/taxRates`,
`settings/defaultOperatingHours`) that had been folded into `settings`. Both
classes now have rows: 19 top-level collections became **28 top-level + 7 nested
= 35 rule paths**. Literal rows carry no placeholder and seed nothing, because a
seeded `settings/<random>` is denied for having no matching rule — a false proof.

Gates on 5a alone: (i) PASS (35 paths, 19 ACTIVE), (j) PASS 21.3 s.

## 5b — rules (`this commit`)

- `branches`: `allow read: if true` → `tenantOk()`; `allow write … isOwner()` split
  into `create, update: tenantOkCreate()` and `delete: tenantOk()`.
- `branches/menu_overrides`, `branches/config`: same read conversion, owner writes
  split the same way; `waitlist_meta` gained `tenantOk()` on read and
  `tenantOkCreate()` on its join/serve writes.
- `notifications/items` needed no rule change — it was scoped with its parent —
  so its row is the first to flip ACTIVE without a rules edit, which is exactly
  what a registry that describes rule paths (not collections) should allow.

Gates on 5b: (d) PASS 7.7 s, (j) PASS 22.8 s. **24 of 35 paths ACTIVE**, 11
PENDING: `admins`, `audit_log`, `audit_logs`, `deliveries`, `orders`,
`proof_of_delivery`, `reservations`, `settings`, and the three literal settings
documents.

## Next

Card 6: `orders`/`reservations` (D-039). It needs the create-allow assertion the
current suite does not have, plus the payload/shape-lock change in one commit.

## 6b — sized, attempted, reverted (tree restored to `1ec91000`)

The owner ruled the **ID token claim** as the tenant source. The implementation
touches five layers at once:

1. a cached claim accessor behind a provider (new file);
2. `buildOfflineOrderPayload` gains `tenantId` and the checkout enqueue reads it;
3. `firestore.rules` **and** `staging.firestore.rules` gain `tenantOk()`/
   `tenantOkCreate()` and `'tenantId'` inside the orders create allowlist;
4. `order_create_payload_contract_test.dart` (reads both rule files off disk);
5. `test/rules/firestore_rules_test.js` — 78 call sites share one customer
   identity and 65 references touch `orders/...`; every Admin-SDK seeded order
   also needs `tenantId` or `tenantOk()` denies reads that must succeed.

Attempting 1–4 without 5 is a red tree, and giving `authedApp` a global tenant
claim flips expectations for **every** already-tenanted collection at once, so a
failure would not be attributable to the case that caused it. That is the same
reasoning as D-037, one layer up. Reverted rather than half-landed; nothing of
6b is committed.

**Correction to the plan this paragraph first carried:** a 6b-1/6b-2 split
cannot work. Adding `tenantId` to a harness fixture while the create allowlist
still omits the key is a DENY, so the harness cannot be prepared ahead of the
rule — rules, `staging.firestore.rules`, the payload, the Dart contract test and
the JS harness must land in **one** commit, proven by (d), (j) and (b).

The open question for that commit is the blast radius of a **global** tenant
claim in `authedApp`: it would give every already-tenanted collection's cases a
tenant at once. Run (d) with the global claim first; if unrelated cases move,
scope the claim to the orders cases with `options.tenantId` instead.
