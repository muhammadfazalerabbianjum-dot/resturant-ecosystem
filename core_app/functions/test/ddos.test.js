/**
 * B8-3 DDOS bucket/threshold tests (node:test, runs against the compiled
 * `lib/ddos.js`). The scenario in the last test proves the exact behavior the
 * batch requires: threshold 5 -> the 6th denial in a bucket alerts exactly at
 * 5, then stays quiet until the next minute resets the bucket.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  DEFAULT_DDOS_ALERT_THRESHOLD,
  parseDdosAlertThreshold,
  nextDdosBucketCount,
  shouldTriggerDdosAlert,
} = require('../lib/ddos.js');

const minute = (m) => new Date(2026, 0, 1, 10, m, 0);
const kMinute = (d) => d.getMinutes().toString();

test('parseDdosAlertThreshold FAILS CLOSED to the default (50)', () => {
  assert.equal(DEFAULT_DDOS_ALERT_THRESHOLD, 50);
  assert.equal(parseDdosAlertThreshold('5'), 5);
  assert.equal(parseDdosAlertThreshold(5), 5);
  assert.equal(parseDdosAlertThreshold('50'), 50);
  // malformed / non-positive / fractional / absent
  assert.equal(parseDdosAlertThreshold('0'), 50);
  assert.equal(parseDdosAlertThreshold('-3'), 50);
  assert.equal(parseDdosAlertThreshold('4.5'), 50);
  assert.equal(parseDdosAlertThreshold(0), 50);
  assert.equal(parseDdosAlertThreshold(-9), 50);
  assert.equal(parseDdosAlertThreshold('abc'), 50);
  assert.equal(parseDdosAlertThreshold(undefined), 50);
  assert.equal(parseDdosAlertThreshold(null), 50);
  assert.equal(parseDdosAlertThreshold({}), 50);
  assert.equal(parseDdosAlertThreshold(true), 50);
});

test('nextDdosBucketCount counts up within a minute, resets across minutes', () => {
  // first denial -> 1
  assert.equal(nextDdosBucketCount(undefined, minute(30)), 1);
  // same bucket continues the count
  assert.equal(
    nextDdosBucketCount(
      { currentBucket: kMinute(minute(30)), denyCount: 4 },
      minute(30),
    ),
    5,
  );
  // different minute resets back to 1
  assert.equal(
    nextDdosBucketCount(
      { currentBucket: kMinute(minute(30)), denyCount: 4 },
      minute(31),
    ),
    1,
  );
  // missing denyCount increments from the effective 0 -> 1
  assert.equal(
    nextDdosBucketCount(
      { currentBucket: kMinute(minute(30)), denyCount: undefined },
      minute(30),
    ),
    1,
  );
});

test('shouldTriggerDdosAlert fires exactly at threshold, not above', () => {
  assert.equal(shouldTriggerDdosAlert(5, 5), true);
  assert.equal(shouldTriggerDdosAlert(4, 5), false);
  assert.equal(shouldTriggerDdosAlert(6, 5), false);
  assert.equal(shouldTriggerDdosAlert(50, 50), true);
  assert.equal(shouldTriggerDdosAlert(51, 50), false);
});

test('scenario: threshold 5 -> alerts at exactly 5, not again until bucket resets', () => {
  const threshold = 5;
  const now = new Date(2026, 0, 1, 10, 42, 30); // minute 42
  const laterSameMinute = new Date(2026, 0, 1, 10, 42, 59);
  const nextMinute = new Date(2026, 0, 1, 10, 43, 0);

  // Denials 1..6 in the same bucket.
  let state;
  const alerts = [];
  for (let i = 1; i <= 6; i++) {
    const count = nextDdosBucketCount(state, i === 1 ? now : laterSameMinute);
    state = { currentBucket: kMinute(laterSameMinute), denyCount: count };
    alerts.push(shouldTriggerDdosAlert(count, threshold));
  }
  // count hits 5 (alert), then 6 (no re-alert in the same bucket).
  assert.deepEqual(alerts, [false, false, false, false, true, false]);

  // New minute: bucket resets; a fresh climb to 5 alerts again.
  let count = nextDdosBucketCount(state, nextMinute);
  assert.equal(count, 1);
  assert.equal(shouldTriggerDdosAlert(count, threshold), false);
  for (let i = 2; i <= 5; i++) {
    count = nextDdosBucketCount(
      { currentBucket: kMinute(nextMinute), denyCount: i - 1 },
      nextMinute,
    );
    const alert = shouldTriggerDdosAlert(count, threshold);
    if (i === 5) assert.equal(alert, true);
    else assert.equal(alert, false);
  }
});