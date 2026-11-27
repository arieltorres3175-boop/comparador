# Comparador API (Cloudflare Worker)

Intermediario liviano para consultar los catálogos públicos de Jumbo, Disco, Vea, Carrefour, DIA, ChangoMás y Coto desde la app web y Android.

## Rutas

- `GET /health`: estado del servicio.
- `GET /search?q=leche&store=Jumbo&limit=50`: consulta una sola cadena por invocación. Valores válidos: `Jumbo`, `Disco`, `Vea`, `Carrefour`, `DIA`, `ChangoMás` y `Coto`.
- La app realiza una invocación independiente por supermercado, conserva los resultados parciales y reintenta hasta dos veces adicionales únicamente las tiendas que fallan.
- Cada invocación puede recorrer hasta 10 páginas del catálogo de esa tienda; una tienda exitosa sin coincidencias no se reintenta.
- Los productos solo se agrupan entre comercios cuando coincide el EAN.
- La respuesta incluye precio online, precio de lista si el comercio lo informa, imagen, enlace y disponibilidad cuando existe.
- La respuesta identifica la fecha de consulta y el canal/sucursal de referencia.

## Despliegue gratuito

1. Crear una cuenta gratuita en Cloudflare.
2. En Workers & Pages, crear un Worker llamado `comparador-api`.
3. Elegir **Deploy** y luego **Edit code**.
4. Copiar el contenido de `src/index.js` y pegarlo en el editor.
5. Guardar y desplegar.
6. Probar `https://NOMBRE-DEL-WORKER.USUARIO.workers.dev/health`.
7. Configurar esa URL como base de API en la app.

También puede desplegarse desde GitHub Actions sin pegar el código manualmente:

1. En Cloudflare, crear un API Token con permiso **Workers Scripts: Edit** para la cuenta.
2. En GitHub, abrir **Settings → Secrets and variables → Actions → Secrets**.
3. Crear los secretos `CLOUDFLARE_API_TOKEN` y `CLOUDFLARE_ACCOUNT_ID`.
4. Abrir **Actions → desplegar-api-comparador → Run workflow**.
5. Al finalizar, copiar la URL `workers.dev` del Worker y guardarla como variable `COMPARADOR_API_BASE_URL` en **Settings → Secrets and variables → Actions → Variables**.

También puede desplegarse desde una terminal con Wrangler:

```bash
cd worker
npx wrangler deploy
```

## Límites y cuidados

- El Worker no inicia sesión ni agrega productos a carritos.
- Consulta únicamente búsquedas públicas y limita cada invocación a 10 páginas de hasta 50 resultados por página.
- Cachea cada búsqueda por supermercado durante aproximadamente un minuto.
- Coto está consultado con `idSucursal=200` como referencia técnica. Antes de presentarlo como precio de la zona del usuario hay que permitir seleccionar la sucursal correcta.
- VTEX usa el canal online predeterminado de cada tienda; puede variar por código postal/sucursal.
- No interpreta todavía descuentos bancarios, topes, medios de pago ni acumulación de promociones.
- No agrupa productos sin EAN: evita comparar variantes que solo se parecen por nombre.
- El Worker agrega CORS para que la web pueda consultar APIs que no habilitan CORS directamente.

## Prueba técnica

Los endpoints VTEX y Coto se comprobaron desde GitHub Actions con búsquedas públicas. En una prueba de EAN, el mismo producto apareció en Coto, Jumbo, Disco, Vea, DIA y ChangoMás; Carrefour no devolvió coincidencia para ese EAN.
