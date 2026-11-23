# P2-1a pre-work — web-int hazard audit of the shared packages

Question: before the shell compiles `packages/core` / `packages/core_ui` for the
browser, which integer assumptions in shared code break under web semantics
(`int` is an IEEE double, exactly representable only up to 2^53, bitwise ops are
32-bit)?

Method: static sweep of `packages/core/lib`, `packages/core_ui/lib`,
`core_app/lib/app/config` (the shell's likely graph) for each hazard class, plus
the two target-specific probes recorded in `checkpoints/P2-00.md` §8. No source
change was made for this audit.

Date: 2026-11-13 · Branch `cline/p32-golden-gates`.

---

## Findings by class

### 1. Integer literals above 2^53 — REAL, and already contained

Sweep for `\b[0-9]{16,}\b` and `0x[0-9a-fA-F]{9,}`:

| Site | Status |
| --- | --- |
| `packages/core/lib/src/cache/isar_schemas.g.dart` (9 lines) | Native-only. Excluded from the shell by D-050's import allowlist; the file is generated for a database that has no web platform. |
| `packages/core_ui/lib/src/ui/money_text.dart:51` | Fixed by P2-1a item 2 (predicate pre-verified, P2-00 §8). |
| `core_app/lib/app/config/currency_format.dart:48` | Same. |
| everything else | **none** — no other literal ≥16 digits, and no hex literal above 32 bits, anywhere in the swept tree. |

**Detection is already correct and loud:** dart2js refuses to compile such a
literal with a named file:line. That is how P2-0 found the class. No new check is
needed for it — but note the corollary: a *runtime* value above 2^53 is silently
rounded instead, so this class is only loud at the literal.

### 2. Bitwise operators (32-bit on the web) — no hazard found

- No color-channel decomposition anywhere in the shared packages: colors are
  declared as `Color(0x...)` constants (`app_colors.dart`) and never split with
  shifts or masks. Hex parsing lives in `app_config._colorFromHex`, which uses
  `int.parse(radix: 16)` (no bitwise ops).
- The one shift in the tree is `sync_queue.dart:352`,
  `Duration(seconds: 1 << op.retryCount.clamp(0, 5))` — operand ≤ 32, far inside
  the 32-bit window, and the file is Isar-only so it is not in the shell's graph.
- `push_notification_service.dart:418` uses `.remainder(0x7fffffff)` — an
  arithmetic remainder, not a mask; it deliberately keeps the id below 2^31 and
  is correct on both targets.

### 3. `hashCode` — no defect, but a constraint worth writing down

Every use is a value-type `==`/`hashCode` pair via `Object.hash(...)`
(freezed-generated models, theme tokens). **None is persisted, used as a
Firestore document id, put in a URL, or sent to the server.** That matters
because `Object.hash` and `String.hashCode` are not guaranteed equal across
targets. Rule for every later card, including the shell: a hash may decide
in-memory equality only; it must never become a stored key, a dedupe key in a
queue, or a cache filename.

### 4. `as int` / `toInt()` on external data — web is MORE permissive, not broken

`freezed` generated code does `(json[...] as num?)?.toInt()` and raw `as int`
casts. On the VM `1.0 is int` is false; on the web it is true (integral doubles
are `int`). So a Firestore or JSON value of `1.0` would be rejected on the VM and
accepted in the shell. This is a behaviour difference to test, not a compile
hazard: Firestore returns `int` for integral numbers on both targets, and no
money field is read through a lenient cast today.

**Acceptance for P2-1a:** one test that the shell's order read tolerates the
number shapes Firestore actually returns (`int`, and `double` for a field written
as a fraction like a tax rate) — the tax path already stores fractions as
`double`.

### 5. `.abs()` overflow — only the two money sites

`grep` for `.abs()` in the shared packages returns `money_text.dart` (the guard
and the renderer) and the documentation in `currency_format.dart`. Nothing else
takes `.abs()` of an int. The class is therefore closed by P2-1a item 2.

### 6. Arithmetic magnitude — safe by a wide margin, stated so it is not re-asked

Money is integer cents. 2^53 cents ≈ 90 trillion dollars of daily total, and
every sum on the path (`totalCents`, ledger rollups, tax) is bounded by one
order or one day. `DateTime.microsecondsSinceEpoch` (≈1.8e15) is below 2^53 but
is the largest naturally occurring value in the app — it must not be multiplied.
No code multiplies it.

---

## What this audit does NOT prove

- It is a static sweep plus two probe programs; **no web run** of the money or
  receipt math has happened. P2-1a's build is the first.
- It covers `packages/core`, `packages/core_ui` and `core_app/lib/app/config`.
  It does not cover `core_app/lib/features/**`, which the shell does not import —
  but any shared module promoted into the shell later must be swept by the same
  classes.
- Anything reaching the shell through a dependency (Flutter, Firestore JS, intl)
  is outside this check by definition.

## Result

No new defects. The only compile-breaking class in the shell's path is the two
money-guard literals, which P2-1a already fixes with a verified predicate. Three
constraints are now written down so they stay true: no hash as a stored key, no
bitwise math on colour values, no multiplication of microsecond timestamps.
