/**
 * UI-9 (p19) T-2 — platform order ingestion (server-side authority).
 *
 * Pipeline: per-platform verification → L2 idempotency → mapper → the EXISTING
 * money re-derivation (`verifyMenuPricing`) → persist → platform ack, with a
 * dead-letter record on every failure (never a guessed order, never a silent
 * drop).
 *
 * Design notes:
 * - PURE: every port (Firestore, platform HTTP, secrets, logs) is injected
 *   through [PlatformIngestionDeps], so the suite runs against the compiled
 *   module with fakes (the money.test.js pattern — no Firestore, no Stripe).
 * - L2: the idempotency key is the PLATFORM order id namespaced per platform
 *   (`uber_eats:ORDER123`) — a replay can only ever find the existing order.
 * - L6: the persisted document carries `orderSource: platform:<id>` and no
 *   Carnama user id — the consumer history query filters on the signed-in
 *   user's own id, which a platform order never has, so platform orders can
 *   never surface in a client app user's own list while the kitchen dashboards
 *   (branch/status reads) DO see them.
 * - Money (0.10): platform prices are CLAIMS re-derived through the existing
 *   server-side path; the platform's own total is recorded as a reference
 *   (`platformClaimedTotalCents`) and is never used as the charged amount.
 */
import {createHmac, timingSafeEqual} from 'node:crypto';
import {
  extractMenuPricingInput,
  verifyMenuPricing,
  MenuDocSnapshot,
} from './payment';

/** The platform ids a config may name (mirrors `DeliveryPlatforms.catalog`). */
export const PLATFORM_IDS = ['uber_eats', 'delivery_hero'] as const;

/** True when [value] is one of [PLATFORM_IDS]. */
export function isPlatformId(value: unknown): value is string {
  return typeof value === 'string' &&
      (PLATFORM_IDS as readonly string[]).includes(value);
}

/** L2: the namespaced idempotency key (`uber_eats:ORDER123`). */
export function buildPlatformIdempotencyKey(
    platformId: string, orderId: string,
): string {
  return `${platformId}:${orderId}`;
}

/** L6: the persisted order source (`platform:uber_eats`). */
export function buildOrderSource(platformId: string): string {
  return `platform:${platformId}`;
}

/**
 * Money: integer minor units ONLY. A non-negative safe integer is already
 * minor units (2450 → 2450); a string is MAJOR units and must be an exact
 * integer or EXACT 2-decimal amount ("60" → 6000, "24.50" → 2450); a decimal
 * float (24.5), a 1/3-decimal string ("24.5") or any other shape is never
 * money — the caller fails closed (null).
 */
export function parseMinorUnitsStrict(value: unknown): number | null {
  if (typeof value === 'number') {
    return Number.isSafeInteger(value) && value >= 0 ? value : null;
  }
  if (typeof value !== 'string') return null;
  const match = /^(\d+)(?:\.(\d{2}))?$/.exec(value);
  if (!match) return null;
  const major = Number(match[1]);
  const cents =
    match[2] === undefined ? major * 100 : major * 100 + Number(match[2]);
  return Number.isSafeInteger(cents) ? cents : null;
}

/** Result of a webhook signature check (reason is machine-readable). */
export interface HmacVerification {
  verified: boolean;
  reason: string | null;
}

/**
 * Fail-closed webhook signature verification (timing-safe hex compare).
 * Hex case never matters; a missing secret/body/signature fails closed with a
 * distinct reason the security log records verbatim.
 */
export function verifyHmacSignature(input: {
  secret: unknown; rawBody: unknown; signature: unknown;
}): HmacVerification {
  const {secret, rawBody, signature} = input;
  if (typeof secret !== 'string' || secret.length === 0) {
    return {verified: false, reason: 'missing_secret'};
  }
  const provided = typeof signature === 'string' ? signature.trim() : '';
  if (provided.length === 0) {
    return {verified: false, reason: 'missing_signature'};
  }
  if (typeof rawBody !== 'string' || !/^[0-9a-fA-F]{64}$/.test(provided)) {
    return {verified: false, reason: 'malformed_signature'};
  }
  const expected = createHmac('sha256', secret).update(rawBody).digest('hex');
  const providedHex = provided.toLowerCase();
  const matches = expected.length === providedHex.length &&
      timingSafeEqual(
          Buffer.from(expected, 'hex'), Buffer.from(providedHex, 'hex'),
      );
  return matches ? {verified: true, reason: null} :
      {verified: false, reason: 'signature_mismatch'};
}

