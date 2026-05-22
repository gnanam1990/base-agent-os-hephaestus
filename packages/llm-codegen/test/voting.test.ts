import { describe, it, expect, vi } from 'vitest';
import { generateContract, GenerationFailed } from '../src/voting.js';

vi.mock('../src/models/claude.js', () => ({
  generateWithClaude: vi.fn(),
}));
vi.mock('../src/models/gpt.js', () => ({
  generateWithGPT: vi.fn(),
}));
vi.mock('../src/models/codex.js', () => ({
  generateWithCodex: vi.fn(),
}));
vi.mock('execa', () => ({
  execa: vi.fn().mockResolvedValue({ stdout: '{}' }),
}));

import { generateWithClaude } from '../src/models/claude.js';
import { generateWithGPT } from '../src/models/gpt.js';
import { generateWithCodex } from '../src/models/codex.js';

const SAMPLE_CONTRACT = `// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
contract Test { }`;

const SAMPLE_CONTRACT_2 = `// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
contract Another { }`;

describe('generateContract', () => {
  it('returns consensus when all 3 agree', async () => {
    vi.mocked(generateWithClaude).mockResolvedValue(SAMPLE_CONTRACT);
    vi.mocked(generateWithGPT).mockResolvedValue(SAMPLE_CONTRACT);
    vi.mocked(generateWithCodex).mockResolvedValue(SAMPLE_CONTRACT);

    const result = await generateContract('test spec');
    expect(result).toContain('contract Test');
  });

  it('returns consensus when 2/3 agree', async () => {
    vi.mocked(generateWithClaude).mockResolvedValue(SAMPLE_CONTRACT);
    vi.mocked(generateWithGPT).mockResolvedValue(SAMPLE_CONTRACT);
    vi.mocked(generateWithCodex).mockResolvedValue(SAMPLE_CONTRACT_2);

    const result = await generateContract('test spec');
    expect(result).toContain('contract Test');
  });

  it('returns shortest when all differ', async () => {
    vi.mocked(generateWithClaude).mockResolvedValue(SAMPLE_CONTRACT + '\n// extra comment');
    vi.mocked(generateWithGPT).mockResolvedValue(SAMPLE_CONTRACT_2 + '\n// more extra');
    vi.mocked(generateWithCodex).mockResolvedValue(SAMPLE_CONTRACT);

    const result = await generateContract('test spec');
    expect(result).toContain('contract');
  });

  it('throws GenerationFailed when all fail', async () => {
    vi.mocked(generateWithClaude).mockRejectedValue(new Error('API error'));
    vi.mocked(generateWithGPT).mockRejectedValue(new Error('API error'));
    vi.mocked(generateWithCodex).mockRejectedValue(new Error('CLI error'));

    await expect(generateContract('test spec')).rejects.toThrow(GenerationFailed);
  });
});
