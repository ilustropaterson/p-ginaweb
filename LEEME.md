# Portfolio Web — Fernando Paterson

Web estática, sin dependencias externas: fuentes, GSAP, ScrollTrigger y Lenis van
incluidos en `assets/`. Se sube tal cual a cualquier hosting (Netlify, Vercel,
GitHub Pages, cPanel…).

## Cómo está montado

Todo el contenido del sitio vive en **un solo archivo de datos**, y las páginas se
generan a partir de él. No se edita HTML a mano.

```
_sistema/contenido.json      ← TODO el texto, los proyectos y los ajustes del sitio
_sistema/plantillas/         ← la maquetación HTML (esqueleto + trozos reutilizables)
_sistema/generar.ps1         ← construye el sitio
_sistema/servidor.ps1        ← servidor local para previsualizar
_sistema/convertir-svg.py    ← pasa los SVG de los clientes a WebP

index.html                   ← GENERADO
proyectos/*.html             ← GENERADOS (15 case studies)
sitemap.xml, robots.txt      ← GENERADOS
assets/                      ← imágenes, fuentes, CSS y JS
_originales/                 ← NO SE SUBE: material de trabajo en bruto
```

> **`_originales/` no se sube al hosting.** Ahí viven los SVG de Illustrator de
> los clientes (más de 1 GB, con los PNG incrustados dentro). Lo que va a la web
> son sus versiones en WebP, ya convertidas, en `assets/img/clientes/`.

> **No edites `index.html`, `proyectos/*.html`, `sitemap.xml` ni `robots.txt`:**
> el generador los sobrescribe. Si quieres cambiar un texto, cámbialo en
> `contenido.json`; si quieres cambiar la maquetación, en `_sistema/plantillas/`.

> Si alguna vez tocas uno de esos archivos a mano y luego se pierde al
> regenerar, VS Code guarda copias: clic derecho en el archivo → *Open Timeline*
> (o la pestaña **Timeline** debajo del explorador). Ahí está cada versión con
> su hora, y se puede comparar o restaurar. De ahí se sacan los cambios para
> llevarlos a `contenido.json`, que es donde sobreviven.

## Generar el sitio

Doble clic no funciona con los `.ps1`. Abre PowerShell en la carpeta `_sistema` y:

```bash
powershell -ExecutionPolicy Bypass -File generar.ps1
```

Avisa si alguna imagen referenciada no existe en `assets/img/`, y recuerda si
falta poner el dominio.

## Previsualizar

Abrir `index.html` con doble clic funciona a medias (el navegador bloquea las
fuentes). Mejor levantar el servidor local:

```bash
powershell -ExecutionPolicy Bypass -File servidor.ps1
```

Y abrir <http://localhost:8777/>. `Ctrl+C` para pararlo.

## Material de clientes

Las imágenes de cada marca están en `assets/img/clientes/<marca>/` en WebP
(máx. 1600 px de lado). Los originales de Illustrator están en
`_originales/clientes/<Marca>/` y **no se suben**: son SVG de entre 2 y 84 MB
porque llevan los PNG incrustados en base64, y además usan fuentes de pago que
el navegador de un visitante no tiene.

Para convertir material nuevo hay `_sistema/convertir-svg.py`, que rasteriza con
Chrome en modo headless y comprime a WebP con Pillow (`pip install pillow`). El
primer argumento es la carpeta en `_originales/clientes` y el segundo la de
destino en `assets/img/clientes`:

```bash
python _sistema/convertir-svg.py "Mibebéstore" mibebestore
```

Se rasteriza con Chrome, y no con una librería de SVG, porque estos archivos
usan **fuentes de pago instaladas en el equipo**. Metiendo el SVG en el DOM de
una página, Chrome las resuelve igual que al abrirlo a mano; cargarlo como
`<img>` no vale. Lo importante:

- **Nunca enlaces un SVG de `_originales/` desde `contenido.json`.** Pesan
  cientos de veces más que su WebP y el texto se vería con otra tipografía.
- Los nombres se pasan a minúsculas y sin acentos: `A+ 1.svg` → `a-plus-1.webp`,
  `Página 2.svg` → `pagina-2.webp`. De eso se encarga el propio script.
- **Los SVG van en `_originales/`, nunca en `assets/img/`.** Los de las tres
  últimas marcas llegaron por error dentro de `assets/img/clientes/` y eran
  343 MB en la carpeta que se sube al hosting.