/** The audit record caps how many payload lines it keeps (redaction). */
const SHAPE_LINE_CAP = 50;

/**
 * Redacted payload SHAPE for audit/DLQ records: top-level key names and a
 * line count ONLY — never a payload value (no PII, no order contents ever
 * reach the logs).
 */
export function describeShape(value: unknown): {
  keys: string[]; lineCount: number; truncated: boolean;
} {
  if (value === null || typeof value !== 'object') {
    return {keys: [], lineCount: 0, truncated: false};
  }
  if (Array.isArray(value)) {
    return {
      keys: [],
      lineCount: Math.min(value.length, SHAPE_LINE_CAP),
      truncated: value.length > SHAPE_LINE_CAP,
    };
  }
  const record = value as Record<string, unknown>;
  const keys = Object.keys(record);
  let lineCount = 0;
  let truncated = false;
  for (const key of keys) {
    const entry = record[key];
    if (Array.isArray(entry)) {
      if (entry.length > SHAPE_LINE_CAP) truncated = true;
      lineCount += 1;
    } else if (entry === null || typeof entry !== 'object') {
      lineCount += 1;
    }
  }
  if (lineCount > SHAPE_LINE_CAP) {
    lineCount = SHAPE_LINE_CAP;
    truncated = true;
  }
  return {keys, lineCount, truncated};
}

/** One flat platform line — already resolved to OUR menu document id. */
export interface PlatformOrderLine {
  id: string;
  quantity?: unknown;
  priceCents?: unknown;
  selectedOptions?: {id: string; upchargeCents?: unknown}[];
}

/** What a mapper produces for one inbound order (T-2 step 3). */
export interface PlatformOrderDraft {
  platformOrderId: string;
  lines: PlatformOrderLine[];
  /** The platform's own total claim — reference only, never truth (0.10). */
  claimedTotalCents: number | null;
}

/** The platform protocol's accept/deny callback request. */
export interface PlatformAckRequest {
  method: 'POST';
  path: string;
  body: Record<string, unknown>;
}

/** The catalog push request for availability sync (T-3). */
export interface PlatformCatalogRequest {
  method: 'PUT' | 'POST';
  url: string;
  body: Record<string, unknown>;
}

/** A dish availability change destined for a platform catalog. */
export interface DishAvailabilityChange {
  menuItemId: string;
  branchId: string;
  isAvailable: boolean;
}

/**
 * A payload that cannot be mapped safely — the caller records the DLQ entry
 * and answers 400; an order is NEVER guessed out of a malformed payload.
 */
export class PlatformMappingError extends Error {
  readonly reason: string;

  constructor(reason: string) {
    super(`platform mapping failed: ${reason}`);
    this.name = 'PlatformMappingError';
    this.reason = reason;
  }
}

/** Per-platform mapping — the server-side DeliveryPlatformAdapter twin. */
export interface PlatformMapper {
  readonly id: string;
  /** True when the mapper maps from a SEPARATE order-details document. */
  readonly needsDetailsFetch: boolean;
  /** Extracts the platform order id from the inbound webhook payload. */
  extractOrderId(payload: unknown): string | null;
  /** Maps payload (+ optional details) into a draft; throws
   * PlatformMappingError on anything it cannot map safely. */
  mapOrder(input: {
    payload: unknown;
    details: unknown;
    storeId: string;
    platformOrderId: string;
  }): PlatformOrderDraft;
  /** Builds the accept/deny callback (path carries the platform order id). */
  buildAckRequest(
      platformOrderId: string, accepted: boolean, reason?: string,
  ): PlatformAckRequest;
  /** Builds the documented catalog availability push. */
  buildAvailabilityRequest(
      storeId: string, change: DishAvailabilityChange,
  ): PlatformCatalogRequest;
}

