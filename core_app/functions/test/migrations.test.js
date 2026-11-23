/**
 * P1-6 — backfills. The card's assertion is "a second run changes zero
 * documents", which is a property of the PLANNER, so it is asserted over the
 * applied output rather than observed once against a live database.
 *
 *   M-1 v004 fills a missing tenantId
 *   M-2 v004 a second run over its own output plans ZERO writes
 *   M-3 v004 never reassigns a document that belongs to another tenant
 *   M-4 v005 derives roles[]/branchIds[] from the legacy single fields
 *   M-5 v005 a second run plans zero writes
 *   M-6 v005 refuses malformed authority and leaves non-staff alone
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  DEFAULT_TENANT_ID,
  MigrationConflictError,
  planRolesBackfill,
  planSettingsRename,
  planTenancyBackfill,
} = require('../lib/migrations/plans.js');

const {
  applySettingsRename,
  applyTenancyBackfill,
} = require('../lib/migrations/v004__tenancy_backfill.js');
const {applyRolesBackfill} = require('../lib/migrations/v005__roles_backfill.js');

/** Minimal admin-Firestore stand-in: collections, batches, merge writes. */
function fakeDb(seed) {
  const docs = new Map(Object.entries(seed));
  const commits = [];

  return {
    docs,
    commits,
    collection(name) {
      return {
        async get() {
          return {
            docs: [...docs]
                .filter(([path]) => path.startsWith(`${name}/`))
                .map(([path, data]) => ({ref: {path}, data: () => ({...data})})),
          };
        },
      };
    },
    doc(path) {
      return {path};
    },
    batch() {
      const ops = [];
      return {
        set(ref, data, options) {
          ops.push([ref.path, data, options]);
        },
        async commit() {
          for (const [path, data, options] of ops) {
            const merged = options && options.merge ? {...(docs.get(path) ?? {}), ...data} : data;
            docs.set(path, merged);
          }
          commits.push(ops.length);
        },
      };
    },
  };
}

/** Apply a plan to the input rows, as the batch writer would. */
function applyPlan(rows, plan) {
  const byPath = new Map(rows.map((r) => [r.path, {...(r.data ?? {})}]));
  for (const write of plan.writes) byPath.set(write.path, {...write.data});
  return [...byPath].map(([path, data]) => ({path, data}));
}

const tenancyRows = [
  {path: 'orders/o1', data: {status: 'delivered'}},
  {path: 'menus/m1', data: {name: 'Chicken'}},
  {path: 'users/u1', data: {role: 'manager'}},
  {path: 'orders/o2', data: undefined},
];

test('M-1: v004 fills a missing tenantId', () => {
  const plan = planTenancyBackfill(tenancyRows);

  assert.equal(plan.planned ?? plan.writes.length, 4);
  assert.equal(plan.conflicts.length, 0);
  assert.equal(plan.unchanged, 0);
  for (const write of plan.writes) {
    assert.equal(write.data.tenantId, DEFAULT_TENANT_ID);
  }
  // Existing fields survive: the write is additive.
  assert.equal(plan.writes.find((w) => w.path === 'menus/m1').data.name, 'Chicken');
});

test('M-2: v004 a second run over its own output plans zero writes', () => {
  const first = planTenancyBackfill(tenancyRows);
  const applied = applyPlan(tenancyRows, first);
  const second = planTenancyBackfill(applied);

  assert.deepEqual(second.writes, [], 'idempotent: nothing left to change');
  assert.equal(second.unchanged, tenancyRows.length);
  assert.equal(second.conflicts.length, 0);
  assert.deepEqual(applyPlan(applied, second), applied, 'the documents are unchanged');
});