- Algunos SVG **enlazan** un PNG o un JPG del equipo en vez de incrustarlo
  (pasó con `A+ 4` y `A+ 6` de Saludbox). El script los busca por su ruta
  relativa a la carpeta `Aa Trabajo` y los incrusta al vuelo; si no encuentra
  alguno, lo avisa por pantalla. Sin ese aviso, Chrome pinta un icono de imagen
  rota y la pieza se sube así, sin que nada falle.
- Si un SVG **pide una fuente que no existe con ese nombre exacto**, Chrome cae
  a la serif por defecto sin avisar. El logo de Neobit pedía
  `Segoe UI Variable`, pero Windows la registra como `Segoe UI Variable Small
  Light` y `... Small Semibold`. Ante una pieza que salga con una tipografía
  rara, lo primero que hay que mirar es eso.

## Logos de marca

Los logos de `assets/img/marcas/` **se incrustan dentro del HTML**, no se
piden como `<img src>`. Son SVG monocromos de 2-5 KB: metidos en la página se
pintan a la vez que ella, sin peticiones ni parpadeo. De eso se encarga
`LogoIncrustado` en `generar.ps1`, que además les pone un prefijo a las clases
`.cls-N` (si no, el `<style>` de un logo repintaría a los demás) y les quita
los `id` repetidos.

Tres marcas no tienen versión vectorial y caen a `<img>` con `fetchpriority`
alto y su `<link rel="preload">` automático: **Gubosa** (solo existe en mapa de
bits), **ZenDreams** (su SVG lleva texto vivo en «Luckiest Guy», una fuente
que el visitante no tiene) y **Neobit** (texto vivo en «Segoe UI Variable
Small», que hay en Windows pero no en Mac, iPhone ni Android). Si aparece el
SVG de cualquiera de las tres con el texto ya trazado, basta con dejarlo en
`assets/img/marcas/` y se incrusta solo.

`assets/img/Nuevos Logos/` guarda los SVG de marca tal como llegan, antes de
prepararlos. El sitio no lee de ahí: los que usa son los de
`assets/img/marcas/`, ya con su `data-recorte` puesto.

Los logos salen en dos sitios, y cada uno los quiere de una forma:

- **Rejilla de clientes** — casilla cuadrada, así que se usa el lienzo original
  del SVG (800×800, con su margen).
- **Proyectos destacados** — todos a la misma altura sobre el titular. Aquí el
  lienzo cuadrado no vale: las proporciones reales van de 0,72 (Tottal, alto)
  a 6,18 (Valbaby, muy apaisado), y dentro de un cuadrado los logotipos anchos
  salen diminutos. Por eso cada SVG lleva un atributo **`data-recorte`** con el
  encuadre ajustado a su contenido, y `LogoIncrustado -Ajustado` lo pone como
  `viewBox`. El atributo nunca llega al HTML.

Si añades un logo nuevo y quieres que salga bien en los destacados, tiene que
llevar su `data-recorte="x y ancho alto"` en la etiqueta `<svg>`. Se saca
abriendo el SVG en el navegador y pidiendo `document.querySelector('svg')
.getBBox()`. Sin ese atributo no se rompe nada: simplemente se usa el lienzo
entero.

## Documentos en PDF

Una fila de galería puede ser `"tipo": "pdf"`. En vez de imágenes empotra el
documento en un visor, y el nombre del archivo va **con su extensión**:

```json
{ "tipo": "pdf",
  "items": [["clientes/zendreams/Folleto.pdf", "Folleto — las dos caras"]] }
```

Lo usa ZenDreams, cuyo case study es solo el folleto. Dos cosas que conviene
saber:

- **La portada del case study es opcional.** Si un proyecto no tiene `cover`,
  la página sale sin la imagen grande de arriba y la `og:image` pasa a ser la
  del sitio (`sitio.og_imagen`). ZenDreams es el único caso.
- **Safari en iPhone y varios navegadores de Android no empotran PDF.** Donde
  no puedan, en lugar del folleto se verá un recuadro vacío. Es una limitación
  del navegador, no del sitio: si algún día molesta, la solución es volver a
  poner las páginas como imagen (siguen en
  `assets/img/clientes/zendreams/pagina-1.webp` y `pagina-2.webp`) o añadir un
  enlace de descarga.

## Formatos de imagen admitidos

En `contenido.json` las imágenes se escriben **sin extensión** (`injusa-cover`,
`Listados/Edad-100`, `Nuevos Logos/Injusa`). El generador busca el archivo en
`assets/img/` probando, por este orden: `.svg`, `.webp`, `.jpg`, `.jpeg`, `.png`,
y escribe en el HTML el que encuentre.

