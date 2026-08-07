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