test('M-3: v004 never reassigns another tenant\u2019s document', () => {
  const rows = [
    {path: 'orders/o1', data: {tenantId: DEFAULT_TENANT_ID}},
    {path: 'orders/o2', data: {tenantId: 'other-client'}},
    {path: 'orders/o3', data: {}},
  ];

  const plan = planTenancyBackfill(rows);

  assert.deepEqual(plan.conflicts, ['orders/o2']);
  assert.deepEqual(plan.writes.map((w) => w.path), ['orders/o3']);
  assert.equal(plan.unchanged, 1);
  assert.throws(
      () => planTenancyBackfill(rows, ''),
      (err) => err instanceof MigrationConflictError);
});

const roleRows = [
  {path: 'users/owner', data: {role: 'owner', branchId: 'branch_main'}},
  {path: 'users/waiter', data: {role: 'manager'}},
  {path: 'users/customer', data: {name: 'Sam'}},
  {path: 'users/migrated', data: {role: 'owner', roles: ['owner'], branchIds: ['b1']}},
];

test('M-4: v005 derives roles[] and branchIds[] from the legacy fields', () => {
  const plan = planRolesBackfill(roleRows);

  const byPath = new Map(plan.writes.map((w) => [w.path, w.data]));
  assert.deepEqual(byPath.get('users/owner').roles, ['owner']);
  assert.deepEqual(byPath.get('users/owner').branchIds, ['branch_main']);
  assert.deepEqual(byPath.get('users/waiter').roles, ['manager']);
  assert.deepEqual(byPath.get('users/waiter').branchIds, [], 'no branch means no branches');
  assert.equal(byPath.has('users/customer'), false, 'a customer is not staff');
  assert.equal(byPath.has('users/migrated'), false, 'already migrated');
  assert.equal(plan.unchanged, 2);
});

test('M-5: v005 a second run plans zero writes', () => {
  const applied = applyPlan(roleRows, planRolesBackfill(roleRows));
  const second = planRolesBackfill(applied);

  assert.deepEqual(second.writes, []);
  assert.equal(second.conflicts.length, 0);
  // The legacy fields are preserved for older clients.
  assert.equal(applied.find((r) => r.path === 'users/owner').data.role, 'owner');
});

test('M-7: v004 is a dry run by default and writes nothing', async () => {
  const db = fakeDb({'orders/o1': {status: 'created'}, 'users/u1': {role: 'owner'}});

  const report = await applyTenancyBackfill(db, {apply: false});

  assert.equal(report.planned, 2, 'the plan is reported');
  assert.equal(report.applied, 0);
  assert.equal(db.commits.length, 0, 'no batch was ever committed');
  assert.equal(db.docs.get('orders/o1').tenantId, undefined);
});

test('M-8: v004 applied once, then a second run writes nothing', async () => {
  const db = fakeDb({'orders/o1': {status: 'created'}, 'menus/m1': {name: 'Chicken'}});

  const first = await applyTenancyBackfill(db, {apply: true});
  assert.equal(first.applied, 2);
  assert.equal(db.docs.get('orders/o1').tenantId, DEFAULT_TENANT_ID);
  assert.equal(db.docs.get('orders/o1').status, 'created', 'merge, not replace');

  const commitsAfterFirst = db.commits.length;
  const second = await applyTenancyBackfill(db, {apply: true});

  assert.equal(second.planned, 0, 'the card\u2019s assertion: a second run changes zero documents');
  assert.equal(second.applied, 0);
  assert.equal(db.commits.length, commitsAfterFirst, 'not one batch was committed');
});

test('M-9: v004 refuses to reassign a foreign tenant through the wrapper', async () => {
  const db = fakeDb({
    'orders/o1': {tenantId: 'other-client'},
    'orders/o2': {},
  });

  const report = await applyTenancyBackfill(db, {apply: true});

  assert.deepEqual(report.conflicts, ['orders/o1']);
  assert.equal(db.docs.get('orders/o1').tenantId, 'other-client', 'untouched');
  assert.equal(db.docs.get('orders/o2').tenantId, DEFAULT_TENANT_ID);
});

