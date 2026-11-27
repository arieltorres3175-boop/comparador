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
    productName: 'Arroz con leche Tregar con dulce de leche 180 g',
    brand: 'Tregar',
    link: '/arroz-con-leche-tregar/p',
    items: [{
      itemId: 'sku-1',
      name: '180 g',
      ean,
      images: [{ imageUrl: 'https://images.example/product.jpg' }],
      sellers: [{
        commertialOffer: {
          Price: vtexPrice,
          ListPrice: 2700,
          AvailableQuantity: 8,
        },
      }],
    }],
  }];
}

function cotoResponse() {
  return {
    contents: [{
      Main: [
        {},
        {},
        {
          contents: [{
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
                detailsAction: {
                  recordState: '/arroz-con-leche-tregar/_/A-123?',
                },
              }],
            }],
          }],
        },
      ],
    }],
  };
}

beforeEach(() => {
  cotoSearchTerm = null;
  vtexPrice = 2500;
  globalThis.caches = {
    default: {
      match: async () => undefined,
      put: async () => undefined,
    },
  };
  globalThis.fetch = async (input) => {
    const url = new URL(input instanceof URL ? input.toString() : typeof input === 'string' ? input : input.url);
    if (url.hostname === 'www.cotodigital.com.ar') {
      cotoSearchTerm = url.searchParams.get('Ntt');
      return new Response(JSON.stringify(cotoResponse()), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    }
    return new Response(JSON.stringify(vtexResponse(url.hostname)), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  };
});

afterEach(() => {
  globalThis.fetch = originalFetch;
  if (originalCaches === undefined) delete globalThis.caches;
  else globalThis.caches = originalCaches;
});

test('rejects an empty query without contacting supermarkets', async () => {
  const response = await worker.fetch(
    new Request('https://comparador-api.example.workers.dev/search?q='),
    {},
    { waitUntil: () => {} },
  );
  assert.equal(response.status, 400);
});

test('groups identical products by EAN and preserves store-specific prices', async () => {
  const response = await worker.fetch(
    new Request(`https://comparador-api.example.workers.dev/search?q=${expectedEan}`),
    {},
    { waitUntil: () => {} },
  );
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
  assert.equal(body.stores.length, 7);
  assert.equal(body.products.length, 2);

  const exact = body.products.find((product) => product.ean === expectedEan);
  assert.ok(exact);
  assert.equal(exact.offers.length, 6);
  assert.equal(exact.comparableByEan, true);
  assert.ok(exact.offers.every((offer) => offer.price === 2500));
  assert.equal(exact.offers.find((offer) => offer.store === 'Coto')?.brand, 'Tregar');
  assert.match(cotoSearchTerm, /Arroz con leche Tregar/i);
});

test('parses comma thousands separators as thousands, not decimal fractions', async () => {
  vtexPrice = '5,000';
  const response = await worker.fetch(
    new Request('https://comparador-api.example.workers.dev/search?q=arroz'),
    {},
    { waitUntil: () => {} },
  );
  const body = await response.json();
  const product = body.products.find((item) => item.ean === expectedEan);
  assert.ok(product);
  // Carrefour deliberately has a different EAN in this fixture, so only
  // five VTEX offers belong to this exact-EAN group; Coto is the sixth.
  const vtexOffers = product.offers.filter((offer) => offer.store !== 'Coto');
  assert.equal(vtexOffers.length, 5);
  assert.equal(product.offers.length, 6);
  assert.ok(vtexOffers.every((offer) => offer.price === 5000));
  assert.equal(product.offers.find((offer) => offer.store === 'Coto')?.price, 2500);
});


test('caps a full VTEX search at ten pages per store', async () => {
  const requests = new Map();
  globalThis.fetch = async (input) => {
    const url = new URL(input instanceof URL ? input.toString() : typeof input === 'string' ? input : input.url);
    if (url.hostname === 'www.cotodigital.com.ar') {
      return new Response(JSON.stringify({ contents: [] }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    }
    requests.set(url.hostname, (requests.get(url.hostname) ?? 0) + 1);
    return new Response(JSON.stringify(Array.from({ length: 50 }, (_, index) => ({
      ...vtexResponse(url.hostname)[0],
      productId: `page-product-${index}`,
      productName: `Arroz producto ${index}`,
    }))), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  };

  const response = await worker.fetch(
    new Request('https://comparador-api.example.workers.dev/search?q=arroz&limit=50'),
    {},
    { waitUntil: () => {} },
  );

  assert.equal(response.status, 200);
  assert.equal(requests.size, 6);
  assert.ok([...requests.values()].every((count) => count === 10));
});

test('stops VTEX pagination when a page contains fewer results than requested', async () => {
  const requests = new Map();
  globalThis.fetch = async (input) => {
    const url = new URL(input instanceof URL ? input.toString() : typeof input === 'string' ? input : input.url);
    if (url.hostname === 'www.cotodigital.com.ar') {
      return new Response(JSON.stringify({ contents: [] }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    }
    requests.set(url.hostname, (requests.get(url.hostname) ?? 0) + 1);
    return new Response(JSON.stringify(vtexResponse(url.hostname)), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  };

  const response = await worker.fetch(
    new Request('https://comparador-api.example.workers.dev/search?q=arroz&limit=50'),
    {},
    { waitUntil: () => {} },
  );

  assert.equal(response.status, 200);
  assert.equal(requests.size, 6);
  assert.ok([...requests.values()].every((count) => count === 1));
});
