#!/usr/bin/env node
// Gate (d) bootstrap — run the rules probe against a Firestore emulator on a
// port that is actually free on this machine.
//
// Why this exists: the emulator binds 0.0.0.0:<configured port> and aborts with
// "Port ... is not open ... port taken" when anything else already listens
// there. On this machine the usual suspects are occupied by unrelated software
// (a Docker container publishes 127.0.0.1:8080 and answered the probe with a
// 404 from Apache; a toast-notification app holds 0.0.0.0:8090). A fixed port
// therefore cannot be trusted, and guessing a different fixed number just moves
// the collision.
//
// So: ask the OS for a free loopback port, write a sibling config (same
// directory as core_app/firebase.json, so relative `rules` paths still resolve),
// run `emulators:exec` with it, then delete it. The probe itself is unchanged
// and still reads FIRESTORE_EMULATOR_HOST, which `emulators:exec` exports.

import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:net';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const CORE = resolve(HERE, '..', 'core_app');
const CONFIG = join(CORE, 'firebase.json');
const TEMP_CONFIG = join(CORE, '.gate-firebase.json');

function freePort() {
  return new Promise((resolvePort, reject) => {
    const server = createServer();
    server.unref();
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const {port} = server.address();
      server.close(() => resolvePort(port));
    });
  });
}

const base = JSON.parse(readFileSync(CONFIG, 'utf8'));
const port = await freePort();

writeFileSync(TEMP_CONFIG, JSON.stringify({
  ...base,
  emulators: {
    ...base.emulators,
    firestore: {...(base.emulators?.firestore ?? {}), port},
    // The UI is pure noise for a rules probe and is one more port to collide on.
    ui: {enabled: false},
  },
}, null, 2));

console.log(`emulator-probe: firestore on free port ${port} (config ${TEMP_CONFIG})`);

// One shell string, with the script quoted: emulators:exec takes the script as a
// SINGLE positional argument, and an argv array re-splits it on spaces.
const res = spawnSync(
    'firebase emulators:exec --only firestore --project demo-carnama-gate ' +
      '--config .gate-firebase.json "node ../tool/rules_probe.mjs"',
    {
      cwd: CORE,
      shell: true,
      encoding: 'utf8',
      timeout: 600000,
      maxBuffer: 64 * 1024 * 1024,
    },
);

process.stdout.write(res.stdout ?? '');
process.stderr.write(res.stderr ?? '');

if (existsSync(TEMP_CONFIG)) rmSync(TEMP_CONFIG);

if (res.error) {
  console.error(`emulator-probe: could not run firebase — ${res.error.message}`);
  process.exit(1);
}
process.exit(res.status === null ? 1 : res.status);
