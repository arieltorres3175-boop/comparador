# Comparador inteligente

Aplicación Flutter para comparar productos publicados en supermercados de Argentina y armar una lista propia.

## Qué hace esta versión de desarrollo

- Permite búsquedas por categoría o producto. La búsqueda textual prioriza únicamente productos cuyo nombre comienza con la primera palabra buscada (por ejemplo, «leche» no mezcla «dulce de leche» ni «chicle sin azúcar»).
- Muestra distintas marcas y presentaciones con nombre, EAN, imagen, precio publicado y enlace al producto cuando la tienda entrega esos datos. Las opciones se ordenan por menor precio y se pueden filtrar por marca.
- Agrupa ofertas de distintas cadenas únicamente cuando coincide el EAN. Los artículos sin EAN quedan separados para evitar comparaciones dudosas; no confunde productos parecidos con el mismo producto.
- Permite agregar el producto elegido a una lista local, cambiar cantidades y comparar el total por supermercado.
- Marca como incompleto el total de una tienda cuando no se encontró alguno de los productos.
- Guarda la lista y los precios consultados en el teléfono.

## Cómo se consultan los catálogos

- **Jumbo, Disco, Vea, Carrefour, DIA y ChangoMás:** API pública de catálogo VTEX. **Coto:** buscador público de Coto Digital con sucursal de referencia `200`.
- La app Android y la versión web consultan el intermediario Cloudflare Worker configurado en `COMPARADOR_API_BASE_URL`.
- La app realiza una solicitud independiente por supermercado. Cada una puede recorrer hasta 10 páginas de 50 resultados; los resultados exitosos se conservan y se muestran progresivamente.
- Si una tienda falla, se reintenta esa tienda hasta dos veces adicionales. Una búsqueda exitosa sin coincidencias no se reintenta.
- Separar las invocaciones evita que las consultas de otras cadenas consuman el límite de subsolicitudes de Cloudflare de una misma ejecución.

## Configuración de la versión web

1. Crear un Worker gratuito en Cloudflare.
2. Publicar el código de `worker/src/index.js` siguiendo `worker/README.md`.
3. En GitHub, abrir **Settings → Secrets and variables → Actions → Variables**.
4. Crear la variable `COMPARADOR_API_BASE_URL` con la URL base del Worker, por ejemplo `https://comparador-api.tu-cuenta.workers.dev`.
5. Volver a ejecutar el workflow de Flutter Web.

La variable es necesaria tanto para Android como para Web. Los workflows de validación también comprueban que esté configurada antes de compilar los artefactos.

## Límites que la app informa

- Los precios son los publicados en catálogos online en el momento de la consulta. Pueden variar por sucursal, código postal, canal de venta y disponibilidad.
- Coto usa una sucursal de referencia hasta que se incorpore la selección de sucursal del usuario.
- La comparación marca el menor precio publicado entre ofertas del mismo producto identificado por EAN y muestra las promociones de catálogo que cada cadena informa. Los beneficios bancarios, billeteras, topes, mínimos, exclusiones y reglas de acumulación todavía requieren una fuente verificable y una configuración de medios de pago del usuario.
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
