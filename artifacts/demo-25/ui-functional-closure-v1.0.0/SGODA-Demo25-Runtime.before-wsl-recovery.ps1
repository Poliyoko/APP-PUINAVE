[CmdletBinding()]
param(
    [ValidateSet('Start','Status','Recover','Stop')]
    [string]$Action = 'Status',

    [string]$RepoRoot = '',

    [int]$ApiPort = 8010,

    [int]$WebPort = 8091
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ================================================================
# SGODA DEMO-25 RUNTIME MANAGER
# Compatible with Windows PowerShell 5.1
#
# Responsibilities:
# - FastAPI DEMO-25 runtime
# - Flutter static Web runtime
# - process ownership
# - readiness
# - controlled recovery
#
# Does NOT:
# - modify PostgreSQL data
# - execute n8n
# - load REAL-N
# - rebuild Flutter
# ================================================================

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {

    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

    $RepoRoot = (
        Resolve-Path (
            Join-Path $ScriptDir '..\..'
        )
    ).Path
}
else {
    $RepoRoot = (
        Resolve-Path $RepoRoot
    ).Path
}

$Python = Join-Path `
    $RepoRoot `
    '.venv\Scripts\python.exe'

$ApiApp = Join-Path `
    $RepoRoot `
    'src\sgoda\demo_ready\app.py'

$WebRoot = Join-Path `
    $RepoRoot `
    'apps\sgoda_puinave_demo\build\web'

$RuntimeRoot = Join-Path `
    $env:LOCALAPPDATA `
    'SGODA-PUINAVE\runtime'

$ApiPidFile = Join-Path `
    $RuntimeRoot `
    'fastapi-8010.pid'

$WebPidFile = Join-Path `
    $RuntimeRoot `
    'web-8091.pid'

$ApiOut = Join-Path `
    $RuntimeRoot `
    'fastapi-8010.out.log'

$ApiErr = Join-Path `
    $RuntimeRoot `
    'fastapi-8010.err.log'

$WebOut = Join-Path `
    $RuntimeRoot `
    'web-8091.out.log'

$WebErr = Join-Path `
    $RuntimeRoot `
    'web-8091.err.log'

$MetadataFile = Join-Path `
    $RuntimeRoot `
    'demo25-runtime.json'

$ApiUrl = (
    'http://127.0.0.1:{0}/api/demo/pilot25' `
        -f $ApiPort
)

$WebUrl = (
    'http://127.0.0.1:{0}/' `
        -f $WebPort
)

New-Item `
    -ItemType Directory `
    -Path $RuntimeRoot `
    -Force | Out-Null


function Test-SgodaHttp {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,

        [int]$TimeoutSec = 4
    )

    try {
        $Response = Invoke-WebRequest `
            -Uri $Uri `
            -UseBasicParsing `
            -TimeoutSec $TimeoutSec

        return (
            $Response.StatusCode -ge 200 `
            -and `
            $Response.StatusCode -lt 400
        )
    }
    catch {
        return $false
    }
}


function Get-SgodaOwnedProcess {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PidFile
    )

    if (-not (Test-Path -LiteralPath $PidFile)) {
        return $null
    }

    $RawPid = (
        Get-Content `
            -LiteralPath $PidFile `
            -Raw
    ).Trim()

    $ParsedPid = 0

    if (-not [int]::TryParse(
        $RawPid,
        [ref]$ParsedPid
    )) {
        return $null
    }

    try {
        return Get-Process `
            -Id $ParsedPid `
            -ErrorAction Stop
    }
    catch {
        return $null
    }
}


function Wait-SgodaEndpoint {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,

        [int]$Attempts = 15
    )

    for ($i = 1; $i -le $Attempts; $i++) {

        if (Test-SgodaHttp -Uri $Uri) {
            return $true
        }

        Start-Sleep -Seconds 2
    }

    return $false
}


