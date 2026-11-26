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

  test('una búsqueda genérica devuelve varias opciones y hasta 50 por cadena', () async {
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
      ];
      return http.Response(jsonEncode(products), 206);
    });

    final service = CatalogService(client: client);
    final result = await service.search('leche');

    expect(requestedRanges, hasLength(6));
    expect(requestedRanges.every((range) => range == '49'), isTrue);
    expect(result.products, hasLength(2));
    expect(result.products.map((product) => product.brand).toSet(),
        containsAll(['Marca A', 'Marca B']));
    expect(result.products.first.brand, 'Marca A');
    expect(result.products.first.offers.first.price, 1800);

    service.close();
  });
}
