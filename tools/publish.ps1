# 国盗り年代記（Godot版）を書き出して GitHub Pages に公開する
#   powershell -ExecutionPolicy Bypass -File tools\publish.ps1 -Message "変更内容"
# 1) core_src をまとめて scripts/core.gd を作る  2) Web 版を build/web に書き出す
# 3) ソースをコミットして main に push  4) build/web を gh-pages ブランチに置く（履歴は残さず上書き）
param([string]$Message = "更新")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$godot = "C:\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe"
$repo = "https://github.com/a16ca031cia-svg/kunitori-nendaiki.git"

# 1) core.gd
$utf8 = New-Object System.Text.UTF8Encoding($false)
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# 自動生成：core_src/*.gd をまとめたもの（直接編集しない。tools/build_core.sh か publish.ps1 で作り直す）")
[void]$sb.AppendLine("extends Node")
foreach ($f in Get-ChildItem core_src -Filter "k*.gd" | Sort-Object Name) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# ==================== $($f.Name) ====================")
    foreach ($line in [IO.File]::ReadAllLines($f.FullName, $utf8)) {
        if ($line -match '^extends ') { continue }
        [void]$sb.AppendLine(($line -replace '\bvar (\w+) := ', 'var $1 = '))
    }
}
[IO.File]::WriteAllText((Join-Path $root "scripts\core.gd"), $sb.ToString(), $utf8)
Write-Host "core.gd を作りました"

# 2) Web 書き出し
New-Item -ItemType Directory -Force build\web | Out-Null
& $godot --headless --path . --export-release Web build/web/index.html 2>&1 | Select-String -Pattern "ERROR|SCRIPT ERROR" | ForEach-Object { Write-Host $_ }
if (-not (Test-Path build\web\index.pck)) { throw "書き出しに失敗しました" }
Write-Host "Web 版を書き出しました"

# 3) ソース
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) { git commit -m $Message; git push }

# 4) gh-pages
$tmp = Join-Path $env:TEMP "kunitori_pages"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory $tmp | Out-Null
Copy-Item build\web\* $tmp -Recurse
New-Item -ItemType File (Join-Path $tmp ".nojekyll") | Out-Null
Push-Location $tmp
git init -q -b gh-pages
git config user.name (git -C $root config user.name)
git config user.email (git -C $root config user.email)
git add -A
git commit -q -m "公開: $Message"
git push -f $repo gh-pages
Pop-Location
Remove-Item -Recurse -Force $tmp
Write-Host "公開しました。1〜2分後に https://a16ca031cia-svg.github.io/kunitori-nendaiki/ に反映されます"