function Start-SgodaApi {

    if (Test-SgodaHttp -Uri $ApiUrl) {
        Write-Host "FASTAPI_$ApiPort=ALREADY_READY"
        return
    }

    if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) {
        throw "PYTHON_NOT_FOUND=$Python"
    }

    if (-not (Test-Path -LiteralPath $ApiApp -PathType Leaf)) {
        throw "FASTAPI_APP_NOT_FOUND=$ApiApp"
    }

    # Import preflight: exact known module, no repository search.
    Push-Location $RepoRoot
    try {
        & $Python `
            -c `
            "from src.sgoda.demo_ready.app import app; print('FASTAPI_IMPORT=PASS')"

        if ($LASTEXITCODE -ne 0) {
            throw "FASTAPI_IMPORT_FAILED"
        }
    }
    finally {
        Pop-Location
    }

    Remove-Item `
        -LiteralPath $ApiOut `
        -Force `
        -ErrorAction SilentlyContinue

    Remove-Item `
        -LiteralPath $ApiErr `
        -Force `
        -ErrorAction SilentlyContinue

    $Process = Start-Process `
        -FilePath $Python `
        -ArgumentList @(
            '-m',
            'uvicorn',
            'src.sgoda.demo_ready.app:app',
            '--host',
            '127.0.0.1',
            '--port',
            [string]$ApiPort
        ) `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput $ApiOut `
        -RedirectStandardError $ApiErr `
        -PassThru

    Set-Content `
        -LiteralPath $ApiPidFile `
        -Value $Process.Id `
        -Encoding ASCII

    Write-Host "FASTAPI_PID=$($Process.Id)"

    if (-not (
        Wait-SgodaEndpoint `
            -Uri $ApiUrl
    )) {

        Write-Host "FASTAPI_READINESS=FAIL"

        if (Test-Path -LiteralPath $ApiErr) {
            Write-Host "----- FASTAPI STDERR -----"
            Get-Content `
                -LiteralPath $ApiErr `
                -Tail 80
        }

        throw "FASTAPI_READINESS_FAILED"
    }

    Write-Host "FASTAPI_$ApiPort=READY"
}


function Start-SgodaWeb {

    if (Test-SgodaHttp -Uri $WebUrl) {
        Write-Host "WEB_$WebPort=ALREADY_READY"
        return
    }

    if (-not (Test-Path -LiteralPath $WebRoot -PathType Container)) {
        throw "WEB_BUILD_NOT_FOUND=$WebRoot"
    }

    Remove-Item `
        -LiteralPath $WebOut `
        -Force `
        -ErrorAction SilentlyContinue

    Remove-Item `
        -LiteralPath $WebErr `
        -Force `
        -ErrorAction SilentlyContinue

    $Process = Start-Process `
        -FilePath $Python `
        -ArgumentList @(
            '-m',
            'http.server',
            [string]$WebPort,
            '--bind',
            '127.0.0.1',
            '--directory',
            ('"{0}"' -f $WebRoot)
        ) `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput $WebOut `
        -RedirectStandardError $WebErr `
        -PassThru

    Set-Content `
        -LiteralPath $WebPidFile `
        -Value $Process.Id `
        -Encoding ASCII

    Write-Host "WEB_PID=$($Process.Id)"

    if (-not (
        Wait-SgodaEndpoint `
            -Uri $WebUrl
    )) {

        Write-Host "WEB_READINESS=FAIL"

        if (Test-Path -LiteralPath $WebErr) {
            Write-Host "----- WEB STDERR -----"
            Get-Content `
                -LiteralPath $WebErr `
                -Tail 80
        }

        throw "WEB_READINESS_FAILED"
    }

    Write-Host "WEB_$WebPort=READY"
}


function Write-SgodaRuntimeMetadata {

    $ApiReady = Test-SgodaHttp -Uri $ApiUrl
    $WebReady = Test-SgodaHttp -Uri $WebUrl

    $Metadata = [ordered]@{
        schema_version = '1.0.0'
        runtime = 'DEMO-25'
        repository = $RepoRoot

        endpoints = [ordered]@{
            fastapi = $ApiUrl
            web = $WebUrl
        }

        readiness = [ordered]@{
            fastapi = $ApiReady
            web = $WebReady
        }

        protection = [ordered]@{
            database_writes = 0
            n8n_executions = 0
            real_n = 'NOT_STARTED'
        }

        generated_at = (
            Get-Date
        ).ToString('o')
    }

    $Metadata |
        ConvertTo-Json -Depth 8 |
        Set-Content `
            -LiteralPath $MetadataFile `
            -Encoding UTF8
}


