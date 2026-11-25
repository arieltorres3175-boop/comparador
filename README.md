# comparador inteligente

primera base funcional en flutter para android y preparada para evolucionar a ios

## incluye
- selector de compra minorista y mayorista
- catálogo inicial de muestra: leches, yogures, mantecas y quesos
- lista de compras guardada localmente en el teléfono
- pantalla de comparación ilustrativa por día
- sección de promociones y estrategia de sincronización
- workflow de github actions para compilar un apk android

## importante
los productos, precios y descuentos de esta versión son datos ficticios de demostración. no está conectada todavía a supermercados, mayoristas, bancos ni billeteras. no usar los importes como precios vigentes.

## ejecutar
1. instalar flutter sdk
2. ejecutar `flutter pub get`
3. ejecutar `flutter run`

## generar apk
en github: abrir la pestaña actions, seleccionar `generar-apk-android` y ejecutar `run workflow`. al finalizar, descargar el artefacto `comparador-inteligente-apk`.

## próximos hitos
1. ampliar catálogo y normalizar productos por marca, presentación y código de barras
2. diseñar backend y base central
3. integrar fuentes oficiales/autorizadas de precios
4. modelar promociones, condiciones, topes y vigencias
5. implementar sincronización incremental y notificaciones
6. validar reglas de compra minorista y mayorista por separado
