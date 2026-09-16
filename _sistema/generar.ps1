#Requires -Version 5.1
<#
    Generador del portfolio — Fernando Paterson
    ===========================================

    Fuente de datos :  _sistema/contenido.json
    Plantillas      :  _sistema/plantillas/

    Genera          :  index.html · proyectos/*.html · sitemap.xml · robots.txt

    Uso (desde esta carpeta):

        powershell -ExecutionPolicy Bypass -File generar.ps1

    Para añadir un proyecto basta con añadir una entrada a "proyectos" en
    contenido.json y volver a ejecutar: la home, su case study, la rejilla de
    clientes y el sitemap se actualizan solos. No se edita HTML a mano.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$AQUI       = Split-Path -Parent $PSCommandPath
$RAIZ       = Split-Path -Parent $AQUI
$PLANTILLAS = Join-Path $AQUI 'plantillas'
$PARCIALES  = Join-Path $PLANTILLAS 'parciales'
$IMAGENES   = Join-Path $RAIZ 'assets\img'

$DOMINIO_POR_DEFECTO = 'https://TUDOMINIO.com'

# Extensiones que se prueban al resolver una imagen, por orden de preferencia.
# Los logos de marca son SVG y el grueso del sitio va en WebP, pero se admiten
# JPG y PNG sueltos: así en contenido.json se puede apuntar a cualquier archivo
# que ya esté en assets/img/ sin tener que convertirlo antes.
$EXTENSIONES = @('.svg', '.webp', '.jpg', '.jpeg', '.png')

function LogosDeMapaDeBits($Datos) {
    <# Los logos del grid que no tienen versión vectorial. Hoy solo Gubosa. #>
    $sueltos = @()
    foreach ($p in $Datos.proyectos)     { $sueltos += $p.logo }
    foreach ($c in $Datos.archivo_extra) { $sueltos += $c.logo }
    $sueltos | ForEach-Object { RutaImagen $_ } |
        Where-Object { $_ -notlike '*.svg' } | Sort-Object -Unique
}


function LogoIncrustado([string]$Nombre, [string]$Alt, [switch]$Ajustado) {
    <# Los logos de la rejilla de clientes van METIDOS en el HTML, no como
       <img src>. Así se pintan a la vez que la página: cero peticiones, cero
       espera y cero parpadeo. Son SVG monocromos de 2-5 KB que además
       comprimen de maravilla.
       Si de una marca solo hay mapa de bits (Gubosa, ZenDreams), se cae a
       <img> con prioridad alta y su <link rel="preload"> en la cabecera.

       -Ajustado recorta el lienzo al logo. Los SVG vienen en cuadrado 800x800
       con mucho margen, y las proporciones reales van de 0,7 (Tottal) a 6,2
       (Valbaby): dentro de una caja cuadrada los logotipos anchos salen
       diminutos. Con el recorte se pueden poner todos a la misma altura.
       El valor lo lleva cada SVG en data-recorte; en la rejilla, que es
       cuadrada, se usa el lienzo original. #>
    $ruta = Join-Path $IMAGENES (RutaImagen $Nombre)
    $alt  = $Alt -replace '"', '&quot;'

    if ($ruta -like '*.svg' -and (Test-Path $ruta)) {
        $svg = [IO.File]::ReadAllText($ruta, [Text.Encoding]::UTF8)

        # Fuera la declaración XML y los comentarios: dentro del HTML sobran.
        $svg = [regex]::Replace($svg, '<\?xml[^>]*\?>', '')
        $svg = [regex]::Replace($svg, '(?s)<!--.*?-->', '')

        # width/height fijos pelean con el CSS de la casilla; manda el viewBox.
        $svg = [regex]::Replace($svg, '\s(width|height)="[^"]*"', '')

        if ($Ajustado) {
            $m = [regex]::Match($svg, '\sdata-recorte="([^"]+)"')
            if ($m.Success) {
                $svg = [regex]::Replace($svg, '\sviewBox="[^"]*"',
                    (' viewBox="{0}"' -f $m.Groups[1].Value), 1)
            }
        }
        # El atributo ya ha hecho su trabajo: no llega al HTML.
        $svg = [regex]::Replace($svg, '\sdata-recorte="[^"]*"', '')

        # Un id repetido varias veces en la misma página es HTML inválido.
        $svg = [regex]::Replace($svg, '\sid="[^"]*"', '')

        # Las clases .cls-N las repiten TODOS los logos: sin prefijo, el
        # <style> de un logo repinta los demás. Se les pone el de la marca.
        $marca = ($Nombre -split '[/\\]')[-1]
        $svg = [regex]::Replace($svg, '(?<=[.\s"])cls-(\d+)', ('{0}-cls-$1' -f $marca))

        $svg = [regex]::Replace(
            $svg, '^\s*<svg',
            ('<svg class="logo-svg" role="img" aria-label="{0}"' -f $alt))

        # Todo en una línea: si no, la sangría del parcial se descuadra.
        return ([regex]::Replace($svg, '\s+', ' ')).Trim()
    }

    return ('<img class="logo-img" src="assets/img/{0}" alt="{1}" decoding="async" fetchpriority="high">' -f
        (RutaImagen $Nombre), $alt)
}


function RutaImagen([string]$Nombre) {
    <# Convierte "marcas/injusa" en "marcas/injusa.svg" mirando qué archivo
       existe de verdad. Si no hay ninguno devuelve .webp, para que el aviso
       de imágenes ausentes lo siga cazando en vez de callárselo. #>
    foreach ($ext in $EXTENSIONES) {
        if (Test-Path (Join-Path $IMAGENES ($Nombre + $ext))) { return $Nombre + $ext }
    }
    return $Nombre + '.webp'
}


# ------------------------------------------------------------------ plantillas

function LeerTexto([string]$Ruta) {
    ([System.IO.File]::ReadAllText($Ruta)) -replace "`r`n", "`n"
}

function Render {
    <# Rellena una plantilla. Avisa si queda alguna variable sin valor. #>
    param([string]$Ruta, [hashtable]$Valores)

    $texto = LeerTexto $Ruta
    foreach ($clave in $Valores.Keys) {
        $texto = $texto.Replace('${' + $clave + '}', [string]$Valores[$clave])
    }
    if ($texto -match '\$\{([A-Za-z_][A-Za-z0-9_]*)\}') {
        throw ("Falta la variable '{0}' al rellenar {1}" -f $Matches[1], (Split-Path -Leaf $Ruta))
    }
    $texto -replace "[\r\n]+$", ''
}

function Parcial([string]$Nombre, [hashtable]$Valores) {
    Render (Join-Path $PARCIALES ('{0}.html' -f $Nombre)) $Valores
}


# -------------------------------------------------------------------- utilidad

function Sangrar([string[]]$Lineas, [int]$Espacios) {
    $pad = ' ' * $Espacios
    ($Lineas | ForEach-Object { $pad + $_ }) -join "`n"
}

function Numero([int]$Indice) {
    # Los índices visibles del sitio van siempre a dos cifras: 01, 02…
    '{0:D2}' -f $Indice
}

function TituloLineas($Lineas) {
    # Titular que se revela línea a línea: cada una dentro de su máscara.
    $salida = foreach ($linea in $Lineas) {
        if ($linea -is [string]) { $texto = $linea; $clase = '' }
        else                     { $texto = $linea.texto; $clase = $linea.clase }

        if ($clase) { $interior = '<span class="{0}">{1}</span>' -f $clase, $texto }
        else        { $interior = '<span>{0}</span>' -f $texto }

        '<span class="line-mask">{0}</span>' -f $interior
    }
    $salida -join ''
}

function Etiquetas($Nombres) {
    ($Nombres | ForEach-Object { '<span class="tag">{0}</span>' -f $_ }) -join ''
}

function Envolver($Textos, [string]$Formato) {
    ($Textos | ForEach-Object { $Formato -f $_ }) -join ''
}

function UrlAbsoluta([string]$Dominio, [string]$Ruta) {
    if ($Dominio) { '{0}/{1}' -f $Dominio, $Ruta } else { $Ruta }
}


# ----------------------------------------------------------- bloques comunes

function Cabecera($Sitio, [bool]$EnCaso) {
    if ($EnCaso) { $prefijo = '../index.html'; $inicio = '../index.html' }
    else         { $prefijo = '';              $inicio = 'index.html' }

    $nav = foreach ($i in $Sitio.nav) {
        '<a href="{0}{1}">{2}</a>' -f $prefijo, $i.ancla, $i.texto
    }
    Parcial 'cabecera' @{
        inicio = $inicio
        marca  = $Sitio.marca
        nav    = (Sangrar $nav 4)
    }
}

function Menu($Sitio, [bool]$EnCaso) {
    if ($EnCaso) { $prefijo = '../index.html' } else { $prefijo = '' }

    $enlaces = foreach ($i in $Sitio.nav) {
        '<a href="{0}{1}"><span class="num">{2}</span>{3}</a>' -f $prefijo, $i.ancla, $i.num, $i.texto
    }
    Parcial 'menu' @{
        menu_label = $Sitio.menu_label
        enlaces    = (Sangrar $enlaces 4)
        email      = $Sitio.email
        menu_meta  = $Sitio.menu_meta
    }
}

function Pie($Sitio, [bool]$EnCaso, [int]$Anio) {
    if ($EnCaso) {
        $medio  = '  <a href="mailto:{0}">{0}</a>' -f $Sitio.email
        $href   = '../index.html'
        $volver = $Sitio.textos.volver_inicio
    } else {
        $medio  = '  <p>{0}</p>' -f $Sitio.pie_home
        $href   = '#top'
        $volver = $Sitio.textos.volver_arriba
    }
    Parcial 'pie' @{
        anio         = [string]$Anio
        autor        = $Sitio.autor
        medio        = $medio
        arriba_href  = $href
        arriba_texto = $volver
    }
}

function Pagina {
    param(
        $Sitio,
        [bool]$EnCaso,
        [string]$Titulo,
        [string]$Descripcion,
        [string]$OgTipo,
        [string]$OgTitulo,
        [string]$OgDescripcion,
        [string]$OgImagen,
        [string]$Transicion,
        [string]$Main,
        [string]$CabezaExtra = ''
    )
    if ($EnCaso) { $raiz = '../' } else { $raiz = '' }

    (Render (Join-Path $PLANTILLAS 'base.html') @{
        idioma         = $Sitio.idioma
        raiz           = $raiz
        titulo         = $Titulo
        descripcion    = $Descripcion
        og_tipo        = $OgTipo
        og_titulo      = $OgTitulo
        og_descripcion = $OgDescripcion
        og_imagen      = $OgImagen
        locale         = $Sitio.locale
        theme_color    = $Sitio.theme_color
        cabeza_extra   = $CabezaExtra
        transicion     = $Transicion
        cabecera       = (Cabecera $Sitio $EnCaso)
        menu           = (Menu $Sitio $EnCaso)
        main           = $Main
        pie            = (Pie $Sitio $EnCaso (Get-Date).Year)
    }) + "`n"
}


# ------------------------------------------------------------------- la home

function BloqueDestacados($Proyectos) {
    $indice = 0
    $filas = foreach ($p in $Proyectos) {
        $indice++
        $h = $p.home
        if ($h.aria) { $aria = $h.aria } else { $aria = 'Ver proyecto {0}' -f $p.nombre }

        Parcial 'destacado' @{
            slug    = $p.slug
            aria    = $aria
            cover   = (RutaImagen $h.cover)
            alt     = $h.alt
            carga   = $h.carga
            logo    = (LogoIncrustado $p.logo $p.logo_alt -Ajustado)
            indice  = (Numero $indice)
            anio    = $h.anio
            nombre  = $p.nombre
            tags    = (Etiquetas $h.tags)
            cliente = $h.cliente
        }
    }
    $filas -join "`n"
}

function BloqueArchivo($Proyectos, $Extra) {
    $items = @()
    foreach ($p in $Proyectos) {
        $items += Parcial 'archivo-item' @{
            cats     = ($p.archivo.cats -join ' ')
            slug     = $p.slug
            logo     = (LogoIncrustado $p.logo $p.logo_alt)
            nombre   = $p.nombre
            meta     = $p.archivo.meta
        }
    }
    foreach ($c in $Extra) {
        $items += Parcial 'archivo-item-sin-enlace' @{
            cats     = ($c.cats -join ' ')
            logo     = (LogoIncrustado $c.logo $c.logo_alt)
            nombre   = $c.nombre
            meta     = $c.meta
        }
    }
    $items -join "`n"
}

function BloqueServicios($Servicios) {
    $indice = 0
    $filas = foreach ($s in $Servicios) {
        $indice++
        Parcial 'servicio' @{
            clave  = $s.clave
            indice = (Numero $indice)
            titulo = $s.titulo
            texto  = $s.texto
            items  = (Envolver $s.items '<li>{0}</li>')
        }
    }
    $filas -join "`n"
}

function ColumnasSobreMi($Sobre) {
    $columnas = foreach ($col in $Sobre.columnas) {
        $filas = foreach ($f in $col.filas) {
            $celdas = '<span>{0}</span>' -f $f[0]
            if ($f[1]) { $celdas += '<span>{0}</span>' -f $f[1] }
            '              <li>{0}</li>' -f $celdas
        }
        @(
            '          <div class="about-col">'
            ('            <h5>{0}</h5>' -f $col.titulo)
            '            <ul>'
            ($filas -join "`n")
            '            </ul>'
            '          </div>'
        ) -join "`n"
    }
    $columnas -join "`n"
}

function StatsSobreMi($Sobre) {
    $stats = foreach ($s in $Sobre.stats) {
        '<div class="stat"><span class="big"><span data-count="{0}" data-suffix="{1}">{0}{1}</span></span><span class="label">{2}</span></div>' -f $s.valor, $s.sufijo, $s.label
    }
    Sangrar $stats 10
}

function GenerarHome($Datos, $Destacados) {
    $sitio = $Datos.sitio
    $portada  = $Datos.home
    $hero  = $portada.hero
    $sobre = $portada.sobre_mi

    $marquee = Envolver $portada.marquee '<span>{0}</span>'
    $fila1   = Envolver $portada.clientes.fila_1 '<span>{0}</span>'
    $fila2   = Envolver $portada.clientes.fila_2 '<span>{0}</span>'

    $ctas = foreach ($c in $hero.ctas) {
        $clase = ('btn ' + $c.clase).Trim()
        if ($c.cursor) { $cursor = ' data-cursor="ver" data-cursor-label="{0}"' -f $c.cursor }
        else           { $cursor = '' }
        '<a class="{0}" href="{1}"{2}>{3}</a>' -f $clase, $c.href, $cursor, $c.texto
    }

    $filtros = @()
    foreach ($f in $portada.archivo.filtros) {
        if ($filtros.Count -eq 0) { $activo = ' is-active' } else { $activo = '' }
        $filtros += '<button class="filter-btn{0}" data-filter="{1}">{2}</button>' -f $activo, $f.id, $f.texto
    }

    $proceso = @()
    foreach ($p in $portada.proceso) {
        $proceso += '<div class="step"><span class="num">{0}</span><h4>{1}</h4><p>{2}</p></div>' -f (Numero ($proceso.Count + 1)), $p.titulo, $p.texto
    }

    $palabras = foreach ($p in $hero.rotador_palabras) { '<span class="word">{0}</span>' -f $p }
    $parrafos = foreach ($p in $sobre.parrafos) { '<p data-reveal>{0}</p>' -f $p }

    $formulario = $portada.contacto.formulario

    $main = Render (Join-Path $PLANTILLAS 'home.html') @{
        hero_label             = $hero.label
        hero_estado            = $hero.estado
        hero_titulo_1          = $hero.titulo[0]
        hero_titulo_2          = $hero.titulo[1]
        hero_rotador_prefijo   = $hero.rotador_prefijo
        hero_rotador_palabras  = (Sangrar $palabras 12)
        hero_claim             = $hero.claim
        hero_ctas              = (Sangrar $ctas 8)
        marquee                = (Sangrar @($marquee, $marquee) 6)
        destacados_titulo      = (TituloLineas $portada.destacados.titulo)
        destacados_label       = $portada.destacados.label
        destacados             = (BloqueDestacados $Destacados)
        archivo_titulo         = (TituloLineas $portada.archivo.titulo)
        archivo_label          = $portada.archivo.label
        filtros                = (Sangrar $filtros 6)
        archivo                = (BloqueArchivo $Datos.proyectos $Datos.archivo_extra)
        servicios_titulo       = (TituloLineas $portada.servicios.titulo)
        servicios_label        = $portada.servicios.label
        servicios              = (BloqueServicios $portada.servicios.lista)
        proceso                = (Sangrar $proceso 6)
        sobre_titulo           = (TituloLineas $sobre.titulo)
        sobre_label            = $sobre.label
        sobre_foto             = (RutaImagen $sobre.foto)
        sobre_foto_alt         = $sobre.foto_alt
        sobre_foto_pie         = $sobre.foto_pie
        sobre_claim            = $sobre.claim
        sobre_parrafos         = (Sangrar $parrafos 8)
        sobre_columnas         = (ColumnasSobreMi $sobre)
        sobre_stats            = (StatsSobreMi $sobre)
        clientes_label         = $portada.clientes.label
        clientes_fila_1        = (Sangrar @($fila1, $fila1) 6)
        clientes_fila_2        = (Sangrar @($fila2, $fila2) 6)
        contacto_label         = $portada.contacto.label
        contacto_titulo        = (TituloLineas $portada.contacto.titulo)
        contacto_cursor        = $portada.contacto.cursor
        contacto_form_label    = $formulario.label
        contacto_form_asunto   = $formulario.asunto
        contacto_form_nombre   = $formulario.nombre
        contacto_form_nombre_pista  = $formulario.nombre_pista
        contacto_form_email    = $formulario.email
        contacto_form_email_pista   = $formulario.email_pista
        contacto_form_mensaje  = $formulario.mensaje
        contacto_form_mensaje_pista = $formulario.mensaje_pista
        contacto_form_nombre_error  = $formulario.nombre_error
        contacto_form_email_error   = $formulario.email_error
        contacto_form_mensaje_error = $formulario.mensaje_error
        contacto_form_enviar   = $formulario.enviar
        contacto_form_enviando = $formulario.enviando
        contacto_form_exito    = $formulario.exito
        contacto_form_error    = $formulario.error
        abierto_a              = $portada.contacto.abierto_a
        email                  = $sitio.email
        linkedin_url           = $sitio.linkedin.url
        linkedin_texto         = $sitio.linkedin.texto
        base                   = $sitio.base
    }

    $jsonLd = Parcial 'datos-estructurados' @{ autor = $sitio.autor; email = $sitio.email }

    # Los logos del grid van incrustados en el HTML menos los que solo existen
    # en mapa de bits: esos se piden por adelantado para que lleguen a la vez.
    $precarga = foreach ($n in (LogosDeMapaDeBits $Datos)) {
        '<link rel="preload" href="assets/img/{0}" as="image" type="image/webp">' -f $n
    }
    if ($precarga) { $jsonLd = ($precarga -join "`n") + "`n" + $jsonLd }

    Pagina -Sitio $sitio -EnCaso $false `
        -Titulo $sitio.titulo -Descripcion $sitio.descripcion `
        -OgTipo 'website' -OgTitulo $sitio.og_titulo -OgDescripcion $sitio.og_descripcion `
        -OgImagen (UrlAbsoluta $sitio.dominio ('assets/img/{0}.webp' -f $sitio.og_imagen)) `
        -Transicion $sitio.autor -Main $main -CabezaExtra $jsonLd
}


# ---------------------------------------------------------------- case studies

function BloqueGaleria($Galeria, [string]$Nombre, [string]$FormatoAlt) {
    $filas = foreach ($fila in $Galeria) {
        # Una fila "pdf" empotra el documento en vez de mostrar imágenes.
        if ($fila.tipo -eq 'pdf') {
            $items = foreach ($it in $fila.items) {
                Parcial 'galeria-doc' @{
                    doc    = $it[0]
                    titulo = $FormatoAlt -f $it[1], $Nombre
                    pie    = $it[1]
                }
            }
            ('    <div class="g-row">') + "`n" + ($items -join "`n") + "`n    </div>"
            continue
        }

        if ($fila.tipo -eq 'full') { $clase = 'g-row' } else { $clase = 'g-row {0}' -f $fila.tipo }

        $items = foreach ($it in $fila.items) {
            Parcial 'galeria-item' @{
                img = (RutaImagen $it[0])
                alt = $FormatoAlt -f $it[1], $Nombre
                pie = $it[1]
            }
        }
        ('    <div class="{0}">' -f $clase) + "`n" + ($items -join "`n") + "`n    </div>"
    }
    $filas -join "`n"
}

function PortadaCaso($Proyecto) {
    <# La imagen grande de arriba. Un proyecto puede no tenerla: ZenDreams es
       solo un folleto en PDF, así que su case study va sin portada. #>
    if (-not $Proyecto.cover.img) { return '' }
    Parcial 'portada' @{
        cover_img = (RutaImagen $Proyecto.cover.img)
        cover_alt = $Proyecto.cover.alt
    }
}


function GenerarCaso($Datos, [int]$Indice) {
    $sitio     = $Datos.sitio
    $proyectos = $Datos.proyectos
    $total     = $proyectos.Count

    $p         = $proyectos[$Indice]
    $anterior  = $proyectos[(($Indice - 1 + $total) % $total)]
    $siguiente = $proyectos[(($Indice + 1) % $total)]

    $main = Render (Join-Path $PLANTILLAS 'caso.html') @{
        nombre        = $p.nombre
        logo          = (RutaImagen $p.logo)
        logo_alt      = $p.logo_alt
        cliente       = $p.cliente
        anio          = $p.anio
        sector        = $p.sector
        servicios_txt = ($p.servicios -join $sitio.textos.separador_servicios)
        portada       = (PortadaCaso $p)
        contexto      = $p.contexto
        trabajo       = $p.trabajo
        tags          = (Etiquetas $p.servicios)
        galeria       = (BloqueGaleria $p.galeria $p.nombre $sitio.textos.alt_galeria)
        resultado     = $p.resultado
        prev_slug     = $anterior.slug
        prev_nombre   = $anterior.nombre
        next_slug     = $siguiente.slug
        next_nombre   = $siguiente.nombre
    }

    $titulo = $sitio.textos.titulo_caso -f $p.nombre, $sitio.autor
    # Sin portada propia (ZenDreams es solo un PDF) tira de la imagen del sitio.
    if ($p.cover.img) { $og = $p.cover.img } else { $og = $sitio.og_imagen }
    if ($sitio.dominio) {
        $ogImagen = '{0}/assets/img/{1}.webp' -f $sitio.dominio, $og
    } else {
        $ogImagen = '../assets/img/{0}.webp' -f $og
    }

    Pagina -Sitio $sitio -EnCaso $true `
        -Titulo $titulo -Descripcion $p.descripcion_seo `
        -OgTipo 'article' -OgTitulo $titulo -OgDescripcion $p.descripcion_seo `
        -OgImagen $ogImagen -Transicion $p.nombre -Main $main
}


# ---------------------------------------------------------------- SEO estático

function GenerarSitemap($Datos) {
    $dominio = $Datos.sitio.dominio
    if (-not $dominio) { $dominio = $DOMINIO_POR_DEFECTO }

    $urls = @('  <url><loc>{0}/</loc><priority>1.0</priority></url>' -f $dominio)
    foreach ($p in $Datos.proyectos) {
        $urls += '  <url><loc>{0}/proyectos/{1}.html</loc><priority>0.8</priority></url>' -f $dominio, $p.slug
    }
    if ($Datos.sitio.dominio) { $aviso = '' }
    else { $aviso = "`n<!-- Pon tu dominio en `"dominio`" (contenido.json) y vuelve a generar. -->" }

    '<?xml version="1.0" encoding="UTF-8"?>' + $aviso + "`n" +
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + "`n" +
    ($urls -join "`n") + "`n</urlset>`n"
}

function GenerarRobots($Datos) {
    $dominio = $Datos.sitio.dominio
    if (-not $dominio) { $dominio = $DOMINIO_POR_DEFECTO }
    "User-agent: *`nAllow: /`nSitemap: {0}/sitemap.xml`n" -f $dominio
}


# --------------------------------------------------------------------- avisos

function ImagenesReferenciadas($Datos) {
    $nombres = New-Object System.Collections.Generic.HashSet[string]

    foreach ($c in $Datos.archivo_extra)            { [void]$nombres.Add($c.logo) }
    [void]$nombres.Add($Datos.home.sobre_mi.foto)

    foreach ($p in $Datos.proyectos) {
        [void]$nombres.Add($p.logo)
        if ($p.cover.img)  { [void]$nombres.Add($p.cover.img) }
        if ($p.home.cover) { [void]$nombres.Add($p.home.cover) }
        foreach ($fila in $p.galeria) {
            # Las filas de documento llevan la extensión puesta: no son imágenes.
            if ($fila.tipo -eq 'pdf') { continue }
            foreach ($it in $fila.items) { [void]$nombres.Add($it[0]) }
        }
    }
    $nombres
}

function AvisarDeImagenesAusentes($Datos) {
    $faltan = @()
    foreach ($n in (ImagenesReferenciadas $Datos)) {
        if (-not (Test-Path (Join-Path $IMAGENES (RutaImagen $n)))) { $faltan += $n }
    }
    if ($faltan.Count -gt 0) {
        Write-Host ''
        Write-Warning 'Faltan imágenes en assets/img/:'
        foreach ($n in ($faltan | Sort-Object)) { Write-Host ('   · {0} (.svg o .webp)' -f $n) }
    }
}


# ----------------------------------------------------------------------- main

function Escribir([string]$Ruta, [string]$Contenido) {
    $carpeta = Split-Path -Parent $Ruta
    if (-not (Test-Path $carpeta)) { New-Item -ItemType Directory -Force -Path $carpeta | Out-Null }

    $utf8SinBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Ruta, $Contenido, $utf8SinBom)

    Write-Host ('  OK  {0}' -f $Ruta.Substring($RAIZ.Length + 1))
}

$datos = (LeerTexto (Join-Path $AQUI 'contenido.json')) | ConvertFrom-Json
$destacados = @($datos.proyectos | Where-Object { $_.home.destacado })

Escribir (Join-Path $RAIZ 'index.html') (GenerarHome $datos $destacados)
for ($i = 0; $i -lt $datos.proyectos.Count; $i++) {
    Escribir (Join-Path $RAIZ ('proyectos\{0}.html' -f $datos.proyectos[$i].slug)) (GenerarCaso $datos $i)
}
Escribir (Join-Path $RAIZ 'sitemap.xml') (GenerarSitemap $datos)
Escribir (Join-Path $RAIZ 'robots.txt')  (GenerarRobots $datos)

Write-Host ''
Write-Host ('{0} case studies · {1} destacados en la home.' -f $datos.proyectos.Count, $destacados.Count)
if (-not $datos.sitio.dominio) {
    Write-Host '· Recuerda rellenar "dominio" en contenido.json antes de publicar.'
}
AvisarDeImagenesAusentes $datos
