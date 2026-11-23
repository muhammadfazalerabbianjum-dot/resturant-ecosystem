/**
 * B8-0 deploy-guard test.
 *
 * Protects the single most dangerous backend defect this batch fixed: the
 * Firebase `main` entry silently pointing at a stale v1 `index.js` while the
 * verified `src/index.ts` compiled into `lib/` never deployed. These checks
 * fail if the entry regresses, a committed build artifact reappears, or a
 * mocked Stripe secret sneaks back into source.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const FUNCTIONS_ROOT = path.resolve(__dirname, '..');

function collectTsFiles(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return collectTsFiles(full);
    return entry.name.endsWith('.ts') ? [full] : [];
  });
}

test('deploy entry: package.json "main" points at the compiled lib/index.js', () => {
  const pkg = JSON.parse(
    fs.readFileSync(path.join(FUNCTIONS_ROOT, 'package.json'), 'utf8'),
  );
  assert.ok(
    typeof pkg.main === 'string' && pkg.main.startsWith('lib/'),
    `expected "main" to start with lib/, got: ${pkg.main}`,
  );
});

test('deploy entry: the compiled lib/index.js exists (source actually builds)', () => {
  const compiled = path.join(FUNCTIONS_ROOT, 'lib', 'index.js');
  assert.ok(fs.existsSync(compiled), `missing compiled deploy entry: ${compiled}`);
  // Pulled-in pure modules must compile too, or the bundle fails at load.
  assert.ok(fs.existsSync(path.join(FUNCTIONS_ROOT, 'lib', 'notification_copy.js')));
  assert.ok(fs.existsSync(path.join(FUNCTIONS_ROOT, 'lib', 'ddos.js')));
});

test('deploy entry: the stale root functions/index.js is GONE from the tree', () => {
  const stale = path.join(FUNCTIONS_ROOT, 'index.js');
  assert.ok(!fs.existsSync(stale), `stale root entry must not exist: ${stale}`);
});

test('no mocked Stripe secrets in functions/src (secrets only via process.env)', () => {
  const files = collectTsFiles(path.join(FUNCTIONS_ROOT, 'src'));
  assert.ok(files.length > 0, 'expected at least one .ts source file');

  const offenders = files.filter((file) => {
    const text = fs.readFileSync(file, 'utf8');
    return /sk_test_|ReplaceMeInProduction/.test(text);
  });
  assert.deepEqual(
    offenders,
    [],
    'found mocked Stripe secret / ReplaceMeInProduction in source: ' +
      offenders.join(', '),
  );
});

test('no bare English push literals remain in source (copy lives in dictionary)', () => {
  // The five B8-1 push sites must render from the dictionary; a regressed
  // English literal at any site would violate the localization gate.
  const indexTs = fs.readFileSync(path.join(FUNCTIONS_ROOT, 'src', 'index.ts'), 'utf8');
  for (const literal of [
    "title: 'Still hungry?'",
    "'Still hungry?'",
    "'Order Confirmed!'",
    "'New Reservation!'",
    "'CRITICAL: DDOS Alert'",
  ]) {
    assert.ok(
      !indexTs.includes(literal),
      `bare English push literal found in src/index.ts: ${literal}`,
    );
  }
});