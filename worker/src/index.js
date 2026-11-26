const STORES = [
  { name: 'Jumbo', domain: 'www.jumbo.com.ar' },
  { name: 'Disco', domain: 'www.disco.com.ar' },
  { name: 'Vea', domain: 'www.vea.com.ar' },
  { name: 'Carrefour', domain: 'www.carrefour.com.ar' },
  { name: 'DIA', domain: 'diaonline.supermercadosdia.com.ar' },
  { name: 'ChangoMás', domain: 'www.masonline.com.ar' },
];

const COTO_SEARCH = 'https://www.cotodigital.com.ar/sitios/cdigi/categoria';

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'GET, OPTIONS',
      'access-control-allow-headers': 'Content-Type',
      'cache-control': 'public, max-age=60',
      ...extraHeaders,
    },
  });
}

function parsePrice(value) {
  if (value == null) return null;
  let raw = String(value).trim().replace(/[^0-9,.-]/g, '');
  if (raw.includes(',') && raw.includes('.')) {
    raw = raw.replace(/\./g, '').replace(',', '.');
  } else if (raw.includes(',')) {
    raw = raw.replace(',', '.');
  } else if (/^\d{1,3}(\.\d{3})+$/.test(raw)) {
    raw = raw.replace(/\./g, '');
  }
  const result = Number(raw);
  return Number.isFinite(result) && result > 0 ? result : null;
}

function vtexProducts(products, store, domain) {
  const offers = [];
  for (const product of Array.isArray(products) ? products : []) {
    for (const item of product.items ?? []) {
      const sellers = (item.sellers ?? [])
        .map((seller) => seller.commertialOffer ?? seller.commercialOffer)
        .filter(Boolean)
        .filter((offer) => parsePrice(offer.Price ?? offer.price) != null)
        .sort((a, b) =>
          (parsePrice(a.Price ?? a.price) ?? Infinity) -
          (parsePrice(b.Price ?? b.price) ?? Infinity));
      const offer = sellers[0];
      if (!offer) continue;
      const ean = String(item.ean ?? '').trim() || null;
      const productUrl = product.link
        ? new URL(product.link, `https://${domain}`).toString()
        : null;
      offers.push({
        store,
        ean,
        name: product.productName ?? item.name ?? 'Producto sin nombre',
        brand: product.brand ?? null,
        variant: item.name ?? null,
        price: parsePrice(offer.Price ?? offer.price),
        listPrice: parsePrice(offer.ListPrice ?? offer.listPrice),
        stock: offer.AvailableQuantity == null && offer.availableQuantity == null
          ? null
          : Number(offer.AvailableQuantity ?? offer.availableQuantity),
        image: item.images?.[0]?.imageUrl ?? null,
        url: productUrl,
        priceType: 'online_default_channel',
      });
    }
  }
  return offers;
}

function cotoProducts(data) {
  const records = data?.contents?.[0]?.Main?.[2]?.contents?.[0]?.records ?? [];
  return records.flatMap((record) => {
    const attrs = record?.records?.[0]?.attributes ?? {};
    const value = (key) => attrs[key]?.[0] ?? null;
    const price = parsePrice(value('sku.activePrice'));
    const ean = String(value('product.eanPrincipal') ?? '').trim() || null;
    if (!price) return [];
    const state = record?.records?.[0]?.detailsAction?.recordState ?? '';
    let url = null;
    if (state) {
      url = `https://www.cotodigital.com.ar/sitios/cdigi/productos${state.split('?')[0]}`;
    }
    let promotions = [];
    try {
      const raw = value('product.dtoDescuentos');
      if (raw) promotions = JSON.parse(raw).map((item) => ({
        text: item.textoDescuento ?? null,
        price: parsePrice(String(item.precioDescuento ?? '').replace('c/u', '')),
        restriction: String(item.imagenDescuento ?? '').includes('comunidad')
          ? 'Exclusivo Comunidad Coto'
          : null,
      }));
    } catch {
      promotions = [];
    }
    return [{
      store: 'Coto',
      ean,
      name: value('sku.displayName') ?? 'Producto sin nombre',
      brand: null,
      variant: value('sku.displayName') ?? null,
      price,
      listPrice: parsePrice(value('sku.listPrice')),
      stock: null,
      image: value('product.largeImage.url'),
      url,
      priceType: 'online_branch_200',
      branchLabel: 'Sucursal de referencia 200',
      promotions,
    }];
  });
}

