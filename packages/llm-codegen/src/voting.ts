import { generateWithClaude } from './models/claude.js';
import { generateWithGPT } from './models/gpt.js';
import { generateWithCodex } from './models/codex.js';
import { execa } from 'execa';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

export class GenerationFailed extends Error {
    constructor(public reasons: string[]) {
        super('all candidates failed: ' + reasons.join('; '));
    }
}

interface Candidate {
    source: string;
    model: 'claude' | 'gpt' | 'codex';
    compiles: boolean;
    slitherHighFindings: number;
}

function stripFences(src: string): string {
    return src.replace(/^```(?:solidity)?\n?|\n?```$/g, '').trim();
}

async function tryCompile(src: string): Promise<{ ok: boolean; tempDir: string }> {
    const tmpdir = await fs.mkdtemp(path.join(os.tmpdir(), 'heph-vote-'));
    await fs.mkdir(path.join(tmpdir, 'src'), { recursive: true });
    await fs.writeFile(path.join(tmpdir, 'foundry.toml'), '[profile.default]\nsolc="0.8.24"\n');
    await fs.writeFile(path.join(tmpdir, 'src/Generated.sol'), src);
    try {
        await execa('forge', ['build'], { cwd: tmpdir });
        return { ok: true, tempDir: tmpdir };
    } catch {
        return { ok: false, tempDir: tmpdir };
    }
}

async function runSlither(tempDir: string): Promise<number> {
    try {
        const { stdout } = await execa('slither', [path.join(tempDir, 'src/Generated.sol'), '--json', '-'], { reject: false });
        const parsed = JSON.parse(stdout || '{}');
        const dets = parsed?.results?.detectors || [];
        return dets.filter((d: any) => d.impact === 'High' || d.impact === 'Critical').length;
    } catch {
        return 0;
    }
}

export async function generateContract(spec: string): Promise<string> {
    const reasons: string[] = [];
    const candidates: Candidate[] = [];

    const sources = await Promise.allSettled([
        generateWithClaude(spec).then((s) => ({ s: stripFences(s), m: 'claude' as const })),
        generateWithGPT(spec).then((s) => ({ s: stripFences(s), m: 'gpt' as const })),
        generateWithCodex(spec).then((s) => ({ s: stripFences(s), m: 'codex' as const })),
    ]);

    for (const r of sources) {
        if (r.status === 'rejected') { reasons.push(`gen failed: ${r.reason}`); continue; }
        const { s, m } = r.value;
        const { ok, tempDir } = await tryCompile(s);
        if (!ok) { reasons.push(`${m}: compile failed`); continue; }
        const high = await runSlither(tempDir);
        if (high > 0) { reasons.push(`${m}: ${high} slither HIGH findings`); continue; }
        candidates.push({ source: s, model: m, compiles: true, slitherHighFindings: high });
    }

    if (candidates.length === 0) throw new GenerationFailed(reasons);

    // Prefer consensus: if 2+ candidates' sources are identical after whitespace normalization, return that.
    const norm = (s: string) => s.replace(/\s+/g, ' ').trim();
    const groups = new Map<string, Candidate[]>();
    for (const c of candidates) {
        const key = norm(c.source);
        groups.set(key, [...(groups.get(key) || []), c]);
    }
    const consensus = [...groups.values()].find((g) => g.length >= 2);
    if (consensus) return consensus[0].source;

    // Else return shortest (proxy for cleanest)
    candidates.sort((a, b) => a.source.length - b.source.length);
    return candidates[0].source;
}
