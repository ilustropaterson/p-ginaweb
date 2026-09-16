# -*- coding: utf-8 -*-
"""Pasa los SVG de _originales/clientes a WebP dentro de assets/img/clientes.

    python _sistema/convertir-svg.py "Saludbox" saludbox

El primer argumento es la carpeta dentro de _originales/clientes y el segundo
la de destino dentro de assets/img/clientes (en minusculas y sin acentos). Si
se omite el segundo, se deduce del primero.

Por que Chrome y no una libreria de SVG: los originales de Illustrator llevan
los PNG incrustados en base64 y usan fuentes de pago instaladas en el equipo.
Metiendo el SVG en el DOM de una pagina, Chrome resuelve esas fuentes igual que
lo haria al abrirlo a mano. Cargarlo como <img> no vale.

Requisitos: Google Chrome y Pillow (pip install pillow).
"""
import os, re, io, sys, base64, mimetypes, subprocess, tempfile, unicodedata
from PIL import Image

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
ORIGINALES = os.path.join('_originales', 'clientes')
DESTINO = os.path.join('assets', 'img', 'clientes')
RAIZ_TRABAJO = os.path.abspath('..')   # ...\Aa Trabajo, para los enlaces externos
LADO = 1600                            # lado mayor del WebP final
CALIDAD = 82
TMP = os.path.join(tempfile.gettempdir(), 'convertir-svg')


def normaliza(nombre):
    """'A+ 1.svg' -> 'a-plus-1'   'Pagina 2.svg' -> 'pagina-2'"""
    n = os.path.splitext(nombre)[0].replace('+', '-plus')
    n = unicodedata.normalize('NFKD', n).encode('ascii', 'ignore').decode().lower()
    return re.sub(r'-+', '-', re.sub(r'[^a-z0-9]+', '-', n)).strip('-')


def incrusta_externas(svg):
    """Algunos SVG enlazan PNG/JPG del equipo en vez de incrustarlos. Se
       resuelven contra la raiz de trabajo y se meten como data: URI; si no,
       Chrome pinta un icono de imagen rota y no avisa de nada."""
    faltan = []

    def sustituye(m):
        href = m.group(1)
        if href.startswith('data:') or href.startswith('#'):
            return m.group(0)
        rel = href.replace(chr(92), '/').lstrip('./')
        while rel.startswith('../'):
            rel = rel[3:]
        ruta = os.path.join(RAIZ_TRABAJO, rel.replace('/', os.sep))
        if not os.path.exists(ruta):
            faltan.append(href)
            return m.group(0)
        mime = mimetypes.guess_type(ruta)[0] or 'image/png'
        b64 = base64.b64encode(io.open(ruta, 'rb').read()).decode()
        return 'xlink:href="data:%s;base64,%s"' % (mime, b64)

    return re.sub(r'xlink:href="([^"]*)"', sustituye, svg), faltan


def convierte(ruta_svg, ruta_webp):
    svg = io.open(ruta_svg, encoding='utf-8', errors='replace').read()
    svg, faltan = incrusta_externas(svg)

    m = re.search(r'viewBox="([\d.\s-]+)"', svg[:2000])
    if m:
        p = [float(x) for x in m.group(1).split()]
        f = LADO / max(p[2], p[3])
        w, h = int(round(p[2] * f)), int(round(p[3] * f))
    else:
        w = h = LADO
    svg = re.sub(r'<svg\b', '<svg width="%d" height="%d"' % (w, h), svg, count=1)

    os.makedirs(TMP, exist_ok=True)
    f_html = os.path.join(TMP, 'r.html')
    f_png = os.path.join(TMP, 'r.png')
    io.open(f_html, 'w', encoding='utf-8').write(
        '<!doctype html><meta charset="utf-8"><style>html,body{margin:0;padding:0;'
        'background:#fff}svg{display:block}</style>' + svg)
    if os.path.exists(f_png):
        os.remove(f_png)
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                    '--force-device-scale-factor=1', '--virtual-time-budget=20000',
                    '--screenshot=' + f_png, '--window-size=%d,%d' % (w, h),
                    'file:///' + f_html.replace(chr(92), '/')],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=300)
    if not os.path.exists(f_png):
        return None, faltan

    imagen = Image.open(f_png).convert('RGB')
    os.makedirs(os.path.dirname(ruta_webp), exist_ok=True)
    imagen.save(ruta_webp, 'WEBP', quality=CALIDAD, method=6)
    return (imagen.size, os.path.getsize(ruta_webp)), faltan


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    marca = sys.argv[1]
    destino = sys.argv[2] if len(sys.argv) > 2 else normaliza(marca)
    origen = os.path.join(ORIGINALES, marca)
    if not os.path.isdir(origen):
        print('no existe %s' % origen)
        return 1

    svgs = sorted(f for f in os.listdir(origen) if f.lower().endswith('.svg'))
    print('%s -> assets/img/clientes/%s   (%d archivos)' % (origen, destino, len(svgs)))
    problemas = 0
    for f in svgs:
        salida = os.path.join(DESTINO, destino, normaliza(f) + '.webp')
        resultado, faltan = convierte(os.path.join(origen, f), salida)
        if resultado is None:
            print('   FALLO   %s' % f)
            problemas += 1
            continue
        (w, h), peso = resultado
        print('   %-24s -> %-24s %dx%d  %d KB' %
              (f, os.path.basename(salida), w, h, peso // 1024))
        for e in faltan:
            print('      AVISO: enlaza una imagen que no se encuentra -> %s' % e)
            problemas += 1
    print()
    print('listo%s' % ('' if not problemas else '  (%d avisos, revisa arriba)' % problemas))
    return 0


if __name__ == '__main__':
    sys.exit(main())
