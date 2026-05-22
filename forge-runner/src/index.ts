import 'dotenv/config';
import { createClient } from 'redis';
import { processJob } from './pipeline.js';
import { DeployJobSchema } from '@hephaestus/core';

const STREAM = 'hephaestus:jobs';
const GROUP = 'runner';
const CONSUMER = process.env.CONSUMER_ID || 'runner-1';
const CONCURRENCY = parseInt(process.env.CONCURRENCY || '3', 10);

async function main() {
    const r = createClient({ url: process.env.REDIS_URL });
    r.on('error', (e) => console.error('redis error', e));
    await r.connect();
    try { await r.xGroupCreate(STREAM, GROUP, '$', { MKSTREAM: true }); } catch {}

    console.log(`forge-runner consumer=${CONSUMER} concurrency=${CONCURRENCY}`);
    const inflight = new Set<Promise<void>>();

    while (true) {
        while (inflight.size >= CONCURRENCY) await Promise.race(inflight);

        const reply = await r.xReadGroup(GROUP, CONSUMER, { key: STREAM, id: '>' }, { COUNT: 5, BLOCK: 5000 });
        if (!reply) continue;
        for (const { messages } of reply) {
            for (const m of messages) {
                const task = (async () => {
                    try {
                        const job = DeployJobSchema.parse(JSON.parse(m.message.payload));
                        await processJob(r, job);
                        await r.xAck(STREAM, GROUP, m.id);
                    } catch (e) {
                        console.error('job error', m.id, e);
                        await r.xAck(STREAM, GROUP, m.id);
                    }
                })();
                inflight.add(task);
                task.finally(() => inflight.delete(task));
            }
        }
    }
}

main().catch((e) => { console.error(e); process.exit(1); });
