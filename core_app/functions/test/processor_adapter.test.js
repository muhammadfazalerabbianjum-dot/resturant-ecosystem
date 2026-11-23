/**
 * P0-11 — the processor seam is a pure extraction, so these tests pin the
 * exact request the old inline call produced. If the adapter ever changes the
 * params (amount units, idempotency key, receipt_email condition, metadata), the
 * money-path behaviour has changed and these fail.
 */
const test = require('node:test');
const assert = require('node:assert/strict');

const {
  StripeProcessorAdapter,
} = require('../lib/payments/processor_adapter.js');

function fakeStripe() {
  const calls = [];
  return {
    calls,
    paymentIntents: {
      create: async (params, opts) => {
        calls.push({params, opts});
        return {id: 'pi_test_123', client_secret: 'pi_test_123_secret_abc', status: 'requires_payment_method'};
      },
    },
  };
}

const baseRequest = () => ({
  amountCents: 2345,
  currency: 'gbp',
  metadata: {userId: 'u1', createdBy: 'u1', orderId: 'o1', taxCents: '200', currency: 'gbp'},
  receiptEmail: 'guest@example.com',
  idempotencyKey: 'idem-abc',
});

test('T-PA1 createIntent sends amount, currency and idempotency key unchanged', async () => {
  const stripe = fakeStripe();
  const adapter = new StripeProcessorAdapter(stripe);
  await adapter.createIntent(baseRequest());

  assert.equal(stripe.calls.length, 1);
  const {params, opts} = stripe.calls[0];
  assert.equal(params.amount, 2345, 'amount must stay in cents');
  assert.equal(params.currency, 'gbp');
  assert.deepEqual(opts, {idempotencyKey: 'idem-abc'});
});

test('T-PA2 automatic payment methods stay enabled and metadata is passed through untouched', async () => {
  const stripe = fakeStripe();
  const adapter = new StripeProcessorAdapter(stripe);
  const request = baseRequest();
  await adapter.createIntent(request);

  const {params} = stripe.calls[0];
  assert.deepEqual(params.automatic_payment_methods, {enabled: true});
  assert.deepEqual(params.metadata, request.metadata);
});

test('T-PA3 receipt_email is sent when present', async () => {
  const stripe = fakeStripe();
  await new StripeProcessorAdapter(stripe).createIntent(baseRequest());
  assert.equal(stripe.calls[0].params.receipt_email, 'guest@example.com');
});

test('T-PA4 receipt_email is omitted when absent or empty (opt-out safe)', async () => {
  for (const receiptEmail of [undefined, '']) {
    const stripe = fakeStripe();
    await new StripeProcessorAdapter(stripe).createIntent({...baseRequest(), receiptEmail});
    assert.equal(
        'receipt_email' in stripe.calls[0].params,
        false,
        `receipt_email must not be sent for ${JSON.stringify(receiptEmail)}`,
    );
  }
});

test('T-PA5 result maps id/client_secret/status without reinterpretation', async () => {
  const stripe = fakeStripe();
  const result = await new StripeProcessorAdapter(stripe).createIntent(baseRequest());
  assert.deepEqual(result, {
    paymentIntentId: 'pi_test_123',
    clientSecret: 'pi_test_123_secret_abc',
    status: 'requires_payment_method',
  });
});

test('T-PA6 adapter identity is stripe and a Stripe rejection propagates unchanged', async () => {
  const adapter = new StripeProcessorAdapter({
    paymentIntents: {
      create: async () => {
        throw new Error('card_declined');
      },
    },
  });
  assert.equal(adapter.processor, 'stripe');
  await assert.rejects(() => adapter.createIntent(baseRequest()), /card_declined/);
});
