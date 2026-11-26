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
    await tester.pumpAndSettle();
    expect(find.text('Filtros para Leche'), findsOneWidget);

    // The brand field is lower in a lazy ListView and may not be built yet.
    final brandLabel = find.text('Marca (opcional)');
    await tester.scrollUntilVisible(
      brandLabel,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(brandLabel, findsOneWidget);

    final brandField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Marca (opcional)',
    );
    expect(brandField, findsOneWidget);

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
}