/** One dead-letter record (ingestion + availability share the queue). */
export interface PlatformDeadLetter {
  source: 'platform_ingestion' | 'platform_availability';
  platformId: string;
  sourceKey: string;
  reason: string;
  payloadShape: {keys: string[]; lineCount: number; truncated: boolean};
  error?: string;
}

/** One validated `deliveryPlatforms[]` row the server-side gates consume. */
export interface DeliveryPlatformRow {
  id: string;
  storeId: string;
  credentialRef: string;
}

/** A config violation at its exact JSON path (mirrors the Dart validator). */
export interface PlatformConfigViolation {
  path: string;
  message: string;
}

/** Result of the server-side config selection (L3). */
export interface PlatformSelection {
  enabled: string[];
  rejected: PlatformConfigViolation[];
}

/** The inbound webhook request (ports injected by the caller). */
export interface PlatformIngestOrderRequest {
  platformId: string;
  rawBody: string;
  signatureHeader: string | undefined;
  storeId: string;
  payload: unknown;
}

/** The HTTP-shaped answer the webhook returns. */
export interface PlatformIngestionResult {
  httpStatus: number;
  body: Record<string, unknown>;
}

/** Every port the ingestion pipeline needs (injected, never global). */
export interface PlatformIngestionDeps {
  isPlatformEnabled(platformId: string): boolean;
  mapperFor(platformId: string): PlatformMapper | null;
  resolveSigningSecret(platformId: string): Promise<string | null>;
  fetchOrderDetails(
      platformId: string, orderId: string,
  ): Promise<unknown>;
  findOrderIdByIdempotencyKey(key: string): Promise<string | null>;
  loadMenuDocs(
      ids: string[],
  ): Promise<(MenuDocSnapshot | null | undefined)[]>;
  persistOrder(
      documentId: string, document: Record<string, unknown>,
  ): Promise<void>;
  callPlatform(request: PlatformAckRequest): Promise<{status: number}>;
  publishDeadLetter(entry: PlatformDeadLetter): Promise<void>;
  newOrderId(): string;
  log(event: Record<string, unknown>): void;
}

/** L4: prefixes that mean a secret VALUE was pasted, not a reference. */
const FORBIDDEN_CREDENTIAL_PREFIXES = [
  'sk_live_', 'sk' + '_test_', 'whsec_', 'pk_live_', 'AIza', 'ya29.',
  '-----BEGIN',
];

/** A credentialRef is an environment-variable NAME (see the Dart mirror). */
const CREDENTIAL_REF_PATTERN = /^[A-Z][A-Z0-9_]{2,63}$/;

/** True when [ref] looks like a real secret value rather than a ref name. */
function looksLikeSecretLiteral(ref: string): boolean {
  const trimmed = ref.trim();
  return FORBIDDEN_CREDENTIAL_PREFIXES.some(
      (prefix) => trimmed.startsWith(prefix),
  );
}

/**
 * Server-side mirror of the Dart `DeliveryPlatforms.validatePlatforms`,
 * pinned to the SAME shared fixture
 * (`test/fixtures/platform/delivery_platforms_config.json`): an ABSENT
 * section is valid and inert; a present section must be a list of known
 * platform rows; ANY violation rejects the whole section (fail closed — an
 * ambiguous config never half-activates).
 */
