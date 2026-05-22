import { paymentMiddleware } from 'x402-hono';

const wallet = (process.env.AGENT_WALLET || '0x0000000000000000000000000000000000000000') as `0x${string}`;

export const x402 = paymentMiddleware(
  wallet,
  {
    'POST /api/deploy/standard': { price: '$20.00', network: 'base' },
    'POST /api/deploy/custom': { price: '$1.00', network: 'base' },
    'POST /api/deploy/custom/confirm': { price: '$99.00', network: 'base' },
    'POST /api/deploy/deep': { price: '$5.00', network: 'base' },
    'POST /api/deploy/deep/confirm': { price: '$495.00', network: 'base' },
  },
  { url: 'https://api.cdp.coinbase.com/platform/v2/x402' }
);
