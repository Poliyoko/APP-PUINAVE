[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Get-Location).Path,
    [string]$BackupRoot
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path $RepositoryRoot).Path

if (-not $BackupRoot) {
    $base = Join-Path $root "artifacts\backups\spb-003.2-b1.3"
    $latest = Get-ChildItem $base -Directory -ErrorAction Stop |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if (-not $latest) { throw "No existe respaldo B1.3." }
    $BackupRoot = $latest.FullName
}

$backup = (Resolve-Path $BackupRoot).Path
Get-ChildItem $backup -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($backup.Length).TrimStart('\')
    $target = Join-Path $root $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item $_.FullName $target -Force
    Write-Host "RESTAURADO: $relative" -ForegroundColor Cyan
}

Write-Host "Rollback B1.3 completado desde: $backup" -ForegroundColor Green
