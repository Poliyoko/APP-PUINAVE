[CmdletBinding()]
param(
    [ValidateSet('Start','Status','Recover','Stop')]
    [string]$Action = 'Status',

    [string]$RepoRoot = '',

    [string]$WslDistro = 'Ubuntu-24.04',

    [string]$WindowsDrive = 'G:',

    [string]$WindowsSgodaRoot = 'G:\Mi unidad\SGODA-PUINAVE',

    [string]$WslMount = '/mnt/g',

    [string]$WslSgodaRoot = '/mnt/g/Mi unidad/SGODA-PUINAVE',

    [string]$AudioRelativeRoot = 'AUDIOS/PRUEBA_20_PALABRAS/MP3',

    [string]$WslService = 'sgoda-productivo25-visual-8010.service',

    [int]$ApiPort = 8010,

    [int]$WebPort = 8091
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ================================================================
# SGODA DEMO-25 RUNTIME MANAGER
#
# Persistent responsibilities:
# - recognize FastAPI hosted by WSL/systemd
# - recognize Windows wslrelay ownership of the forwarded port
# - verify and recover G: -> /mnt/g only when unhealthy
# - verify REAL-25 native audio dependency
# - recover the known SGODA systemd service only when required
# - preserve healthy components
# - serve Flutter static Web without rebuilding it
#
# Protection:
# - no PostgreSQL writes
# - no n8n execution
# - no REAL-N
# - no Flutter/Android build
# - no Git mutation
# - no killing unrelated processes
# ================================================================

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
}
else {
    $RepoRoot = (Resolve-Path $RepoRoot).Path
}

$Python = Join-Path $RepoRoot '.venv\Scripts\python.exe'
$WebRoot = Join-Path $RepoRoot 'apps\sgoda_puinave_demo\build\web'

$RuntimeRoot = Join-Path `
    $env:LOCALAPPDATA `
    'SGODA-PUINAVE\runtime'

$WebPidFile = Join-Path $RuntimeRoot 'web-8091.pid'
$WebOut = Join-Path $RuntimeRoot 'web-8091.out.log'
$WebErr = Join-Path $RuntimeRoot 'web-8091.err.log'
$MetadataFile = Join-Path $RuntimeRoot 'demo25-runtime.json'

$ApiUrl = 'http://127.0.0.1:{0}/api/demo/pilot25' -f $ApiPort
$WebUrl = 'http://127.0.0.1:{0}/' -f $WebPort

New-Item `
    -ItemType Directory `
    -Path $RuntimeRoot `
    -Force | Out-Null

function Invoke-SgodaWsl {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Script
    )

    # WSL bash requires LF-normalized stdin.
    # Prevent hidden CR characters from contaminating systemd unit names.
    $NormalizedScript = (
        $Script -replace "`r`n", "`n"
    ) -replace "`r", "`n"

    $Output = @(
        $NormalizedScript |
            wsl.exe `
                -d $WslDistro `
                -u root `
                -- bash -s 2>&1
    )

    $Exit = $LASTEXITCODE

    foreach ($Line in $Output) {
        Write-Host $Line
    }

    if ($Exit -ne 0) {
        throw "WSL_COMMAND_FAILED_EXIT_$Exit"
    }
}

function Test-SgodaHttp {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,

        [int]$TimeoutSec = 5
    )

    try {
        $Response = Invoke-WebRequest `
            -Uri $Uri `
            -UseBasicParsing `
            -TimeoutSec $TimeoutSec

        return (
            $Response.StatusCode -ge 200 -and
            $Response.StatusCode -lt 400
        )
    }
    catch {
        return $false
    }
}

function Test-SgodaWslHttp {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,

        [int]$TimeoutSec = 8
    )

    try {
        $Output = @(
            & wsl.exe `
                -d $WslDistro `
                -- curl `
                -sS `
                -o /dev/null `
                -w "%{http_code}" `
                --max-time $TimeoutSec `
                $Uri `
                2>$null
        )

        $Exit = $LASTEXITCODE

        if ($Exit -ne 0) {
            return $false
        }

        $Code = (($Output -join '')).Trim()

        return ($Code -eq '200')
    }
    catch {
        return $false
    }
}

function Wait-SgodaWslEndpoint {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,

        [int]$Attempts = 15,

        [int]$DelaySeconds = 1
    )

    for ($i = 1; $i -le $Attempts; $i++) {

        if (Test-SgodaWslHttp -Uri $Uri) {
            return $true
        }

        Start-Sleep -Seconds $DelaySeconds
    }

    return $false
}

