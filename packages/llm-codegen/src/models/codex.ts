import { execa } from 'execa';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

export async function generateWithCodex(spec: string): Promise<string> {
  const tmpdir = await fs.mkdtemp(path.join(os.tmpdir(), 'heph-codex-'));
  const promptPath = path.join(tmpdir, 'prompt.txt');
  await fs.writeFile(promptPath, spec);
  const { stdout } = await execa('codex', ['exec', '--no-color', '-f', promptPath], { timeout: 90_000 });
  return stdout.trim();
}
