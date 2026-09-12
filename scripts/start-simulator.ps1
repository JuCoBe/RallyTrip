[CmdletBinding()]
param([switch]$CheckOnly)

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskBase = 'https://api.github.com/repos/JuCoBe/RallyTrip'
$taskOriginalInteractive = $env:GCM_INTERACTIVE
$taskArchivePath = $null

function Invoke-RallyGitHub {
    param([string]$Path, [string]$Method = 'Get', [object]$Body)
    $taskArguments = @{
        Uri = "$taskBase/$Path"; Method = $Method
        Headers = $taskGitHubHeaders; TimeoutSec = 30
    }
    if ($null -ne $Body) {
        $taskArguments.ContentType = 'application/json'
        $taskArguments.Body = ConvertTo-Json -InputObject $Body -Depth 5 -Compress
    }
    Invoke-RestMethod @taskArguments
}

try {
    # These two credentials stay local/in memory and never enter the repository or logs.
    $taskAccessPath = Join-Path $env:USERPROFILE '.codex\artifacts\RallyTrip\remote-access.json'
    if (-not (Test-Path -LiteralPath $taskAccessPath)) {
        throw 'Der lokale Simulator-Zugangsschluessel fehlt. Bitte die Einrichtung in diesem Codex-Projekt erneuern lassen.'
    }
    $taskAccess = Get-Content -LiteralPath $taskAccessPath -Raw | ConvertFrom-Json
    if ($taskAccess.token -notmatch '^[A-Za-z0-9_-]{32,}$') { throw 'Der lokale Zugangsschluessel ist ungueltig.' }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git wurde nicht gefunden. Bitte Git fuer Windows installieren.' }
    $env:GCM_INTERACTIVE = 'never'
    $taskCredential = "protocol=https`nhost=github.com`nusername=JuCoBe`n`n" | git -C $taskRoot credential fill 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'GitHub-Anmeldung fehlt. Bitte zuerst Git fuer JuCoBe bei GitHub anmelden.' }
    $taskPasswordLine = @($taskCredential | Where-Object { $_.StartsWith('password=') })
    if ($taskPasswordLine.Count -ne 1) { throw 'GitHub-Zugang konnte nicht geladen werden.' }
    $taskGitHubHeaders = @{
        Authorization = 'Bearer ' + $taskPasswordLine[0].Substring(9)
        Accept = 'application/vnd.github+json'
        'User-Agent' = 'RallyTrip-Simulator-Launcher'
    }
    $taskWorkflow = Invoke-RallyGitHub 'actions/workflows/remote-simulator.yml'
    if ($taskWorkflow.state -ne 'active') { throw 'Der GitHub-Simulator-Workflow ist nicht aktiv.' }
    if ($CheckOnly) {
        Write-Host 'Startpruefung erfolgreich: GitHub-Anmeldung, Workflow und lokaler Zugangsschluessel vorhanden.'
        Write-Host 'Es wurde keine Simulatorsitzung gestartet.'
        return
    }

    $taskRequestId = [guid]::NewGuid().ToString('N')
    Write-Host 'Starte einen neuen iPhone-Simulator auf GitHub ...'
    Write-Host 'Eine eventuell noch laufende Simulatorsitzung wird dadurch beendet.'
    Invoke-RallyGitHub 'actions/workflows/remote-simulator.yml/dispatches' 'Post' @{
        ref = 'main'; inputs = @{ request_id = $taskRequestId }
    } | Out-Null
    $taskDeadline = (Get-Date).AddMinutes(25)
    $taskRun = $null
    $taskLastStatus = ''
    $taskArtifact = $null
    while ((Get-Date) -lt $taskDeadline) {
        if ($null -eq $taskRun) {
            $taskRuns = Invoke-RallyGitHub 'actions/workflows/remote-simulator.yml/runs?event=workflow_dispatch&per_page=30'
            $taskRun = $taskRuns.workflow_runs | Where-Object { $_.display_title -eq "Simulator $taskRequestId" } | Select-Object -First 1
            if ($null -ne $taskRun) { Write-Host ('GitHub-Lauf: ' + $taskRun.html_url) }
        }
        if ($null -ne $taskRun) {
            $taskRun = Invoke-RallyGitHub "actions/runs/$($taskRun.id)"
            if ($taskRun.status -eq 'completed') {
                throw "Der Lauf wurde beendet ($($taskRun.conclusion)). Details: $($taskRun.html_url)"
            }
            $taskArtifacts = Invoke-RallyGitHub "actions/runs/$($taskRun.id)/artifacts"
            $taskArtifact = $taskArtifacts.artifacts | Where-Object { $_.name -eq 'simulator-connection' -and -not $_.expired } | Select-Object -First 1
            if ($null -ne $taskArtifact) { break }
            $taskJobs = Invoke-RallyGitHub "actions/runs/$($taskRun.id)/jobs"
            $taskStep = $taskJobs.jobs.steps | Where-Object { $_.status -eq 'in_progress' } | Select-Object -First 1
            $taskStatus = if ($null -ne $taskStep) { $taskStep.name } else { $taskRun.status }
            if ($taskStatus -ne $taskLastStatus) { Write-Host ('Status: ' + $taskStatus); $taskLastStatus = $taskStatus }
        }
        Start-Sleep -Seconds 15
    }
    if ($null -eq $taskArtifact) { throw 'Nach 25 Minuten noch kein Zugang. Bitte den oben angezeigten GitHub-Lauf pruefen.' }

    $taskArchivePath = Join-Path ([IO.Path]::GetTempPath()) ("rallytrip-connection-$taskRequestId.zip")
    Invoke-WebRequest -UseBasicParsing -Uri "$taskBase/actions/artifacts/$($taskArtifact.id)/zip" -Headers $taskGitHubHeaders -OutFile $taskArchivePath -TimeoutSec 60
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $taskArchive = [IO.Compression.ZipFile]::OpenRead($taskArchivePath)
    try {
        $taskEntry = $taskArchive.GetEntry('url.txt')
        if ($null -eq $taskEntry -or $taskEntry.Length -gt 2048) { throw 'Unerwartetes Verbindungsarchiv.' }
        $taskReader = New-Object IO.StreamReader($taskEntry.Open())
        try { $taskHostUrl = $taskReader.ReadToEnd().Trim() } finally { $taskReader.Dispose() }
    } finally { $taskArchive.Dispose() }
    # Do not send the access key to an arbitrary URL supplied by an artifact.
    if ($taskHostUrl -notmatch '^https://[a-z0-9-]+\.trycloudflare\.com$') { throw 'Unerwartete Simulator-Adresse; Zugang wurde nicht geoeffnet.' }
    $taskRemoteHeaders = @{ Authorization = 'Bearer ' + $taskAccess.token }
    $taskReady = $null
    for ($taskAttempt = 0; $taskAttempt -lt 12; $taskAttempt++) {
        try {
            $taskReady = Invoke-RestMethod -Uri "$taskHostUrl/status" -Headers $taskRemoteHeaders -TimeoutSec 15
            break
        } catch {
            $taskCode = if ($null -ne $_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            if ($taskCode -eq 401) { throw 'Der lokale Zugangsschluessel passt nicht mehr zum GitHub Secret. Bitte die Einrichtung erneuern lassen.' }
            if ($taskCode -eq 410) { throw 'Diese Simulatorsitzung ist bereits beendet.' }
            Start-Sleep -Seconds 5
        }
    }
    if ($null -eq $taskReady) { throw 'Der Simulator ist gestartet, aber sein Browserzugang noch nicht erreichbar. Bitte GitHub-Lauf pruefen.' }
    $taskLaunchUrl = $taskHostUrl + '/#' + $taskAccess.token
    Start-Process -FilePath $taskLaunchUrl
    Write-Host ('Simulator im Standardbrowser geoeffnet. Restzeit: ca. ' + [math]::Floor($taskReady.remaining/60) + ' Minuten.')
    Write-Host 'Zum Testen: Einstellungen > Demo-Modus, danach Tripmaster > Fahrt starten.'
} catch {
    Write-Host ('Simulator konnte nicht geoeffnet werden: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    $env:GCM_INTERACTIVE = $taskOriginalInteractive
    $taskCredential = $null; $taskPasswordLine = $null; $taskGitHubHeaders = $null
    $taskAccess = $null; $taskRemoteHeaders = $null; $taskLaunchUrl = $null
    if ($taskArchivePath -and (Test-Path -LiteralPath $taskArchivePath)) { Remove-Item -LiteralPath $taskArchivePath -Force }
}