test('M-10: v005 is a dry run by default and idempotent when applied', async () => {
  const db = fakeDb({'users/u1': {role: 'manager', branchId: 'b1'}});

  const dry = await applyRolesBackfill(db, {apply: false});
  assert.equal(dry.planned, 1);
  assert.equal(db.commits.length, 0);

  const applied = await applyRolesBackfill(db, {apply: true});
  assert.equal(applied.applied, 1);
  assert.deepEqual(db.docs.get('users/u1').roles, ['manager']);
  assert.deepEqual(db.docs.get('users/u1').branchIds, ['b1']);
  assert.equal(db.docs.get('users/u1').role, 'manager', 'legacy field kept');

  const again = await applyRolesBackfill(db, {apply: true});
  assert.equal(again.planned, 0);
  assert.equal(again.applied, 0);
});

test('M-11: settings documents are copied to their tenant-prefixed name', () => {
  const plan = planSettingsRename([
    {path: 'settings/restaurantConfig', data: {currency: 'USD'}},
    {path: 'settings/ownerInfo', data: {ownerEmail: 'o@example.com'}},
  ]);

  assert.deepEqual(plan.writes.map((w) => w.to).sort(), [
    `settings/${DEFAULT_TENANT_ID}_ownerInfo`,
    `settings/${DEFAULT_TENANT_ID}_restaurantConfig`,
  ]);
  const config = plan.writes.find((w) => w.to.endsWith('_restaurantConfig'));
  assert.equal(config.from, 'settings/restaurantConfig');
  assert.equal(config.data.tenantId, DEFAULT_TENANT_ID, 'the copy carries the tenant');
  assert.equal(config.data.currency, 'USD', 'the body is copied, not replaced');
});

test('M-12: a second settings rename plans zero writes (source is kept)', () => {
  const rows = [{path: 'settings/restaurantConfig', data: {currency: 'USD'}}];
  const plan = planSettingsRename(rows);
  const applied = [
    ...rows,
    ...plan.writes.map((w) => ({path: w.to, data: w.data})),
  ];

  const second = planSettingsRename(applied);

  assert.equal(second.writes.length, 0, 'P1-6 bar: a second run changes nothing');
  assert.equal(second.conflicts.length, 0);
  assert.ok(second.unchanged >= 2, 'both the source and the target are recognised');
});

test('M-13: a settings document claimed by another tenant is never copied', () => {
  const plan = planSettingsRename([
    {path: 'settings/taxRates', data: {tenantId: 'other-client', clients: {}}},
  ]);

  assert.deepEqual(plan.conflicts, ['settings/taxRates']);
  assert.deepEqual(plan.writes, []);
});

test('M-14: the settings rename is a dry run by default', async () => {
  const db = fakeDb({'settings/restaurantConfig': {currency: 'USD'}});

  const report = await applySettingsRename(db, {apply: false});

  assert.equal(report.planned, 1);
  assert.equal(report.applied, 0);
  assert.equal(db.commits.length, 0, 'no batch was committed');
  assert.equal(db.docs.get(`settings/${DEFAULT_TENANT_ID}_restaurantConfig`), undefined);
});

test('M-15: the settings rename refuses an empty target tenant', () => {
  assert.throws(
      () => planSettingsRename([{path: 'settings/restaurantConfig', data: {}}], ''),
      MigrationConflictError,
  );
});

test('M-16: a nested path is not a settings document and is left alone', () => {
  const plan = planSettingsRename([
    {path: 'settings/tenant_a_nested/inner', data: {}},
  ]);

  assert.deepEqual(plan.writes, []);
  assert.deepEqual(plan.conflicts, []);
});

test('M-17: a target already claimed by another tenant is a conflict, never an overwrite', () => {
  const plan = planSettingsRename([
    {path: 'settings/taxRates', data: {clients: {}}},
    {
      path: `settings/${DEFAULT_TENANT_ID}_taxRates`,
      data: {tenantId: 'other-client'},
    },
  ]);

  assert.deepEqual(plan.conflicts, [`settings/${DEFAULT_TENANT_ID}_taxRates`]);
  assert.deepEqual(plan.writes, []);
});

