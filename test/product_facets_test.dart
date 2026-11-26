import 'package:flutter_test/flutter_test.dart';
import '../lib/services/product_facets.dart';

void main() {
  test('leche exposes milk-only facets', () {
    final values = ProductFacets.available('Leche', [
      'Leche entera larga vida 1 litro',
      'Leche descremada sachet 1 L',
      'Leche sin lactosa botella 1 litro',
    ]);

    expect(values['Tipo'], containsAll(['Entera', 'Descremada', 'Sin lactosa']));
    expect(values['Presentación'], containsAll(['Larga vida / Tetra', 'Sachet', 'Botella']));
    expect(values.containsKey('Preparación'), isFalse);
  });

  test('café exposes preparation and process, never milk presentation', () {
    final values = ProductFacets.available('Café', [
      'Café molido tostado 250 g',
      'Café instantáneo 100 g doypack',
      'Café en grano torrado 500 g',
      'Café molido en saquitos 18 g',
    ]);

    expect(values['Preparación'], containsAll(['Molido', 'Instantáneo', 'En grano']));
    expect(values['Proceso'], containsAll(['Tostado', 'Torrado']));
    expect(values['Contenido'], containsAll(['500 g', '100 g', '18 g']));
    expect(values['Presentación'], containsAll(['Doypack', 'Saquitos']));
  });

  test('manteca only exposes its own variant and package content', () {
    final values = ProductFacets.available('Manteca', [
      'Manteca sin sal 200 g',
      'Manteca con sal 100 g',
    ]);

    expect(values['Variante'], containsAll(['Sin sal', 'Con sal']));
    expect(values['Contenido'], containsAll(['200 g', '100 g']));
    expect(values.containsKey('Preparación'), isFalse);
  });

  test('category search rejects unrelated products that merely contain the word leche', () {
    expect(ProductFacets.isCategoryProduct('Leche', 'Leche entera 1 litro'), isTrue);
    expect(ProductFacets.isCategoryProduct('Leche', 'La Serenisima Leche descremada 1 L'), isTrue);
    expect(ProductFacets.isCategoryProduct('Leche', 'Chocolate con leche Milka 150 g'), isFalse);
    expect(ProductFacets.isCategoryProduct('Leche', 'Oblea Leche 4 Fingers'), isFalse);
    expect(ProductFacets.isCategoryProduct('Leche', 'Arroz con leche Tregar 180 g'), isFalse);
  });

  test('selected facets narrow only products with matching attributes', () {
    expect(
      ProductFacets.matches('Leche', 'Leche entera sachet 1 L',
          {'Tipo': 'Entera', 'Presentación': 'Sachet'}),
      isTrue,
    );
    expect(
      ProductFacets.matches('Leche', 'Leche descremada botella 1 L',
          {'Tipo': 'Entera'}),
      isFalse,
    );
  });
}
