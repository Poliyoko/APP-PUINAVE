<#
.SYNOPSIS
SPT-021.3 v1.1.3 - Institutional Master Book Auto-Update Layer
One-time installer for Windows PowerShell 5.1.

.DESCRIPTION
Instala una capa persistente que mantiene SGD-002 actualizado sin volver a
desarrollar o reinstalar el generador en cada cierre.

Instala:
  tools/institutional/Invoke-SGD002-AutoUpdate.ps1
  tools/institutional/Publish-SGODA-WithMasterBook.ps1
  config/institutional/sgd002-auto-update.json

Registra una tarea programada del usuario que:
  - calcula fingerprint del repositorio;
  - ignora las propias salidas del Libro Maestro para evitar bucles;
  - ejecuta SPT-021.3 solo cuando existen cambios reales;
  - conserva logs y estado;
  - no hace commit ni push automaticamente.

La publicacion sigue delegada al motor institucional existente SPT-021.0.1.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [ValidateRange(5,1440)]
    [int]$IntervalMinutes = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-021.3"
$Version = "1.1.3"
$TaskName = "SGODA-PUINAVE-SGD002-AutoUpdate"
$SelfPath = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Utf8NoBom {
    param([string]$Path,[AllowEmptyString()][string]$Content)
    $Parent = Split-Path -Parent $Path
    if ($Parent -and -not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Write-Json {
    param([string]$Path,[object]$Data)
    Write-Utf8NoBom -Path $Path -Content (
        (($Data | ConvertTo-Json -Depth 50) + "`r`n")
    )
}

function Test-PowerShellSyntax {
    param([string]$Path)
    $Tokens = $null
    $Errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $Path,[ref]$Tokens,[ref]$Errors
    )
    return @($Errors)
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot ".git"))) {
    throw "Ejecute el instalador desde la raiz Git de SGODA-PUINAVE."
}

$Generator = Join-Path $ProjectRoot "Install-SPT021.3-v1.0.0-OneFile-PS51.ps1"
$Publisher = Join-Path $ProjectRoot "Install-SPT021.0.1-v1.0.6-OneFile-PS51.ps1"

if (-not (Test-Path -LiteralPath $Generator -PathType Leaf)) {
    throw "No se encontro Install-SPT021.3-v1.0.0-OneFile-PS51.ps1 en la raiz."
}
if (-not (Test-Path -LiteralPath $Publisher -PathType Leaf)) {
    throw "No se encontro Install-SPT021.0.1-v1.0.6-OneFile-PS51.ps1."
}

$ToolsRoot = Join-Path $ProjectRoot "tools\institutional"
$ConfigRoot = Join-Path $ProjectRoot "config\institutional"
$RuntimeRoot = Join-Path $ProjectRoot "artifacts\runtime\sgd002-auto"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-021.3-v1.1.3"
$DocRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-021.3"

foreach ($D in @($ToolsRoot,$ConfigRoot,$RuntimeRoot,$ReleaseRoot,$DocRoot)) {
    New-Item -ItemType Directory -Path $D -Force | Out-Null
}

$StableGenerator = Join-Path $ToolsRoot "Install-SPT021.3-v1.0.0-OneFile-PS51.ps1"
Copy-Item -LiteralPath $Generator -Destination $StableGenerator -Force

$RunnerPath = Join-Path $ToolsRoot "Invoke-SGD002-AutoUpdate.ps1"
$WrapperPath = Join-Path $ToolsRoot "Publish-SGODA-WithMasterBook.ps1"
$ConfigPath = Join-Path $ConfigRoot "sgd002-auto-update.json"

