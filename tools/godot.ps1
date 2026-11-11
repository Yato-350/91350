# Lance la version de Godot épinglée dans .godot-version.
# Ordre de recherche : $env:GODOT (exécutable *console* sous Windows), puis « godot » du PATH.
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$version = (Get-Content (Join-Path $root ".godot-version") -Raw).Trim()
$expected = $version.Replace("-", ".")

$godot = $env:GODOT
if (-not $godot) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { $godot = $command.Source }
}
if (-not $godot -or -not (Test-Path $godot)) {
    Write-Error "Godot $version introuvable. Définis la variable GODOT vers l'exécutable console (Godot_v${version}_win64_console.exe)."
    exit 1
}

$actual = (& $godot --version | Select-Object -First 1)
if (-not $actual.StartsWith($expected)) {
    Write-Error "Godot $expected attendu, $actual trouvé ($godot)."
    exit 1
}

& $godot @args
exit $LASTEXITCODE
