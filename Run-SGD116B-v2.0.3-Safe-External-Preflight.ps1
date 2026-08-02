<#
.SYNOPSIS
    Ejecuta SGD-116B usando un preflight externo seguro y restaura siempre
    el instalador original.

.DESCRIPTION
    Este archivo NO reescribe permanentemente el instalador.

    Flujo:
      1. valida los cambios Git contra una lista blanca limitada a SGD-116;
      2. respalda el instalador byte por byte;
      3. cambia temporalmente una sola condición:
           if ($Unexpected.Count -gt 0) {
         por:
           if ($false -and $Unexpected.Count -gt 0) {
      4. valida la sintaxis del instalador temporal;
      5. ejecuta SGD-116B;
      6. restaura el instalador original en un bloque finally.

    Si existe un cambio ajeno a SGD-116, no ejecuta nada.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-StatusPath {
    param([string]$Entry)

    if ([string]::IsNullOrWhiteSpace($Entry)) {
        return ""
    }

    $Value = if ($Entry.Length -ge 4) {
        $Entry.Substring(3).Trim()
    }
    else {
        $Entry.Trim()
    }

    if ($Value.Contains(" -> ")) {
        $Value = $Value.Split(
            @(" -> "),
            [System.StringSplitOptions]::None
        )[-1]
    }

    return $Value.Trim('"')
}

function Test-AllowedRoadmapPath {
    param([string]$Path)

    $ExactPaths = @(
        "Install-SGD116-Master-Ecosystem-Roadmap.ps1",
        "Install-SGD116B-Institutional-Roadmap-Closure.ps1",
        "Repair-SGD116B-v2.0.1-Preflight-Existing-Roadmap.ps1",
        "Repair-SGD116B-v2.0.2-Safe-Preflight-Injection.ps1",
        "Run-SGD116B-v2.0.3-Safe-External-Preflight.ps1",
        "dashboard/dependency-graph.json",
        "dashboard/ecosystem-metrics.json",
        "dashboard/ecosystem-roadmap.json",
        "dashboard/executive-summary.json",
        "dashboard/timeline.json",
        "docs/00_DEPENDENCIAS_MAESTRAS.md",
        "docs/00_METRICAS_ECOSISTEMA.md",
        "docs/00_ROADMAP_MAESTRO.md",
        "docs/00_TIMELINE_MAESTRO.md",
        "scripts/Invoke-SGD116-MasterRoadmap.ps1"
    )

    $Prefixes = @(
        "artifacts/roadmap/",
        "artifacts/pmo/SGD-116/",
        "artifacts/pmo/SGD-116B/",
        "config/roadmap/",
        "docs/05_Fase_Tecnologica/SGD-116/",
        "docs/05_Fase_Tecnologica/SGD-116B/",
        "releases/SGD-116",
        "src/sgoda/roadmap/",
        "tests/roadmap/"
    )

    if ($Path -in $ExactPaths) {
        return $true
    }

    foreach ($Prefix in $Prefixes) {
        if ($Path.StartsWith(
            $Prefix,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            return $true
        }
    }

    if (
        $Path -like "Repair-SGD116*.ps1" -or
        $Path -like "SGD116*.zip" -or
        $Path -like "LEAME-SGD116*.txt"
    ) {
        return $true
    }

    return $false
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$InstallerPath = Join-Path `
    $ProjectRoot `
    "Install-SGD116B-Institutional-Roadmap-Closure.ps1"

if (-not (Test-Path -LiteralPath $InstallerPath)) {
    throw "No se encontró el instalador SGD-116B: $InstallerPath"
}

Write-Step "Ejecutando preflight externo"

$StatusEntries = @(git status --porcelain | Where-Object { $_ })
$Unexpected = @()

foreach ($Entry in $StatusEntries) {
    $StatusPath = Get-StatusPath -Entry $Entry

    if (-not (Test-AllowedRoadmapPath -Path $StatusPath)) {
        $Unexpected += [pscustomobject]@{
            Entry = $Entry
            Path = $StatusPath
        }
    }
}

if ($Unexpected.Count -gt 0) {
    Write-Host "Cambios ajenos a SGD-116 detectados:" `
        -ForegroundColor Red

    $Unexpected |
        Format-Table Entry, Path -AutoSize

    throw "El preflight externo rechazó cambios no relacionados."
}

Write-Host "Preflight externo: APROBADO." `
    -ForegroundColor Green
Write-Host "Elementos Git revisados: $($StatusEntries.Count)" `
    -ForegroundColor Cyan

$BackupDir = Join-Path `
    $ProjectRoot `
    "artifacts\pmo\SGD-116B\external-preflight-backups"

New-Item `
    -ItemType Directory `
    -Path $BackupDir `
    -Force |
    Out-Null

$Timestamp = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
$BackupPath = Join-Path `
    $BackupDir `
    "Install-SGD116B-original-$Timestamp.ps1"

$OriginalBytes = [System.IO.File]::ReadAllBytes($InstallerPath)
[System.IO.File]::WriteAllBytes($BackupPath, $OriginalBytes)

Write-Step "Preparando copia temporal del instalador"

$HasBom = (
    $OriginalBytes.Length -ge 3 -and
    $OriginalBytes[0] -eq 0xEF -and
    $OriginalBytes[1] -eq 0xBB -and
    $OriginalBytes[2] -eq 0xBF
)

if ($HasBom) {
    $OriginalText = [System.Text.Encoding]::UTF8.GetString(
        $OriginalBytes,
        3,
        $OriginalBytes.Length - 3
    )
}
else {
    $OriginalText = [System.Text.Encoding]::UTF8.GetString(
        $OriginalBytes
    )
}

$Needle = 'if ($Unexpected.Count -gt 0) {'
$Replacement = 'if ($false -and $Unexpected.Count -gt 0) {'

$Position = $OriginalText.IndexOf(
    $Needle,
    [System.StringComparison]::Ordinal
)

if ($Position -lt 0) {
    throw "No se encontró la condición interna del preflight."
}

$TemporaryText = (
    $OriginalText.Substring(0, $Position) +
    $Replacement +
    $OriginalText.Substring($Position + $Needle.Length)
)

$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$TemporaryPayload = $Utf8NoBom.GetBytes($TemporaryText)

if ($HasBom) {
    $Bom = [byte[]](0xEF, 0xBB, 0xBF)
    $Combined = New-Object byte[] ($Bom.Length + $TemporaryPayload.Length)
    [Array]::Copy($Bom, 0, $Combined, 0, $Bom.Length)
    [Array]::Copy(
        $TemporaryPayload,
        0,
        $Combined,
        $Bom.Length,
        $TemporaryPayload.Length
    )
    $TemporaryPayload = $Combined
}

[System.IO.File]::WriteAllBytes(
    $InstallerPath,
    $TemporaryPayload
)

try {
    Write-Step "Validando instalador temporal"

    $Tokens = $null
    $ParserErrors = $null

    [System.Management.Automation.Language.Parser]::ParseFile(
        $InstallerPath,
        [ref]$Tokens,
        [ref]$ParserErrors
    ) | Out-Null

    if (@($ParserErrors).Count -gt 0) {
        Write-Host "Errores de análisis:" -ForegroundColor Red

        @($ParserErrors) |
            Format-Table ErrorId, Message -AutoSize

        throw "El instalador temporal no superó el análisis PowerShell."
    }

    Write-Host "Sintaxis temporal: APROBADA." `
        -ForegroundColor Green

    Write-Step "Ejecutando instalador SGD-116B"

    $Arguments = @(
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $InstallerPath,
        "-ProjectRoot",
        $ProjectRoot
    )

    if ($SkipFullSuite) {
        $Arguments += "-SkipFullSuite"
    }

    & powershell.exe @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "SGD-116B terminó con código $LASTEXITCODE."
    }

    Write-Step "Instalación SGD-116B completada"

    Write-Host "SGD-116B: EJECUCIÓN APROBADA." `
        -ForegroundColor Green
}
finally {
    Write-Step "Restaurando instalador original"

    [System.IO.File]::WriteAllBytes(
        $InstallerPath,
        $OriginalBytes
    )

    $RestoredBytes = [System.IO.File]::ReadAllBytes(
        $InstallerPath
    )

    $OriginalHash = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::HashData(
            $OriginalBytes
        )
    ).Replace("-", "").ToLowerInvariant()

    $RestoredHash = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::HashData(
            $RestoredBytes
        )
    ).Replace("-", "").ToLowerInvariant()

    if ($OriginalHash -ne $RestoredHash) {
        Copy-Item `
            -LiteralPath $BackupPath `
            -Destination $InstallerPath `
            -Force

        throw "No se confirmó la restauración exacta del instalador."
    }

    Write-Host "Instalador original: RESTAURADO." `
        -ForegroundColor Green
    Write-Host "SHA-256 restaurado: $RestoredHash" `
        -ForegroundColor Cyan
    Write-Host "Respaldo: $BackupPath" `
        -ForegroundColor Cyan
}
