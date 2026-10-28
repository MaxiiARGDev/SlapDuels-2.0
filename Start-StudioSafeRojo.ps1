param([switch]$GenerateOnly)
$ErrorActionPreference = 'Stop'
$workspaceRoot = $PSScriptRoot
$projectPath = Join-Path $workspaceRoot 'studio-safe.project.json'
$project = [pscustomobject]@{
    name = "SlapDuels-2.0 Scripts Only SAFE"
    servePort = 34873
    tree = [pscustomobject]@{
        '$className' = 'DataModel'
        '$ignoreUnknownInstances' = $true
        ReplicatedStorage = [pscustomobject]@{
            '$className' = 'ReplicatedStorage'
            '$ignoreUnknownInstances' = $true
            Shared = [pscustomobject]@{
                '$className' = 'Folder'
                '$ignoreUnknownInstances' = $true
            }
        }
        ServerScriptService = [pscustomobject]@{
            '$className' = 'ServerScriptService'
            '$ignoreUnknownInstances' = $true
        }
        ServerStorage = [pscustomobject]@{
            '$className' = 'ServerStorage'
            '$ignoreUnknownInstances' = $true
        }
        StarterPlayer = [pscustomobject]@{
            '$className' = 'StarterPlayer'
            '$ignoreUnknownInstances' = $true
            StarterPlayerScripts = [pscustomobject]@{
                '$className' = 'StarterPlayerScripts'
                '$ignoreUnknownInstances' = $true
            }
            StarterCharacterScripts = [pscustomobject]@{
                '$className' = 'StarterCharacterScripts'
                '$ignoreUnknownInstances' = $true
            }
        }
        Workspace = [pscustomobject]@{
            '$className' = 'Workspace'
            '$ignoreUnknownInstances' = $true
        }
    }
}

function Ensure-SafeChild($parent, [string]$name) {
    $property = $parent.PSObject.Properties[$name]
    if ($null -eq $property) {
        $value = [pscustomobject]@{'$className'='Folder'; '$ignoreUnknownInstances'=$true}
        $parent | Add-Member -NotePropertyName $name -NotePropertyValue $value
        return $value
    }
    return $property.Value
}
$sourceFiles = Get-ChildItem -LiteralPath (Join-Path $workspaceRoot 'src') -Recurse -File |
    Where-Object { $_.Extension -in @('.luau', '.lua') }
$count = 0
foreach ($file in $sourceFiles) {
    $relative = $file.FullName.Substring($workspaceRoot.Length + 1).Replace('\','/')
    $target = $null
    if ($relative -eq 'src/server/RagdollModule.luau') {
        $target = 'ServerStorage/RagdollModule.luau'
    } elseif ($relative -eq 'src/shared/DialogModule.luau') {
        $target = 'ReplicatedStorage/DialogModule.luau'
    } elseif ($relative.StartsWith('src/server/')) {
        $target = 'ServerScriptService/' + $relative.Substring('src/server/'.Length)
    } elseif ($relative.StartsWith('src/client/')) {
        $target = 'StarterPlayer/StarterPlayerScripts/' + $relative.Substring('src/client/'.Length)
    } elseif ($relative.StartsWith('src/shared/')) {
        $target = 'ReplicatedStorage/Shared/' + $relative.Substring('src/shared/'.Length)
    } elseif ($relative.StartsWith('src/character/')) {
        $target = 'StarterPlayer/StarterCharacterScripts/' + $relative.Substring('src/character/'.Length)
    } elseif ($relative.StartsWith('src/world/')) {
        $target = 'Workspace/' + $relative.Substring('src/world/'.Length)
    }
    if (-not $target) { continue }
    $target = $target -replace '\.(server|client)\.(lua|luau)$','' -replace '\.(lua|luau)$',''
    $segments = $target.Split('/')
    $node = $project.tree
    for ($index=0; $index -lt $segments.Length-1; $index++) {
        $node = Ensure-SafeChild $node $segments[$index]
    }
    $name = $segments[-1]
    if ($name -eq 'init') {
        if ($null -eq $node.PSObject.Properties['$path']) {
            $node | Add-Member -NotePropertyName '$path' -NotePropertyValue $relative
        } else {
            $node.PSObject.Properties['$path'].Value = $relative
        }
        $count++
        continue
    }
    $leaf = [pscustomobject]@{'$path'=$relative; '$ignoreUnknownInstances'=$true}
    if ($null -eq $node.PSObject.Properties[$name]) {
        $node | Add-Member -NotePropertyName $name -NotePropertyValue $leaf
    } else {
        $node.PSObject.Properties[$name].Value = $leaf
    }
    $count++
}
[IO.File]::WriteAllText($projectPath, ($project | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))
Write-Host "Safe project refreshed: $count scripts. Existing physical assets stay in Studio."
if ($GenerateOnly) { return }
Write-Host 'Serving 127.0.0.1:34873. Use this port in Studio. Ctrl+C stops this server.'
Write-Host 'If port 34873 is already occupied by the prepared SAFE server, reconnect to that server.'
& rojo serve $projectPath --address 127.0.0.1 --port 34873
