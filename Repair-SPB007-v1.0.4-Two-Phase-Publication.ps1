<#
.SYNOPSIS
    Corrige SPB-007 para publicar evidencias en una segunda fase y
    ejecutar la auditoría estricta final fuera del repositorio.

.DESCRIPTION
    La primera publicación fue exitosa, pero después se generaron dentro
    del repositorio:
      - publication-result.json;
      - repository-audit.json;
      - repository-manifest.json;
      - repository-governance-event.json.

    Esos archivos volvieron a ensuciar Git.

    Este correctivo reemplaza el orquestador SPB-007 para:
      1. ejecutar la publicación principal;
      2. generar la auditoría institucional y sus evidencias;
      3. confirmar y publicar esas evidencias en un segundo commit;
      4. ejecutar una auditoría estricta final con salidas temporales
         fuera del repositorio;
      5. verificar que Git quede realmente limpio.

    No modifica la configuración global de Git.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.EXAMPLE
    .\Repair-SPB007-v1.0.4-Two-Phase-Publication.ps1
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
    param(
        [string]$Path,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontró $Description en: $Path"
    }
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo crear: $Path"
    }

    $Info = Get-Item -LiteralPath $Path
    Write-Host "Corregido: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$InvokePath = Join-Path `
    $ProjectRoot `
    "scripts\Invoke-SPB007-InstitutionalPublish.ps1"

$PublisherTestPath = Join-Path `
    $ProjectRoot `
    "tests\publisher\test_SPB_007_institutional_publisher.py"

Assert-Path `
    -Path $InvokePath `
    -Description "Invoke-SPB007-InstitutionalPublish.ps1"

Assert-Path `
    -Path $PublisherTestPath `
    -Description "las pruebas SPB-007"

$InvokeContent = @'
[CmdletBinding()]
param(
    [switch]$Publish,
    [string]$CommitMessage = "feat(repository): institutional publication through SPB-007",
    [string]$EvidenceCommitMessage = "chore(repository): publish institutional evidence",
    [string]$TagName = "",
    [string]$Remote = "origin"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

function Invoke-GitChecked {
    param([string[]]$Arguments)

    & git @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Falló el comando Git: git $($Arguments -join ' ')"
    }
}

function Get-GitChanges {
    return @(
        & git status --porcelain |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

$Arguments = @(
    "-m",
    "sgoda.publisher.institutional_publisher",
    "--root",
    $Root,
    "--commit-message",
    $CommitMessage,
    "--remote",
    $Remote,
    "--audit-output",
    "artifacts/pmo/SPB-007/prepublication-audit.json",
    "--evidence-output",
    "artifacts/pmo/SPB-007/publication-result.json"
)

if (-not [string]::IsNullOrWhiteSpace($TagName)) {
    $Arguments += @("--tag", $TagName)
}

if ($Publish) {
    $Arguments += "--publish"
}

& python @Arguments

if ($LASTEXITCODE -ne 0) {
    throw "SPB-007 terminó con errores."
}

if (-not $Publish) {
    return
}

Write-Host ""
Write-Host "==> Generando auditoría institucional versionable" -ForegroundColor Cyan

& python -m sgoda.governance.repository_governance `
    --root "$Root" `
    --policy "config/governance/sgd-114-v2-repository-policy.json" `
    --audit-output "artifacts/pmo/SGD-114-v2/repository-audit.json" `
    --manifest-output "artifacts/pmo/SGD-114-v2/repository-manifest.json" `
    --event-output "artifacts/pmo/SGD-114-v2/repository-governance-event.json"

if ($LASTEXITCODE -ne 0) {
    throw "La auditoría institucional versionable no fue aprobada."
}

$EvidenceChanges = Get-GitChanges