function Wait-SgodaWindowsRelay {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,

        [int]$Attempts = 45,

        [int]$DelaySeconds = 1
    )

    for ($i = 1; $i -le $Attempts; $i++) {

        if (Test-SgodaHttp -Uri $Uri) {
            return $true
        }

        & wsl.exe `
            -d $WslDistro `
            -- true `
            2>$null

        Start-Sleep -Seconds $DelaySeconds
    }

    return $false
}
function Wait-SgodaEndpoint {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,

        [int]$Attempts = 8
    )

    for ($i = 1; $i -le $Attempts; $i++) {

        if (Test-SgodaHttp -Uri $Uri) {
            return $true
        }

        Start-Sleep -Seconds 2
    }

    return $false
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

function Get-SgodaApiListener {

    $Connections = @(
        Get-NetTCPConnection `
            -LocalPort $ApiPort `
            -State Listen `
            -ErrorAction SilentlyContinue
    )

    if ($Connections.Count -eq 0) {
        return $null
    }

    $Connection = $Connections[0]

    $Process = Get-Process `
        -Id $Connection.OwningProcess `
        -ErrorAction SilentlyContinue

    return [pscustomobject]@{
        Pid = $Connection.OwningProcess
        ProcessName = if ($null -ne $Process) {
            $Process.ProcessName
        }
        else {
            'UNKNOWN'
        }
    }
}

function Test-SgodaWindowsAudio {

    if (-not (
        Test-Path `
            -LiteralPath $WindowsSgodaRoot `
            -PathType Container
    )) {
        throw "WINDOWS_SGODA_ROOT_NOT_FOUND=$WindowsSgodaRoot"
    }

    $RelativeWindows = $AudioRelativeRoot -replace '/', '\'

    $AudioRoot = Join-Path `
        $WindowsSgodaRoot `
        $RelativeWindows

    if (-not (
        Test-Path `
            -LiteralPath $AudioRoot `
            -PathType Container
    )) {
        throw "WINDOWS_AUDIO_ROOT_NOT_FOUND=$AudioRoot"
    }

    $Files = @(
        Get-ChildItem `
            -LiteralPath $AudioRoot `
            -Filter 'PU-*_pu.mp3' `
            -File
    )

    Write-Host "WINDOWS_AUDIO_ROOT=$AudioRoot"
    Write-Host "WINDOWS_REAL25_AUDIO_COUNT=$($Files.Count)"

    if ($Files.Count -lt 25) {
        throw "WINDOWS_REAL25_AUDIO_COUNT_LT_25"
    }

    Write-Host "WINDOWS_REAL25_AUDIO=PASS"
}

function Repair-SgodaWslStorage {

    Test-SgodaWindowsAudio

    $ExpectedFstab = "$WindowsDrive $WslMount drvfs defaults,nofail 0 0"

    $Script = @"
set -e

MOUNT='$WslMount'
SOURCE='$WindowsDrive'
ROOT='$WslSgodaRoot'
AUDIO_REL='$AudioRelativeRoot'
FSTAB_LINE='$ExpectedFstab'

healthy=0

if findmnt "`$MOUNT" >/dev/null 2>&1; then
    if ls -ld "`$ROOT" >/dev/null 2>&1; then
        healthy=1
    fi
fi

if [ "`$healthy" -eq 1 ]; then
    echo "WSL_G_MOUNT=ALREADY_HEALTHY"
else
    echo "WSL_G_MOUNT=RECOVERY_REQUIRED"

    if findmnt "`$MOUNT" >/dev/null 2>&1; then
        umount -l "`$MOUNT"
        echo "WSL_STALE_MOUNT_REMOVED=PASS"
    fi

    rm -rf "`$MOUNT"
    mkdir -p "`$MOUNT"

    mount -t drvfs "`$SOURCE" "`$MOUNT"

    echo "WSL_G_REMOUNT=PASS"
fi

findmnt "`$MOUNT"

if ! ls -ld "`$ROOT" >/dev/null 2>&1; then
    echo "WSL_SGODA_ROOT=FAIL"
    exit 31
fi

echo "WSL_SGODA_ROOT=PASS"

AUDIO="`$ROOT/`$AUDIO_REL"

if [ ! -d "`$AUDIO" ]; then
    echo "WSL_AUDIO_ROOT=FAIL"
    exit 32
fi

echo "WSL_AUDIO_ROOT=PASS"

COUNT=`$(find "`$AUDIO" -maxdepth 1 -type f -name 'PU-*_pu.mp3' | wc -l)
COUNT=`$(echo "`$COUNT" | tr -d '[:space:]')

echo "WSL_REAL25_AUDIO_COUNT=`$COUNT"

if [ "`$COUNT" -lt 25 ]; then
    echo "WSL_REAL25_AUDIO=FAIL"
    exit 33
fi

echo "WSL_REAL25_AUDIO=PASS"

if grep -qE '^[[:space:]]*G:[[:space:]]+/mnt/g[[:space:]]+drvfs([[:space:]]|$)' /etc/fstab; then
    echo "FSTAB_G_ENTRY=PASS"
else
    cp /etc/fstab /etc/fstab.sgoda.bak
    printf '%s\n' "`$FSTAB_LINE" >> /etc/fstab
    echo "FSTAB_G_ENTRY=ADDED"
fi

echo "WSL_STORAGE_GATE=PASS"
"@

    Invoke-SgodaWsl -Script $Script
}


function Invoke-SgodaSystemctl {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('start','restart','is-active')]
        [string]$Verb
    )

    $CleanService = $WslService.Trim()

    if ([string]::IsNullOrWhiteSpace($CleanService)) {
        throw "WSL_SERVICE_NAME_EMPTY"
    }

    if ($CleanService -match "[`r`n]") {
        throw "WSL_SERVICE_NAME_CONTAINS_CRLF"
    }

    Write-Host "SYSTEMCTL_VERB=$Verb"
    Write-Host "SYSTEMCTL_UNIT=$CleanService"

    $Output = @(
        & wsl.exe `
            -d $WslDistro `
            -u root `
            -- systemctl $Verb $CleanService 2>&1
    )

    $Exit = $LASTEXITCODE

    foreach ($Line in $Output) {
        Write-Host $Line
    }

    if ($Exit -ne 0) {
        throw "SYSTEMCTL_${Verb}_FAILED_EXIT_$Exit"
    }

    return $Output
}

function Get-SgodaWslServiceState {

    $CleanService = $WslService.Trim()

    if ([string]::IsNullOrWhiteSpace($CleanService)) {
        return 'invalid'
    }

    $Output = @(
        & wsl.exe `
            -d $WslDistro `
            -u root `
            -- systemctl is-active $CleanService 2>$null
    )

    if ($LASTEXITCODE -ne 0) {
        return 'inactive'
    }

    if ($Output.Count -eq 0) {
        return 'unknown'
    }

    return ([string]$Output[0]).Trim()
}