function Show-SgodaStatus {

    $ApiReady = Test-SgodaHttp -Uri $ApiUrl
    $WebReady = Test-SgodaHttp -Uri $WebUrl

    $ApiProcess = Get-SgodaOwnedProcess `
        -PidFile $ApiPidFile

    $WebProcess = Get-SgodaOwnedProcess `
        -PidFile $WebPidFile

    Write-Host ""
    Write-Host "================ SGODA RUNTIME STATUS ================"

    if ($ApiReady) {
        Write-Host "FASTAPI_$ApiPort=READY"
    }
    else {
        Write-Host "FASTAPI_$ApiPort=OFFLINE"
    }

    if ($WebReady) {
        Write-Host "WEB_$WebPort=READY"
    }
    else {
        Write-Host "WEB_$WebPort=OFFLINE"
    }

    if ($null -ne $ApiProcess) {
        Write-Host "FASTAPI_OWNED_PID=$($ApiProcess.Id)"
    }
    else {
        Write-Host "FASTAPI_OWNED_PID=NONE"
    }

    if ($null -ne $WebProcess) {
        Write-Host "WEB_OWNED_PID=$($WebProcess.Id)"
    }
    else {
        Write-Host "WEB_OWNED_PID=NONE"
    }

    Write-Host "API=$ApiUrl"
    Write-Host "WEB=$WebUrl"

    if ($ApiReady -and $WebReady) {
        Write-Host "DEMO25_RUNTIME=READY"
    }
    else {
        Write-Host "DEMO25_RUNTIME=DEGRADED"
    }

    Write-Host "======================================================="
}


function Stop-SgodaOwnedRuntime {

    foreach ($Entry in @(
        @{
            Name = 'FASTAPI'
            PidFile = $ApiPidFile
        },
        @{
            Name = 'WEB'
            PidFile = $WebPidFile
        }
    )) {

        $Process = Get-SgodaOwnedProcess `
            -PidFile $Entry.PidFile

        if ($null -eq $Process) {
            Write-Host "$($Entry.Name)_OWNED_PROCESS=NOT_RUNNING"
            continue
        }

        # Only PID registered by this Runtime Manager.
        Stop-Process `
            -Id $Process.Id `
            -ErrorAction Stop

        $Process.WaitForExit(10000)

        Remove-Item `
            -LiteralPath $Entry.PidFile `
            -Force `
            -ErrorAction SilentlyContinue

        Write-Host "$($Entry.Name)_OWNED_PROCESS=STOPPED"
    }
}


switch ($Action) {

    'Status' {

        Write-SgodaRuntimeMetadata
        Show-SgodaStatus
    }

    'Start' {

        Start-SgodaApi
        Start-SgodaWeb

        Write-SgodaRuntimeMetadata
        Show-SgodaStatus
    }

    'Recover' {

        # Idempotent:
        # healthy components are preserved;
        # only missing components are started.

        Start-SgodaApi
        Start-SgodaWeb

        if (-not (Test-SgodaHttp -Uri $ApiUrl)) {
            throw "FASTAPI_FINAL_GATE_FAILED"
        }

        if (-not (Test-SgodaHttp -Uri $WebUrl)) {
            throw "WEB_FINAL_GATE_FAILED"
        }

        Write-SgodaRuntimeMetadata
        Show-SgodaStatus

        Write-Host ""
        Write-Host "SGODA_RUNTIME_RECOVERY=PASS"
    }

    'Stop' {

        Stop-SgodaOwnedRuntime

        Write-SgodaRuntimeMetadata
        Show-SgodaStatus
    }
}
