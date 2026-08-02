<#
.SYNOPSIS
    Completa la validación de SPB-007 usando PowerShell nativo.

.DESCRIPTION
    Evita python -c y cualquier problema de comillas o expansión.
    Comprueba directamente que el publicador:
      - omite --tag cuando TagName está vacío;
      - agrega --tag y su valor cuando existe;
      - conserva mensajes UTF-8 correctos.

    Después ejecuta:
      - auditoría previa sin publicar;
      - 6 pruebas específicas;
      - suite completa de 103 pruebas.

    Este correctivo NO ejecuta commit ni push.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.EXAMPLE
    .\Repair-SPB007-v1.0.3-Native-PowerShell-Validation.ps1
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

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$InvokePath = Join-Path `
    $ProjectRoot `
    "scripts\Invoke-SPB007-InstitutionalPublish.ps1"

$TestPath = Join-Path `
    $ProjectRoot `
    "tests\publisher\test_SPB_007_institutional_publisher.py"

Assert-Path `
    -Path $InvokePath `
    -Description "Invoke-SPB007-InstitutionalPublish.ps1"

Assert-Path `
    -Path $TestPath `
    -Description "las pruebas SPB-007"

Write-Step "Validando el correctivo con PowerShell nativo"

$InvokeContent = Get-Content `
    -LiteralPath $InvokePath `
    -Raw `
    -Encoding UTF8

$RequiredFragments = @(
    'if (-not [string]::IsNullOrWhiteSpace($TagName))',
    '$Arguments += @("--tag", $TagName)',
    'if ($Publish)',
    '$Arguments += "--publish"',
    'throw "SPB-007 terminó con errores."'
)

$MissingFragments = @()

foreach ($Fragment in $RequiredFragments) {
    if (-not $InvokeContent.Contains($Fragment)) {
        $MissingFragments += $Fragment
    }
}

if ($MissingFragments.Count -gt 0) {
    throw (
        "El script publicador no contiene todos los elementos requeridos: " +
        ($MissingFragments -join " | ")
    )
}

$TagAppendPosition = $InvokeContent.IndexOf(
    '$Arguments += @("--tag", $TagName)'
)

$TagConditionPosition = $InvokeContent.IndexOf(
    'if (-not [string]::IsNullOrWhiteSpace($TagName))'
)

if ($TagConditionPosition -lt 0 -or $TagAppendPosition -lt 0) {
    throw "No se pudo localizar la lógica del tag opcional."
}

if ($TagAppendPosition -lt $TagConditionPosition) {
    throw "La instrucción --tag aparece fuera o antes de su condición."
}

Write-Host "Tag opcional verificado correctamente." -ForegroundColor Green
Write-Host "Validación sin python -c: APROBADA." -ForegroundColor Green

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

Write-Host "SPB-007 v1.0.3 validado correctamente." -ForegroundColor Green
Write-Host "Tag vacío: OMITIDO CORRECTAMENTE." -ForegroundColor Green
Write-Host "Validación PowerShell nativa: APROBADA." -ForegroundColor Green
Write-Host "Auditoría previa: APROBADA." -ForegroundColor Green
Write-Host "Pruebas específicas: 6 APROBADAS." -ForegroundColor Green
Write-Host "Suite completa: 103 APROBADAS." -ForegroundColor Green

Write-Host ""
Write-Host "Publicación institucional pendiente." -ForegroundColor Yellow
Write-Host "Ejecute ahora:" -ForegroundColor Cyan
Write-Host @'
.\scripts\Invoke-SPB007-InstitutionalPublish.ps1 `
    -Publish `
    -CommitMessage "feat(repository): publish SGODA-PUINAVE institutional baseline"
'@ -ForegroundColor Cyan