$Runner = @'
[CmdletBinding()]
param(
    [string]$ProjectRoot = "",
    [switch]$ForceUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-GitProbe {
    param(
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $Git = Get-Command git.exe `
        -CommandType Application `
        -ErrorAction Stop |
        Select-Object -First 1

    if (
        $null -eq $Git -or
        [string]::IsNullOrWhiteSpace([string]$Git.Source)
    ) {
        throw "git.exe no pudo resolverse."
    }

    $Psi = New-Object System.Diagnostics.ProcessStartInfo
    $Psi.FileName = $Git.Source
    $Psi.WorkingDirectory = $ProjectRoot
    $Psi.UseShellExecute = $false
    $Psi.RedirectStandardOutput = $true
    $Psi.RedirectStandardError = $true
    $Psi.CreateNoWindow = $true

    $Escaped = @()

    foreach ($Argument in $Arguments) {
        $Value = [string]$Argument

        if (
            $Value.Contains(" ") -or
            $Value.Contains("`t") -or
            $Value.Contains('"')
        ) {
            $Value = '"' + $Value.Replace('"', '\"') + '"'
        }

        $Escaped += $Value
    }

    $Psi.Arguments = $Escaped -join " "

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $Psi

    [void]$Process.Start()

    $StdOut = $Process.StandardOutput.ReadToEnd()
    $StdErr = $Process.StandardError.ReadToEnd()

    $Process.WaitForExit()

    if (
        ($Process.ExitCode -ne 0) -and
        (-not $AllowFailure)
    ) {
        throw (
            "Git probe fallo. Exit code: " +
            $Process.ExitCode +
            "`r`n" +
            $StdErr
        )
    }

    return [PSCustomObject]@{
        ExitCode = $Process.ExitCode
        StdOut = $StdOut
        StdErr = $StdErr
    }
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = [System.IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot "..\..")
    )
}
else {
    $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}

Set-Location -LiteralPath $ProjectRoot

$StateRoot = Join-Path $ProjectRoot "artifacts\runtime\sgd002-auto"
$StatePath = Join-Path $StateRoot "state.json"
$LockPath = Join-Path $StateRoot "update.lock"
$LogRoot = Join-Path $StateRoot "logs"
$Generator = Join-Path $ProjectRoot (
    "tools\institutional\Install-SPT021.3-v1.0.0-OneFile-PS51.ps1"
)

foreach ($D in @($StateRoot,$LogRoot)) {
    New-Item -ItemType Directory -Path $D -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $Generator -PathType Leaf)) {
    throw "Generador institucional SPT-021.3 no disponible."
}