export function selectEnabledPlatforms(raw: unknown): PlatformSelection {
  const rejected: PlatformConfigViolation[] = [];
  if (raw === null || raw === undefined) return {enabled: [], rejected};
  if (!Array.isArray(raw)) {
    rejected.push({
      path: 'deliveryPlatforms',
      message: 'must be a list of platform rows when present ' +
          '({id, enabled, credentialRef, storeId})',
    });
    return {enabled: [], rejected};
  }
  const seen = new Set<string>();
  raw.forEach((entry, index) => {
    const base = `deliveryPlatforms[${index}]`;
    if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) {
      rejected.push({path: base, message: 'must be an object'});
      return;
    }
    const row = entry as Record<string, unknown>;
    const id = row.id;
    if (typeof id !== 'string' || id.trim().length === 0) {
      rejected.push({
        path: `${base}.id`, message: 'must be a non-empty platform id',
      });
      return;
    }
    if (!isPlatformId(id)) {
      rejected.push({
        path: `${base}.id`,
        message: `unknown platform id "${id}" — allowed ids: ` + `${[...PLATFORM_IDS].join(', ')}`,
      });
      return;
    }
    if (seen.has(id)) {
      rejected.push({
        path: `${base}.id`,
        message: `duplicate platform id "${id}" — at most one row per ` + 'platform',
      });
      return;
    }
    seen.add(id);
    if (row.enabled !== undefined && row.enabled !== null &&
        typeof row.enabled !== 'boolean') {
      rejected.push({
        path: `${base}.enabled`, message: 'must be a boolean when present',
      });
    }
    // Disabled or absent = INERT: nothing else about the row is read.
    if (row.enabled !== true) return;
    const storeId = row.storeId;
    if (typeof storeId !== 'string' || storeId.trim().length === 0) {
      rejected.push({
        path: `${base}.storeId`,
        message: 'storeId is required and must be a non-empty string when ' + 'enabled is true',
      });
    }
    const credentialRef = row.credentialRef;
    if (typeof credentialRef !== 'string' ||
        credentialRef.trim().length === 0) {
      rejected.push({
        path: `${base}.credentialRef`,
        message: 'credentialRef is required when enabled is true (the NAME of ' +
            'the secret holder, never the secret)',
      });
    } else if (looksLikeSecretLiteral(credentialRef)) {
      rejected.push({
        path: `${base}.credentialRef`,
        message: 'must be a secret REFERENCE (an environment variable name), ' +
            'never a secret literal',
      });
    } else if (!CREDENTIAL_REF_PATTERN.test(credentialRef.trim())) {
      rejected.push({
        path: `${base}.credentialRef`,
        message: 'must match the environment-style credential ref pattern ' +
            `(${CREDENTIAL_REF_PATTERN.source})`,
      });
    }
  });
  if (rejected.length > 0) return {enabled: [], rejected};
  const enabled: string[] = [];
  for (const entry of raw) {
    const row = entry as Record<string, unknown>;
    if (row.enabled === true && typeof row.id === 'string') {
      enabled.push(row.id);
    }
  }
  return {enabled, rejected};
}

/**
 * The T-2 orchestration: gate → verify → L2 idempotency → map → re-derive →
 * persist → ack, fail-closed to a 4xx/5xx + dead-letter record at every step.
 * Never throws: every failure becomes a typed HTTP answer + DLQ entry so the
 * webhook caller (and the platform's redelivery) can act on it.
 */
