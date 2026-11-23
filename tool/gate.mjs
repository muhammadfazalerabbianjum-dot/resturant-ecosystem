#!/usr/bin/env node
// Carnama gate runner (P0-1).
//
// One command, one verdict, and a written receipt for every run:
//   node tool/gate.mjs check            -> every gate in gate_config.json
//   node tool/gate.mjs check --only=a,e -> selected gates
//   node tool/gate.mjs list             -> the gate table, nothing executed
//
// Status vocabulary (deliberately distinct, because "green" must never be a lie):
//   PASS        the command exited 0
//   FAIL        the command exited non-zero or timed out
//   UNAVAILABLE a required tool is not on this machine; the gate did not run
//   NOT-ACTIVE  the gate exists but is switched off until a named card wires it
//
// Only FAIL makes the run red (exit 1). UNAVAILABLE and NOT-ACTIVE are printed
// in a loud block and recorded in the receipt, so they can never be mistaken
// for a pass. See docs/DECISIONS.md D-002 for why that asymmetry is deliberate.

import { spawnSync } from 'node:child_process';
import {
  appendFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..');
const CONFIG_PATH = join(ROOT, 'gate_config.json');
const CKPT_DIR = join(ROOT, 'checkpoints');
const LEDGER = join(ROOT, 'ledger.md');
const DIGEST = join(ROOT, 'DIGEST.md');

// Built by concatenation on purpose: this file is inside the stub-scan gate's
// own scope, and a literal marker here would make the gate fail on itself.
const STUB_MARKERS = ['TO' + 'DO', 'FIX' + 'ME', 'Unimplemented' + 'Error', 'NOT_IMPLEMENT' + 'ED'];

function run(cmd, opts = {}) {
  const started = Date.now();
  const res = spawnSync(cmd, {
    cwd: opts.cwd ?? ROOT,
    shell: true,
    encoding: 'utf8',
    timeout: opts.timeoutMs ?? 900000,
    maxBuffer: 96 * 1024 * 1024,
    env: { ...process.env, CI: '1', NO_COLOR: '1' },
  });
  const ms = Date.now() - started;
  const out = `${res.stdout ?? ''}${res.stderr ?? ''}`;
  const timedOut = res.error && res.error.code === 'ETIMEDOUT';
  return {
    ms,
    code: timedOut ? null : res.status,
    timedOut: Boolean(timedOut),
    ok: !timedOut && res.status === 0,
    out,
  };
}

function haveTool(tool) {
  const probe = process.platform === 'win32' ? `where ${tool}` : `command -v ${tool}`;
  const res = spawnSync(probe, { shell: true, encoding: 'utf8' });
  return res.status === 0;
}

function git(args) {
  const res = spawnSync(`git ${args}`, { cwd: ROOT, shell: true, encoding: 'utf8' });
  return (res.stdout ?? '').trim();
}

function utcStamp() {
  return new Date().toISOString().replace(/[-:]/g, '').replace(/\..*$/, 'Z');
}

// ---------------------------------------------------------------- stub scan

function parsePorcelainPaths(text) {
  // " M path", "?? path", "R  old -> new"
  return text
    .split('\n')
    .map((line) => line.trimEnd())
    .filter((line) => line.length > 3)
    .map((line) => {
      let p = line.slice(3).trim();
      if (p.includes(' -> ')) p = p.split(' -> ').pop().trim();
      return p.replace(/^"|"$/g, '').replace(/\\/g, '/');
    });
}

function loadBaselineExclusions(relPath) {
  // Only tracked-file churn counts as the owner's pre-existing dirt: those are
  // the files the expansion must never touch or judge. Untracked files stay in
  // scan scope on purpose, so P0's own new code cannot hide from gate (f) by
  // virtue of having been created before the snapshot was taken.
  const abs = join(ROOT, relPath);
  if (!existsSync(abs)) return new Set();
  const tracked = readFileSync(abs, 'utf8')
    .split('\n')
    .filter((line) => line.length > 3 && !line.startsWith('??'))
    .join('\n');
  return new Set(parsePorcelainPaths(tracked));
}

// A marker that already exists in HEAD is the file's pre-existing state, not
// P0's: editing a file whose legacy placeholders are real (whitelabel.dart's
// boilerplate stripper, index.ts's deploy note) must not be a gate failure. The
// budget is consumed per occurrence, so an ADDITIONAL marker still fails.
function headMarkerBudget(rel) {
  const budget = new Map();
  const head = git(`show "HEAD:${rel}"`);
  if (!head) return budget;
  for (const line of head.split('\n')) {
    for (const marker of STUB_MARKERS) {
      if (!line.includes(marker)) continue;
      const key = `${marker}\u0000${line.trim()}`;
      budget.set(key, (budget.get(key) ?? 0) + 1);
    }
  }
  return budget;
}

function stubScan(gate, scopeArgs) {
  const exts = gate.extensions ?? ['.dart', '.ts', '.js', '.mjs'];
  const baseline = loadBaselineExclusions(gate.baseline ?? 'checkpoints/P0-01.pre.txt');
  // -uall: without it git collapses a brand-new directory to "?? dir/", so code
  // added under a new folder — the normal shape of new work — would never be
  // scanned. With -uall every untracked file is listed individually.
  const status = git('status --porcelain -uall');
  const candidates = new Set([...parsePorcelainPaths(status), ...scopeArgs]);

  const scanned = [];
  const hits = [];
  for (const rel of candidates) {
    if (!rel) continue;
    if (baseline.has(rel)) continue; // the owner's pre-existing dirt is inviolate (L11)
    if (!exts.some((e) => rel.endsWith(e))) continue;
    const abs = join(ROOT, rel);
    if (!existsSync(abs) || statSync(abs).isDirectory()) continue;
    scanned.push(rel);
    const lines = readFileSync(abs, 'utf8').split('\n');
    const budget = headMarkerBudget(rel);
    lines.forEach((line, i) => {
      for (const marker of STUB_MARKERS) {
        if (!line.includes(marker)) continue;
        const key = `${marker}\u0000${line.trim()}`;
        const left = budget.get(key) ?? 0;
        if (left > 0) {
          budget.set(key, left - 1);
          continue;
        }
        hits.push(`${rel}:${i + 1}: ${line.trim().slice(0, 160)}`);
      }
    });
  }

  if (hits.length > 0) {
    return {
      ok: false,
      ms: 0,
      out: `stub markers found in ${hits.length} place(s):\n${hits.join('\n')}`,
      detail: `${scanned.length} file(s) scanned`,
    };
  }
  return {
    ok: true,
    ms: 0,
    out: scanned.length
      ? `clean: ${scanned.length} in-scope file(s) scanned\n${scanned.map((s) => `  ${s}`).join('\n')}`
      : 'clean: no in-scope changed files (only baseline dirt present)',
    detail: `${scanned.length} file(s) scanned`,
  };
}

// ------------------------------------------------------- licence claims

// Gate (l). The root LICENSE grants nothing but viewing, so a document that calls
// this project open source, source-available or MIT-licensed asserts a grant the
// owner never made. That is the exact drift this gate stops.
//
// Deliberately narrow: it reads prose only (markdown and licence files), and a
// mention is allowed when it is negated in the same sentence ("this is not open
// source") or attributed to a dependency ("third-party open-source packages").
// Historical receipts and the frozen archive are out of scope: they record what
// was true when they were written, and a gate cannot rewrite history.
const CLAIM_PATTERNS = [/open[- ]source/i, /source[- ]available/i, /\bMIT\b/];
const CLAIM_NEGATIONS = /\b(not|no|never|without|neither|nor|isn't|aren't|doesn't|don't)\b/i;
const CLAIM_OUT_OF_SCOPE = /^(archive|checkpoints|tool_uilib|\.github|node_modules)\//;
const CLAIM_ATTRIBUTION = /third[- ]party|dependenc|licences of|their own licences/i;
const CLAIM_FILE = /(\.md$)|((^|\/)(licen[cs]e|copying|notice)(\.[a-z]+)?$)/i;

function claimScan(gate) {
  const started = Date.now();
  const files = git('ls-files')
    .split('\n')
    .map((p) => p.trim())
    .filter(Boolean)
    .filter((p) => !CLAIM_OUT_OF_SCOPE.test(p) && CLAIM_FILE.test(p));

  const hits = [];
  for (const rel of files) {
    const abs = join(ROOT, rel);
    if (!existsSync(abs) || statSync(abs).isDirectory()) continue;
    const lines = readFileSync(abs, 'utf8').split('\n');
    lines.forEach((raw, i) => {
      const line = raw.replace(/\r$/, '');
      if (!CLAIM_PATTERNS.some((re) => re.test(line))) return;
      if (CLAIM_ATTRIBUTION.test(line)) return;
      // A wrapped sentence can put the negation on the line before (README keeps
      // "not open source and" / "not \"source-available\"" on two lines).
      const prev = (lines[i - 1] ?? '').replace(/\r$/, '');
      const wrappedIntoPrev = prev.length > 0 && !/[.!?:|]\s*$/.test(prev);
      if (CLAIM_NEGATIONS.test(line)) return;
      if (wrappedIntoPrev && CLAIM_NEGATIONS.test(prev)) return;
      hits.push(`${rel}:${i + 1}: ${line.trim().slice(0, 160)}`);
    });
  }

  const ms = Date.now() - started;
  if (hits.length > 0) {
    return {
      ok: false,
      ms,
      out:
        `licence claim(s) found in ${hits.length} place(s) \u2014 the repository grants viewing only;\n` +
        `either remove the claim or state it as a denial (\"not open source\"):\n${hits.join('\n')}`,
      detail: `${files.length} file(s) scanned`,
    };
  }
  return {
    ok: true,
    ms,
    out: `clean: ${files.length} doc/licence file(s) scanned, no open-source claim`,
    detail: `${files.length} file(s) scanned`,
  };
}

// ---------------------------------------------------------------- reporting

function tail(text, n = 40) {
  const lines = text.trimEnd().split('\n');
  return lines.slice(Math.max(0, lines.length - n)).join('\n');
}

function ensureLedger() {
  if (!existsSync(LEDGER)) {
    writeFileSync(
      LEDGER,
      '# LEDGER — append-only run record\n\n' +
        'One row per executed card or gate run. Never edited, never reordered; a\n' +
        'correction is a new row (the same rule the product ledger follows).\n\n' +
        '| UTC | kind | result | detail | receipt |\n' +
        '|---|---|---|---|---|\n',
    );
  }
}

function appendLedger(row) {
  ensureLedger();
  appendFileSync(LEDGER, `${row}\n`);
}

function appendDigest(line) {
  if (!existsSync(DIGEST)) {
    writeFileSync(DIGEST, '# DIGEST\n\nHuman-readable running summary of P0.\n\n## Gate runs\n\n');
  }
  appendFileSync(DIGEST, `${line}\n`);
}

function usage(msg) {
  console.error(`gate: ${msg}`);
  console.error('usage: gate.cmd [check|list] [--only=a,b] [--scope=path1,path2]');
  process.exit(2);
}

// ---------------------------------------------------------------- main

const argv = process.argv.slice(2);
const command = argv.find((a) => !a.startsWith('--')) ?? 'check';
const flag = (name) => {
  const hit = argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3).split(',').map((s) => s.trim()).filter(Boolean) : null;
};

