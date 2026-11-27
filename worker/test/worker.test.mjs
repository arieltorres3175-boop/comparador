import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';

import worker from '../src/index.js';

const originalFetch = globalThis.fetch;
const originalCaches = globalThis.caches;
const expectedEan = '7793913013467';
let cotoSearchTerm = null;
let vtexPrice = 2500;

function vtexResponse(store) {
  const ean = store === 'www.carrefour.com.ar' ? '7790000000000' : expectedEan;
  return [{
    productId: `product-${store}`,
    productName: 'Arroz con leche Tregar 180 g',
    brand: 'Tregar',
    link: '/arroz-con-leche-tregar/p',
    items: [{
      itemId: 'sku-1',
      name: '180 g',
      ean,
      images: [{ imageUrl: 'https://images.example/product.jpg' }],
      sellers: [{ commertialOffer: { Price: vtexPrice, ListPrice: 2700, AvailableQuantity: 8 } }],
    }],
  }];
}

function cotoResponse() {
  return {
    contents: [{
      Main: [{}, {}, { contents: [{
        records: [{
          records: [{
            attributes: {
              'sku.activePrice': ['2500.000000'],
              'sku.listPrice': ['2700.000000'],
              'product.eanPrincipal': [expectedEan],
              'sku.displayName': ['Arroz Con Leche Tregar 180 g'],
              'product.brand': ['Tregar'],
              'product.largeImage.url': ['https://images.example/coto.jpg'],
              'product.dtoDescuentos': ['[]'],
            },
            detailsAction: { recordState: '/arroz-con-leche-tregar/_/A-123?' },
          }],
        }],
      }] }],
    }],
  };
}

beforeEach(() => {
  cotoSearchTerm = null;
  vtexPrice = 2500;
  globalThis.caches = { default: { match: async () => undefined, put: async () => undefined } };
  globalThis.fetch = async (input) => {
    const url = new URL(input instanceof URL ? input.toString() : typeof input === 'string' ? input : input.url);
    if (url.hostname === 'www.cotodigital.com.ar') {
      cotoSearchTerm = url.searchParams.get('Ntt');
      return new Response(JSON.stringify(cotoResponse()), { status: 200, headers: { 'content-type': 'application/json' } });
    }
    return new Response(JSON.stringify(vtexResponse(url.hostname)), { status: 200, headers: { 'content-type': 'application/json' } });
  };
});

afterEach(() => {
  globalThis.fetch = originalFetch;
  if (originalCaches === undefined) delete globalThis.caches;
  else globalThis.caches = originalCaches;
});

const invoke = (query, store, limit = 50) => worker.fetch(
  new Request(`https://comparador-api.example.workers.dev/search?q=${encodeURIComponent(query)}&store=${encodeURIComponent(store)}&limit=${limit}`),
  {},
  { waitUntil: () => {} },
);

test('requires a single valid supermarket per invocation', async () => {
  const missing = await worker.fetch(
    new Request('https://comparador-api.example.workers.dev/search?q=arroz'),
    {},
    { waitUntil: () => {} },
  );
  assert.equal(missing.status, 400);
  const invalid = await invoke('arroz', 'TiendaInventada');
  assert.equal(invalid.status, 400);
});

test('searches one VTEX retailer and returns only its offers', async () => {
  const response = await invoke('arroz', 'Jumbo');
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.stores.length, 1);
  assert.equal(body.stores[0].store, 'Jumbo');
  assert.equal(body.stores[0].ok, true);
  assert.equal(body.products.length, 1);
  assert.equal(body.products[0].offers.length, 1);
  assert.equal(body.products[0].offers[0].store, 'Jumbo');
});

test('allows up to ten pages for one VTEX store without fan-out', async () => {
  let requests = 0;
  globalThis.fetch = async (input) => {
    const url = new URL(input instanceof URL ? input.toString() : typeof input === 'string' ? input : input.url);
    requests++;
    assert.equal(url.hostname, 'www.jumbo.com.ar');
    assert.equal(url.searchParams.get('_from'), String((requests - 1) * 50));
    return new Response(JSON.stringify(Array.from({ length: 50 }, (_, index) => ({
      ...vtexResponse(url.hostname)[0],
      productId: `page-${requests}-${index}`,
    }))), { status: 200, headers: { 'content-type': 'application/json' } });
  };
  const response = await invoke('arroz', 'Jumbo');
  assert.equal(response.status, 200);
  assert.equal(requests, 10);
});

test('stops pagination when a page contains fewer results than requested', async () => {
  let requests = 0;
  globalThis.fetch = async (input) => {
    const url = new URL(input instanceof URL ? input.toString() : typeof input === 'string' ? input : input.url);
    requests++;
    return new Response(JSON.stringify(vtexResponse(url.hostname)), { status: 200, headers: { 'content-type': 'application/json' } });
  };
  const response = await invoke('arroz', 'Disco');
  assert.equal(response.status, 200);
  assert.equal(requests, 1);
});

test('queries Coto independently using the supplied product name', async () => {
  const response = await invoke('Arroz con leche Tregar', 'Coto');
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.stores[0].store, 'Coto');
  assert.equal(body.products[0].offers[0].store, 'Coto');
  assert.match(cotoSearchTerm, /Arroz con leche Tregar/i);
});

test('keeps HTTP failures local to the requested retailer', async () => {
  globalThis.fetch = async () => new Response('temporarily unavailable', { status: 503 });
  const response = await invoke('arroz', 'Vea');
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.stores.length, 1);
  assert.equal(body.stores[0].ok, false);
  assert.equal(body.stores[0].status, 503);
  assert.deepEqual(body.products, []);
});
