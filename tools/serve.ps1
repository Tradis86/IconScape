# Static server for the browser preview when Node is not installed: serves prototype/ on http://localhost:5178/ (same port as prototype/serve.mjs)
param([int]$Port = 5178)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\prototype'))
$types = @{ '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.mjs' = 'text/javascript; charset=utf-8';
    '.json' = 'application/json; charset=utf-8'; '.css' = 'text/css; charset=utf-8'; '.png' = 'image/png'; '.webp' = 'image/webp';
    '.svg' = 'image/svg+xml'; '.ico' = 'image/x-icon' }
$listener = New-Object Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $root on http://localhost:$Port/"
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $response = $context.Response
        try {
            $relative = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath).TrimStart('/')
            if ($relative -eq '') { $relative = 'settings.html' }
            $path = [IO.Path]::GetFullPath((Join-Path $root $relative))
            # Only files inside prototype/ are served
            if ($path.StartsWith($root + [IO.Path]::DirectorySeparatorChar) -and (Test-Path -LiteralPath $path -PathType Leaf)) {
                $bytes = [IO.File]::ReadAllBytes($path)
                $type = $types[[IO.Path]::GetExtension($path).ToLowerInvariant()]
                $response.ContentType = if ($type) { $type } else { 'application/octet-stream' }
                $response.Headers['Cache-Control'] = 'no-store'
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else { $response.StatusCode = 404 }
        } catch { $response.StatusCode = 500 }
        finally { $response.Close() }
    }
} finally { $listener.Stop() }