if (!existsSync(CONFIG_PATH)) usage(`gate_config.json not found at ${CONFIG_PATH}`);
const config = JSON.parse(readFileSync(CONFIG_PATH, 'utf8'));
const gates = config.gates ?? [];
const only = flag('only');
const scope = flag('scope') ?? [];

if (command === 'list') {
  for (const g of gates) {
    const state = g.active === false ? `NOT-ACTIVE (${g.activation ?? 'unwired'})` : 'active';
    console.log(`[${g.id}] ${g.label.padEnd(22)} ${state}`);
  }
  process.exit(0);
}
if (command !== 'check') usage(`unknown command "${command}"`);

const selected = only ? gates.filter((g) => only.includes(g.id)) : gates;
if (only && selected.length !== only.length) {
  const known = gates.map((g) => g.id).join(',');
  usage(`unknown gate id in --only=${only.join(',')} (known: ${known})`);
}

mkdirSync(CKPT_DIR, { recursive: true });

const startedAt = new Date();
const stamp = utcStamp();
const branch = git('rev-parse --abbrev-ref HEAD');
const head = git('rev-parse --short HEAD');
const results = [];

console.log(`=== GATE RUN ${stamp} ===`);
console.log(`repo: ${ROOT}  branch: ${branch}  head: ${head}`);
console.log('');

