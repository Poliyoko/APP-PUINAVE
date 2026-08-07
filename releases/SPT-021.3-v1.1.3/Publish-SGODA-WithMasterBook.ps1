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