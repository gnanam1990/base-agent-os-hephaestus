import { Hono } from 'hono';
import { createClient } from 'redis';
import crypto from 'node:crypto';

const deployRoutes = new Hono();

const STREAM = 'hephaestus:jobs';
const HMAC_SECRET = process.env.PREVIEW_HMAC_SECRET || 'dev-secret';

function signPreviewToken(payload: object): string {
    const data = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const sig = crypto.createHmac('sha256', HMAC_SECRET).update(data).digest('base64url');
    return `${data}.${sig}`;
}

function verifyPreviewToken(token: string): object | null {
    const [data, sig] = token.split('.');
    if (!data || !sig) return null;
    const expected = crypto.createHmac('sha256', HMAC_SECRET).update(data).digest('base64url');
    if (sig !== expected) return null;
    const payload = JSON.parse(Buffer.from(data, 'base64url').toString());
    if (payload.expires_at < Date.now()) return null;
    return payload;
}

async function getRedis() {
    const r = createClient({ url: process.env.REDIS_URL });
    await r.connect();
    return r;
}

deployRoutes.post('/standard', async (c) => {
    const body = await c.req.json();
    const { spec, constructor_args, template_hint } = body;
    if (!spec && !template_hint) return c.json({ error: 'spec or template_hint required' }, 400);

    const jobId = `job-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const r = await getRedis();

    await r.xAdd(STREAM, '*', {
        payload: JSON.stringify({
            job_id: jobId,
            requester: c.req.header('X-Payment-Address') || '0x0000000000000000000000000000000000000000',
            spec: spec || '',
            template_hint: template_hint || '',
            constructor_args: constructor_args || [],
            audit_tier: 'standard',
            payment_receipt: c.req.header('X-Payment-Receipt') || '',
            created_at: Math.floor(Date.now() / 1000),
        }),
    });

    await r.disconnect();
    return c.json({ job_id: jobId });
});

deployRoutes.post('/custom', async (c) => {
    const body = await c.req.json();
    const { spec } = body;
    if (!spec) return c.json({ error: 'spec required' }, 400);

    const specHash = crypto.createHash('sha256').update(spec).digest('hex');
    const token = signPreviewToken({
        spec_hash: specHash,
        capabilities: ['erc20', 'erc721', 'erc4626'],
        requester: c.req.header('X-Payment-Address') || '0x0000000000000000000000000000000000000000',
        expires_at: Date.now() + 600_000,
    });

    return c.json({
        preview_token: token,
        summary: `Custom contract from spec (hash: ${specHash.slice(0, 16)}...)`,
        detected_capabilities: ['erc20'],
        warnings: [],
    });
});

deployRoutes.post('/custom/confirm', async (c) => {
    const body = await c.req.json();
    const { preview_token, constructor_args } = body;
    if (!preview_token) return c.json({ error: 'preview_token required' }, 400);

    const payload = verifyPreviewToken(preview_token);
    if (!payload) return c.json({ error: 'invalid or expired token' }, 400);

    const jobId = `job-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const r = await getRedis();

    await r.xAdd(STREAM, '*', {
        payload: JSON.stringify({
            job_id: jobId,
            requester: (payload as any).requester,
            spec: '',
            constructor_args: constructor_args || [],
            audit_tier: 'standard',
            payment_receipt: c.req.header('X-Payment-Receipt') || '',
            created_at: Math.floor(Date.now() / 1000),
        }),
    });

    await r.disconnect();
    return c.json({ job_id: jobId });
});

deployRoutes.post('/deep', async (c) => {
    const body = await c.req.json();
    const { spec } = body;
    if (!spec) return c.json({ error: 'spec required' }, 400);

    const specHash = crypto.createHash('sha256').update(spec).digest('hex');
    const token = signPreviewToken({
        spec_hash: specHash,
        capabilities: ['erc20', 'erc721', 'erc4626'],
        requester: c.req.header('X-Payment-Address') || '0x0000000000000000000000000000000000000000',
        expires_at: Date.now() + 600_000,
    });

    return c.json({
        preview_token: token,
        summary: `Deep audit contract from spec (hash: ${specHash.slice(0, 16)}...)`,
        detected_capabilities: ['erc20'],
        warnings: ['kratos-deep audit tier selected'],
    });
});

deployRoutes.post('/deep/confirm', async (c) => {
    const body = await c.req.json();
    const { preview_token, constructor_args } = body;
    if (!preview_token) return c.json({ error: 'preview_token required' }, 400);

    const payload = verifyPreviewToken(preview_token);
    if (!payload) return c.json({ error: 'invalid or expired token' }, 400);

    const jobId = `job-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const r = await getRedis();

    await r.xAdd(STREAM, '*', {
        payload: JSON.stringify({
            job_id: jobId,
            requester: (payload as any).requester,
            spec: '',
            constructor_args: constructor_args || [],
            audit_tier: 'kratos-deep',
            payment_receipt: c.req.header('X-Payment-Receipt') || '',
            created_at: Math.floor(Date.now() / 1000),
        }),
    });

    await r.disconnect();
    return c.json({ job_id: jobId });
});

export { deployRoutes };