const skipped = [];
for (const gate of gates) {
  if (!selected.includes(gate)) {
    skipped.push(gate);
    continue;
  }
  const label = `[${gate.id}] ${gate.label}`.padEnd(26);

  if (gate.active === false) {
    console.log(`${label} NOT-ACTIVE  ${gate.activation ?? 'unwired'}`);
    results.push({ gate, status: 'NOT-ACTIVE', note: gate.activation ?? 'unwired', ms: 0, out: '' });
    continue;
  }

  const missing = (gate.requires ?? []).filter((t) => !haveTool(t));
  if (missing.length > 0) {
    console.log(`${label} UNAVAILABLE  missing: ${missing.join(', ')}`);
    results.push({ gate, status: 'UNAVAILABLE', note: `missing: ${missing.join(', ')}`, ms: 0, out: '' });
    continue;
  }

  let res;
  if (gate.kind === 'stub_scan') {
    res = stubScan(gate, scope);
  } else if (gate.kind === 'claim_scan') {
    res = claimScan(gate);
  } else {
    res = run(gate.cmd, { cwd: join(ROOT, gate.cwd ?? '.'), timeoutMs: gate.timeoutMs });
  }

  const status = res.ok ? 'PASS' : 'FAIL';
  const secs = (res.ms / 1000).toFixed(1);
  console.log(`${label} ${status.padEnd(10)} ${secs}s${res.detail ? `  (${res.detail})` : ''}`);
  if (!res.ok) {
    console.log(tail(res.out, 30).split('\n').map((l) => `      ${l}`).join('\n'));
  }
  results.push({ gate, status, ms: res.ms, out: res.out, cmd: gate.cmd, cwd: gate.cwd });
}

