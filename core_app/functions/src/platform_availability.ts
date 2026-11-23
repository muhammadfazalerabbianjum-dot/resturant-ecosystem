/**
 * UI-9 (p19) T-3 — menu availability → platform catalog sync.
 *
 * The app's own `menus/{itemId}` write has ALREADY committed when this runs,
 * so the push is fail-safe by design: outcomes are classified (ok / retry /
 * dead_letter), a platform outage is retried and then recorded in the
 * dead-letter queue — the caller NEVER sees a throw (the write path is never
 * blocked by a platform).
 *
 * PURE: the HTTP client, targets (config rows) and DLQ are injected through
 * [AvailabilityDeps] (the money.test.js pattern — fixtures supply the HTTP
 * envelopes from test/fixtures/platform/platform_http_responses.json).
 */
import {
  DishAvailabilityChange,
  PlatformCatalogRequest,
  PlatformDeadLetter,
  PlatformMapper,
  isPlatformId,
  describeShape,
} from './platform_ingestion';

/** One enabled platform row the sync may push to. */
export interface AvailabilityTarget {
  platformId: string;
  storeId: string;
  mapper: PlatformMapper | null;
}

/** The change-detection result: strictly-when-present, null = nothing to do. */
export type AvailabilityChangeDetection = {isAvailable: boolean} | null;

/** Ports the sync needs (injected; never global). */
export interface AvailabilityDeps {
  /** 0-based attempt of the CURRENT round (0 on the first push). */
  attempt: number;
  /** Total attempts before a retryable failure dead-letters. */
  maxAttempts: number;
  targets(): Promise<AvailabilityTarget[]> | AvailabilityTarget[];
  callPlatform(request: PlatformCatalogRequest): Promise<{status?: number}>;
  publishDeadLetter(entry: PlatformDeadLetter): Promise<void> | void;
  log(event: Record<string, unknown>): void;
}

/** The per-invocation outcome table (exactly these five keys). */
export interface AvailabilitySummary {
  pushed: string[];
  retried: string[];
  deadLettered: string[];
  skipped: string[];
  failed: boolean;
}

/** Reads a strictly-boolean `isAvailable` field, or null when absent/bad. */
function readAvailability(value: unknown): boolean | null {
  if (value === null || typeof value !== 'object') return null;
  const candidate = (value as Record<string, unknown>).isAvailable;
  return typeof candidate === 'boolean' ? candidate : null;
}

/**
 * Change detection from the EXISTING menu write (strictly-when-present):
 * - both sides present + differ ⇒ the new state (a restore or a suspension)
 * - identical / non-boolean after ⇒ null (no push)
 * - before missing (newly created doc) ⇒ only a SUSPENDED item needs a push;
 *   a newly published available item requires nothing
 */
export function detectAvailabilityChange(
    before: unknown, after: unknown,
): AvailabilityChangeDetection {
  const afterAvailable = readAvailability(after);
  if (afterAvailable === null) return null;
  const beforeAvailable = readAvailability(before);
  if (beforeAvailable === afterAvailable) return null;
  if (beforeAvailable === null) {
    return afterAvailable ? null : {isAvailable: false};
  }
  return {isAvailable: afterAvailable};
}

/** The planned push per platform + the targets that were skipped (and why). */
export interface AvailabilityPlan {
  requests: {platformId: string; request: PlatformCatalogRequest}[];
  skipped: {platformId: string; reason: string}[];
}

/**
 * Builds the per-platform catalog requests (documented payload shapes via the
 * mapper). An invalid target is SKIPPED and reported — never pushed blind.
 */
