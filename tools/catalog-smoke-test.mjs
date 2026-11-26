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
        productUrl: product.link ?? null,
      };
    });

    return { store: store.name, domain: store.domain, status: response.status,
      ok: true, resultCount: products.length, sample };
  } catch (error) {
    return { store: store.name, domain: store.domain, ok: false,
      reason: error instanceof Error ? error.message : String(error) };
  }
}

async function checkCoto() {
  const url = new URL('https://api.cotodigital.com.ar/sitios/cdigi/categoria');
  url.searchParams.set('_dyncharset', 'utf-8');
  url.searchParams.set('Nrpp', '10');
  url.searchParams.set('Ntt', query);
  try {
    const response = await fetch(url, {
      headers: {
        accept: 'application/json, text/plain, */*',
        origin: 'https://www.coto.com.ar',
        referer: 'https://www.coto.com.ar/',
        'user-agent': 'Mozilla/5.0 ComparadorInteligenteCatalogCheck/0.2',
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
    const keys = Object.keys(data ?? {});
    return { store: 'Coto', ok: true, status: response.status, contentType,
      topLevelKeys: keys, preview: JSON.stringify(data).slice(0, 1200) };
  } catch (error) {
    return { store: 'Coto', ok: false,
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
      headers: { accept: 'application/json', 'user-agent': 'ComparadorInteligenteCatalogCheck/0.2' },
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
      exactMatch: matches.length > 0, matches };
  } catch (error) {
    return { store: store.name, ok: false, exactMatch: false,
      reason: error instanceof Error ? error.message : String(error) };
  }
}

const results = [];
for (const store of stores) {
  results.push(await checkStore(store));
  // Keep requests sequential and gentle: one small query per retailer.
  await new Promise((resolve) => setTimeout(resolve, 1200));
}
const coto = await checkCoto();
const verificationEan = process.env.VERIFY_EAN?.trim() || '7793913013467';
const exactEanResults = [];
for (const store of stores) {
  exactEanResults.push(await checkExactEan(store, verificationEan));
  await new Promise((resolve) => setTimeout(resolve, 1200));
}

const report = {
  generatedAt: new Date().toISOString(),
  query,
  verificationEan,
  note: 'Diagnostic only. Results are not yet used as consumer prices.',
  results,
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
console.log(JSON.stringify({ store: 'Coto', ...coto }));
for (const result of exactEanResults) console.log(JSON.stringify({ verificationEan, ...result }));