const failed = results.filter((r) => r.status === 'FAIL');
const unavailable = results.filter((r) => r.status === 'UNAVAILABLE');
const notActive = results.filter((r) => r.status === 'NOT-ACTIVE');

// Loud block: these are the states that must never read as "green" at a glance.
if (unavailable.length || notActive.length) {
  console.log('');
  console.log('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
  for (const r of unavailable) console.log(`!! LOUD  [${r.gate.id}] UNAVAILABLE — ${r.note}`);
  for (const r of notActive) console.log(`!! LOUD  [${r.gate.id}] NOT-ACTIVE — ${r.note}`);
  console.log('!! A run containing the lines above is NOT full coverage.');
  console.log('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
}

const verdict = failed.length > 0 ? 'FAIL' : 'PASS';
console.log('');
console.log(
  `GATE RESULT: ${verdict}  (${results.length} ran, ${failed.length} failed, ` +
    `${unavailable.length} unavailable, ${notActive.length} not-active` +
    `${skipped.length ? `, ${skipped.length} not selected` : ''})`,
);

// ---------------------------------------------------------------- receipt

const receiptRel = `checkpoints/gate-${stamp}.md`;
const lines = [];
lines.push(`# Gate run — ${startedAt.toISOString()}`);
lines.push('');
lines.push(`- Repo: \`${ROOT}\``);
lines.push(`- Branch: \`${branch}\`  Head: \`${head}\``);
lines.push(`- Command: \`gate.cmd ${argv.join(' ') || 'check'}\``);
lines.push(`- Verdict: **${verdict}**`);
lines.push(`- Not full coverage: ${unavailable.length} unavailable, ${notActive.length} not-active`);
lines.push('');
lines.push('| Gate | Name | Status | Duration | Command |');
lines.push('|---|---|---|---|---|');
for (const r of results) {
      const cmd =
      r.gate.kind === 'stub_scan'
        ? 'stub scan'
        : r.gate.kind === 'claim_scan'
          ? 'licence claim scan'
          : `\`${r.gate.cmd}\` (cwd \`${r.gate.cwd ?? '.'}\`)`;
  lines.push(
    `| ${r.gate.id} | ${r.gate.label} | **${r.status}** | ${(r.ms / 1000).toFixed(1)}s | ${cmd} |`,
  );
}
lines.push('');
lines.push('## What each gate proved, and why that gate exists');
lines.push('');
for (const r of results) {
  lines.push(`- **[${r.gate.id}] ${r.gate.label} — ${r.status}.** ${r.gate.proves ?? ''}`);
  if (r.note) lines.push(`  - Note: ${r.note}`);
}
for (const r of failed) {
  lines.push('');
  lines.push(`## Failure output — gate [${r.gate.id}] ${r.gate.label}`);
  lines.push('');
  lines.push('```text');
  lines.push(tail(r.out, 80));
  lines.push('```');
}
writeFileSync(join(ROOT, receiptRel), lines.join('\n') + '\n');

appendLedger(
  `| ${stamp} | gate | ${verdict} | ${results.map((r) => `${r.gate.id}:${r.status}`).join(' ')} | \`${receiptRel}\` |`,
);
appendDigest(
  `- ${stamp} — gate **${verdict}** (${failed.length} failed, ${unavailable.length} unavailable, ` +
    `${notActive.length} not-active) → \`${receiptRel}\``,
);

console.log(`receipt: ${receiptRel}`);
process.exit(failed.length > 0 ? 1 : 0);