if (Test-Path -LiteralPath $LockPath) {
    $Age = (Get-Date) - (Get-Item -LiteralPath $LockPath).LastWriteTime

    if ($Age.TotalMinutes -lt 120) {
        Write-Output "AUTO_UPDATE_SKIPPED: another execution is active."
        exit 0
    }

    Remove-Item `
        -LiteralPath $LockPath `
        -Force `
        -ErrorAction SilentlyContinue
}

[System.IO.File]::WriteAllText(
    $LockPath,
    [DateTime]::UtcNow.ToString("o"),
    (New-Object System.Text.UTF8Encoding($false))
)

try {
    $HeadProbe = Invoke-GitProbe -Arguments @(
        "-c",
        "core.longpaths=true",
        "rev-parse",
        "HEAD"
    )

    $Head = $HeadProbe.StdOut.Trim()

    # Fingerprint tracked modifications without recursively traversing
    # historical repository-backup directories.
    $TrackedProbe = Invoke-GitProbe -Arguments @(
        "-c",
        "core.longpaths=true",
        "-c",
        "core.quotepath=false",
        "diff",
        "--name-only",
        "--no-renames",
        "HEAD",
        "--",
        ".",
        ":(exclude)artifacts/consolidation/**/repository-backup/**",
        ":(exclude)artifacts/consolidation/**/registry-backup/**"
    )

    # Untracked files are queried with the same exclusions.
    # stderr warnings are captured, never promoted to PowerShell errors.
    $UntrackedProbe = Invoke-GitProbe -Arguments @(
        "-c",
        "core.longpaths=true",
        "-c",
        "core.quotepath=false",
        "ls-files",
        "--others",
        "--exclude-standard",
        "--",
        ".",
        ":(exclude)artifacts/consolidation/**/repository-backup/**",
        ":(exclude)artifacts/consolidation/**/registry-backup/**"
    ) -AllowFailure

    $StatusLines = @(
        ($TrackedProbe.StdOut -split "\r?\n") +
        ($UntrackedProbe.StdOut -split "\r?\n") |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        } |
        Sort-Object -Unique
    )

    $Ignored = @(
        "docs/00_Estado_Maestro/SGD-002-Libro-Maestro-Institucional-",
        "artifacts/development/SPT-021.3-",
        "artifacts/runtime/sgd002-auto/",
        "releases/SPT-021.3-",
        "docs/06_Tecnologia/SPT-021.3/ACT-021.3-",
        "tools/institutional/Invoke-SGD002-AutoUpdate.ps1",
        "config/institutional/sgd002-auto-update.json"
    )

    $Relevant = @()

    foreach ($Line in $StatusLines) {
        $Normalized = ([string]$Line).Replace("\","/")
        $Skip = $false

        foreach ($Pattern in $Ignored) {
            if ($Normalized.Contains($Pattern)) {
                $Skip = $true
                break
            }
        }

        if (-not $Skip) {
            $Relevant += $Normalized
        }
    }

    $FingerprintSource = (
        $Head +
        "`n" +
        (($Relevant | Sort-Object) -join "`n")
    )

    $Sha = [System.Security.Cryptography.SHA256]::Create()

    try {
        $Bytes = [System.Text.Encoding]::UTF8.GetBytes(
            $FingerprintSource
        )

        $HashBytes = $Sha.ComputeHash($Bytes)

        $Fingerprint = (
            $HashBytes |
            ForEach-Object {
                $_.ToString("x2")
            }
        ) -join ""
    }
    finally {
        $Sha.Dispose()
    }

    $Previous = ""

    if (Test-Path -LiteralPath $StatePath) {
        try {
            $State = Get-Content `
                -LiteralPath $StatePath `
                -Raw |
                ConvertFrom-Json

            $Previous = [string]$State.fingerprint
        }
        catch {
            $Previous = ""
        }
    }

    if (
        (-not $ForceUpdate) -and
        ($Fingerprint -eq $Previous)
    ) {
        Write-Output (
            "AUTO_UPDATE_SKIPPED: repository fingerprint unchanged."
        )
        exit 0
    }

    $RunStamp = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
    $LogPath = Join-Path $LogRoot (
        "update-" + $RunStamp + ".log"
    )

    $PowerShellExe = Join-Path $env:SystemRoot (
        "System32\WindowsPowerShell\v1.0\powershell.exe"
    )

    $Psi = New-Object System.Diagnostics.ProcessStartInfo
    $Psi.FileName = $PowerShellExe
    $Psi.WorkingDirectory = $ProjectRoot
    $Psi.UseShellExecute = $false
    $Psi.RedirectStandardOutput = $true
    $Psi.RedirectStandardError = $true
    $Psi.CreateNoWindow = $true
    $Psi.Arguments = (
        '-NoProfile -ExecutionPolicy Bypass -File "' +
        $Generator +
        '" -ProjectRoot "' +
        $ProjectRoot +
        '"'
    )

    $GeneratorProcess = New-Object System.Diagnostics.Process
    $GeneratorProcess.StartInfo = $Psi

    [void]$GeneratorProcess.Start()

    $GeneratorStdOut = $GeneratorProcess.StandardOutput.ReadToEnd()
    $GeneratorStdErr = $GeneratorProcess.StandardError.ReadToEnd()

    $GeneratorProcess.WaitForExit()

    $GeneratorOutput = (
        $GeneratorStdOut +
        "`r`n" +
        $GeneratorStdErr
    ).Trim()

    [System.IO.File]::WriteAllText(
        $LogPath,
        ($GeneratorOutput + "`r`n"),
        (New-Object System.Text.UTF8Encoding($false))
    )

    if ($GeneratorProcess.ExitCode -ne 0) {
        throw (
            "SPT-021.3 auto-update failed. Exit code: " +
            $GeneratorProcess.ExitCode +
            ". Revise: " +
            $LogPath
        )
    }

    $NewState = [ordered]@{
        updated_at_utc = [DateTime]::UtcNow.ToString("o")
        fingerprint = $Fingerprint
        head = $Head
        relevant_changes = $Relevant.Count
        tracked_changes = @(
            $TrackedProbe.StdOut -split "\r?\n" |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
        ).Count
        untracked_candidates = @(
            $UntrackedProbe.StdOut -split "\r?\n" |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
        ).Count
        untracked_probe_exit_code = $UntrackedProbe.ExitCode
        untracked_probe_warning = (
            -not [string]::IsNullOrWhiteSpace(
                [string]$UntrackedProbe.StdErr
            )
        )
        long_paths_enabled_per_command = $true
        historical_backups_excluded = $true
        last_log = $LogPath
        status = "UPDATED"
    }

    [System.IO.File]::WriteAllText(
        $StatePath,
        (($NewState | ConvertTo-Json -Depth 10) + "`r`n"),
        (New-Object System.Text.UTF8Encoding($false))
    )

    Write-Output "SGD-002 AUTO-UPDATED."
    Write-Output "Relevant changes: $($Relevant.Count)"
    Write-Output "Long paths: ENABLED PER COMMAND"
    Write-Output "Historical recursive backups: EXCLUDED"
    Write-Output "Log: $LogPath"
}
finally {
    Remove-Item `
        -LiteralPath $LockPath `
        -Force `
        -ErrorAction SilentlyContinue
}
'@

$Wrapper = @'
[CmdletBinding()]
param([switch]$PrepareOnly)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-PowerShellFileIsolated {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    $PowerShellExe = Join-Path $env:SystemRoot (
        "System32\WindowsPowerShell\v1.0\powershell.exe"
    )

    $Psi = New-Object System.Diagnostics.ProcessStartInfo
    $Psi.FileName = $PowerShellExe
    $Psi.WorkingDirectory = (Get-Location).Path
    $Psi.UseShellExecute = $false
    $Psi.RedirectStandardOutput = $true
    $Psi.RedirectStandardError = $true
    $Psi.CreateNoWindow = $true

    $ArgParts = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ('"' + $FilePath + '"')
    )

    foreach ($Argument in $Arguments) {
        $Value = [string]$Argument

        if (
            $Value.Contains(" ") -or
            $Value.Contains("`t") -or
            $Value.Contains('"')
        ) {
            $Value = '"' + $Value.Replace('"', '\"') + '"'
        }

        $ArgParts += $Value
    }

    $Psi.Arguments = $ArgParts -join " "

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $Psi

    [void]$Process.Start()

    $StdOut = $Process.StandardOutput.ReadToEnd()
    $StdErr = $Process.StandardError.ReadToEnd()

    $Process.WaitForExit()

    if (-not [string]::IsNullOrWhiteSpace($StdOut)) {
        $StdOut.TrimEnd() -split "\r?\n" |
            ForEach-Object { Write-Host $_ }
    }

    if (-not [string]::IsNullOrWhiteSpace($StdErr)) {
        $StdErr.TrimEnd() -split "\r?\n" |
            ForEach-Object {
                Write-Host $_ -ForegroundColor DarkYellow
            }
    }

    return [int]$Process.ExitCode
}

$ProjectRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..\..")
)

Set-Location -LiteralPath $ProjectRoot

$Updater = Join-Path $ProjectRoot (
    "tools\institutional\Invoke-SGD002-AutoUpdate.ps1"
)

$Publisher = Join-Path $ProjectRoot (
    "Install-SPT021.0.1-v1.0.6-OneFile-PS51.ps1"
)

if (-not (Test-Path -LiteralPath $Updater -PathType Leaf)) {
    throw "Auto-updater SGD-002 no disponible."
}

if (-not (Test-Path -LiteralPath $Publisher -PathType Leaf)) {
    throw "SPT-021.0.1 v1.0.6 no disponible."
}

Write-Host "==> Actualizando Libro Maestro antes de publicar" `
    -ForegroundColor Cyan

$UpdateExitCode = Invoke-PowerShellFileIsolated `
    -FilePath $Updater `
    -Arguments @(
        "-ProjectRoot",
        $ProjectRoot
    )

Write-Host "SGD-002 updater exit code: $UpdateExitCode"

if ($UpdateExitCode -ne 0) {
    throw (
        "No fue posible actualizar SGD-002. Exit code: " +
        $UpdateExitCode
    )
}

if ($PrepareOnly) {
    Write-Host "==> Ejecutando PREPARE institucional" `
        -ForegroundColor Cyan

    $PublishExitCode = Invoke-PowerShellFileIsolated `
        -FilePath $Publisher
}
else {
    Write-Host "==> Ejecutando PUBLISH institucional" `
        -ForegroundColor Cyan

    $PublishExitCode = Invoke-PowerShellFileIsolated `
        -FilePath $Publisher `
        -Arguments @("-Publish")
}

