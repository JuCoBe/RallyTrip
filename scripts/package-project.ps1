$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskStage = Join-Path ([System.IO.Path]::GetTempPath()) ('RallyTrip-package-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskStage | Out-Null
try {
    foreach ($taskDirectory in @('RallyTrip','RallyTrip.xcodeproj','Sources','Tests','scripts','.github')) {
        Copy-Item -LiteralPath (Join-Path $taskRoot $taskDirectory) -Destination $taskStage -Recurse
    }
    foreach ($taskFile in @('Package.swift','README.md','VALIDATION.md','.gitignore','.gitattributes')) {
        Copy-Item -LiteralPath (Join-Path $taskRoot $taskFile) -Destination $taskStage
    }
    $taskDocs = Join-Path $taskStage 'docs'
    New-Item -ItemType Directory -Path $taskDocs | Out-Null
    foreach ($taskFile in @('index.html','styles.css','.nojekyll','assets')) {
        Copy-Item -LiteralPath (Join-Path $taskRoot "docs/$taskFile") -Destination $taskDocs -Recurse
    }
    # An archive cannot contain itself. Re-running this script restores the site download.
    $taskZip = Join-Path $taskRoot 'RallyTrip-iOS.zip'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $taskZipStream = [System.IO.File]::Open($taskZip, [System.IO.FileMode]::Create)
    $taskArchive = [System.IO.Compression.ZipArchive]::new($taskZipStream, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($taskFile in Get-ChildItem -LiteralPath $taskStage -Recurse -File -Force) {
            $taskRelative = [System.IO.Path]::GetRelativePath($taskStage, $taskFile.FullName).Replace('\','/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($taskArchive, $taskFile.FullName, $taskRelative) | Out-Null
        }
    } finally { $taskArchive.Dispose(); $taskZipStream.Dispose() }
    $taskDownloads = Join-Path $taskRoot 'docs/downloads'
    New-Item -ItemType Directory -Path $taskDownloads -Force | Out-Null
    Copy-Item -LiteralPath $taskZip -Destination (Join-Path $taskDownloads 'RallyTrip-iOS.zip') -Force
    Write-Output "Updated iPhone source archive and site download: $taskZip"
} finally {
    $taskResolvedStage = [System.IO.Path]::GetFullPath($taskStage)
    $taskTempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $taskResolvedStage.StartsWith($taskTempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not ([System.IO.Path]::GetFileName($taskResolvedStage)).StartsWith('RallyTrip-package-')) {
        throw 'Unexpected temporary staging path; cleanup stopped.'
    }
    Remove-Item -LiteralPath $taskResolvedStage -Recurse -Force
}
