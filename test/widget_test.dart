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
  });

  testWidgets('muestra criterios del producto antes de consultar supermercados', (tester) async {
    await tester.pumpWidget(const ComparadorApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    final lecheChip = find.widgetWithText(ChoiceChip, 'Leche');
    await tester.ensureVisible(lecheChip);
    await tester.tap(lecheChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Precisá Leche'), findsOneWidget);
    // ListView builds children lazily. Scroll the criteria into the viewport
    // before asserting that their TextFields have been mounted.
    final searchButton = find.text('Buscar en los supermercados');
    await tester.scrollUntilVisible(
      searchButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Inspect the TextField configuration; decoration is nullable in Flutter.
    for (final label in [
      'Marca',
      'Tipo o variedad',
      'Envase o presentación',
      'Contenido',
    ]) {
      expect(
        find.byWidgetPredicate(
          (widget) => widget is DropdownButtonFormField<String> &&
              widget.decoration.labelText == label,
        ),
        findsOneWidget,
        reason: 'Debe existir el selector "$label" antes de consultar tiendas.',
      );
    }
    expect(find.textContaining('Primero consultamos los supermercados'), findsNothing);
    expect(find.text('Buscar en los supermercados'), findsOneWidget);
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
