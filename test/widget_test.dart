import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('muestra la pantalla inicial del comparador', (tester) async {
    await tester.pumpWidget(const ComparadorApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('comparador inteligente'), findsOneWidget);
    expect(find.text('Una búsqueda, siete supermercados'), findsOneWidget);
    expect(find.text('Elegí una categoría para empezar'), findsOneWidget);
    expect(find.text('Búsquedas frecuentes'), findsNothing);
    // Select the category through the same visible control a user taps.
    // This keeps this screen smoke test independent from text-entry behavior.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Leche'));
    await tester.pumpAndSettle();
    expect(find.text('Filtros para Leche'), findsOneWidget);

    // Filters are data-driven and wait for the first catalog discovery.
    final discoveryHint = find.textContaining('Primero consultamos los supermercados.');
    await tester.scrollUntilVisible(
      discoveryHint,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(discoveryHint, findsOneWidget);
    expect(find.text('Marca (opcional)'), findsNothing);

    final searchButton = find.text('Buscar en los supermercados');
    await tester.scrollUntilVisible(
      searchButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(searchButton, findsOneWidget);
    expect(find.text('Consultando los catálogos online...'), findsNothing);
  });

  testWidgets('permite cargar un producto a la lista sin consultar supermercados', (tester) async {
    await tester.pumpWidget(const ComparadorApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'aceite de girasol Natura 900 ml');
    await tester.pumpAndSettle();
    final quickAddButton = find.text('Agregar a mi lista sin buscar precios');
    await tester.scrollUntilVisible(
      quickAddButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(quickAddButton, findsOneWidget);
    await tester.tap(quickAddButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mi lista').last);
    await tester.pumpAndSettle();

    expect(find.text('aceite de girasol Natura 900 ml'), findsOneWidget);
    expect(find.text('Pendiente de comparar · todavía no consultamos precios'), findsOneWidget);
  });
}
