/**
 * P0-11 — processor seam for the charge path.
 *
 * PURE EXTRACTION: `StripeProcessorAdapter.createIntent` performs the exact
 * `paymentIntents.create` call that `createChargeIntentCore` used to make
 * inline — same params, same order, same idempotency key, same
 * `automatic_payment_methods`, same conditional `receipt_email`. The only change
 * is that the params arrive as a typed request instead of being written at the
 * call site.
 *
 * What deliberately did NOT move: every money *decision* (menu re-pricing, tax,
 * promo, delivery-fee clamp, amount computation, metadata builder) stays in
 * `createChargeIntentCore`. A processor adapter moves money, it does not decide
 * how much.
 */

/**
 * Processor identity; one value today, and the seam exists so a second can be
 * added without touching the core.
 */
export type ProcessorName = 'stripe';

export interface CreateIntentRequest {
  amountCents: number;
  currency: string;
  /** Built by the caller's single metadata builder — never assembled here. */
  metadata: Record<string, string>;
  /** Omitted (or empty) means: no Stripe-hosted receipt, exactly as before. */
  receiptEmail?: string;
  idempotencyKey: string;
}

export interface CreateIntentResult {
  paymentIntentId: string;
  clientSecret: string;
  status?: string;
}

export interface ProcessorAdapter {
  readonly processor: ProcessorName;
  createIntent(request: CreateIntentRequest): Promise<CreateIntentResult>;
}

/**
 * The minimal Stripe surface the adapter needs. Structurally identical to
 * `CreateChargeIntentStripeSeam` in index.ts (which is kept as the public
 * injection point so existing callers and the emulator harness do not change).
 */
export interface StripeIntentClient {
  paymentIntents: {
    create: (
        params: Record<string, unknown>,
        opts?: {idempotencyKey?: string},
    ) => Promise<{id: string; client_secret: string; status?: string}>;
  };
}

export class StripeProcessorAdapter implements ProcessorAdapter {
  readonly processor: ProcessorName = 'stripe';

  constructor(private readonly stripe: StripeIntentClient) {}

  async createIntent(request: CreateIntentRequest): Promise<CreateIntentResult> {
    const paymentIntent = await this.stripe.paymentIntents.create(
        {
          amount: request.amountCents,
          currency: request.currency,
          automatic_payment_methods: {enabled: true},
          // MONEY-3 (W3.7): Stripe-hosted email receipt — the authenticated
          // user's email. Omitted entirely when absent (opt-out-safe: no email,
          // no receipt; Stripe also respects the user's receipt preferences).
          ...(request.receiptEmail && request.receiptEmail.length > 0 ?
            {receipt_email: request.receiptEmail} :
            {}),
          metadata: request.metadata,
        },
        {idempotencyKey: request.idempotencyKey},
    );
    return {
      paymentIntentId: paymentIntent.id,
      clientSecret: paymentIntent.client_secret,
      status: paymentIntent.status,
    };
  }
}
