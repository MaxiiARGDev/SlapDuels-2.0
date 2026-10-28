$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path $PSScriptRoot 'SlapDuelsUIBridge.rbxm'
if (-not (Test-Path -LiteralPath $sourcePath)) { throw 'Compilá primero el plugin con Rojo.' }
$pluginsPath = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
New-Item -ItemType Directory -Path $pluginsPath -Force | Out-Null
$destinationPath = Join-Path $pluginsPath 'SlapDuelsUIBridge.rbxm'
if (Test-Path -LiteralPath $destinationPath) {
    if ((Get-FileHash -LiteralPath $sourcePath).Hash -eq (Get-FileHash -LiteralPath $destinationPath).Hash) {
        Write-Output 'El mismo plugin ya está instalado.'
        return
    }
    $backupPath = $destinationPath + '.' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.bak'
    Copy-Item -LiteralPath $destinationPath -Destination $backupPath
    Write-Output "Versión anterior conservada en $backupPath"
}
Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
if ((Get-FileHash -LiteralPath $sourcePath).Hash -ne (Get-FileHash -LiteralPath $destinationPath).Hash) { throw 'Falló verificación SHA-256' }
Write-Output "Plugin instalado y verificado: $destinationPath"
Write-Output 'Guardá tus cambios y reiniciá Studio cuando vos decidas. Este instalador no cierra el lugar.'
