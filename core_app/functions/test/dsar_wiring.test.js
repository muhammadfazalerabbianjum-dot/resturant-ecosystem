/**
 * C-9 / D-059 — WIRING contract, read off the source on disk.
 *
 * `dsar_ledger.test.js` proves the anonymisation module. This file proves the
 * two call sites that make it reachable — the failure mode being fixed was
 * precisely a module that existed in spirit and was never called from the
 * erasure path. Reading the shipped source (the same technique the orders
 * payload contract uses) means a refactor that drops the call fails here instead
 * of silently reopening the gap.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');

const SOURCE = readFileSync(join(__dirname, '..', 'src', 'index.ts'), 'utf8');

function indexOfOrFail(needle) {
  const at = SOURCE.indexOf(needle);
  assert.notEqual(at, -1, `expected source to contain: ${needle}`);
  return at;
}

test('W-1 the erasure imports the anonymiser and the export reader', () => {
  assert.match(
      SOURCE,
      /import\s*\{[^}]*anonymiseLedgerRows[^}]*collectLedgerRows[^}]*\}\s*from\s*'\.\/ledger_privacy'/s,
  );
});

test('W-2 runErase anonymises the ledger AFTER the refs and BEFORE the auth delete', () => {
  const eraseRefsAt = indexOfOrFail('await eraseRefs(db, refs);');
  const anonymiseAt = indexOfOrFail('anonymiseLedgerRows(');
  const authDeleteAt = indexOfOrFail('await authDeleter(uid);');

  assert.ok(
      anonymiseAt > eraseRefsAt,
      'the ledger pass must run after the document erasure',
  );
  assert.ok(
      anonymiseAt < authDeleteAt,
      'a failure must leave the marker in_progress for the hourly retrier, so the ' +
      'auth delete cannot come first',
  );
});

test('W-3 the export includes the caller\'s ledger rows', () => {
  const collectAt = indexOfOrFail('export async function collectUserData(');
  const ledgerAt = indexOfOrFail('out.transactions = await collectLedgerRows(');
  assert.ok(ledgerAt > collectAt, 'the export section belongs inside collectUserData');
});

test('W-4 nothing in the erasure DELETES a ledger row', () => {
  // The ruling is retention + anonymisation; a delete here would destroy the
  // taxable record. Guards against a future "just delete them" shortcut.
  const ledgerPrivacy = readFileSync(
      join(__dirname, '..', 'src', 'ledger_privacy.ts'),
      'utf8',
  );
  assert.equal(
      /\.delete\(/.test(ledgerPrivacy),
      false,
      'ledger_privacy must never call delete()',
  );
});