Write-Host "Publication engine exit code: $PublishExitCode"

exit [int]$PublishExitCode
'@

Write-Step "Instalando auto-actualizador persistente"
Write-Utf8NoBom -Path $RunnerPath -Content $Runner
Write-Utf8NoBom -Path $WrapperPath -Content $Wrapper

$RunnerErrors = @(Test-PowerShellSyntax -Path $RunnerPath)
$WrapperErrors = @(Test-PowerShellSyntax -Path $WrapperPath)

if ($RunnerErrors.Count -ne 0) {
    throw "Invoke-SGD002-AutoUpdate.ps1 tiene errores de sintaxis."
}
if ($WrapperErrors.Count -ne 0) {
    throw "Publish-SGODA-WithMasterBook.ps1 tiene errores de sintaxis."
}

Write-Json -Path $ConfigPath -Data ([ordered]@{
    component = $Component
    version = $Version
    mode = "PERSISTENT_INCREMENTAL_AUTO_UPDATE"
    interval_minutes = $IntervalMinutes
    repository_source_of_truth = $true
    auto_regeneration = $true
    incremental_fingerprint = $true
    long_paths_enabled_per_command = $true
    historical_recursive_backups_excluded = $true
    native_git_stderr_isolated = $true
    powershell_child_exitcode_isolated = $true
    wrapper_pipeline_output_isolated = $true
    git_auto_commit = $false
    git_auto_push = $false
    publication_engine = "SPT-021.0.1-v1.0.6"
    publication_wrapper = "tools/institutional/Publish-SGODA-WithMasterBook.ps1"
    installed_at_utc = [DateTime]::UtcNow.ToString("o")
})

Write-Step "Registrando tarea programada"

$PowerShellExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$ActionArguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $RunnerPath + '" -ProjectRoot "' + $ProjectRoot + '"'

