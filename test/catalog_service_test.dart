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
}
