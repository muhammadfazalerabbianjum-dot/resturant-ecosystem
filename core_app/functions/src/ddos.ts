/**
 * DDOS alerting logic (B8-3), extracted into a pure module so the bucket
 * counter and the threshold decision are unit-testable without Firestore or
 * Remote Config. The `onFirestorePermissionDenied` Cloud Function reads the
 * threshold once per run from Remote Config (via `parseDdosAlertThreshold`)
 * and drives both `nextDdosBucketCount` and `shouldTriggerDdosAlert`.
 */

export const DEFAULT_DDOS_ALERT_THRESHOLD = 50;

/** Shape of the `securityMetrics/ddosCounters` doc persisted between events. */
export interface DdosBucketState {
  currentBucket?: string;
  denyCount?: number;
}

/**
 * Parse a Remote Config value into a positive integer threshold.
 * Malformed, non-positive, fractional, or absent values FAIL CLOSED to the
 * documented default (50) — a bad config never disables the alert.
 */
export function parseDdosAlertThreshold(raw: unknown): number {
  if (typeof raw === 'number' && Number.isInteger(raw) && raw > 0) return raw;
  if (typeof raw === 'string') {
    const n = Number(raw);
    if (Number.isInteger(n) && n > 0) return n;
  }
  return DEFAULT_DDOS_ALERT_THRESHOLD;
}

/**
 * Increment the per-minute denial counter, resetting to 1 when the calendar
 * minute rolls over (the bucket). Returns the counter for the current bucket.
 */
export function nextDdosBucketCount(
    prev: DdosBucketState | undefined,
    now: Date,
): number {
  const minuteBucket = now.getMinutes().toString();
  if (!prev) return 1;
  if (prev.currentBucket !== minuteBucket) return 1;
  return (prev.denyCount || 0) + 1;
}

/**
 * Alert exactly once when the bucket count reaches the configured threshold.
 * Because every later denial in the same bucket pushes `count` strictly above
 * the threshold, the alert fires at threshold and then stays quiet until the
 * next minute resets the bucket (count returns to 1 and climbs again).
 */
export function shouldTriggerDdosAlert(count: number, threshold: number): boolean {
  return count === threshold;
}