Así se puede apuntar a cualquier archivo que ya esté en `assets/img/` sin tener
que convertirlo antes, y vale igual para las portadas de la home
(`home.cover`), las de los case studies (`cover.img`), las galerías y la foto de
la sección "sobre mí". Lo recomendable sigue siendo WebP por peso, y SVG para
todo lo que sea vectorial —logos, listados hechos en Illustrator—, que escala
sin pixelarse y suele pesar menos.

Si no aparece ningún archivo con esos nombres, el generador avisa al terminar
con la lista de las que faltan.

## Encuadre de las imágenes

Casi todo el trabajo de este portfolio son listados e infografías con texto
pegado al borde. Por eso la portada del case study, las fotos de la galería y
las portadas de los destacados llevan `data-encuadre="completo"`: entran con la
cortinilla, pero **sin ampliarse ni recortarse**. Si alguna vez pones una foto
que sí admita el parallax con zoom, quítale ese atributo y ponle
`data-parallax`.

## Añadir un proyecto nuevo

1. Exporta las imágenes a WebP (máx. ~1600 px de ancho) y déjalas en `assets/img/`.
   Si las guardas en una subcarpeta, **el nombre en `contenido.json` lleva la
   subcarpeta delante y nunca la extensión**: `"Listados/gubosa-2"`, no
   `"gubosa-2"` ni `"Listados/gubosa-2.webp"`. Respeta las mayúsculas tal cual
   están en el disco: Windows perdona `listados/`, pero el hosting no.
   Evita espacios en los nombres de carpeta y de archivo.
2. En `contenido.json`, copia una entrada de `"proyectos"` y cambia sus datos:
   - `slug` — nombre del archivo que se creará en `proyectos/`.
   - `logo`, `cliente`, `anio`, `sector`, `servicios`, `descripcion_seo`.
   - `contexto`, `trabajo`, `resultado` — los tres textos del case study (admiten
     `<strong>` y `<em>`).
   - `cover` — la imagen grande de portada.
   - `galeria` — filas de imágenes. Cada fila es `"g-2"` (dos columnas),
     `"g-3"` (tres) o `"full"` (una a todo el ancho). También existe
     `"pdf"`, que empotra un documento en vez de imágenes (ver más abajo).
   - `home` — cómo aparece en la portada: imagen, año, 3 etiquetas y la línea de
     cliente. Con `"destacado": true` sale en «Proyectos destacados».
   - `archivo` — categorías para los filtros (`amazon`, `aplus`, `packaging`) y el
     texto pequeño de la rejilla de clientes.
3. Ejecuta `generar.ps1`.

El orden de la lista `"proyectos"` manda: numera los destacados, ordena la rejilla
de clientes y define el «anterior / siguiente» de los case studies.

Las marcas sin case study propio (Ambiti, Mooiza…) están en `"archivo_extra"`.

## El formulario de contacto

