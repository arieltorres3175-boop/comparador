# Comparador inteligente

Aplicación Flutter para ayudar a comparar compras en supermercados de Argentina.

## Estado de esta versión (MVP inicial)

- Búsqueda de texto del producto que el usuario quiere consultar.
- Acceso directo a los sitios oficiales de Carrefour, Jumbo, Coto, Disco, Vea, ChangoMás y DIA.
- Copiado del texto de búsqueda para pegarlo en el buscador de cada tienda.
- Lista de compras propia, con cantidades y persistencia local en el teléfono.
- Sin precios, descuentos, stock ni resultados ficticios.

## Limitación importante

Esta versión todavía **no consulta automáticamente** los catálogos de los supermercados ni compara precios. Los botones abren los sitios oficiales y el usuario realiza la búsqueda allí. No se debe interpretar esta versión como un comparador automático ni como una fuente de precios vigentes.

La integración automática requiere estudiar y validar por separado las fuentes públicas/autorizadas de cada cadena, sus condiciones de acceso, la identificación de variantes (idealmente EAN), sucursales, vigencias y promociones.

## Ejecutar

1. Instalar Flutter SDK.
2. Ejecutar `flutter pub get`.
3. Ejecutar `flutter run`.

## Generar APK

En GitHub: abrir **Actions**, seleccionar **generar-apk-android** y ejecutar **Run workflow**. Al finalizar, descargar el artefacto `comparador-inteligente-apk`.

## Próximos hitos

1. Validar búsquedas y rutas de catálogo de cada supermercado.
2. Implementar conectores de consulta donde el acceso esté permitido y sea técnicamente estable.
3. Normalizar productos por marca, variante, contenido y EAN.
4. Incorporar precios con fuente y fecha/hora de consulta.
5. Modelar promociones, medios de pago, topes, mínimos, vigencias y reglas de acumulación.
6. Comparar listas completas y combinaciones de comercios sin inventar datos.
