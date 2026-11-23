/**
 * UI-9 (p19) — Uber Eats mapper (documented shapes, L5).
 *
 * Source: developer.uber.com/docs/eats/guides/order_integration — the
 * `orders.notification` webhook names the resource; the order document is
 * then fetched with Get Order Details (`cart.items[]` with integer minor-unit
 * `amount` + `currency_code`), and accept/deny happens in the required time
 * window. Fixtures are best-effort + UNVERIFIED (gated doc, written-approval
 * API) — see test/fixtures/platform/PROVENANCE.md.
 */
import {
  DishAvailabilityChange,
  PlatformAckRequest,
  PlatformCatalogRequest,
  PlatformMapper,
  PlatformMappingError,
  PlatformOrderDraft,
  parseMinorUnitsStrict,
} from '../platform_ingestion';

/** Narrow an unknown payload value to a record, or null. */
function asRecord(value: unknown): Record<string, unknown> | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

/** The Uber Eats order mapper (notification → details → our draft). */
export const uberEatsMapper: PlatformMapper = {
  id: 'uber_eats',
  needsDetailsFetch: true,

  extractOrderId(payload: unknown): string | null {
    const meta = asRecord(asRecord(payload)?.meta);
    const id = meta?.resource_id;
    return typeof id === 'string' && id.length > 0 ? id : null;
  },

  mapOrder(input): PlatformOrderDraft {
    const {details, platformOrderId} = input;
    // The notification alone is never enough — details_required DLQ.
    if (details === null || details === undefined) {
      throw new PlatformMappingError('details_required');
    }
    const document = asRecord(details);
    if (!document) throw new PlatformMappingError('malformed_payload');
    // Never map details for a different order (cross-order guard).
    if (document.id !== platformOrderId) {
      throw new PlatformMappingError('order_id_mismatch');
    }
    const cart = asRecord(document.cart);
    const items = cart?.items;
    if (!Array.isArray(items) || items.length === 0) {
      throw new PlatformMappingError('malformed_payload');
    }
    const lines = items.map((rawItem) => {
      const item = asRecord(rawItem);
      const id = item?.id;
      if (!item || typeof id !== 'string' || id.length === 0) {
        throw new PlatformMappingError('malformed_payload');
      }
      const quantity = item.quantity;
      if (typeof quantity !== 'number' || !Number.isSafeInteger(quantity) ||
          quantity < 1) {
        throw new PlatformMappingError('malformed_payload');
      }
      const price = asRecord(asRecord(item.price)?.unit_price);
      const unitPriceCents = parseMinorUnitsStrict(price?.amount);
      if (unitPriceCents === null) {
        throw new PlatformMappingError('price_unparseable');
      }
      const customizations = Array.isArray(item.customizations) ?
          item.customizations : [];
      const selectedOptions = customizations.map((rawOption) => {
        const option = asRecord(rawOption);
        const optionId = option?.id;
        if (!option || typeof optionId !== 'string' || optionId.length === 0) {
          throw new PlatformMappingError('malformed_payload');
        }
        const upchargeCents = parseMinorUnitsStrict(
            asRecord(option.price)?.amount,
        );
        if (upchargeCents === null) {
          throw new PlatformMappingError('price_unparseable');
        }
        return {id: optionId, upchargeCents};
      });
      return {id, quantity, priceCents: unitPriceCents, selectedOptions};
    });
    const payment = asRecord(document.payment);
    const total = asRecord(asRecord(payment?.charges)?.total);
    const claimedTotalCents = parseMinorUnitsStrict(total?.amount);
    return {platformOrderId, lines, claimedTotalCents};
  },

  buildAckRequest(platformOrderId, accepted, reason): PlatformAckRequest {
    return {
      method: 'POST',
      path: `/v2/eats/order/${encodeURIComponent(platformOrderId)}/accept`,
      body: reason === undefined ? {accepted} : {accepted, reason},
    };
  },

  buildAvailabilityRequest(
      storeId: string, change: DishAvailabilityChange,
  ): PlatformCatalogRequest {
    // Uber Menu API: suspension_info — {suspend_until: 0} suspends the item,
    // null clears the suspension (the documented suspend/restore shapes).
    return {
      method: 'PUT',
      url: 'https://api.uber.com/v2/eats/stores/' + `${encodeURIComponent(storeId)}/menus`,
      body: {
        menus: [{
          items: [{
            id: change.menuItemId,
            suspension_info: change.isAvailable ?
              null : {suspend_until: 0},
          }],
        }],
      },
    };
  },
};