En la sección de contacto, debajo del enlace grande con el correo, hay un
formulario con tres campos: **nombre, correo y mensaje**. Una web estática no
puede mandar correos por sí sola, así que el envío lo hace
[FormSubmit](https://formsubmit.co) — un servicio gratuito, sin registro y sin
límite de mensajes, que recibe los datos y te los reenvía a
`ilustropaterson@gmail.com`.

**Hay que activarlo una sola vez, y solo funciona con la web ya publicada:**

1. Sube la web al hosting.
2. Entra y manda un mensaje de prueba desde el formulario.
3. FormSubmit te envía un correo con un botón de confirmación. Púlsalo.
4. A partir de ahí, todos los mensajes te llegan directos a la bandeja.

Hasta que se confirme ese primer correo, los envíos no se reenvían. En local
(`localhost:8777`) el envío no funciona: hace falta el dominio real.

Los textos del formulario (etiquetas, pistas, avisos de error, el mensaje de
"enviado") están en `contenido.json`, en `portada.contacto.formulario`. El
asunto con el que te llegan los correos es `formulario.asunto`.

El correo de destino es `sitio.email`: si lo cambias ahí, cambia también el del
formulario, el del enlace grande y el del menú, y habrá que volver a confirmar
la activación con la dirección nueva.

Detalles que ya están resueltos y conviene no tocar:

- **Antispam.** El formulario lleva un campo trampa (`_honey`) invisible para
  las personas; si un robot lo rellena, FormSubmit descarta el envío. Por eso
  está desactivado el captcha (`_captcha: false`), que si no aparece una página
  intermedia de verificación.
- **Sin JavaScript también funciona.** El formulario tiene su `action` normal:
  si el JS falla, se envía igual y responde la página de gracias de FormSubmit.
  Con JS activo se manda por detrás y el aviso sale en la propia página, sin
  moverse del sitio.

Si algún día prefieres un panel donde ver los mensajes recibidos, se cambia el
`action` (y el `data-form-contacto`) de `plantillas/home.html` por el de
Formspree o el de Netlify Forms: el resto del formulario vale igual.

## Antes de publicar

Rellena `"dominio"` en `contenido.json` (por ejemplo `https://fernandopaterson.com`,
sin barra final) y vuelve a generar. Con eso se arreglan solos el `sitemap.xml`,
el `robots.txt` y las `og:image`, que pasan a ser URLs absolutas para que las
previsualizaciones al compartir funcionen.

Comprueba también el enlace de LinkedIn (`sitio.linkedin.url`): ahora apunta a una
búsqueda de tu nombre, no a tu perfil.

## Detalles que conviene no romper

- **Los `.ps1` se guardan como UTF-8 con BOM.** Si los editas con el Bloc de notas
  y los guardas sin BOM, PowerShell malinterpreta las tildes y el script deja de
  funcionar. Por eso los textos con símbolos (`↑`, `←`, `·`, `—`) viven en
  `contenido.json`, no en el script.
- Los `&` sueltos en los textos van escritos como `&amp;`.
- Las filas de proyectos destacados alternan el lado de la imagen con
  `:nth-child(even)`, contando también la cabecera de la sección.

## Accesibilidad y rendimiento

- Respeta `prefers-reduced-motion`: sin animaciones para quien lo pida.
- El menú fullscreen se cierra con `Esc`, mueve el foco al abrirse y se marca como
  `inert` mientras está cerrado.
- Imágenes con `loading="lazy"` y `alt` descriptivo.
- Los logos de la rejilla de clientes no son peticiones: van dentro del HTML.
- Animaciones basadas en `transform`/`opacity` (60 fps).
- Pendiente: hay imágenes pesadas en `assets/img/` — `injusa-aire.webp` (~293 KB)
  e `injusa-75.webp` (~285 KB) son las que más pesan y se pueden recomprimir.

## Pendientes conocidos

- **Falta la carpeta de Puremind.** Es el único cliente sin material en
  `_originales/clientes/`: su case study sigue tirando de las imágenes de
  siempre, `assets/img/Listados/puremind-1` a `-8`. Hay además una copia byte a
  byte de esas ocho en `assets/img/clientes/Puremind/` que no usa nadie; si
  algún día se enlaza, ojo con la **P mayúscula**, que en el hosting sí
  distingue. Lo limpio sería mover las imágenes a `clientes/puremind/` y borrar
  las otras dos versiones.
- **Unik Health está descartada.** Ya no tiene logo, ni ficha en la rejilla, ni
  mención en la home. Si algún día vuelve, hay que rehacer su entrada en
  `archivo_extra` y devolver el logo a `assets/img/marcas/`.
- **Faltan dos imágenes de Auvra:** `auvra-v2-a2` («Contenido A+ — módulo de uso»)
  y `auvra-v2-a4` («Contenido A+ — compatibilidad») no están en `assets/img/`.
  Se quitaron de la galería para que la página no saliera con huecos rotos. Si
  aparecen los archivos, se vuelven a añadir en `"galeria"` del proyecto Auvra.
  (La galería de Auvra ya se ha ampliado con 19 imágenes nuevas, así que no
  quedan huecos visibles.)
- **Una imagen de Valbaby sin usar:** `tienda-de-amazon-imagen-1-3-copia` es
  prácticamente idéntica a `tienda-de-amazon-imagen-1-3-1`, así que solo está
  puesta una de las dos.
- **Logos duplicados: resuelto.** Se borraron los 24 `logo-*.webp` que estaban
  repetidos en `assets/img/` y en `assets/img/Logos/`. De esa carpeta solo
  queda `lion-logo.webp`, que sí se usa (galería de Tottal). Los originales de
  marca siguen en `assets/img/Nuevos Logos/` y los que lee el sitio, en
  `assets/img/marcas/`.
- **Sin usar en `assets/img/`:** `Listados/Catálogo Valbaby2.jpg`,
  `Listados/Packa-100.jpg`, `Listados/e_commerce.jpg`, `ambiti-a1.webp`,
  `ambiti-cover.webp`, `mooiza-cover.webp`, `ubaby-cover.webp` y
  `valbaby-abc.webp`. Ninguno lo enlaza nada; se pueden borrar cuando quieras.
