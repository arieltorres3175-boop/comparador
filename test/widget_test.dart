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
    await tester.enterText(find.byType(TextField).first, 'leche');
    await tester.pump();
    expect(find.text('Filtros para Leche'), findsOneWidget);

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));
    expect(
      tester.widget<TextField>(textFields.at(1)).decoration.labelText,
      'Marca (opcional)',
    );

    expect(find.text('Buscar en los supermercados'), findsOneWidget);
    expect(find.text('Consultando los catálogos online...'), findsNothing);
  });
}