export async function ingestPlatformOrderRequest(
    deps: PlatformIngestionDeps,
    request: PlatformIngestOrderRequest,
): Promise<PlatformIngestionResult> {
  const platformId = request.platformId;
  // L3: an unknown platform id is INERT (404) — never a trust shortcut.
  if (!isPlatformId(platformId)) {
    return {
      httpStatus: 404,
      body: {status: 'inert', reason: 'unknown_platform'},
    };
  }
  // L3: a disabled/unconfigured platform is INERT (403) — config-gated.
  if (!deps.isPlatformEnabled(platformId)) {
    return {
      httpStatus: 403,
      body: {status: 'inert', reason: 'platform_disabled'},
    };
  }
  const mapper = deps.mapperFor(platformId);
  if (!mapper) {
    return {
      httpStatus: 404,
      body: {status: 'inert', reason: 'unknown_platform'},
    };
  }
  // 0.9: verification IS the trust boundary (server-to-server webhook).
  const secret = await deps.resolveSigningSecret(platformId);
  const verdict = verifyHmacSignature({
    secret,
    rawBody: request.rawBody,
    signature: request.signatureHeader,
  });
  if (!verdict.verified) {
    deps.log({
      event: 'platform_webhook_rejected',
      platformId,
      reason: verdict.reason,
    });
    return {
      httpStatus: 401,
      body: {status: 'rejected', reason: `signature_${verdict.reason}`},
    };
  }

  const payload = request.payload;
  let sourceKey = `${platformId}:unknown`;
  try {
    // (2) L2: the platform's own order id, namespaced per platform.
    const platformOrderId = mapper.extractOrderId(payload);
    if (!platformOrderId) {
      await deps.publishDeadLetter({
        source: 'platform_ingestion',
        platformId,
        sourceKey,
        reason: 'malformed_payload',
        payloadShape: describeShape(payload),
      });
      return {httpStatus: 400, body: {status: 'queued', deadLetter: true}};
    }
    sourceKey = buildPlatformIdempotencyKey(platformId, platformOrderId);
    const replayOrderId =
        await deps.findOrderIdByIdempotencyKey(sourceKey);
    if (replayOrderId) {
      return {
        httpStatus: 200,
        body: {status: 'replayed', orderId: replayOrderId},
      };
    }
    // (3) map via the platform mapper (details fetch is per-mapper).
    const details = mapper.needsDetailsFetch ?
        await deps.fetchOrderDetails(platformId, platformOrderId) :
        undefined;
    const draft = mapper.mapOrder({
      payload,
      details,
      storeId: request.storeId,
      platformOrderId,
    });
    // (4) the EXISTING money-authority path re-derives every line — platform
    // claims are never trusted; a missing menu id fails closed to the DLQ.
    const pricingItems = extractMenuPricingInput(draft.lines);
    if (pricingItems === null) {
      await deps.publishDeadLetter({
        source: 'platform_ingestion',
        platformId,
        sourceKey,
        reason: 'malformed_payload',
        payloadShape: describeShape(payload),
      });
      return {httpStatus: 400, body: {status: 'queued', deadLetter: true}};
    }
    const menuDocs = await deps.loadMenuDocs(
        pricingItems.map((line) => line.id),
    );
    const verified = verifyMenuPricing(pricingItems, menuDocs);
    if (!verified.ok || verified.itemsSubtotalCents === undefined) {
      // L6: a price we cannot re-derive is NEVER persisted — the platform's
      // fulfillment-issue/deny flow takes the order instead.
      const reason = verified.reason ??
          'Menu pricing could not be re-derived';
      deps.log({
        event: 'platform_order_denied',
        platformId,
        orderId: platformOrderId,
        reason,
      });
      await deps.callPlatform(
          mapper.buildAckRequest(platformOrderId, false, reason),
      );
      return {
        httpStatus: 200,
        body: {status: 'rejected', fulfillmentIssue: true, reason},
      };
    }
    const subtotalCents = verified.itemsSubtotalCents;
    // (5) persist FIRST (durability before ack), then acknowledge.
    const orderId = deps.newOrderId();
    const document: Record<string, unknown> = {
      orderSource: buildOrderSource(platformId),
      platformId,
      platformStoreId: request.storeId,
      platformOrderId,
      idempotencyKey: sourceKey,
      status: 'confirmed',
      branchId: verified.branchId,
      items: verified.canonicalItems,
      itemsSubtotalCents: subtotalCents,
      totalCents: subtotalCents,
      platformClaimedTotalCents: draft.claimedTotalCents,
    };
    await deps.persistOrder(orderId, document);
    await deps.callPlatform(mapper.buildAckRequest(platformOrderId, true));
    deps.log({
      event: 'platform_order_ingested',
      platformId,
      orderId,
      idempotencyKey: sourceKey,
    });
    return {httpStatus: 200, body: {status: 'accepted', orderId}};
  } catch (error) {
    // A mapping error is a documented fail-closed outcome (400 + DLQ with a
    // redacted shape only); anything else is an unexpected port failure
    // (500 + DLQ with the operator-facing error text — the platform's
    // redelivery then hits the L2 idempotency gate).
    const mappingFailure =
        error instanceof PlatformMappingError ? error.reason : null;
    await deps.publishDeadLetter({
      source: 'platform_ingestion',
      platformId,
      sourceKey,
      reason: mappingFailure ?? 'unhandled_error',
      payloadShape: describeShape(payload),
      ...(mappingFailure === null ?
        {error: error instanceof Error ? error.message : String(error)} :
        {}),
    });
    return {
      httpStatus: mappingFailure === null ? 500 : 400,
      body: {status: 'queued', deadLetter: true},
    };
  }
}
