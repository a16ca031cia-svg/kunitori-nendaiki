# 動作確認用のローカルサーバー（build/web を配信）: powershell -ExecutionPolicy Bypass -File tools\serve.ps1
param([int]$Port = 8771)
$root = Join-Path (Split-Path -Parent $PSScriptRoot) 'build\web'
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Output "Serving $root at http://localhost:$Port/"
$types = @{ '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.wasm' = 'application/wasm'; '.pck' = 'application/octet-stream'; '.png' = 'image/png'; '.json' = 'application/json' }
while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    if ($path -eq '') { $path = 'index.html' }
    $file = Join-Path $root $path
    try {
        if (Test-Path $file -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $ext = [System.IO.Path]::GetExtension($file).ToLower()
            $ctx.Response.ContentType = $(if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' })
            $ctx.Response.Headers.Add('Cache-Control', 'no-store')
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else { $ctx.Response.StatusCode = 404 }
    } catch { }
    try { $ctx.Response.Close() } catch { }
}
