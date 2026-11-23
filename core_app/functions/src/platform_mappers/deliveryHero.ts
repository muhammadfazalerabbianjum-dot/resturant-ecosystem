/**
 * UI-9 (p19) — DeliveryHero mapper (documented shapes, L5).
 *
 * Source: developers.deliveryhero.com/documentation/pos.html — the Integration
 * Middleware pushes orders to our HTTPS plugin (order id, store id, products
 * with options, 2-decimal currency strings); menu/availability sync goes
 * through the Catalog Import API. One program covers Talabat + HungerStation +
 * foodpanda behind ONE agreement. Fixtures are best-effort + UNVERIFIED (gated
 * doc) — see test/fixtures/platform/PROVENANCE.md.
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

/** The DeliveryHero order-push mapper (direct — no details fetch). */
export const deliveryHeroMapper: PlatformMapper = {
  id: 'delivery_hero',
  needsDetailsFetch: false,

  extractOrderId(payload: unknown): string | null {
    const id = asRecord(payload)?.order_id;
    return typeof id === 'string' && id.length > 0 ? id : null;
  },

  mapOrder(input): PlatformOrderDraft {
    const {payload, platformOrderId} = input;
    const document = asRecord(payload);
    if (!document) throw new PlatformMappingError('malformed_payload');
    if (document.order_id !== platformOrderId) {
      throw new PlatformMappingError('malformed_payload');
    }
    const products = document.products;
    if (!Array.isArray(products) || products.length === 0) {
      throw new PlatformMappingError('malformed_payload');
    }
    const lines = products.map((rawProduct) => {
      const product = asRecord(rawProduct);
      const id = product?.id;
      if (!product || typeof id !== 'string' || id.length === 0) {
        throw new PlatformMappingError('malformed_payload');
      }
      const quantity = product.quantity;
      if (typeof quantity !== 'number' || !Number.isSafeInteger(quantity) ||
          quantity < 1) {
        throw new PlatformMappingError('malformed_payload');
      }
      const unitPriceCents = parseMinorUnitsStrict(product.unit_price);
      if (unitPriceCents === null) {
        throw new PlatformMappingError('price_unparseable');
      }
      const rawOptions = product.options;
      const options = Array.isArray(rawOptions) ? rawOptions : [];
      const selectedOptions = options.map((rawOption) => {
        const option = asRecord(rawOption);
        const optionId = option?.id;
        if (!option || typeof optionId !== 'string' || optionId.length === 0) {
          throw new PlatformMappingError('malformed_payload');
        }
        const upchargeCents = parseMinorUnitsStrict(option.price);
        if (upchargeCents === null) {
          throw new PlatformMappingError('price_unparseable');
        }
        return {id: optionId, upchargeCents};
      });
      return {id, quantity, priceCents: unitPriceCents, selectedOptions};
    });
    const claimedTotalCents = parseMinorUnitsStrict(document.order_total);
    return {platformOrderId, lines, claimedTotalCents};
  },

  buildAckRequest(platformOrderId, accepted, reason): PlatformAckRequest {
    return {
      method: 'POST',
      path: '/plugin/v1/orders/' + `${encodeURIComponent(platformOrderId)}/confirmation`,
      body: reason === undefined ? {accepted} : {accepted, reason},
    };
  },

  buildAvailabilityRequest(
      storeId: string, change: DishAvailabilityChange,
  ): PlatformCatalogRequest {
    // Catalog Import API: per-item availability (the documented shape).
    return {
      method: 'POST',
      url: 'https://pos-integrations.deliveryhero.com/stores/' + `${encodeURIComponent(storeId)}/catalog`,
      body: {
        items: [{
          id: change.menuItemId,
          availability: {available: change.isAvailable},
        }],
      },
    };
  },
};
