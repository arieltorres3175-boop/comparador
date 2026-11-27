import 'package:flutter_test/flutter_test.dart';

import '../lib/services/product_facets.dart';

void main() {
  group('ProductFacets para leche', () {
    test('normaliza larga vida, variedad, marca, envase y litro', () {
      final facets = ProductFacets.extract(
        'Leche',
        'Leche UAT Entera Sancor 1 Lt Tetra',
      );

      expect(facets['Tipo'], 'Larga vida');
      expect(facets['Variedad'], 'Entera');
      expect(facets['Envase'], 'Caja de cartón');
      expect(facets['Contenido'], '1 L');
    });

    test('distingue sachet de caja de cartón', () {
      final facets = ProductFacets.extract(
        'Leche',
        'Leche entera La Serenísima sachet 1000 ml',
      );

      expect(facets['Envase'], 'Sachet');
      expect(facets['Contenido'], '1 L');
    });

    test('reconoce parcialmente descremada y leche fresca', () {
      final facets = ProductFacets.extract(
        'Leche',
        'Leche fresca semi descremada 1 litro',
      );

      expect(facets['Tipo'], 'Fresca');
      expect(facets['Variedad'], 'Parcialmente descremada');
      expect(facets['Contenido'], '1 L');
    });

    test('detecta botella plástica cuando el catálogo la informa', () {
      final facets = ProductFacets.extract(
        'Leche',
        'Leche UAT La Serenísima clásica 3% botella PET 1 L',
      );

      expect(facets['Envase'], 'Botella plástica');
      expect(facets['Contenido'], '1 L');
    });

    test('no inventa un filtro de envase cuando no hay datos', () {
      final facets = ProductFacets.extract('Leche', 'Leche La Serenísima 1 L');

      expect(facets.containsKey('Envase'), isFalse);
      expect(facets.values, isNot(contains('Botella')));
    });

    test('excluye productos de higiene y alimentos con dulce de leche', () {
      expect(
        ProductFacets.isCategoryProduct('Leche', 'Leche corporal hidratante 400 ml'),
        isFalse,
      );
      expect(
        ProductFacets.isCategoryProduct('Leche', 'Alfajor relleno con dulce de leche'),
        isFalse,
      );
      expect(
        ProductFacets.isCategoryProduct('Leche', 'Leche UAT La Serenísima 1 L'),
        isTrue,
      );
    });

    test('solo ofrece atributos presentes en los productos de la marca elegida', () {
      final options = ProductFacets.available('Leche', [
        'Leche UAT Sancor Entera Sachet 1 L',
        'Leche UAT Sancor Descremada Caja Tetra 1 L',
      ]);

      expect(options['Tipo'], contains('Larga vida'));
      expect(options['Variedad'], containsAll(['Entera', 'Descremada']));
      expect(options['Envase'], containsAll(['Sachet', 'Caja de cartón']));
      expect(options['Contenido'], ['1 L']);
    });

    test('aplica filtros combinados sin confundir variedades', () {
      expect(
        ProductFacets.matches('Leche', 'Leche UAT Sancor Entera 1 L Tetra', {
          'Tipo': 'Larga vida',
          'Variedad': 'Entera',
          'Envase': 'Caja de cartón',
          'Contenido': '1 L',
        }),
        isTrue,
      );
      expect(
        ProductFacets.matches('Leche', 'Leche fresca Sancor Descremada 1 L', {
          'Tipo': 'Larga vida',
        }),
        isFalse,
      );
    });
  });
}
