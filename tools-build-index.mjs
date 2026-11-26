import fs from 'node:fs/promises';
import path from 'node:path';

const BASE = 'https://hysmarcos.github.io/superprecios-claros';
const REGIONS = ['NACIONAL', 'AMBA', 'CENTRO', 'CUYO', 'NEA', 'NOA', 'PATAGONIA'];
const OUT = path.resolve('public/data');
const letters = 'abcdefghijklmnopqrstuvwxyz0123456789#'.split('');
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function getJson(url, retries = 3) {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const response = await fetch(url, { headers: { 'User-Agent': 'ComparadorArgentina/1.0 (public price index)' } });
      if (response.status === 404) return null;
      if (!response.ok) throw new Error(`HTTP ${response.status} ${url}`);
      return await response.json();
    } catch (error) {
      if (attempt === retries) throw error;
      await sleep(800 * (attempt + 1));
    }
  }
}

function normalize(value) {
  return String(value ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
}
function bucketsFor(name) {
  const tokens = [...new Set(normalize(name).split(/[^a-z0-9]+/).filter(Boolean))];
  return new Set(tokens.map(t => /^[a-z]/.test(t) ? t[0] : /^[0-9]/.test(t) ? t[0] : '#'));
}

await fs.rm(OUT, { recursive: true, force: true });
await fs.mkdir(OUT, { recursive: true });
const upstreamManifest = await getJson(`${BASE}/v1/manifest.json`);
if (!upstreamManifest) throw new Error('No se pudo leer el manifest de SEPA procesado.');
const chainMap = new Map((upstreamManifest.cadenas ?? []).map(c => [String(c.id), c.nombre]));
const meta = {
  generatedAt: new Date().toISOString(),
  source: 'SEPA - Sistema Electrónico de Publicidad de Precios Argentinos',
  sourceUrl: 'https://www.argentina.gob.ar/economia/industria-y-comercio/defensadelconsumidor/precios-sepa',
  processor: 'superprecios-claros (API comunitaria basada en datos SEPA)',
  processorUrl: BASE,
  dataDate: upstreamManifest.fecha ?? upstreamManifest.data_date ?? upstreamManifest.version_tag ?? null,
  regions: REGIONS,
  chains: [...chainMap.entries()].map(([id, name]) => ({ id, name })),
  note: 'Los importes son precios informados a SEPA y agregados por cadena/región; no equivalen a precio confirmado en una sucursal ni incluyen todos los beneficios bancarios o de billeteras.'
};
await fs.writeFile(path.join(OUT, 'manifest.json'), JSON.stringify(meta));

let requestQueue = [];
for (const region of REGIONS) for (let i = 0; i < 100; i++) requestQueue.push({ region, shard: String(i).padStart(2, '0') });
let cursor = 0;
const buckets = new Map();
for (const region of REGIONS) for (const letter of letters) buckets.set(`${region}/${letter}`, []);
let completed = 0;
async function worker() {
  while (true) {
    const task = requestQueue[cursor++];
    if (!task) return;
    const payload = await getJson(`${BASE}/v1/skus/${task.region}/${task.shard}.json`);
    if (payload?.items) {
      for (const [ean, item] of Object.entries(payload.items)) {
        const p = item.producto ?? {};
        const name = p.nombre ?? '';
        if (!name) continue;
        const prices = Object.entries(item.por_cadena ?? {}).map(([id, value]) => ({
          chainId: Number(id), chain: chainMap.get(String(id)) ?? `Cadena ${id}`,
          price: Number(value.precio_efectivo ?? value.precio_lista ?? 0),
          promo: Boolean(value.tiene_promo),
          change7d: value.delta_7d_pct ?? null,
          historicalLow: Boolean(value.is_min_historico)
        })).filter(x => x.price > 0).sort((a, b) => a.price - b.price);
        const record = { ean, name, brand: p.marca ?? '', quantity: p.cantidad ?? null, unit: p.unidad ?? '', prices };
        for (const letter of new Set([...bucketsFor(name), ...bucketsFor(ean)])) buckets.get(`${task.region}/${letter}`)?.push(record);
      }
    }
    completed++;
    if (completed % 100 === 0) console.log(`Procesados ${completed}/${requestQueue.length} archivos`);
  }
}
await Promise.all(Array.from({ length: 8 }, () => worker()));
for (const [key, items] of buckets) {
  if (!items.length) continue;
  const [region, letter] = key.split('/');
  const dir = path.join(OUT, 'index', region);
  await fs.mkdir(dir, { recursive: true });
  const unique = new Map(items.map(item => [item.ean, item]));
  const sorted = [...unique.values()].sort((a, b) => a.name.localeCompare(b.name, 'es'));
  await fs.writeFile(path.join(dir, `${letter}.json`), JSON.stringify({ region, dataDate: meta.dataDate, items: sorted }));
}
await fs.writeFile(path.join(OUT, '.nojekyll'), '');
console.log(`Índice creado. Fecha SEPA: ${meta.dataDate}. Registros indexados en ${OUT}`);
