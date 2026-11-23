/**
 * Phase 1 capability table (handoff §9.2) — pure, no imports, so `node --test`
 * can exercise the compiled `../lib/permissions.js` and so the table cannot
 * accidentally depend on request state.
 *
 * Why a table and not role checks at each call site: the target system has six
 * roles and several staff surfaces, and "is this a manager?" does not answer
 * "may this caller take money during a refund?". A capability is the thing a
 * handler needs; the role is only how a person acquires it. One table means a
 * new role cannot ship with undefined permissions (test P1-1 asserts the full
 * role × capability cartesian product), and a new capability cannot be granted
 * by accident.
 *
 * Fail-closed rules, all asserted in test/permissions.test.js:
 *   - an unknown role grants nothing;
 *   - `customer` grants nothing server-side (customer calls are authorised by
 *     ownership of the order, never by a capability);
 *   - a capability absent from the table is denied for every role.
 *
 * `counter` and `waiter` exist here before their client surfaces do: the server
 * vocabulary must be able to describe them before Phase 2 mints the claims, and
 * the Phase 1 acceptance case ("a waiter-only user is denied payment.take") is
 * expressed against this table.
 */

/** The six roles of the target system, plus the legacy `delivery` role. */
export type Role =
  | 'owner'
  | 'manager'
  | 'counter'
  | 'waiter'
  | 'kitchen'
  | 'delivery'
  | 'customer';

/** Every authority a staff handler can require. */
export type Capability =
  | 'order.create'
  | 'order.add_items'
  | 'order.transition'
  | 'order.set_item_ready'
  | 'order.flag_delay'
  | 'order.cancel'
  | 'payment.take'
  | 'payment.refund'
  | 'payment.reverse'
  | 'table.open'
  | 'table.close'
  | 'shift.clock'
  | 'report.read'
  | 'menu.manage'
  | 'staff.manage'
  | 'fleet.dispatch'
  | 'ledger.read';

/** The authoritative role list; the test asserts this is exactly the table's keys. */
export const ROLES: readonly Role[] = [
  'owner',
  'manager',
  'counter',
  'waiter',
  'kitchen',
  'delivery',
  'customer',
];

/** The authoritative capability list; the test asserts every one is granted somewhere. */
export const CAPABILITIES: readonly Capability[] = [
  'order.create',
  'order.add_items',
  'order.transition',
  'order.set_item_ready',
  'order.flag_delay',
  'order.cancel',
  'payment.take',
  'payment.refund',
  'payment.reverse',
  'table.open',
  'table.close',
  'shift.clock',
  'report.read',
  'menu.manage',
  'staff.manage',
  'fleet.dispatch',
  'ledger.read',
];

const CAPABILITIES_BY_ROLE: Record<Role, readonly Capability[]> = {
  // Owner: everything, across every branch.
  owner: CAPABILITIES,

  // Manager: runs one branch — takes money, refunds, manages menu, reads
  // reports. Staff management and the ledger's raw read stay with the owner.
  manager: [
    'order.create',
    'order.add_items',
    'order.transition',
    'order.set_item_ready',
    'order.flag_delay',
    'order.cancel',
    'payment.take',
    'payment.refund',
    'payment.reverse',
    'table.open',
    'table.close',
    'shift.clock',
    'report.read',
    'menu.manage',
    'fleet.dispatch',
  ],

  // Counter: takes orders and money; refunds and reversals need a manager.
  counter: [
    'order.create',
    'order.add_items',
    'order.transition',
    'payment.take',
    'table.open',
    'table.close',
    'shift.clock',
  ],

  // Waiter: seats, takes rounds, brings the bill. No money authority.
  waiter: [
    'order.create',
    'order.add_items',
    'order.transition',
    'table.open',
    'table.close',
    'shift.clock',
  ],

  // Kitchen: the ticket queue and its states.
  kitchen: [
    'order.transition',
    'order.set_item_ready',
    'order.flag_delay',
  ],

  // Delivery: the legacy driver role. `fleet.dispatch` is kept here because the
  // existing callable admits every staff role today (access.test.js pins the
  // set); Phase 2 narrows it when the dispatcher surface is defined.
  delivery: ['order.transition', 'fleet.dispatch'],

  // Customer: nothing server-side. Ownership authorises their calls.
  customer: [],
};

/** The capabilities granted to a role; an unknown role grants none. */
export function grantsFor(role: string): readonly Capability[] {
  return Object.prototype.hasOwnProperty.call(CAPABILITIES_BY_ROLE, role) ?
    CAPABILITIES_BY_ROLE[role as Role] :
    [];
}

/** True when `role` holds `capability`. Unknown roles and capabilities fail closed. */
export function can(role: string, capability: string): boolean {
  return (grantsFor(role) as readonly string[]).includes(capability);
}

/**
 * True when ANY of the caller's roles holds the capability — the shape claims
 * take once a person may hold several roles (handoff §2.1: counter + floor).
 * Non-array or non-string entries are ignored rather than trusted.
 */
export function canAny(
    roles: readonly unknown[] | null | undefined,
    capability: string,
): boolean {
  if (!Array.isArray(roles)) return false;
  return roles.some((role) => typeof role === 'string' && can(role, capability));
}
