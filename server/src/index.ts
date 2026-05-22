import { Hono } from 'hono';
import { serve } from '@hono/node-server';
import { x402 } from './x402.js';
import { deployRoutes } from './routes/deploy.js';
import { queryRoutes } from './routes/query.js';

const app = new Hono();

app.use('/api/deploy/*', x402);

app.route('/api/deploy', deployRoutes);
app.route('/api', queryRoutes);

app.get('/health', (c) => c.json({ ok: true, version: '0.1.0' }));

app.get('/openapi.json', (c) => c.json({
    openapi: '3.1.0',
    info: { title: 'Hephaestus API', version: '0.1.0' },
    paths: {
        '/api/deploy/standard': { post: { summary: 'Deploy from template', requestBody: { content: { 'application/json': { schema: { type: 'object', properties: { template_hint: { type: 'string' }, constructor_args: { type: 'array' } } } } } } } },
        '/api/deploy/custom': { post: { summary: 'Preview custom deploy' } },
        '/api/deploy/custom/confirm': { post: { summary: 'Confirm custom deploy' } },
        '/api/deploy/deep': { post: { summary: 'Preview deep audit deploy' } },
        '/api/deploy/deep/confirm': { post: { summary: 'Confirm deep audit deploy' } },
        '/api/jobs/{id}': { get: { summary: 'Get job status' } },
        '/api/deploys/{addr}': { get: { summary: 'Get deploy record' } },
        '/api/templates': { get: { summary: 'List templates' } },
        '/api/refund/{job_id}': { post: { summary: 'Request refund' } },
    },
}));

const port = parseInt(process.env.PORT_API || '3031', 10);
serve({ fetch: app.fetch, port });
console.log(`Hephaestus API listening on :${port}`);
