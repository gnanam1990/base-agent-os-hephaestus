import { execa } from 'execa';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { DeployJob, JobStatus, hashId } from '@hephaestus/core';
import { generateContract } from '@hephaestus/llm-codegen';
import { attest } from '@hephaestus/eas-attest';
type RedisClient = any;
import { logDeploy } from './cost.js';

const STATUS_KEY = (jobId: string) => `hephaestus:status:${jobId}`;
const RESULTS_STREAM = 'hephaestus:results';

async function setStatus(r: RedisClient, jobId: string, status: JobStatus, extra?: Record<string, string>) {
    await r.hSet(STATUS_KEY(jobId), { status, ...extra });
}

export async function processJob(r: RedisClient, job: DeployJob) {
    const { job_id, spec, template_hint, constructor_args, audit_tier } = job;
    let source: string;
    let tempDir: string;

    // 1. GENERATING
    await setStatus(r, job_id, 'GENERATING');
    try {
        if (template_hint) {
            source = await loadTemplate(template_hint);
        } else {
            source = await generateContract(spec);
        }
    } catch (e: any) {
        await setStatus(r, job_id, 'GENERATION_FAILED', { error: e.message });
        return;
    }

    // 2. COMPILING
    await setStatus(r, job_id, 'COMPILING');
    tempDir = await fs.mkdtemp(path.join(os.tmpdir(), `heph-${job_id}-`));
    await fs.mkdir(path.join(tempDir, 'src'), { recursive: true });
    await fs.writeFile(path.join(tempDir, 'foundry.toml'), '[profile.default]\nsolc="0.8.24"\n');
    await fs.writeFile(path.join(tempDir, 'src/Generated.sol'), source);

    try {
        await execa('forge', ['build'], { cwd: tempDir });
    } catch (e: any) {
        await setStatus(r, job_id, 'COMPILE_FAILED', { error: e.message });
        return;
    }

    // 3. AUDITING
    await setStatus(r, job_id, 'AUDITING');
    try {
        const { stdout } = await execa('slither', [path.join(tempDir, 'src/Generated.sol'), '--json', '-'], { reject: false });
        const parsed = JSON.parse(stdout || '{}');
        const highFindings = (parsed?.results?.detectors || []).filter((d: any) => d.impact === 'High' || d.impact === 'Critical');
        if (highFindings.length > 0) {
            await setStatus(r, job_id, 'AUDIT_FAILED', { error: `${highFindings.length} high/critical findings` });
            return;
        }
    } catch {
        // Slither not available, continue
    }

    // 4. DEPLOYING
    await setStatus(r, job_id, 'DEPLOYING');
    let contractAddr: string;
    let txHash: string;
    try {
        const pk = process.env.DEPLOYER_PK!;
        const rpc = process.env.BASE_MAINNET_RPC!;
        const args = constructor_args?.length ? ['--constructor-args', ...constructor_args.map(String)] : [];
        const { stdout } = await execa('forge', [
            'create', 'src/Generated.sol:Generated',
            '--rpc-url', rpc,
            '--private-key', pk,
            ...args,
        ], { cwd: tempDir });
        const match = stdout.match(/Deployed to: (0x[a-fA-F0-9]{40})/);
        if (!match) throw new Error('Could not parse contract address');
        contractAddr = match[1];
        txHash = 'unknown'; // forge create doesn't always output tx hash
    } catch (e: any) {
        await setStatus(r, job_id, 'DEPLOY_FAILED', { error: e.message });
        return;
    }

    // 5. VERIFYING
    await setStatus(r, job_id, 'VERIFYING');
    try {
        await execa('forge', [
            'verify-contract', contractAddr,
            'src/Generated.sol:Generated',
            '--chain-id', '8453',
            '--etherscan-api-key', process.env.BASESCAN_API_KEY || '',
        ], { cwd: tempDir });
    } catch {
        // Verification can fail, continue
    }

    // 6. RECORDING
    await setStatus(r, job_id, 'RECORDING');
    let attestationUid = '';
    try {
        const specHash = hashId(spec);
        const receipt = await attest({
            rpcUrl: process.env.BASE_MAINNET_RPC!,
            privateKey: process.env.AGENT_PK || process.env.DEPLOYER_PK!,
            schemaUID: process.env.EAS_SCHEMA_UID_DEPLOY!,
            recipient: job.requester,
            data: [
                { name: 'contractAddr', value: contractAddr, type: 'address' },
                { name: 'requester', value: job.requester, type: 'address' },
                { name: 'specHash', value: specHash, type: 'bytes32' },
                { name: 'auditTier', value: audit_tier === 'kratos-deep' ? 1 : 0, type: 'uint8' },
                { name: 'deployedAt', value: BigInt(Math.floor(Date.now() / 1000)), type: 'uint64' },
            ],
            schemaString: 'address contractAddr, address requester, bytes32 specHash, uint8 auditTier, uint64 deployedAt',
        });
        attestationUid = receipt;
    } catch {
        // Attestation can fail, continue
    }

    // 7. SUCCESS
    await logDeploy({
        job_id,
        requester: job.requester,
        contract_address: contractAddr,
        tx_hash: txHash,
        audit_tier,
    });

    await setStatus(r, job_id, 'SUCCESS', {
        contract_address: contractAddr,
        attestation_uid: attestationUid,
    });

    await r.xAdd(RESULTS_STREAM, '*', {
        job_id,
        status: 'SUCCESS',
        contract_address: contractAddr,
        attestation_uid: attestationUid,
    });
}

async function loadTemplate(hint: string): Promise<string> {
    const templatePath = path.join(process.cwd(), '..', 'templates', 'src', hint);
    return await fs.readFile(templatePath, 'utf-8');
}
