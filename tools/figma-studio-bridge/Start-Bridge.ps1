$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot
try { & node 'bridge/server.mjs'; if ($LASTEXITCODE -ne 0) { throw 'El puente terminó con un error.' } }
finally { Pop-Location }
