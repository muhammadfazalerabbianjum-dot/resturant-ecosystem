#!/usr/bin/env node
// Gate (g): enforce the per-file line-coverage floors in coverage-floors.json.
//
// Design rules (checkpoints/P0-09.md):
//   1. Every file under src/ MUST be registered. A new file with no row is a
//      failure, not a silent 0% pass — otherwise "new code is covered" would
//      depend on somebody remembering to add a row.
//   2. A registered file with no explicit `lines` floor gets `defaultLines`
//      (90). New files therefore need 90% by default.
//   3. Actual < floor  -> FAIL with the file, the floor and the measurement.
//   4. A registered file that no longer exists -> FAIL (stale registry).
//   5. `--raise` rewrites the registry from the current measurement, and
//      REFUSES to lower any floor (ratchet only).
//
// Exit: 0 all good, 1 any floor/completeness failure, 2 cannot run (missing
// coverage summary or registry) — never a silent pass.

import { readFileSync, writeFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, relative, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const pkgRoot = join(here, '..');
const summaryPath = join(pkgRoot, 'coverage', 'coverage-summary.json');
const floorsPath = join(pkgRoot, 'coverage-floors.json');
const srcRoot = join(pkgRoot, 'src');
const raise = process.argv.includes('--raise');

function die(msg) {
  console.error(`COVERAGE-FLOOR: cannot run — ${msg}`);
  process.exit(2);
}

if (!existsSync(summaryPath)) {
  die(
    `no ${relative(pkgRoot, summaryPath)}; run ` +
      '`node scripts/check_coverage_floor.mjs` only after `npm run test:coverage` has measured.',
  );
}
if (!existsSync(floorsPath)) die(`no ${relative(pkgRoot, floorsPath)}; the registry is the deliverable`);

const summary = JSON.parse(readFileSync(summaryPath, 'utf8'));
const floors = JSON.parse(readFileSync(floorsPath, 'utf8'));
const defaultFloor = Number.isFinite(floors.defaultLines) ? floors.defaultLines : 90;

/** Actual per-file line coverage, keyed by package-relative path (`src/x.ts`). */
const measured = new Map();
for (const [absPath, data] of Object.entries(summary)) {
  if (absPath === 'total') continue;
  const idx = absPath.replace(/\\/g, '/').lastIndexOf('/src/');
  if (idx === -1) continue;
  measured.set(`src/${absPath.replace(/\\/g, '/').slice(idx + 5)}`, data.lines?.pct ?? 0);
}

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) out.push(...walk(full));
    else if (name.endsWith('.ts') && !name.endsWith('.d.ts')) out.push(relative(pkgRoot, full).replace(/\\/g, '/'));
  }
  return out;
}

const sourceFiles = walk(srcRoot).sort();
const rows = floors.files ?? {};

if (raise) {
  const next = { ...floors, files: {} };
  let changed = 0;
  for (const p of sourceFiles) {
    const previous = rows[p]?.lines;
    const now = measured.get(p);
    if (now === undefined) {
      console.error(`RAISE: no measurement for ${p}; leaving its row untouched`);
      if (rows[p]) next.files[p] = rows[p];
      continue;
    }
    const rounded = Math.floor(now * 100) / 100;
    if (previous !== undefined && rounded < previous) {
      console.error(
        `RAISE: refusing to lower ${p} (${previous}% -> ${rounded}%). ` +
          'Floors only move up; fix the regression instead.',
      );
      next.files[p] = rows[p];
      continue;
    }
    const value = previous === undefined || rounded > previous ? rounded : previous;
    if (value !== previous) changed += 1;
    next.files[p] = { ...(rows[p] ?? {}), lines: value };
  }
  const totalNow = Math.floor((summary.total?.lines?.pct ?? 0) * 100) / 100;
  if (totalNow >= (floors.totalLines ?? 0)) next.totalLines = Math.max(floors.totalLines ?? 0, totalNow);
  writeFileSync(floorsPath, `${JSON.stringify(next, null, 2)}\n`);
  console.log(`RAISE: ${changed} floor(s) raised; registry written.`);
  process.exit(0);
}

const failures = [];
const lines = [];

for (const p of sourceFiles) {
  const row = rows[p];
  if (!row) {
    failures.push(
      `${p} is NOT registered in coverage-floors.json — add a row (no row means no floor; ` +
        `new files get ${defaultFloor}%)`,
    );
    continue;
  }
  const floor = Number.isFinite(row.lines) ? row.lines : defaultFloor;
  // A file no test imports has no c8 entry at all. That is 0% measured, not
  // "unknown": it passes only if its registered floor is 0 (one-shot scripts),
  // and it is labelled as not loaded so the receipt cannot mislead.
  const loaded = measured.has(p);
  const actual = measured.get(p) ?? 0;
  const ok = actual + 1e-9 >= floor;
  if (!ok) {
    failures.push(
      `${p} lines ${actual}% < floor ${floor}%${loaded ? '' : ' (no test imports this file)'}` +
        `${row.note ? ` — ${row.note}` : ''}`,
    );
  }
  lines.push(
    `${ok ? 'ok  ' : 'FAIL'} ${actual.toFixed(2).padStart(6)}% / ${String(floor).padStart(6)}%  ${p}` +
      `${loaded ? '' : '  [not imported by any test]'}`,
  );
}

for (const p of Object.keys(rows)) {
  if (!sourceFiles.includes(p)) failures.push(`${p} is registered but no longer exists — stale registry row`);
}

const totalActual = summary.total?.lines?.pct ?? 0;
const totalFloor = floors.totalLines ?? 0;
const totalOk = totalActual + 1e-9 >= totalFloor;
if (!totalOk) failures.push(`TOTAL lines ${totalActual}% < floor ${totalFloor}%`);

for (const l of lines) console.log(l);
console.log(`${totalOk ? 'ok  ' : 'FAIL'} ${totalActual.toFixed(2).padStart(6)}% / ${String(totalFloor).padStart(6)}%  TOTAL`);

if (failures.length) {
  console.error(`\nCOVERAGE-FLOOR: FAIL (${failures.length})`);
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log(`\nCOVERAGE-FLOOR: PASS (${sourceFiles.length} files at or above floor)`);
