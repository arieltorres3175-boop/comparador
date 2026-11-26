# Comparador inteligente

Aplicación Flutter para comparar productos publicados en supermercados de Argentina y armar una lista propia.

## Qué hace esta versión de desarrollo

- Busca productos en los catálogos online de Jumbo, Disco, Vea, Carrefour, DIA, ChangoMás y Coto.
- Muestra nombre, presentación, EAN, imagen, precio publicado y enlace al producto cuando la tienda entrega esos datos.
- Agrupa productos de distintas cadenas únicamente cuando coincide el EAN. Los artículos sin EAN quedan separados para evitar comparaciones dudosas.
- Permite agregar el producto elegido a una lista local, cambiar cantidades y comparar el total por supermercado.
- Marca como incompleto el total de una tienda cuando no se encontró alguno de los productos.
- Guarda la lista y los precios consultados en el teléfono.

## Cómo se consultan los catálogos

- **Jumbo, Disco, Vea, Carrefour, DIA y ChangoMás:** API pública de catálogo VTEX.
- **Coto:** buscador público de Coto Digital, con el identificador de sucursal de referencia `200`.
- En Android, la app consulta directamente los catálogos.
- En la versión web, las APIs VTEX no habilitan CORS para el sitio de GitHub Pages. Para la web se incluye un intermediario Cloudflare Worker en `worker/`.

## Configuración de la versión web

1. Crear un Worker gratuito en Cloudflare.
2. Publicar el código de `worker/src/index.js` siguiendo `worker/README.md`.
3. En GitHub, abrir **Settings → Secrets and variables → Actions → Variables**.
4. Crear la variable `COMPARADOR_API_BASE_URL` con la URL base del Worker, por ejemplo `https://comparador-api.tu-cuenta.workers.dev`.
5. Volver a ejecutar el workflow de Flutter Web.

Si la variable no está configurada, la búsqueda automática en la versión web mostrará un aviso. La app Android no necesita esa variable.

## Límites que la app informa

- Los precios son los publicados en catálogos online en el momento de la consulta. Pueden variar por sucursal, código postal, canal de venta y disponibilidad.
- Coto usa una sucursal de referencia hasta que se incorpore la selección de sucursal del usuario.
- No se consideran todavía descuentos bancarios, billeteras, topes, mínimos, exclusiones ni reglas de acumulación.
- La lista compara los precios guardados al agregar cada producto; hay que volver a consultar antes de comprar para confirmar vigencia.
- No se inicia sesión, no se accede a cuentas de supermercados y no se agregan productos a carritos externos.

## Pruebas

- `worker/`: pruebas unitarias del intermediario y normalización de productos.
- `.github/workflows/catalog-smoke-test.yml`: diagnóstico de endpoints públicos de las siete cadenas y verificación de coincidencia por EAN.
- `.github/workflows/validate-pr.yml`: pruebas, análisis Flutter y compilación de APK/Web.

## Ejecutar localmente

```bash
flutter pub get
flutter run
```
