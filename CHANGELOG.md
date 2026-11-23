# Carnama Labs — Monorepo Changelog

The canonical version source is `core_app/pubspec.yaml` (today `1.1.0+2`).
Release tags are annotated `v<version>` tags created with
`core_app/tool/tag_release.dart` — see `docs/RELEASE_RUNBOOK.md` for the full
release runbook (signing, CI, fastlane `beta`/`promote`, melos versioning).

## [1.1.0+2] — 2026-09-04

### Production-fix remediation (waves W1–W11, 29 batches)

This release ships the output of the 2026-09 production-readiness program:
nine independent audits (a11y/l10n/UX, state & data flow, white-label config,
payments & privacy, performance, network resilience, Firebase backend,
testing/release/CI) produced seven FAIL verdicts, and every P0/P1/P2 finding
was remediated across 28 window batches plus this RELEASE-1 pipeline batch.
Highlights:

- **CI & tooling (W1/W7):** repo-root CI covering the full estate (tests,
  coverage floor, goldens, format, config-schema + permission-allowlist
  enforcement, functions lint/type/test gates); backend bundle emission +
  per-client runbook + deploy preflight tool.
- **Routing & navigation (W2):** named-route resolution with go_router,
  config-mode route gating, orphan surfacing, and a network blocker test seam.
- **Money & rules (W3/W4):** server-side price integrity with stored-payload
  cross-checks, refund-replay guard, GDPR erasure coverage, Firestore rules
  hasOnly alignment enforced by a growing emulator suite.
- **Offline & push (W2/W5):** offline order queue with DLQ UI, retry coverage,
  kitchen heartbeat scheduling, and an end-to-end push chain with validated
  deep-link taps and cold-start consumption.
- **State & services (W4/W8):** lifecycle-correct dashboard/GPS/cart state,
  family stream providers with named query caps, Isar productionization.
- **White-label (W3/W6):** generator key gate + fail-fast shell boot, config
  schema validation with a fail-closed screen, backend bundle, platform
  privacy layer.
- **UX/a11y/l10n (W5/W9):** AA contrast palette, ARB migration, one money
  formatter, semantics labels, PopScope back guards, GDPR consent chain,
  signup ToS gate, Art.20 export, analytics funnel, BrandColors theme tokens.
- **Release engineering (RELEASE-1/W11):** signing template + fail-closed
  release gate, CI signed-appbundle job, fastlane `beta`/`promote` scaffold,
  `tool/tag_release.dart`, this CHANGELOG, and the typography guard.

### Release engineering

- `core_app/android/key.properties.template` — copy to
  `core_app/android/key.properties` (gitignored) and fill in your keystore.
  Release builds fail closed without it; CI injects it from the
  `ANDROID_KEYSTORE_BASE64` secret (never committed).
- `fastlane/` — `lane :beta` (build + upload to the internal track) and
  `lane :promote` (internal → beta track), both via `supply`.
- `core_app/tool/tag_release.dart` — creates annotated `v<version>` tags from
  `core_app/pubspec.yaml` (`--dry-run` to preview).
- **Typography guard:** a `fontFamily` in `client_config.json` that is not a
  registered bundled font now records an explicit load error and falls back to
  the built-in type system instead of silently degrading (08-P2-2).