export function planAvailabilityPushes(input: {
  change: DishAvailabilityChange;
  targets: AvailabilityTarget[];
}): AvailabilityPlan {
  const plan: AvailabilityPlan = {requests: [], skipped: []};
  for (const target of input.targets) {
    if (typeof target.storeId !== 'string' || target.storeId.length === 0) {
      plan.skipped.push({
        platformId: target.platformId, reason: 'missing_store_id',
      });
      continue;
    }
    if (!isPlatformId(target.platformId)) {
      plan.skipped.push({
        platformId: target.platformId, reason: 'unknown_platform',
      });
      continue;
    }
    if (!target.mapper) {
      plan.skipped.push({
        platformId: target.platformId, reason: 'missing_mapper',
      });
      continue;
    }
    plan.requests.push({
      platformId: target.platformId,
      request: target.mapper.buildAvailabilityRequest(
          target.storeId, input.change,
      ),
    });
  }
  return plan;
}

/** Outcome of one platform push attempt. */
export interface PushOutcome {
  action: 'ok' | 'retry' | 'dead_letter';
}

/** True for the outcomes that are worth another attempt. */
function isRetryableStatus(status: number): boolean {
  return status === 0 || status === 429 || status >= 500;
}

/**
 * Classifies one platform HTTP response: 2xx = ok; rate-limit/5xx/network
 * (status 0) = retry until attempts are exhausted; every other 4xx is a
 * permanent rejection that dead-letters immediately.
 */
export function classifyPushOutcome(
    status: number, attempt: number, maxAttempts: number,
): PushOutcome {
  if (status >= 200 && status < 300) return {action: 'ok'};
  if (!isRetryableStatus(status)) return {action: 'dead_letter'};
  if (attempt >= Math.max(maxAttempts, 1) - 1) {
    return {action: 'dead_letter'};
  }
  return {action: 'retry'};
}

/**
 * The T-3 orchestration: plan → push → classify per platform → record.
 * NEVER throws (the menus write already committed); `failed` stays false —
 * every failure lands in `retried`/`deadLettered` + the operator log.
 */
export async function syncAvailability(
    deps: AvailabilityDeps, change: DishAvailabilityChange | null,
): Promise<AvailabilitySummary> {
  const summary: AvailabilitySummary = {
    pushed: [], retried: [], deadLettered: [], skipped: [], failed: false,
  };
  try {
    if (!change || typeof change.isAvailable !== 'boolean') return summary;
    const targets = await deps.targets();
    const plan = planAvailabilityPushes({change, targets});
    for (const skipped of plan.skipped) {
      summary.skipped.push(skipped.platformId);
    }
    for (const planned of plan.requests) {
      let status = 0;
      try {
        const response = await deps.callPlatform(planned.request);
        status = typeof response?.status === 'number' ? response.status : 0;
      } catch {
        status = 0; // network error = retryable (fail-safe, never a throw)
      }
      const outcome = classifyPushOutcome(
          status, deps.attempt, deps.maxAttempts,
      );
      if (outcome.action === 'ok') {
        summary.pushed.push(planned.platformId);
        continue;
      }
      if (outcome.action === 'retry') {
        summary.retried.push(planned.platformId);
        deps.log({
          event: 'platform_availability_push_failed',
          platformId: planned.platformId,
          menuItemId: change.menuItemId,
          status,
          action: 'retry',
        });
        continue;
      }
      const reason = isRetryableStatus(status) ?
          'attempts_exhausted' : `platform_rejected_${status}`;
      summary.deadLettered.push(planned.platformId);
      deps.log({
        event: 'platform_availability_push_failed',
        platformId: planned.platformId,
        menuItemId: change.menuItemId,
        status,
        action: 'dead_letter',
      });
      await deps.publishDeadLetter({
        source: 'platform_availability',
        platformId: planned.platformId,
        sourceKey: change.menuItemId,
        reason,
        payloadShape: describeShape({id: change.menuItemId}),
      });
    }
  } catch (error) {
    // Fail-safe: the app's own write already committed — record, never throw.
    deps.log({
      event: 'platform_availability_sync_failed',
      error: error instanceof Error ? error.message : String(error),
    });
  }
  return summary;
}