function groupByExactEan(offers) {
  const groups = new Map();
  for (const offer of offers) {
    // Only identical, non-empty EANs are grouped across stores.
    const key = offer.ean
      ? `ean:${offer.ean}`
      : `unmatched:${offer.store}:${offer.name}:${offer.variant ?? ''}`;
    if (!groups.has(key)) {
      groups.set(key, {
        ean: offer.ean,
        name: offer.name,
        brand: offer.brand,
        comparableByEan: Boolean(offer.ean),
        offers: [],
      });
    }
    groups.get(key).offers.push(offer);
  }
  return [...groups.values()].map((group) => ({
    ...group,
    offers: group.offers.sort((a, b) => a.price - b.price),
  })).sort((a, b) => {
    const aMin = Math.min(...a.offers.map((offer) => offer.price));
    const bMin = Math.min(...b.offers.map((offer) => offer.price));
    return aMin - bMin;
  });
}

async function searchVtex(store, query, limit) {
  const url = new URL('/api/catalog_system/pub/products/search', `https://${store.domain}`);
  url.searchParams.set('ft', query);
  url.searchParams.set('_from', '0');
  url.searchParams.set('_to', String(limit - 1));
  try {
    const response = await fetch(url, {
      headers: {
        accept: 'application/json',
        'user-agent': 'ComparadorInteligente/0.1 (public product search)',
      },
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) {
      return { store: store.name, ok: false, status: response.status, offers: [] };
    }
    const products = await response.json();
    return {
      store: store.name,
      ok: true,
      status: response.status,
      offers: vtexProducts(products, store.name, store.domain),
    };
  } catch (error) {
    return {
      store: store.name,
      ok: false,
      error: error instanceof Error ? error.message : String(error),
      offers: [],
    };
  }
}

async function searchCoto(query, limit) {
  const url = new URL(COTO_SEARCH);
  url.searchParams.set('_dyncharset', 'utf8');
  url.searchParams.set('Dy', '1');
  url.searchParams.set('Nrpp', String(limit));
  url.searchParams.set('Ntt', query);
  url.searchParams.set('idSucursal', '200');
  url.searchParams.set('format', 'json');
  try {
    const response = await fetch(url, {
      headers: {
        accept: 'application/json',
        referer: 'https://www.cotodigital.com.ar/',
        'user-agent': 'Mozilla/5.0 (compatible; ComparadorInteligente/0.1)',
      },
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) {
      return { store: 'Coto', ok: false, status: response.status, offers: [] };
    }
    const data = await response.json();
    return {
      store: 'Coto',
      ok: true,
      status: response.status,
      offers: cotoProducts(data),
    };
  } catch (error) {
    return {
      store: 'Coto',
      ok: false,
      error: error instanceof Error ? error.message : String(error),
      offers: [],
    };
  }
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: {
          'access-control-allow-origin': '*',
          'access-control-allow-methods': 'GET, OPTIONS',
          'access-control-allow-headers': 'Content-Type',
          'access-control-max-age': '86400',
        },
      });
    }

    if (url.pathname === '/health') {
      return json({ ok: true, service: 'comparador-api', version: '0.1.0' });
    }
    if (url.pathname !== '/search' || request.method !== 'GET') {
      return json({ error: 'Usá GET /search?q=producto o GET /health' }, 404);
    }

    const query = (url.searchParams.get('q') ?? '').trim();
    if (query.length < 2 || query.length > 80) {
      return json({ error: 'La búsqueda debe tener entre 2 y 80 caracteres.' }, 400);
    }
    const limit = Math.max(1, Math.min(20, Number(url.searchParams.get('limit') ?? 10) || 10));

    const cacheKey = new Request(request.url, { method: 'GET' });
    const cache = caches.default;
    const cached = await cache.match(cacheKey);
    if (cached) {
      const headers = new Headers(cached.headers);
      headers.set('access-control-allow-origin', '*');
      headers.set('x-comparador-cache', 'HIT');
      return new Response(cached.body, { status: cached.status, headers });
    }

    // VTEX permits six simultaneous outbound connections on the free Worker plan.
    const vtexResults = await Promise.all(STORES.map((store) => searchVtex(store, query, limit)));
    // Coto is a separate Endeca-based adapter; run it after the six VTEX requests.
    let cotoQuery = query;
    if (/^\d{8,14}$/.test(query)) {
      const matchedVtexProduct = vtexResults
        .flatMap((result) => result.offers)
        .find((offer) => offer.ean === query);
      if (matchedVtexProduct?.name) cotoQuery = matchedVtexProduct.name;
    }
    const cotoResult = await searchCoto(cotoQuery, limit);
    const storeResults = [...vtexResults, cotoResult];
    const offers = storeResults.flatMap((result) => result.offers);
    const responseBody = {
      query,
      generatedAt: new Date().toISOString(),
      note: 'Precios publicados en catálogos online. La sucursal, canal de venta, stock y promociones pueden variar. Los productos solo se agrupan como iguales cuando coincide el EAN.',
      stores: storeResults.map(({ offers: _offers, ...store }) => store),
      products: groupByExactEan(offers),
    };
    const response = json(responseBody, 200, { 'x-comparador-cache': 'MISS' });
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  },
};