test('M-18: applying the settings rename writes the copy, then a second apply writes nothing', async () => {
  const db = fakeDb({'settings/restaurantConfig': {currency: 'USD'}});

  const first = await applySettingsRename(db, {apply: true});
  assert.equal(first.applied, 1);
  assert.equal(first.planned, 1);
  const copied = db.docs.get(`settings/${DEFAULT_TENANT_ID}_restaurantConfig`);
  assert.equal(copied.currency, 'USD', 'the body is copied');
  assert.equal(copied.tenantId, DEFAULT_TENANT_ID);
  assert.ok(db.docs.get('settings/restaurantConfig'), 'the source is kept');

  const commitsAfterFirst = db.commits.length;
  const second = await applySettingsRename(db, {apply: true});
  assert.equal(second.planned, 0, 'a second run changes zero documents');
  assert.equal(second.applied, 0);
  assert.equal(db.commits.length, commitsAfterFirst);
});

test('M-19: the settings rename wrapper reports a foreign-tenant document and writes nothing', async () => {
  const db = fakeDb({'settings/taxRates': {tenantId: 'other-client'}});

  const report = await applySettingsRename(db, {apply: true});

  assert.deepEqual(report.conflicts, ['settings/taxRates']);
  assert.equal(report.applied, 0);
  assert.equal(db.commits.length, 0);
});

test('M-20: more than 400 settings documents are copied in batches', async () => {
  const seed = {};
  for (let i = 0; i < 401; i += 1) seed[`settings/doc${i}`] = {n: i};
  const db = fakeDb(seed);

  const report = await applySettingsRename(db, {apply: true});

  assert.equal(report.applied, 401);
  assert.equal(db.commits.length, 2, 'Firestore caps a batch at 500 writes');
  assert.equal(
      db.docs.get(`settings/${DEFAULT_TENANT_ID}_doc400`).tenantId,
      DEFAULT_TENANT_ID,
  );
});

test('M-21: migrate() wires the backfill and the settings rename, dry by default', async () => {
  // The only part of the wrapper a unit test cannot reach through a parameter is
  // the fireway entrypoint, which asks firebase-admin for a Firestore handle.
  // Stub exactly that call, so the wiring and its ordering are still proven.
  const admin = require('firebase-admin');
  const db = fakeDb({
    'orders/o1': {status: 'created'},
    'settings/restaurantConfig': {currency: 'USD'},
  });
  // `firestore` is a getter that calls ensureApp(); a plain assignment is
  // ignored, so shadow it on the namespace object and restore it afterwards.
  const descriptor = Object.getOwnPropertyDescriptor(admin, 'firestore');
  Object.defineProperty(admin, 'firestore', {
    value: () => db,
    configurable: true,
    writable: true,
  });
  const savedApply = process.env.MIGRATION_APPLY;
  delete process.env.MIGRATION_APPLY;

  try {
    const {migrate} = require('../lib/migrations/v004__tenancy_backfill.js');
    const report = await migrate();

    // `settings` is one of the backfilled collections, so the field backfill
    // plans both the order and the settings document.
    assert.equal(report.backfill.planned, 2, 'the field backfill ran first');
    assert.equal(report.settings.planned, 1, 'the settings rename ran after it');
    assert.equal(report.backfill.applied, 0, 'dry run by default');
    assert.equal(db.commits.length, 0);
  } finally {
    if (descriptor) {
      Object.defineProperty(admin, 'firestore', descriptor);
    } else {
      delete admin.firestore;
    }
    if (savedApply !== undefined) process.env.MIGRATION_APPLY = savedApply;
  }
});

test('M-6: v005 refuses malformed authority', () => {
  const plan = planRolesBackfill([
    {path: 'users/broken', data: {roles: 'owner'}},
  ]);
  assert.deepEqual(plan.conflicts, ['users/broken']);
  assert.deepEqual(plan.writes, []);
});
