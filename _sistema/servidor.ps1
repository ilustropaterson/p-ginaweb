#Requires -Version 5.1
<#
    Servidor local para previsualizar el portfolio
    ==============================================

    Abrir el index.html directamente (file://) funciona a medias: el navegador
    bloquea las fuentes y algunas rutas. Este script sirve la carpeta por HTTP,
    igual que lo hará el hosting real.

        powershell -ExecutionPolicy Bypass -File servidor.ps1

    Luego abre http://localhost:8777/ en el navegador. Ctrl+C para parar.
#>
[CmdletBinding()]
param(
    [int]$Puerto = 8777
)

$ErrorActionPreference = 'Stop'

$RAIZ   = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$PREFIJO = 'http://localhost:{0}/' -f $Puerto

$TIPOS = @{
    '.html'  = 'text/html; charset=utf-8'
    '.css'   = 'text/css; charset=utf-8'
    '.js'    = 'text/javascript; charset=utf-8'
    '.json'  = 'application/json; charset=utf-8'
    '.xml'   = 'application/xml; charset=utf-8'
    '.txt'   = 'text/plain; charset=utf-8'
    '.webp'  = 'image/webp'
    '.woff2' = 'font/woff2'
    '.svg'   = 'image/svg+xml'
    '.pdf'   = 'application/pdf'
}

$escucha = New-Object System.Net.HttpListener
$escucha.Prefixes.Add($PREFIJO)
$escucha.Start()

Write-Host ('Sirviendo {0}' -f $RAIZ)
Write-Host ('Abre {0}  (Ctrl+C para parar)' -f $PREFIJO)

try {
    while ($escucha.IsListening) {
        $ctx = $escucha.GetContext()

        # Una petición mal formada no debe tumbar el servidor entero.
        try {
            $ruta = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
            if ($ruta -eq '/') { $ruta = '/index.html' }
            $archivo = Join-Path $RAIZ ($ruta.TrimStart('/') -replace '/', '\')

            if (Test-Path $archivo -PathType Leaf) {
                $ext = [System.IO.Path]::GetExtension($archivo).ToLower()
                if ($TIPOS.ContainsKey($ext)) { $ctx.Response.ContentType = $TIPOS[$ext] }

                $bytes = [System.IO.File]::ReadAllBytes($archivo)
                $ctx.Response.ContentLength64 = $bytes.Length

                # HEAD solo pide las cabeceras: escribir cuerpo sería un error de protocolo.
                if ($ctx.Request.HttpMethod -ne 'HEAD') {
                    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                }
            } else {
                $ctx.Response.StatusCode = 404
            }
        } catch {
            Write-Warning $_.Exception.Message
        }

        try { $ctx.Response.Close() } catch { }
    }
} finally {
    $escucha.Stop()
}
