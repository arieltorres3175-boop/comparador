import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';

import worker from '../src/index.js';

const originalFetch = globalThis.fetch;
const originalCaches = globalThis.caches;
const expectedEan = '7793913013467';
let cotoSearchTerm = null;

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
          Price: 2500,
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
  assert.match(cotoSearchTerm, /Arroz con leche Tregar/i);
});
