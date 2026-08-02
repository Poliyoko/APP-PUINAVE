<#
.SYNOPSIS
    Corrige el preflight del instalador SGD-116B para reconocer como
    legítimos los archivos y carpetas generados previamente por SGD-116.

.DESCRIPTION
    No elimina archivos ni modifica el código del Roadmap.
    Únicamente actualiza:
      Install-SGD116B-Institutional-Roadmap-Closure.ps1

    Se permiten explícitamente los elementos existentes de SGD-116:
      - artifacts/roadmap/
      - config/roadmap/
      - dashboard del Roadmap
      - documentos maestros 00_*
      - docs/05_Fase_Tecnologica/SGD-116/
      - scripts/Invoke-SGD116-MasterRoadmap.ps1
      - src/sgoda/roadmap/
      - tests/roadmap/
      - evidencias y releases SGD-116

    Cualquier cambio ajeno continúa bloqueado.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$InstallerPath = Join-Path `
    $ProjectRoot `
    "Install-SGD116B-Institutional-Roadmap-Closure.ps1"

if (-not (Test-Path -LiteralPath $InstallerPath)) {
    throw "No se encontró el instalador SGD-116B en: $InstallerPath"
}

$BackupDir = Join-Path `
    $ProjectRoot `
    "artifacts\pmo\SGD-116B\preflight-backups"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

$BackupPath = Join-Path `
    $BackupDir `
    (
        "Install-SGD116B-Institutional-Roadmap-Closure-" +
        [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss") +
        ".ps1"
    )

Copy-Item `
    -LiteralPath $InstallerPath `
    -Destination $BackupPath `
    -Force

Write-Step "Leyendo instalador SGD-116B"

$Content = Get-Content `
    -LiteralPath $InstallerPath `
    -Raw `
    -Encoding UTF8

$OldBlock = @'
$AllowedPatterns = @(
    '^\?\? Install-SGD116B-Institutional-Roadmap-Closure\.ps1$',
    '^\?\? SGD116B-.*\.zip$',
    '^\?\? LEAME-SGD116B.*\.txt$',
    '^\?\? Repair-SGD116.*\.ps1$',
    '^\?\? Install-SGD116.*\.ps1$',
    '^ M src/sgoda/roadmap/',
    '^ M tests/roadmap/',
    '^ M artifacts/roadmap/SGD-116/',
    '^ M dashboard/',
    '^ M docs/00_',
    '^\?\? artifacts/pmo/SGD-116/',
    '^\?\? releases/SGD-116'
)
'@

$NewBlock = @'
$AllowedPatterns = @(
    '^\?\? Install-SGD116B-Institutional-Roadmap-Closure\.ps1$',
    '^\?\? Repair-SGD116B-v[0-9.]+-.*\.ps1$',
    '^\?\? SGD116B-.*\.zip$',
    '^\?\? LEAME-SGD116B.*\.txt$',
    '^\?\? Repair-SGD116.*\.ps1$',
    '^\?\? Install-SGD116.*\.ps1$',

    '^( M|\?\?) src/sgoda/roadmap(/|$)',
    '^( M|\?\?) tests/roadmap(/|$)',
    '^( M|\?\?) config/roadmap(/|$)',
    '^( M|\?\?) artifacts/roadmap(/|$)',
    '^( M|\?\?) artifacts/pmo/SGD-116(/|$)',
    '^( M|\?\?) artifacts/pmo/SGD-116B(/|$)',
    '^( M|\?\?) releases/SGD-116',
    '^( M|\?\?) dashboard/(dependency-graph|ecosystem-metrics|ecosystem-roadmap|executive-summary|timeline|SGD-116).*\.json$',
    '^( M|\?\?) docs/00_(DEPENDENCIAS_MAESTRAS|METRICAS_ECOSISTEMA|ROADMAP_MAESTRO|TIMELINE_MAESTRO)\.md$',
    '^( M|\?\?) docs/05_Fase_Tecnologica/SGD-116(/|$)',
    '^( M|\?\?) scripts/Invoke-SGD116-MasterRoadmap\.ps1$'
)
'@

if (-not $Content.Contains($OldBlock)) {
    throw @"
No se encontró el bloque de preflight esperado.
El instalador puede haber sido modificado manualmente.
No se aplicó ningún cambio.
Respaldo: $BackupPath
"@
}

$Updated = $Content.Replace($OldBlock, $NewBlock)

[System.IO.File]::WriteAllText(
    $InstallerPath,
    $Updated,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Step "Validando correctivo"

$ParserErrors = $null
$Tokens = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    $InstallerPath,
    [ref]$Tokens,
    [ref]$ParserErrors
) | Out-Null

if (@($ParserErrors).Count -gt 0) {
    Copy-Item `
        -LiteralPath $BackupPath `
        -Destination $InstallerPath `
        -Force

    @($ParserErrors) | Format-List
    throw "La validación PowerShell falló. Se restauró el respaldo."
}

$RequiredPatterns = @(
    "artifacts/roadmap",
    "config/roadmap",
    "src/sgoda/roadmap",
    "tests/roadmap",
    "docs/05_Fase_Tecnologica/SGD-116",
    "Invoke-SGD116-MasterRoadmap"
)

foreach ($Pattern in $RequiredPatterns) {
    if ($Updated -notmatch [regex]::Escape($Pattern)) {
        Copy-Item `
            -LiteralPath $BackupPath `
            -Destination $InstallerPath `
            -Force

        throw "Falta el patrón requerido: $Pattern"
    }
}

Write-Step "Resultado"

Write-Host "SGD-116B v2.0.1: preflight corregido." `
    -ForegroundColor Green
Write-Host "Archivos previos de SGD-116: PERMITIDOS." `
    -ForegroundColor Green
Write-Host "Cambios ajenos al Roadmap: CONTINÚAN BLOQUEADOS." `
    -ForegroundColor Green
Write-Host "Respaldo: $BackupPath" `
    -ForegroundColor Cyan

Write-Host ""
Write-Host "Ejecute nuevamente:" -ForegroundColor Yellow
Write-Host ".\Install-SGD116B-Institutional-Roadmap-Closure.ps1" `
    -ForegroundColor Yellow
