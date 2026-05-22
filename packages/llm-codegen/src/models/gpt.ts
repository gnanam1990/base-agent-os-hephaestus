import OpenAI from 'openai';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const client = new OpenAI();
const systemPrompt = fs.readFileSync(path.join(__dirname, '../prompts/contract-codegen.md'), 'utf-8');

export async function generateWithGPT(spec: string): Promise<string> {
  const resp = await client.chat.completions.create({
    model: 'gpt-4o',
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: spec },
    ],
    max_completion_tokens: 8192,
  });
  const text = resp.choices[0]?.message?.content;
  if (!text) throw new Error('no text response');
  return text.trim();
}
