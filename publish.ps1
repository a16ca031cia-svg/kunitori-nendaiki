param([string]$Message = "更新")
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host "変更はありません"; exit 0 }
git commit -m $Message
git push
Write-Host "push しました。1〜2分後に https://a16ca031cia-svg.github.io/kunitori-nendaiki/ に反映されます"
