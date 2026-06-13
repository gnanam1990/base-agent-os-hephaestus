import { paymentMiddleware } from 'x402-hono';
import { facilitator } from '@coinbase/x402';

const wallet = (process.env.AGENT_WALLET || '0x0000000000000000000000000000000000000000') as `0x${string}`;

// Use the official Coinbase CDP facilitator config. It points at
// https://api.cdp.coinbase.com/platform/v2/x402 AND injects the required CDP JWT
// auth headers (from CDP_API_KEY_ID / CDP_API_KEY_SECRET) on every verify/settle
// call. A bare `{ url }` without `createAuthHeaders` is rejected by CDP (non-200),
// which breaks the paywall: legitimate payments can never be verified or settled.
export const x402 = paymentMiddleware(
  wallet,
  {
    'POST /api/deploy/standard': { price: '$20.00', network: 'base' },
    'POST /api/deploy/custom': { price: '$1.00', network: 'base' },
    'POST /api/deploy/custom/confirm': { price: '$99.00', network: 'base' },
    'POST /api/deploy/deep': { price: '$5.00', network: 'base' },
    'POST /api/deploy/deep/confirm': { price: '$495.00', network: 'base' },
  },
  facilitator
);
