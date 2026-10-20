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

// Vercel / CI: SUPABASE_URL + SUPABASE_ANON_KEY en variables de entorno.
const fromEnvUrl = (process.env.SUPABASE_URL || '').trim();
const fromEnvKey = (process.env.SUPABASE_ANON_KEY || '').trim();

let url = '';
let key = '';
let label = 'PROD/local';

if (fromEnvUrl && fromEnvKey) {
  url = fromEnvUrl;
  key = fromEnvKey;
  label = 'CI/env';
} else if (existsSync(envJsonPath)) {
  const env = JSON.parse(readFileSync(envJsonPath, 'utf8'));
  url = env.SUPABASE_URL ?? '';
  key = env.SUPABASE_ANON_KEY ?? '';
  label = envFileName === 'env.pre.json' ? 'PRE' : 'PROD/local';
} else {
  console.error(
    `No encuentro ${envFileName} ni variables SUPABASE_URL / SUPABASE_ANON_KEY.\n` +
      'Usa: npm run sync-env        → env.json (prod)\n' +
      '     npm run sync-env:pre    → env.pre.json (pre)\n' +
      '     Vercel: define SUPABASE_URL y SUPABASE_ANON_KEY\n' +
      'o rellena admin-web/src/environments/environment.local.ts',
  );
  process.exit(1);
}

if (!url || !key) {
  console.error('Faltan SUPABASE_URL / SUPABASE_ANON_KEY.');
  process.exit(1);
}

const content = `// Generado por npm run sync-env (${label})
// No subir este archivo con claves reales a un repo público.
export const environmentLocal = {
  supabaseUrl: ${JSON.stringify(url)},
  supabaseAnonKey: ${JSON.stringify(key)},
};
`;

writeFileSync(outPath, content, 'utf8');
console.log(`OK → src/environments/environment.local.ts  [${label}]`);
console.log(`URL: ${url}`);
