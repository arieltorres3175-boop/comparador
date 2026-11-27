import { mkdir, writeFile } from 'node:fs/promises';

const query = process.env.SEARCH_QUERY?.trim() || 'leche';
const stores = [
  { name: 'Jumbo', domain: 'www.jumbo.com.ar' },
  { name: 'Disco', domain: 'www.disco.com.ar' },
  { name: 'Vea', domain: 'www.vea.com.ar' },
  { name: 'Carrefour', domain: 'www.carrefour.com.ar' },
  { name: 'DIA', domain: 'diaonline.supermercadosdia.com.ar' },
  { name: 'ChangoMás', domain: 'www.masonline.com.ar' },
];

function parseLocalizedPrice(value) {
  if (value == null) return null;
  let raw = String(value).trim().replace(/[^0-9,.-]/g, '');
  if (raw.includes(',') && raw.includes('.')) {
    if (raw.lastIndexOf(',') > raw.lastIndexOf('.')) {
      raw = raw.replace(/\./g, '').replace(',', '.');
    } else {
      raw = raw.replace(/,/g, '');
    }
  } else if (raw.includes(',')) {
    if (/^\d{1,3}(,\d{3})+$/.test(raw)) {
      raw = raw.replace(/,/g, '');
    } else {
      raw = raw.replace(',', '.');
    }
  } else if (/^\d{1,3}(\.\d{3})+$/.test(raw)) {
    raw = raw.replace(/\./g, '');
  }
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function firstOffer(product) {
  for (const item of product.items ?? []) {
    for (const seller of item.sellers ?? []) {
      const offer = seller.commertialOffer ?? seller.commercialOffer;
      if (offer) return { item, seller, offer };
    }
  }
  return null;
}

async function checkStore(store) {
  const url = new URL('/api/catalog_system/pub/products/search', `https://${store.domain}`);
  url.searchParams.set('ft', query);
  url.searchParams.set('_from', '0');
  url.searchParams.set('_to', '9');

  try {
    const response = await fetch(url, {
      headers: {
        accept: 'application/json',
        origin: 'https://arieltorres3175-boop.github.io',
        'user-agent': 'ComparadorInteligenteCatalogCheck/0.1 (public catalog lookup)',
      },
      signal: AbortSignal.timeout(18000),
    });
    const contentType = response.headers.get('content-type') ?? '';
    if (!response.ok) {
      return { store: store.name, domain: store.domain, status: response.status, ok: false,
        reason: 'HTTP response was not successful' };
    }
    if (!contentType.includes('json')) {
      return { store: store.name, domain: store.domain, status: response.status, ok: false,
        reason: `Unexpected content type: ${contentType}` };
    }

    const products = await response.json();
    if (!Array.isArray(products)) {
      return { store: store.name, domain: store.domain, status: response.status, ok: false,
        reason: 'Response JSON is not a product array' };
    }

    const sample = products.slice(0, 5).map((product) => {
      const found = firstOffer(product);
      const item = found?.item;
      const offer = found?.offer;
      return {
        productId: product.productId ?? null,
        name: product.productName ?? null,
        brand: product.brand ?? null,
        skuName: item?.name ?? null,
        ean: item?.ean ?? null,
        price: offer?.Price ?? offer?.price ?? null,
        listPrice: offer?.ListPrice ?? offer?.listPrice ?? null,
        availableQuantity: offer?.AvailableQuantity ?? offer?.availableQuantity ?? null,
        image: item?.images?.[0]?.imageUrl ?? null,
        productUrl: product.link ?? null,
      };
    });

    let imageCheck = null;
    if (sample[0]?.image) {
      try {
        const imageResponse = await fetch(sample[0].image, {
          method: 'HEAD',
          signal: AbortSignal.timeout(10000),
        });
        imageCheck = {
          status: imageResponse.status,
          contentType: imageResponse.headers.get('content-type'),
        };
      } catch (error) {
        imageCheck = { error: error instanceof Error ? error.message : String(error) };
      }
    }
    return { store: store.name, domain: store.domain, status: response.status,
      corsAllowOrigin: response.headers.get('access-control-allow-origin'),
      ok: true, resultCount: products.length, sample, imageCheck };
  } catch (error) {
    return { store: store.name, domain: store.domain, ok: false,
      reason: error instanceof Error ? error.message : String(error) };
  }
}


async function checkVtexPagination(store) {
  // Match the app's actual catalog request size (limit: 50).
  const pageSize = 50;
  const pages = [];
  const url = new URL('/api/catalog_system/pub/products/search', `https://${store.domain}`);
  url.searchParams.set('ft', query);
  for (let page = 0; page < 10; page++) {
    const from = page * pageSize;
    const to = from + pageSize - 1;
    url.searchParams.set('_from', String(from));
    url.searchParams.set('_to', String(to));
    const started = Date.now();
    try {
      const response = await fetch(url, {
        headers: {
          accept: 'application/json',
          'user-agent': 'ComparadorInteligentePaginationDiagnostic/1.0',
        },
        signal: AbortSignal.timeout(18000),
      });
      const body = await response.text();
      let count = null;
      let jsonValid = false;
      try {
        const parsed = JSON.parse(body);
        jsonValid = Array.isArray(parsed);
        count = Array.isArray(parsed) ? parsed.length : null;
      } catch (_) {}
      pages.push({
        page: page + 1, from, to, status: response.status,
        ok: response.ok, contentRange: response.headers.get('content-range'),
        contentType: response.headers.get('content-type'),
        durationMs: Date.now() - started, jsonValid, count,
        errorPreview: response.ok && jsonValid ? null : body.slice(0, 500),
      });
      if (!response.ok || !jsonValid || count === 0 || count < pageSize) break;
    } catch (error) {
      pages.push({
        page: page + 1, from, to, status: null, ok: false,
        durationMs: Date.now() - started,
        errorPreview: error instanceof Error ? error.message : String(error),
      });
      break;
    }
    await new Promise((resolve) => setTimeout(resolve, 350));
  }
  return { store: store.name, domain: store.domain, pageSize, pages,
    failedAtPage: pages.find((item) => !item.ok)?.page ?? null };
}

async function checkCoto() {
  const url = new URL('https://www.cotodigital.com.ar/sitios/cdigi/categoria');
  url.searchParams.set('_dyncharset', 'utf8');
  url.searchParams.set('Dy', '1');
  url.searchParams.set('Nrpp', '10');
  url.searchParams.set('Ntt', query);
  url.searchParams.set('idSucursal', '200');
  url.searchParams.set('format', 'json');
  try {
    const response = await fetch(url, {
      headers: {
        accept: 'application/json, text/plain, */*',
        referer: 'https://www.cotodigital.com.ar/',
        origin: 'https://arieltorres3175-boop.github.io',
        'user-agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36',
      },
      signal: AbortSignal.timeout(18000),
    });
    const contentType = response.headers.get('content-type') ?? '';
    const body = await response.text();
    if (!response.ok) {
      return { store: 'Coto', ok: false, status: response.status,
        contentType, reason: body.slice(0, 300) };
    }
    let data;
    try { data = JSON.parse(body); } catch {
      return { store: 'Coto', ok: false, status: response.status,
        contentType, reason: 'Response was not JSON', preview: body.slice(0, 300) };
    }
    const records = data?.contents?.[0]?.Main?.[2]?.contents?.[0]?.records ?? [];
    const sample = records.slice(0, 5).map((record) => {
      const attrs = record?.records?.[0]?.attributes ?? {};
      const value = (key) => attrs[key]?.[0] ?? null;
      const rawPrice = value('sku.activePrice');
      const price = parseLocalizedPrice(rawPrice);
      return {
        name: value('sku.displayName'),
        ean: value('product.eanPrincipal'),
        rawPrice,
        price,
        image: value('product.largeImage.url'),
      };
    });
    return { store: 'Coto', ok: true, status: response.status, contentType,
      corsAllowOrigin: response.headers.get('access-control-allow-origin'),
      resultCount: records.length, sample, topLevelKeys: Object.keys(data ?? {}) };
  } catch (error) {
    return { store: 'Coto', ok: false,
      reason: error instanceof Error ? error.message : String(error) };
  }
}
async function checkCotoExactEan(ean) {
  const url = new URL('https://www.cotodigital.com.ar/sitios/cdigi/categoria');
  url.searchParams.set('_dyncharset', 'utf8');
  url.searchParams.set('Dy', '1');
  url.searchParams.set('Nrpp', '20');
  url.searchParams.set('Ntt', process.env.COTO_VERIFY_QUERY?.trim() || 'Leche Parcialmente Descremada Liviana Larga Vida La Serenisima 1l');
  url.searchParams.set('idSucursal', '200');
  url.searchParams.set('format', 'json');
  try {
    const response = await fetch(url, {
      headers: { accept: 'application/json', referer: 'https://www.cotodigital.com.ar/',
        'user-agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36' },
      signal: AbortSignal.timeout(18000),
    });
    if (!response.ok) return { store: 'Coto', ok: false, status: response.status, exactMatch: false };
    const data = await response.json();
    const records = data?.contents?.[0]?.Main?.[2]?.contents?.[0]?.records ?? [];
    const matches = records.flatMap((record) => {
      const attrs = record?.records?.[0]?.attributes ?? {};
      const value = (key) => attrs[key]?.[0] ?? null;
      const foundEan = String(value('product.eanPrincipal') ?? '');
      if (foundEan !== ean) return [];
      const rawPrice = value('sku.activePrice');
      return [{ name: value('sku.displayName'), ean: foundEan,
        rawPrice, price: parseLocalizedPrice(rawPrice) }];
    });
    return { store: 'Coto', ok: true, status: response.status,
      corsAllowOrigin: response.headers.get('access-control-allow-origin'),
      exactMatch: matches.length > 0, matches };
  } catch (error) {
    return { store: 'Coto', ok: false, exactMatch: false,
      reason: error instanceof Error ? error.message : String(error) };
  }
}

async function checkExactEan(store, ean) {
  const url = new URL('/api/catalog_system/pub/products/search', `https://${store.domain}`);
  url.searchParams.set('ft', ean);
  url.searchParams.set('_from', '0');
  url.searchParams.set('_to', '49');
  try {
    const response = await fetch(url, {
      headers: { accept: 'application/json', origin: 'https://arieltorres3175-boop.github.io',
        'user-agent': 'ComparadorInteligenteCatalogCheck/0.2' },
      signal: AbortSignal.timeout(18000),
    });
    if (!response.ok) return { store: store.name, ok: false, status: response.status, exactMatch: false };
    const products = await response.json();
    const matches = [];
    for (const product of Array.isArray(products) ? products : []) {
      for (const item of product.items ?? []) {
        if (String(item.ean ?? '') !== ean) continue;
        const seller = (item.sellers ?? []).find(s => s.commertialOffer ?? s.commercialOffer);
        const offer = seller?.commertialOffer ?? seller?.commercialOffer;
        matches.push({
          name: product.productName ?? null,
          ean: item.ean,
          price: offer?.Price ?? offer?.price ?? null,
          productUrl: product.link ?? null,
        });
      }
    }
    return { store: store.name, ok: true, status: response.status,
      corsAllowOrigin: response.headers.get('access-control-allow-origin'),
      exactMatch: matches.length > 0, matches };
  } catch (error) {
    return { store: store.name, ok: false, exactMatch: false,
      reason: error instanceof Error ? error.message : String(error) };
  }
}


const paginationResults = [];
for (const store of stores) {
  paginationResults.push(await checkVtexPagination(store));
  await new Promise((resolve) => setTimeout(resolve, 1000));
}

const results = [];
for (const store of stores) {
  results.push(await checkStore(store));
  // Keep requests sequential and gentle: one small query per retailer.
  await new Promise((resolve) => setTimeout(resolve, 1200));
}
const coto = await checkCoto();
const verificationEan = process.env.VERIFY_EAN?.trim() || '7790742335609';
const exactEanResults = [await checkCotoExactEan(verificationEan)];
for (const store of stores) {
  exactEanResults.push(await checkExactEan(store, verificationEan));
  await new Promise((resolve) => setTimeout(resolve, 1200));
}


const workerIntegrationResults = [];
let workerBase = process.env.COMPARADOR_API_BASE_URL?.trim() ?? '';
while (workerBase.endsWith('/')) workerBase = workerBase.slice(0, -1);
if (workerBase) {
  let workerVersion = null;
  try {
    const healthResponse = await fetch(new URL('/health', workerBase), {
      signal: AbortSignal.timeout(15000),
    });
    const health = await healthResponse.json();
    workerVersion = health?.version ?? null;
  } catch (_) {}
  if (workerVersion !== '0.2.1') {
    workerIntegrationResults.push({
      skipped: true,
      deployedVersion: workerVersion,
      requiredVersion: '0.2.1',
      reason: 'El Worker desplegado todavía no tiene el endpoint aislado por supermercado. Desplegá la versión validada y repetí este diagnóstico.',
    });
  } else {
  const workerStores = [...stores.map((store) => store.name), 'Coto'];
  for (const workerQuery of ['leche', 'arroz', 'aceite']) {
    for (const workerStore of workerStores) {
      try {
        const workerUrl = new URL('/search', workerBase);
        workerUrl.searchParams.set('q', workerQuery);
        workerUrl.searchParams.set('store', workerStore);
        workerUrl.searchParams.set('limit', '50');
        const response = await fetch(workerUrl, { signal: AbortSignal.timeout(90000) });
        const body = await response.text();
        let data = null;
        try { data = JSON.parse(body); } catch (_) {}
        workerIntegrationResults.push({
          query: workerQuery,
          store: workerStore,
          httpStatus: response.status,
          httpOk: response.ok,
          responseValidJson: data != null,
          storeStatus: data?.stores?.[0] ?? null,
          productsCount: data?.products?.length ?? null,
          bodyPreview: data == null ? body.slice(0, 1000) : null,
        });
      } catch (error) {
        workerIntegrationResults.push({
          query: workerQuery,
          store: workerStore,
          httpOk: false,
          error: error instanceof Error ? error.message : String(error),
        });
      }
      await new Promise((resolve) => setTimeout(resolve, 350));
    }
  }
  }
} else {
  workerIntegrationResults.push({
    ok: false,
    skipped: true,
    reason: 'COMPARADOR_API_BASE_URL is not configured in this workflow',
  });
}

const report = {
  generatedAt: new Date().toISOString(),
  query,
  verificationEan,
  note: 'Diagnostic only. Results are not yet used as consumer prices.',
  results,
  paginationResults,
  workerIntegrationResults,
  coto,
  exactEanResults,
};
await mkdir('catalog-smoke-test', { recursive: true });
await writeFile('catalog-smoke-test/report.json', JSON.stringify(report, null, 2));
for (const result of results) {
  const sample = result.sample?.[0];
  console.log(JSON.stringify({
    store: result.store, ok: result.ok, status: result.status ?? null,
    resultCount: result.resultCount ?? 0, sampleProduct: sample?.name ?? null,
    samplePrice: sample?.price ?? null, sampleEan: sample?.ean ?? null,
    reason: result.reason ?? null,
  }));
}
for (const result of paginationResults) console.log(JSON.stringify({ paginationDiagnostic: result }));
console.log(JSON.stringify({ store: 'Coto', ...coto }));
for (const result of exactEanResults) console.log(JSON.stringify({ verificationEan, ...result }));
