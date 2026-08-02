<#
.SYNOPSIS
    Corrige SPB-007 para no enviar --tag cuando TagName está vacío.

.DESCRIPTION
    Repara scripts/Invoke-SPB007-InstitutionalPublish.ps1,
    valida su contenido, ejecuta las pruebas específicas y la suite
    completa. No realiza commit ni push durante el correctivo.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.EXAMPLE
    .\Repair-SPB007-v1.0.1-Optional-Tag.ps1
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

$InvokePath = Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"
$TestPath = Join-Path $ProjectRoot "tests\publisher\test_SPB_007_institutional_publisher.py"

Assert-Path -Path $InvokePath -Description "Invoke-SPB007-InstitutionalPublish.ps1"
Assert-Path -Path $TestPath -Description "las pruebas SPB-007"

$InvokeContent = @'
[CmdletBinding()]
param(
    [switch]$Publish,
    [string]$CommitMessage = "feat(repository): institutional publication through SPB-007",
    [string]$TagName = "",
    [string]$Remote = "origin"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

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

if ($Publish) {
    & "$Root\scripts\Invoke-SGD114-v2-RepositoryAudit.ps1" -RequireCleanGit

    if ($LASTEXITCODE -ne 0) {
        throw "La auditoría estricta posterior a la publicación falló."
    }
}
'@

Write-Step "Aplicando correctivo de tag opcional"
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Validando contenido del script"

& python -c "from pathlib import Path; p=Path(r'scripts/Invoke-SPB007-InstitutionalPublish.ps1'); t=p.read_text(encoding='utf-8'); assert 'IsNullOrWhiteSpace($TagName)' in t; assert '$Arguments += @(\"--tag\", $TagName)' in t; print('Tag opcional verificado')"

if ($LASTEXITCODE -ne 0) {
    throw "La validación del correctivo falló."
}

Write-Step "Ejecutando auditoría previa sin publicar"

& "$InvokePath"

if ($LASTEXITCODE -ne 0) {
    throw "La auditoría previa corregida falló."
}

Write-Step "Ejecutando pruebas específicas SPB-007"

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

Write-Host "SPB-007 v1.0.1 corregido y validado." -ForegroundColor Green
Write-Host "Tag vacío: OMITIDO CORRECTAMENTE." -ForegroundColor Green
Write-Host "Auditoría previa: APROBADA." -ForegroundColor Green
Write-Host "Pruebas específicas: APROBADAS." -ForegroundColor Green
Write-Host "Suite completa: APROBADA." -ForegroundColor Green
Write-Host ""
Write-Host "Siguiente comando:" -ForegroundColor Cyan
Write-Host '.\scripts\Invoke-SPB007-InstitutionalPublish.ps1 -Publish -CommitMessage "feat(repository): publish SGODA-PUINAVE institutional baseline"' -ForegroundColor Cyan
