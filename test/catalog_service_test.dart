import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/services/catalog_service.dart';

void main() {
  const ean = '7793913013467';

  test('agrupa por EAN y consulta Coto por nombre cuando recibe un EAN', () async {
    String? cotoQuery;
    final client = MockClient((request) async {
      if (request.url.host == 'www.cotodigital.com.ar') {
        cotoQuery = request.url.queryParameters['Ntt'];
        final coto = {
          'contents': [
            {
              'Main': [
                {},
                {},
                {
                  'contents': [
                    {
                      'records': [
                        {
                          'records': [
                            {
                              'attributes': {
                                'sku.activePrice': ['2500.000000'],
                                'sku.listPrice': ['2700.000000'],
                                'product.eanPrincipal': [ean],
                                'sku.displayName': ['Arroz con leche Tregar 180 g'],
                                'product.largeImage.url': ['https://images.example/coto.jpg'],
                                'product.dtoDescuentos': ['[]'],
                              },
                              'detailsAction': {
                                'recordState': '/arroz-con-leche/_/A-123?',
                              },
                            }
                          ],
                        }
                      ],
                    }
                  ],
                }
              ],
            }
          ],
        };
        return http.Response(jsonEncode(coto), 200);
      }

      final isCarrefour = request.url.host == 'www.carrefour.com.ar';
      final product = [
        {
          'productId': 'test-product',
          'productName': 'Arroz con leche Tregar con dulce de leche 180 g',
          'brand': 'Tregar',
          'link': '/arroz-con-leche-tregar/p',
          'items': [
            {
              'itemId': 'test-sku',
              'name': '180 g',
              'ean': isCarrefour ? '7790000000000' : ean,
              'images': [
                {'imageUrl': 'https://images.example/product.jpg'}
              ],
              'sellers': [
                {
                  'commertialOffer': {
                    'Price': 2500,
                    'ListPrice': 2700,
                    'AvailableQuantity': 5,
                  }
                }
              ],
            }
          ],
        }
      ];
      return http.Response(jsonEncode(product), 206);
    });

    final service = CatalogService(client: client);
    final result = await service.search(ean);

    expect(result.stores, hasLength(7));
    final exact = result.products.firstWhere((product) => product.ean == ean);
    expect(exact.offers, hasLength(6));
    expect(exact.comparableByEan, isTrue);
    expect(exact.offers.every((offer) => offer.price == 2500), isTrue);
    expect(cotoQuery, contains('Arroz con leche Tregar'));

    service.close();
  });

  test('una búsqueda genérica devuelve varias opciones con carga inicial acotada', () async {
    final requestedRanges = <String>[];
    final client = MockClient((request) async {
      if (request.url.host == 'www.cotodigital.com.ar') {
        return http.Response(jsonEncode({'contents': []}), 200);
      }
      requestedRanges.add(request.url.queryParameters['_to'] ?? '');
      final products = [
        {
          'productName': 'Leche entera marca A 1 litro',
          'brand': 'Marca A',
          'link': '/leche-a/p',
          'items': [
            {
              'ean': '7790000000001',
              'name': '1 litro',
              'images': [],
              'sellers': [
                {'commertialOffer': {'Price': 1800, 'ListPrice': 1800}}
              ],
            }
          ],
        },
        {
          'productName': 'Leche descremada marca B 1 litro',
          'brand': 'Marca B',
          'link': '/leche-b/p',
          'items': [
            {
              'ean': '7790000000002',
              'name': '1 litro',
              'images': [],
              'sellers': [
                {'commertialOffer': {'Price': 2100, 'ListPrice': 2100}}
              ],
            }
          ],
        },
        {
          'productName': 'Dulce de leche clásico 400 g',
          'brand': 'Marca C',
          'link': '/dulce-de-leche/p',
          'items': [
            {
              'ean': '7790000000003',
              'name': '400 g',
              'images': [],
              'sellers': [
                {'commertialOffer': {'Price': 1900, 'ListPrice': 1900}}
              ],
            }
          ],
        },
        {
          'productName': 'Chicle sin azúcar',
          'brand': 'Marca D',
          'link': '/chicle/p',
          'items': [
            {
              'ean': '7790000000004',
              'name': 'unidad',
              'images': [],
              'sellers': [
                {'commertialOffer': {'Price': 500, 'ListPrice': 500}}
              ],
            }
          ],
        },
      ];
      return http.Response(jsonEncode(products), 206);
    });

    final service = CatalogService(client: client);
    final result = await service.search('leche');

    expect(requestedRanges, hasLength(6));
    expect(requestedRanges.every((range) => range == '19'), isTrue);
    expect(result.products, hasLength(2));
    expect(result.products.map((product) => product.brand).toSet(),
        containsAll(['Marca A', 'Marca B']));
    expect(result.products.first.brand, 'Marca A');
    expect(result.products.first.offers.first.price, 1800);

    service.close();
  });
  test('una categoría de gaseosas incluye marcas cuyos títulos no dicen gaseosa', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'www.cotodigital.com.ar') {
        return http.Response(jsonEncode({'contents': []}), 200);
      }
      return http.Response(jsonEncode([
        {
          'productName': 'Coca Cola Zero botella 2 litros',
          'brand': 'Coca-Cola',
          'items': [
            {
              'ean': '7790000000101',
              'name': '2 litros',
              'images': [],
              'sellers': [
                {'commertialOffer': {'Price': 3000, 'ListPrice': 3000}}
              ],
            }
          ],
        },
        {
          'productName': 'Pepsi regular lata 354 ml',
          'brand': 'Pepsi',
          'items': [
            {
              'ean': '7790000000102',
              'name': '354 ml',
              'images': [],
              'sellers': [
                {'commertialOffer': {'Price': 1200, 'ListPrice': 1200}}
              ],
            }
          ],
        },
      ]), 206);
    });
    final service = CatalogService(client: client);
    final result = await service.search('gaseosa');

    expect(result.products, hasLength(2));
    expect(result.products.map((product) => product.brand),
        containsAll(['Coca-Cola', 'Pepsi']));
    service.close();
  });

  test('una búsqueda filtrada consulta el término elegido y conserva la categoría visible', () async {
    final requestedTerms = <String>[];
    final client = MockClient((request) async {
      if (request.url.host == 'www.cotodigital.com.ar') {
        return http.Response(jsonEncode({'contents': []}), 200);
      }
      requestedTerms.add(request.url.queryParameters['ft'] ?? '');
      return http.Response(jsonEncode([
        {
          'productName': 'Café molido torrado 500 g',
          'brand': 'Marca A',
          'items': [
            {
              'ean': '7790000000201',
              'name': '500 g',
              'images': [],
              'sellers': [
                {'commertialOffer': {'Price': 5000, 'ListPrice': 5000}}
              ],
            }
          ],
        },
      ]), 206);
    });
    final service = CatalogService(client: client);
    final result = await service.search('cafe', catalogQuery: 'molido');

    expect(requestedTerms, everyElement('molido'));
    expect(result.query, 'cafe');
    expect(result.products, hasLength(1));
    service.close();
  });

  test('interpreta correctamente miles y decimales en precios localizados', () async {
    String rawPrice = '5,000';
    final client = MockClient((request) async {
      if (request.url.host == 'www.cotodigital.com.ar') {
        return http.Response(jsonEncode({'contents': []}), 200);
      }
      return http.Response(jsonEncode([
        {
          'productName': 'Leche entera marca A 1 litro',
          'brand': 'Marca A',
          'items': [
            {
              'ean': '7790000000001',
              'name': '1 litro',
              'images': [],
              'sellers': [
                {'commertialOffer': {'Price': rawPrice, 'ListPrice': rawPrice}}
              ],
            }
          ],
        }
      ]), 200);
    });
    final service = CatalogService(client: client);

    for (final entry in {
      '5,000': 5000.0,
      '5,50': 5.5,
      '1.234,50': 1234.5,
      '1,234.50': 1234.5,
    }.entries) {
      rawPrice = entry.key;
      final result = await service.search('leche');
      expect(result.products.single.offers.first.price, entry.value,
          reason: 'Formato de precio: ${entry.key}');
    }

    service.close();
  });

  test('recorre páginas del catálogo VTEX para no limitarse a los primeros 50', () async {
    final offsetsByStore = <String, List<String>>{};
    final client = MockClient((request) async {
      if (request.url.host == 'www.cotodigital.com.ar') {
        return http.Response(jsonEncode({'contents': []}), 200);
      }

      final host = request.url.host;
      final offset = request.url.queryParameters['_from'] ?? '0';
      offsetsByStore.putIfAbsent(host, () => []).add(offset);
      final start = int.parse(offset);
      final count = start == 0 ? 50 : (start == 50 ? 1 : 0);
      final products = List.generate(count, (index) {
        final number = start + index;
        return {
          'productName': 'Leche producto $number',
          'brand': 'Marca',
          'link': '/leche-$number/p',
          'items': [
            {
              'ean': '7790000${number.toString().padLeft(6, '0')}',
              'name': '1 litro',
              'images': [],
              'sellers': [
                {'commertialOffer': {'Price': 1000 + number, 'ListPrice': 1000 + number}}
              ],
            }
          ],
        };
      });
      return http.Response(jsonEncode(products), 206);
    });

    final service = CatalogService(client: client);
    final result = await service.search('leche', limit: 50);

    expect(result.products, hasLength(51));
    expect(offsetsByStore, hasLength(6));
    expect(offsetsByStore.values.every((offsets) => offsets.join(',') == '0,50'), isTrue);

    service.close();
  });

}
