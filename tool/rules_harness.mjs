#!/usr/bin/env node
// Gate (k) — the semantic rules harness, on a port this machine actually has.
//
// Why this exists: `core_app/test/rules/firestore_rules_test.js` asserts rule
// SEMANTICS (allowlists, tenancy, roles) and no gate ran it. A new assertion
// could therefore be added, never execute, and still leave every gate green —
// observed on 2026-11-12, when a deliberately inverted assertion in the settings
// block stayed green because gate (d) only loads the rules.
//
// Two things had to be true before gating it:
//
//  1. The port cannot be fixed. ask the OS for a free loopback port, write a
//     sibling config (same directory as core_app/firebase.json so relative
//     `rules` paths still resolve), and let emulators:exec export
//     FIRESTORE_EMULATOR_HOST. The harness reads that variable.
//  2. The harness must be able to be red for a reason that is not this change.
//     It carries a set of known-stale expectations (see
//     `core_app/test/rules/known_failures.txt`), so the gate is a RATCHET:
//     it fails when a failure appears that is not in the baseline, and it fails
//     when the harness crashes or stops running assertions at all. Fixed entries
//     are reported so the baseline gets pruned.
//
//   node ../tool/rules_harness.mjs                 # gate mode
//   node ../tool/rules_harness.mjs --write-baseline # record today's failures
//
// This does NOT replace gate (d): (d) proves the rules compile and load at all,
// (k) proves what they decide.

import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:net';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const CORE = resolve(HERE, '..', 'core_app');
const CONFIG = join(CORE, 'firebase.json');
const TEMP_CONFIG = join(CORE, '.gate-firebase-harness.json');
const BASELINE = join(CORE, 'test', 'rules', 'known_failures.txt');
const HARNESS = 'test/rules/firestore_rules_test.js';

const writeBaseline = process.argv.includes('--write-baseline');

function freePort() {
  return new Promise((resolvePort, reject) => {
    const server = createServer();
    server.unref();
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      server.close(() => resolvePort(port));
    });
  });
}

/** `  ❌ T5: Self-register role:customer -> ALLOW - ...` -> the assertion label. */
function parseResults(stdout) {
  const failed = [];
  const passed = [];
  for (const rawLine of stdout.split(/\r?\n/)) {
    const line = rawLine.trim();
    const failMatch = line.match(/^❌\s+(.*?)(?:\s+—\s+.*)?$/u);
    if (failMatch) {
      // Some records end with the separator and no message; the label must not
      // carry a trailing dash or the baseline would never match again.
      failed.push(failMatch[1].replace(/\s*—\s*$/u, '').trim());
      continue;
    }
    const passMatch = line.match(/^✅\s+(.*?)(?:\s+—\s+.*)?$/u);
    if (passMatch) passed.push(passMatch[1].trim());
  }
  return { failed: [...new Set(failed)].sort(), passed };
}

function readBaseline() {
  if (!existsSync(BASELINE)) return null;
  return readFileSync(BASELINE, 'utf8')
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0 && !l.startsWith('#'));
}

const base = JSON.parse(readFileSync(CONFIG, 'utf8'));
const port = await freePort();

writeFileSync(
  TEMP_CONFIG,
  JSON.stringify(
    {
      ...base,
      emulators: {
        ...base.emulators,
        firestore: { ...(base.emulators?.firestore ?? {}), port },
        ui: { enabled: false },
      },
    },
    null,
    2,
  ),
);

console.log(`rules-harness: firestore on free port ${port}`);

const res = spawnSync(
  'firebase emulators:exec --only firestore --project demo-carnama-harness ' +
    `--config .gate-firebase-harness.json "node ${HARNESS}"`,
  {
    cwd: CORE,
    shell: true,
    encoding: 'utf8',
    timeout: 600000,
    maxBuffer: 64 * 1024 * 1024,
  },
);

const stdout = res.stdout ?? '';
const stderr = res.stderr ?? '';
process.stdout.write(stdout);
process.stderr.write(stderr);

if (existsSync(TEMP_CONFIG)) rmSync(TEMP_CONFIG);

if (res.error) {
  console.error(`rules-harness: could not run firebase — ${res.error.message}`);
  process.exit(1);
}

const { failed, passed } = parseResults(stdout);

// A crash (undefined name, missing module) still exits non-zero with no ❌
// lines. That must never be mistaken for "nothing failed".
if (failed.length === 0 && passed.length === 0) {
  console.error(
    'rules-harness: no assertions were reported — the harness did not run. ' +
      'This is a FAIL, not an empty pass.',
  );
  process.exit(1);
}

if (writeBaseline) {
  writeFileSync(
    BASELINE,
    `# Known-stale expectations in ${HARNESS} (gate k ratchet).\n` +
      '# One assertion label per line, exactly as the harness prints it.\n' +
      '# Prune an entry when the assertion starts passing; never add an entry\n' +
      '# to silence a failure introduced by the change under test.\n' +
      failed.join('\n') +
      '\n',
  );
  console.log(
    `rules-harness: baseline written with ${failed.length} known failures ` +
      `(${passed.length} passing).`,
  );
  process.exit(0);
}

const baseline = readBaseline();
if (baseline === null) {
  console.error(
    `rules-harness: no baseline at ${BASELINE}. ` +
      'Run `node ../tool/rules_harness.mjs --write-baseline` once and review it.',
  );
  process.exit(1);
}

const known = new Set(baseline);
const newFailures = failed.filter((f) => !known.has(f));
const fixed = baseline.filter((f) => !failed.includes(f));

console.log(
  `rules-harness: ${passed.length} passed, ${failed.length} failed, ` +
    `${known.size} in baseline, ${newFailures.length} new.`,
);

if (fixed.length > 0) {
  console.log(
    `rules-harness: ${fixed.length} baseline entr(ies) now pass — prune them ` +
      'from test/rules/known_failures.txt:',
  );
  for (const entry of fixed) console.log(`  ✅ ${entry}`);
}

if (newFailures.length > 0) {
  console.error('\nrules-harness: NEW failures (not in the baseline):');
  for (const entry of newFailures) console.error(`  ❌ ${entry}`);
  process.exit(1);
}

process.exit(0);