function Recover-SgodaApi {

    $Listener = Get-SgodaApiListener

    if ($null -ne $Listener) {
        Write-Host "WINDOWS_8010_PID=$($Listener.Pid)"
        Write-Host "WINDOWS_8010_PROCESS=$($Listener.ProcessName)"
    }
    else {
        Write-Host "WINDOWS_8010_LISTENER=NONE"
    }

    if (
        (Test-SgodaHttp -Uri $ApiUrl) `
        -or `
        (Test-SgodaWslHttp -Uri $ApiUrl)
    ) {
        Write-Host "FASTAPI_$ApiPort=ALREADY_READY"
        return
    }

    Repair-SgodaWslStorage

    $State = Get-SgodaWslServiceState
    Write-Host "WSL_FASTAPI_SERVICE_BEFORE=$State"

    if ($State -eq 'active') {
        # Storage was repaired underneath the existing process.
        # Restart only the known SGODA systemd service.
        Invoke-SgodaSystemctl -Verb 'restart' | Out-Null
        Invoke-SgodaSystemctl -Verb 'is-active' | Out-Null

        Write-Host "WSL_FASTAPI_SERVICE_ACTION=RESTARTED"
    }
    else {
        Invoke-SgodaSystemctl -Verb 'start' | Out-Null
        Invoke-SgodaSystemctl -Verb 'is-active' | Out-Null

        Write-Host "WSL_FASTAPI_SERVICE_ACTION=STARTED"
    }

    if (-not (
        Wait-SgodaEndpoint `
            -Uri $ApiUrl `
            -Attempts 8
    )) {

        Invoke-SgodaWsl -Script (
            "journalctl -u '{0}' -n 30 --no-pager || true" `
                -f $WslService
        )

        throw "FASTAPI_$ApiPort`_RECOVERY_FAILED"
    }

    Write-Host "FASTAPI_$ApiPort=READY"
}

function Start-SgodaWeb {

    if (Test-SgodaHttp -Uri $WebUrl) {
        Write-Host "WEB_$WebPort=ALREADY_READY"
        return
    }

    if (-not (
        Test-Path `
            -LiteralPath $Python `
            -PathType Leaf
    )) {
        throw "PYTHON_NOT_FOUND=$Python"
    }

    if (-not (
        Test-Path `
            -LiteralPath $WebRoot `
            -PathType Container
    )) {
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

    if (-not (
        Wait-SgodaEndpoint `
            -Uri $WebUrl
    )) {
        throw "WEB_$WebPort`_READINESS_FAILED"
    }

    Write-Host "WEB_$WebPort=READY"
}

function Write-SgodaRuntimeMetadata {

    $Listener = Get-SgodaApiListener

    $Metadata = [ordered]@{
        schema_version = '2.0.0'
        runtime = 'DEMO-25'
        repository = $RepoRoot

        architecture = [ordered]@{
            fastapi_host = 'WSL2_SYSTEMD'
            windows_forwarder = if (
                $null -ne $Listener
            ) {
                $Listener.ProcessName
            }
            else {
                $null
            }
            wsl_distro = $WslDistro
            wsl_service = $WslService
            windows_drive = $WindowsDrive
            wsl_mount = $WslMount
            audio_relative_root = $AudioRelativeRoot
        }

        endpoints = [ordered]@{
            fastapi = $ApiUrl
            web = $WebUrl
        }

        readiness = [ordered]@{
            fastapi = Test-SgodaHttp -Uri $ApiUrl
            web = Test-SgodaHttp -Uri $WebUrl
        }

        protection = [ordered]@{
            database_writes = 0
            n8n_executions = 0
            flutter_builds = 0
            real_n = 'NOT_STARTED'
        }

        generated_at = (Get-Date).ToString('o')
    }

    $Metadata |
        ConvertTo-Json -Depth 10 |
        Set-Content `
            -LiteralPath $MetadataFile `
            -Encoding UTF8
}

function Show-SgodaStatus {

    $ApiReady = Test-SgodaHttp -Uri $ApiUrl
    $WebReady = Test-SgodaHttp -Uri $WebUrl
    $Listener = Get-SgodaApiListener

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

    if ($null -ne $Listener) {
        Write-Host "FASTAPI_WINDOWS_PID=$($Listener.Pid)"
        Write-Host "FASTAPI_WINDOWS_PROCESS=$($Listener.ProcessName)"
    }
    else {
        Write-Host "FASTAPI_WINDOWS_LISTENER=NONE"
    }

    Write-Host "WSL_SERVICE=$(Get-SgodaWslServiceState)"
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

function Stop-SgodaOwnedWeb {

    $Process = Get-SgodaOwnedProcess `
        -PidFile $WebPidFile

    if ($null -eq $Process) {
        Write-Host "WEB_OWNED_PROCESS=NOT_RUNNING"
        return
    }

    Stop-Process `
        -Id $Process.Id `
        -ErrorAction Stop

    $Process.WaitForExit(10000)

    Remove-Item `
        -LiteralPath $WebPidFile `
        -Force `
        -ErrorAction SilentlyContinue

    Write-Host "WEB_OWNED_PROCESS=STOPPED"
}

switch ($Action) {

    'Status' {
        Write-SgodaRuntimeMetadata
        Show-SgodaStatus
    }

    'Start' {
        Recover-SgodaApi
        Start-SgodaWeb
        Write-SgodaRuntimeMetadata
        Show-SgodaStatus
    }

    'Recover' {
        Recover-SgodaApi
        Start-SgodaWeb
        if (-not (
            Wait-SgodaWslEndpoint `
                -Uri $ApiUrl `
                -Attempts 15 `
                -DelaySeconds 1
        )) {
            throw "FASTAPI_WSL_FINAL_GATE_FAILED"
        }

        if (-not (
            Wait-SgodaWindowsRelay `
                -Uri $ApiUrl `
                -Attempts 45 `
                -DelaySeconds 1
        )) {
            throw "FASTAPI_WINDOWS_RELAY_FINAL_GATE_FAILED"
        }

        if (-not (
            Wait-SgodaEndpoint `
                -Uri $WebUrl `
                -Attempts 8
        )) {
            throw "WEB_FINAL_GATE_FAILED"
        }

        Write-SgodaRuntimeMetadata
        Show-SgodaStatus

        Write-Host ""
        Write-Host "SGODA_RUNTIME_RECOVERY=PASS"
    }

    'Stop' {
        # Deliberately stops only the Web process owned by this manager.
        # WSL/systemd FastAPI is not killed implicitly.
        Stop-SgodaOwnedWeb
        Write-SgodaRuntimeMetadata
        Show-SgodaStatus
    }
}