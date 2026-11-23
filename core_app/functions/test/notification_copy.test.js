/**
 * B8-1 localized push-copy dictionary tests (node:test, runs against the
 * compiled `lib/notification_copy.js`).
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  NOTIFICATION_LOCALES,
  notificationCopyKeys,
  verifyNotificationCopyParity,
  resolveNotificationLocale,
  renderNotification,
} = require('../lib/notification_copy.js');

test('parity: every locale declares every key (en + ar), all non-empty', () => {
  const defects = verifyNotificationCopyParity();
  assert.deepEqual(defects, [], `parity defects: ${defects.join(', ')}`);

  const keys = notificationCopyKeys();
  for (const locale of NOTIFICATION_LOCALES) {
    for (const key of keys) {
      assert.ok(key.length > 0, 'key must be non-empty');
      const copy = renderNotification(key, locale);
      assert.ok(copy.title.trim().length > 0, `${locale}.${key} title empty`);
      assert.ok(copy.body.trim().length > 0, `${locale}.${key} body empty`);
    }
  }
});

test('en copy matches the pre-localization strings (no accidental drift)', () => {
  assert.equal(renderNotification('cartRecovery', 'en').title, 'Still hungry?');
  assert.equal(
    renderNotification('cartRecovery', 'en').body,
    'Your cart is waiting for you!',
  );
  assert.equal(renderNotification('orderPreparing', 'en').title, 'Order Confirmed!');
  assert.equal(renderNotification('newReservation', 'en', {
    customerName: 'Omar', partySize: 3, time: '8:00 PM',
  }).body, 'Omar booked 3 guest(s) at 8:00 PM.');
});

test('ar renders Arabic copy (not the English fallback)', () => {
  const copy = renderNotification('orderPreparing', 'ar');
  assert.notEqual(copy.title, 'Order Confirmed!');
  assert.ok(
    /[\u0600-\u06FF]/.test(copy.title + copy.body),
    'Arabic copy must contain Arabic script characters',
  );
});

test('malformed/unknown locales FAIL CLOSED to en', () => {
  const en = renderNotification('cartRecovery', 'en');
  for (const bad of ['fr', 'es-ES', '', 'abc', 123, null, undefined, {}, []]) {
    const copy = renderNotification('cartRecovery', bad);
    assert.deepEqual(copy, en, `locale ${JSON.stringify(bad)} should fall back to en`);
  }
});

test('region tags resolve: ar-EG -> ar, ar/AR/AR-SA -> ar', () => {
  assert.equal(resolveNotificationLocale('ar'), 'ar');
  assert.equal(resolveNotificationLocale('ar-EG'), 'ar');
  assert.equal(resolveNotificationLocale('ar-SA'), 'ar');
  assert.equal(resolveNotificationLocale('AR'), 'ar');
  assert.equal(resolveNotificationLocale('en-US'), 'en');
  assert.equal(resolveNotificationLocale('en'), 'en');
  assert.equal(resolveNotificationLocale('fr-FR'), 'en');
});

test('placeholder substitution keeps variable parts locale-specific', () => {
  const en = renderNotification('newReservation', 'en', {
    customerName: 'Omar', partySize: 4, time: '7:30 PM',
  });
  assert.ok(en.body.includes('Omar'));
  assert.ok(en.body.includes('4'));
  assert.ok(en.body.includes('7:30 PM'));

  const arCopy = renderNotification('newReservation', 'ar', {
    customerName: 'عمر', partySize: 4, time: '7:30 م',
  });
  assert.ok(arCopy.body.includes('عمر'));
  assert.ok(arCopy.body.includes('7:30 م'));

  const ddos = renderNotification('ddosAlert', 'en', { ip: '203.0.113.9' });
  assert.ok(ddos.body.includes('203.0.113.9'));
});

test('missing values keep the {token} literal (never blank strings)', () => {
  const copy = renderNotification('newReservation', 'en');
  assert.ok(copy.body.includes('{customerName}'));
  assert.ok(copy.body.includes('{partySize}'));
  assert.ok(copy.body.includes('{time}'));
});

test('renderNotification throws on an unknown key (fail-closed, no fake push)', () => {
  assert.throws(
    () => renderNotification('does-not-exist', 'en'),
    /missing for key "does-not-exist"/,
  );
});