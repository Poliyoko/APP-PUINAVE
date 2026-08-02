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

$EvidenceChanges = @(Get-GitChanges)

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

$FinalChanges = @(Get-GitChanges)

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