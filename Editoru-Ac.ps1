$ErrorActionPreference = 'Stop'
$projectPath = Join-Path $PSScriptRoot 'godot'
$enginePath = Join-Path $PSScriptRoot '.tools\godot\Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    throw 'Godot bulunamadi. Once python tools/setup_assets.py komutunu calistirin.'
}
& $enginePath --editor --path $projectPath
