<#
.SYNOPSIS
    Corrige el preflight Git de SPT-003A.

.DESCRIPTION
    El instalador original exige un worktree completamente limpio.
    Al copiar el propio instalador a la raíz, Git lo detecta como archivo
    nuevo y bloquea la ejecución.

    Este correctivo modifica únicamente la validación inicial para:
      - permitir archivos de instalación SPT-003A conocidos;
      - bloquear cualquier otro cambio previo;
      - conservar la exigencia de una línea base institucional controlada.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.EXAMPLE
    .\Repair-SPT003A-v0.1.1-Clean-Baseline-Preflight.ps1
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

function Assert-Path {
    param([string]$Path, [string]$Description)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontró $Description en: $Path"
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo escribir: $Path"
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$InstallerPath = Join-Path `
    $ProjectRoot `
    "Install-SPT003A-AI-Multimedia-Orchestrator.ps1"

Assert-Path `
    -Path $InstallerPath `
    -Description "el instalador SPT-003A"

Write-Step "Leyendo instalador SPT-003A"

$Content = Get-Content `
    -LiteralPath $InstallerPath `
    -Raw `
    -Encoding UTF8

$OldBlock = @'
$GitStatus = @(
    git status --porcelain |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)

if ($GitStatus.Count -gt 0) {
    throw "La línea base Git debe estar limpia antes de instalar SPT-003A."
}
'@

$NewBlock = @'
$GitStatus = @(
    git status --porcelain |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)

$AllowedPreflightPatterns = @(
    '^\?\? Install-SPT003A-AI-Multimedia-Orchestrator\.ps1$',
    '^\?\? Repair-SPT003A-v[0-9.]+-.*\.ps1$',
    '^\?\? SPT003A-.*\.zip$',
    '^\?\? LEAME-SPT003A.*\.txt$'
)

$UnexpectedGitChanges = @(
    foreach ($Entry in $GitStatus) {
        $Allowed = $false

        foreach ($Pattern in $AllowedPreflightPatterns) {
            if ($Entry -match $Pattern) {
                $Allowed = $true
                break
            }
        }

        if (-not $Allowed) {
            $Entry
        }
    }
)

if ($UnexpectedGitChanges.Count -gt 0) {
    Write-Host "Cambios Git no permitidos antes de SPT-003A:" -ForegroundColor Red

    foreach ($Entry in $UnexpectedGitChanges) {
        Write-Host "  $Entry" -ForegroundColor Red
    }

    throw (
        "La línea base contiene cambios ajenos a los archivos de " +
        "instalación SPT-003A."
    )
}

if ($GitStatus.Count -gt 0) {
    Write-Host (
        "Preflight Git aprobado con archivos de instalación " +
        "SPT-003A permitidos."
    ) -ForegroundColor Yellow
}
else {
    Write-Host "Preflight Git aprobado: repositorio limpio." -ForegroundColor Green
}
'@

if (-not $Content.Contains($OldBlock)) {
    if ($Content.Contains('$AllowedPreflightPatterns')) {
        Write-Host "El correctivo ya estaba instalado." -ForegroundColor Yellow
    }
    else {
        throw "No se encontró el bloque de preflight esperado."
    }
}
else {
    $Content = $Content.Replace($OldBlock, $NewBlock)
    Write-Utf8NoBom -Path $InstallerPath -Content $Content
    Write-Host "Preflight Git corregido." -ForegroundColor Green
}

Write-Step "Validando correctivo"

$Installed = Get-Content `
    -LiteralPath $InstallerPath `
    -Raw `
    -Encoding UTF8

$Required = @(
    '$AllowedPreflightPatterns',
    '$UnexpectedGitChanges',
    'Install-SPT003A-AI-Multimedia-Orchestrator',
    'Repair-SPT003A-v[0-9.]+',
    'Cambios Git no permitidos antes de SPT-003A'
)

$Missing = @()

foreach ($Fragment in $Required) {
    if (-not $Installed.Contains($Fragment)) {
        $Missing += $Fragment
    }
}

if ($Missing.Count -gt 0) {
    throw "La validación del correctivo falló: $($Missing -join ' | ')"
}

Write-Host "Correctivo SPT-003A v0.1.1 validado." -ForegroundColor Green

Write-Step "Mostrando estado Git actual"

git status -sb

Write-Step "Resultado"

Write-Host "SPT-003A v0.1.1 preflight corregido." -ForegroundColor Green
Write-Host "Ahora vuelva a ejecutar:" -ForegroundColor Cyan
Write-Host ".\Install-SPT003A-AI-Multimedia-Orchestrator.ps1" -ForegroundColor Cyan