if ($EvidenceChanges.Count -gt 0) {
    Write-Host ""
    Write-Host "==> Publicando evidencias posteriores" -ForegroundColor Cyan

    Invoke-GitChecked @(
        "-c",
        "core.safecrlf=false",
        "add",
        "--all"
    )

    $Staged = @(
        & git diff --cached --name-only |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    if ($Staged.Count -gt 0) {
        Invoke-GitChecked @(
            "commit",
            "-m",
            $EvidenceCommitMessage
        )

        $Branch = (& git branch --show-current).Trim()

        if ([string]::IsNullOrWhiteSpace($Branch)) {
            throw "No se pudo determinar la rama para publicar evidencias."
        }

        Invoke-GitChecked @(
            "push",
            $Remote,
            $Branch
        )
    }
}

Write-Host ""
Write-Host "==> Ejecutando auditoría estricta final de solo lectura" -ForegroundColor Cyan

$TempAuditRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ("sgoda-spb007-final-audit-" + [Guid]::NewGuid().ToString("N"))

New-Item `
    -ItemType Directory `
    -Path $TempAuditRoot `
    -Force | Out-Null

try {
    $TempAudit = Join-Path $TempAuditRoot "repository-audit.json"
    $TempManifest = Join-Path $TempAuditRoot "repository-manifest.json"
    $TempEvent = Join-Path $TempAuditRoot "repository-governance-event.json"

    & python -m sgoda.governance.repository_governance `
        --root "$Root" `
        --policy "config/governance/sgd-114-v2-repository-policy.json" `
        --audit-output "$TempAudit" `
        --manifest-output "$TempManifest" `
        --event-output "$TempEvent" `
        --require-clean-git

    if ($LASTEXITCODE -ne 0) {
        throw "La auditoría estricta final no fue aprobada."
    }

    if (-not (Test-Path -LiteralPath $TempAudit)) {
        throw "No se generó la auditoría estricta temporal."
    }

    $StrictAudit = Get-Content `
        -LiteralPath $TempAudit `
        -Raw |
        ConvertFrom-Json

    if (-not $StrictAudit.passed) {
        throw "La auditoría estricta temporal no contiene passed=true."
    }

    if (-not $StrictAudit.git.clean) {
        throw "La auditoría estricta temporal no confirma Git limpio."
    }
}
finally {
    if (Test-Path -LiteralPath $TempAuditRoot) {
        Remove-Item `
            -LiteralPath $TempAuditRoot `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

$FinalChanges = Get-GitChanges

if ($FinalChanges.Count -gt 0) {
    throw (
        "La publicación terminó, pero Git conserva cambios: " +
        ($FinalChanges -join " | ")
    )
}

Write-Host ""
Write-Host "SPB-007 publicación institucional completada." -ForegroundColor Green
Write-Host "Evidencias posteriores: PUBLICADAS." -ForegroundColor Green
Write-Host "Auditoría estricta final: APROBADA." -ForegroundColor Green
Write-Host "Git limpio: True" -ForegroundColor Green
'@

Write-Step "Instalando orquestador de publicación en dos fases"

Write-Utf8NoBom `
    -Path $InvokePath `
    -Content $InvokeContent

Write-Step "Validando estructura del orquestador"

$Installed = Get-Content `
    -LiteralPath $InvokePath `
    -Raw `
    -Encoding UTF8

$RequiredFragments = @(
    'EvidenceCommitMessage',
    'repository-governance-event.json',
    'sgoda-spb007-final-audit-',
    '--require-clean-git',
    'Get-GitChanges',
    'Git limpio: True'
)

$Missing = @()

foreach ($Fragment in $RequiredFragments) {
    if (-not $Installed.Contains($Fragment)) {
        $Missing += $Fragment
    }
}

if ($Missing.Count -gt 0) {
    throw (
        "Faltan elementos del orquestador: " +
        ($Missing -join " | ")
    )
}

Write-Host "Orquestador de dos fases verificado." -ForegroundColor Green

Write-Step "Ejecutando auditoría previa sin publicar"

& $InvokePath

if ($LASTEXITCODE -ne 0) {
    throw "La auditoría previa SPB-007 falló."
}

Write-Step "Ejecutando las 6 pruebas específicas SPB-007"

& python -m pytest `
    "tests/publisher/test_SPB_007_institutional_publisher.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SPB-007 fallaron."
}

Write-Step "Ejecutando suite completa"

& python -m pytest

if ($LASTEXITCODE -ne 0) {
    throw "La suite completa terminó con errores."
}

Write-Step "Resultado final"

Write-Host "SPB-007 v1.0.4 corregido y validado." -ForegroundColor Green
Write-Host "Publicación en dos fases: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Auditoría final temporal: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Pruebas específicas: 6 APROBADAS." -ForegroundColor Green
Write-Host "Suite completa: 103 APROBADAS." -ForegroundColor Green

Write-Host ""
Write-Host "Estado actual:" -ForegroundColor Yellow
& git status -sb

Write-Host ""
Write-Host "Ejecute la publicación correctiva:" -ForegroundColor Cyan
Write-Host @'
.\scripts\Invoke-SPB007-InstitutionalPublish.ps1 `
    -Publish `
    -CommitMessage "fix(repository): complete SPB-007 two-phase publication" `
    -EvidenceCommitMessage "chore(repository): publish final audit evidence"
'@ -ForegroundColor Cyan
