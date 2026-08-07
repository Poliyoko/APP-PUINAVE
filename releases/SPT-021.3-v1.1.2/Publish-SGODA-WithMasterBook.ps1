[CmdletBinding()]
param([switch]$PrepareOnly)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-PowerShellFile {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    $PowerShellExe = Join-Path $env:SystemRoot (
        "System32\WindowsPowerShell\v1.0\powershell.exe"
    )

    $ArgList = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $FilePath
    ) + $Arguments

    & $PowerShellExe @ArgList

    return $LASTEXITCODE
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

Write-Host "==> Actualizando Libro Maestro antes de publicar" `
    -ForegroundColor Cyan

$UpdateExitCode = Invoke-PowerShellFile `
    -FilePath $Updater `
    -Arguments @(
        "-ProjectRoot",
        $ProjectRoot
    )

if ($UpdateExitCode -ne 0) {
    throw (
        "No fue posible actualizar SGD-002. Exit code: " +
        $UpdateExitCode
    )
}

if ($PrepareOnly) {
    $PublishExitCode = Invoke-PowerShellFile `
        -FilePath $Publisher
}
else {
    $PublishExitCode = Invoke-PowerShellFile `
        -FilePath $Publisher `
        -Arguments @("-Publish")
}

exit $PublishExitCode