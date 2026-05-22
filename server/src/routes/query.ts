import { Hono } from 'hono';
import { createClient } from 'redis';
import { ethers } from 'ethers';
import { hephaestusRegistryAbi } from '@hephaestus/core';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const queryRoutes = new Hono();

queryRoutes.get('/jobs/:id', async (c) => {
    const jobId = c.req.param('id');
    const r = await createClient({ url: process.env.REDIS_URL });
    await r.connect();

    const status = await r.hGetAll(`hephaestus:status:${jobId}`);
    await r.disconnect();

    if (!status || Object.keys(status).length === 0) {
        return c.json({ error: 'job not found' }, 404);
    }

    return c.json({
        job_id: jobId,
        status: status.status,
        progress: status.status,
        result: status.contract_address ? { contract_address: status.contract_address } : undefined,
        error: status.error,
    });
});

queryRoutes.get('/deploys/:addr', async (c) => {
    const addr = c.req.param('addr');
    const rpc = process.env.BASE_MAINNET_RPC;
    const registryAddr = process.env.HEPHAESTUS_REGISTRY_ADDR;

    if (!rpc || !registryAddr) {
        return c.json({ error: 'registry not configured' }, 500);
    }

    try {
        const provider = new ethers.JsonRpcProvider(rpc);
        const registry = new ethers.Contract(registryAddr, hephaestusRegistryAbi, provider);
        const record = await registry.getDeployRecord(addr);
        return c.json({
            contractAddr: record.contractAddr,
            requester: record.requester,
            specHash: record.specHash,
            deployedAt: Number(record.deployedAt),
            attestationUID: record.attestationUID,
            auditTier: Number(record.auditTier),
        });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

queryRoutes.get('/templates', async (c) => {
    try {
        const indexPath = path.join(__dirname, '..', '..', '..', 'templates', 'index.json');
        const data = fs.readFileSync(indexPath, 'utf-8');
        return c.json(JSON.parse(data));
    } catch (e: any) {
        return c.json({ error: 'templates not found' }, 500);
    }
});

queryRoutes.post('/refund/:job_id', async (c) => {
    const jobId = c.req.param('job_id');
    const r = await createClient({ url: process.env.REDIS_URL });
    await r.connect();

    const status = await r.hGetAll(`hephaestus:status:${jobId}`);
    await r.disconnect();

    if (!status || Object.keys(status).length === 0) {
        return c.json({ error: 'job not found' }, 404);
    }

    const isFailed = status.status?.includes('FAILED');
    if (!isFailed) {
        return c.json({ error: 'job did not fail' }, 400);
    }

    // For v1, post a refund voucher to Redis
    const voucher = {
        job_id: jobId,
        refund_percent: 50,
        requester: status.requester || 'unknown',
        timestamp: Date.now(),
    };

    const r2 = await createClient({ url: process.env.REDIS_URL });
    await r2.connect();
    await r2.xAdd('hephaestus:refunds', '*', { payload: JSON.stringify(voucher) });
    await r2.disconnect();

    return c.json({ message: 'refund voucher issued', voucher });
});

export { queryRoutes };