$Action = New-ScheduledTaskAction -Execute $PowerShellExe -Argument $ActionArguments
$Trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddMinutes(2) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Description "Mantiene SGD-002 actualizado automaticamente para SGODA-PUINAVE." `
    -Force | Out-Null

Write-Step "Ejecutando validacion inicial"

$ValidationPowerShell = Join-Path $env:SystemRoot (
    "System32\WindowsPowerShell\v1.0\powershell.exe"
)

$ValidationPsi = New-Object System.Diagnostics.ProcessStartInfo
$ValidationPsi.FileName = $ValidationPowerShell
$ValidationPsi.WorkingDirectory = $ProjectRoot
$ValidationPsi.UseShellExecute = $false
$ValidationPsi.RedirectStandardOutput = $true
$ValidationPsi.RedirectStandardError = $true
$ValidationPsi.CreateNoWindow = $true
$ValidationPsi.Arguments = (
    '-NoProfile -ExecutionPolicy Bypass -File "' +
    $RunnerPath +
    '" -ProjectRoot "' +
    $ProjectRoot +
    '" -ForceUpdate'
)

$ValidationProcess = New-Object System.Diagnostics.Process
$ValidationProcess.StartInfo = $ValidationPsi

[void]$ValidationProcess.Start()

$ValidationStdOut = $ValidationProcess.StandardOutput.ReadToEnd()
$ValidationStdErr = $ValidationProcess.StandardError.ReadToEnd()

$ValidationProcess.WaitForExit()

$InitialExitCode = $ValidationProcess.ExitCode

if (-not [string]::IsNullOrWhiteSpace($ValidationStdOut)) {
    $ValidationStdOut.TrimEnd() -split "\r?\n" |
        ForEach-Object { Write-Host $_ }
}

if (-not [string]::IsNullOrWhiteSpace($ValidationStdErr)) {
    $ValidationStdErr.TrimEnd() -split "\r?\n" |
        ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
}

if ($InitialExitCode -ne 0) {
    throw (
        "La validacion inicial del auto-updater fallo. Exit code: " +
        $InitialExitCode
    )
}

$Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop

$ActPath = Join-Path $DocRoot "ACT-021.3-v1.1.3-AutoUpdate-Persistent-Closure.md"

$Act = @"
# ACT-021.3 v1.1.0 - Auto-Update Persistent Closure

| Campo | Resultado |
|---|---|
| Componente | SPT-021.3 |
| Version | 1.1.0 |
| Modo | PERSISTENT_INCREMENTAL_AUTO_UPDATE |
| Intervalo | $IntervalMinutes minutos |
| Tarea programada | $TaskName |
| Estado tarea | $($Task.State) |
| Auto-regeneracion SGD-002 | SI |
| Fingerprint incremental | SI |
| Auto commit | NO |
| Auto push | NO |
| Publicador canonico | SPT-021.0.1 v1.0.6 |
| Errores sintaxis runner | $($RunnerErrors.Count) |
| Errores sintaxis wrapper | $($WrapperErrors.Count) |
| Validacion inicial | APROBADA |
"@

Write-Utf8NoBom -Path $ActPath -Content $Act

$EvidencePath = Join-Path $ReleaseRoot "implementation-evidence.json"
Write-Json -Path $EvidencePath -Data ([ordered]@{
    component = $Component
    version = $Version
    persistent_auto_update = $true
    long_paths_enabled_per_command = $true
    historical_recursive_backups_excluded = $true
    native_git_stderr_isolated = $true
    powershell_child_exitcode_isolated = $true
    wrapper_pipeline_output_isolated = $true
    interval_minutes = $IntervalMinutes
    task_name = $TaskName
    task_state = [string]$Task.State
    runner = $RunnerPath
    publication_wrapper = $WrapperPath
    config = $ConfigPath
    runner_syntax_errors = $RunnerErrors.Count
    wrapper_syntax_errors = $WrapperErrors.Count
    initial_validation_exit_code = $InitialExitCode
    git_auto_commit = $false
    git_auto_push = $false
    publication_engine = "SPT-021.0.1-v1.0.6"
    technical_errors = 0
    status = "CLOSED"
})

foreach ($P in @($RunnerPath,$WrapperPath,$ConfigPath,$ActPath)) {
    Copy-Item -LiteralPath $P -Destination $ReleaseRoot -Force
}

Write-Step "Resultado final"

Write-Host "Persistent auto-update: ENABLED"
Write-Host "Long paths: ENABLED PER COMMAND"
Write-Host "Historical recursive backups: EXCLUDED"
Write-Host "Native Git stderr isolation: ENABLED"
Write-Host "PowerShell child exit-code isolation: ENABLED"
Write-Host "Wrapper pipeline-output isolation: ENABLED"
Write-Host "Interval minutes: $IntervalMinutes"
Write-Host "Scheduled task: $TaskName"
Write-Host "Task state: $($Task.State)"
Write-Host "Runner syntax errors: $($RunnerErrors.Count)"
Write-Host "Publication wrapper syntax errors: $($WrapperErrors.Count)"
Write-Host "Initial validation exit code: $InitialExitCode"
Write-Host "Git auto commit: NO"
Write-Host "Git auto push: NO"
Write-Host "Canonical publication engine: SPT-021.0.1 v1.0.6"
Write-Host "Technical errors: 0"
Write-Host "Institutional status: CLOSED" -ForegroundColor Green
Write-Host "SPT-021.3 v1.1.3: PERSISTENT AUTO-UPDATE ENABLED." -ForegroundColor Green
Write-Host "SGD-002: WILL UPDATE AUTOMATICALLY ON REPOSITORY CHANGES." -ForegroundColor Green
