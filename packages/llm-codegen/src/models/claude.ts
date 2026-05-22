import Anthropic from '@anthropic-ai/sdk';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const client = new Anthropic();
const systemPrompt = fs.readFileSync(path.join(__dirname, '../prompts/contract-codegen.md'), 'utf-8');

export async function generateWithClaude(spec: string): Promise<string> {
  const resp = await client.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 8192,
    system: systemPrompt,
    messages: [{ role: 'user', content: spec }],
  });
  const block = resp.content.find((b) => b.type === 'text');
  if (!block || block.type !== 'text') throw new Error('no text response');
  return block.text.trim();
}
