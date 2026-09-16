import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '../..');
const outPath = resolve(here, '../src/environments/environment.local.ts');

const arg = (process.argv[2] || '').trim();
const envFileName =
  arg === 'pre' || arg === '--pre'
    ? 'env.pre.json'
    : arg === 'prod' || arg === '--prod'
      ? 'env.json'
      : arg.endsWith('.json')
        ? arg
        : 'env.json';
const envJsonPath = resolve(repoRoot, envFileName);

if (!existsSync(envJsonPath)) {
  console.error(
    `No encuentro ${envFileName} en la raíz del repo Cofradeo.\n` +
      'Usa: npm run sync-env        → env.json (prod)\n' +
      '     npm run sync-env:pre    → env.pre.json (pre)\n' +
      'o rellena admin-web/src/environments/environment.local.ts',
  );
  process.exit(1);
}

const env = JSON.parse(readFileSync(envJsonPath, 'utf8'));
const url = env.SUPABASE_URL ?? '';
const key = env.SUPABASE_ANON_KEY ?? '';

if (!url || !key) {
  console.error(`${envFileName} no tiene SUPABASE_URL / SUPABASE_ANON_KEY.`);
  process.exit(1);
}

const label = envFileName === 'env.pre.json' ? 'PRE' : 'PROD/local';
const content = `// Generado por npm run sync-env desde ../../${envFileName} (${label})
// No subir este archivo con claves reales a un repo público.
export const environmentLocal = {
  supabaseUrl: ${JSON.stringify(url)},
  supabaseAnonKey: ${JSON.stringify(key)},
};
`;

writeFileSync(outPath, content, 'utf8');
console.log(`OK → src/environments/environment.local.ts  [${label} · ${envFileName}]`);
console.log(`URL: ${url}`);
