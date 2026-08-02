<#
.SYNOPSIS
    Corrige de forma segura el preflight de SGD-116B sin reemplazar bloques
    completos ni alterar los finales de línea del instalador.

.DESCRIPTION
    Inserta un filtro de elementos legítimos justo antes de:
        if ($Unexpected.Count -gt 0)

    Conserva byte por byte el resto del instalador, incluyendo:
      - codificación original;
      - BOM, si existe;
      - CRLF o LF;
      - continuaciones PowerShell con acento grave;
      - todos los here-strings.

    El filtro permite exclusivamente los archivos existentes de SGD-116.
    Los cambios ajenos al Roadmap continúan bloqueados.
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
    throw "No se encontró el instalador: $InstallerPath"
}

$BackupDir = Join-Path `
    $ProjectRoot `
    "artifacts\pmo\SGD-116B\preflight-backups"

New-Item `
    -ItemType Directory `
    -Path $BackupDir `
    -Force |
    Out-Null

$BackupPath = Join-Path `
    $BackupDir `
    (
        "Install-SGD116B-before-v2.0.2-" +
        [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss") +
        ".ps1"
    )

Copy-Item `
    -LiteralPath $InstallerPath `
    -Destination $BackupPath `
    -Force

Write-Step "Leyendo bytes originales del instalador"

$Bytes = [System.IO.File]::ReadAllBytes($InstallerPath)

$HasUtf8Bom = (
    $Bytes.Length -ge 3 -and
    $Bytes[0] -eq 0xEF -and
    $Bytes[1] -eq 0xBB -and
    $Bytes[2] -eq 0xBF
)

if ($HasUtf8Bom) {
    $Encoding = [System.Text.UTF8Encoding]::new($true)
    $Text = [System.Text.Encoding]::UTF8.GetString(
        $Bytes,
        3,
        $Bytes.Length - 3
    )
}
else {
    $Encoding = [System.Text.UTF8Encoding]::new($false)
    $Text = [System.Text.Encoding]::UTF8.GetString($Bytes)
}

if ($Text.Contains(
    "# SGD-116B-PREFLIGHT-SAFE-INJECTION-v2.0.2"
)) {
    Write-Host "El correctivo v2.0.2 ya está aplicado." `
        -ForegroundColor Yellow
    Write-Host "Respaldo no utilizado: $BackupPath" `
        -ForegroundColor Cyan
    exit 0
}

$NewLine = if ($Text.Contains("`r`n")) {
    "`r`n"
}
else {
    "`n"
}

$Marker = "if (`$Unexpected.Count -gt 0) {"

$Index = $Text.IndexOf(
    $Marker,
    [System.StringComparison]::Ordinal
)

if ($Index -lt 0) {
    throw @"
No se encontró el punto seguro de inserción:
$Marker

No se modificó el instalador.
Respaldo: $BackupPath
"@
}

$InjectionLines = @(
    "# SGD-116B-PREFLIGHT-SAFE-INJECTION-v2.0.2",
    '$LegitimateRoadmapExactPaths = @(',
    '    "dashboard/dependency-graph.json",',
    '    "dashboard/ecosystem-metrics.json",',
    '    "dashboard/ecosystem-roadmap.json",',
    '    "dashboard/executive-summary.json",',
    '    "dashboard/timeline.json",',
    '    "docs/00_DEPENDENCIAS_MAESTRAS.md",',
    '    "docs/00_METRICAS_ECOSISTEMA.md",',
    '    "docs/00_ROADMAP_MAESTRO.md",',
    '    "docs/00_TIMELINE_MAESTRO.md",',
    '    "scripts/Invoke-SGD116-MasterRoadmap.ps1"',
    ')',
    '',
    '$LegitimateRoadmapPrefixes = @(',
    '    "artifacts/roadmap/",',
    '    "artifacts/pmo/SGD-116/",',
    '    "artifacts/pmo/SGD-116B/",',
    '    "config/roadmap/",',
    '    "docs/05_Fase_Tecnologica/SGD-116/",',
    '    "releases/SGD-116",',
    '    "src/sgoda/roadmap/",',
    '    "tests/roadmap/"',
    ')',
    '',
    '$Unexpected = @(',
    '    foreach ($Entry in @($Unexpected)) {',
    '        $StatusPath = if ($Entry.Length -ge 4) {',
    '            $Entry.Substring(3).Trim()',
    '        }',
    '        else {',
    '            $Entry.Trim()',
    '        }',
    '',
    '        $IsLegitimate = (',
    '            $StatusPath -in $LegitimateRoadmapExactPaths',
    '        )',
    '',
    '        if (-not $IsLegitimate) {',
    '            foreach ($Prefix in $LegitimateRoadmapPrefixes) {',
    '                if ($StatusPath.StartsWith(',
    '                    $Prefix,',
    '                    [System.StringComparison]::OrdinalIgnoreCase',
    '                )) {',
    '                    $IsLegitimate = $true',
    '                    break',
    '                }',
    '            }',
    '        }',
    '',
    '        if (-not $IsLegitimate) {',
    '            $Entry',
    '        }',
    '    }',
    ')',
    ''
)

$Injection = (
    $InjectionLines -join $NewLine
) + $NewLine

$UpdatedText = (
    $Text.Substring(0, $Index) +
    $Injection +
    $Text.Substring($Index)
)

Write-Step "Escribiendo el instalador preservando su formato"

$Payload = $Encoding.GetBytes($UpdatedText)

[System.IO.File]::WriteAllBytes(
    $InstallerPath,
    $Payload
)

Write-Step "Validando sintaxis PowerShell"

$Tokens = $null
$ParserErrors = $null

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

    Write-Host "Errores encontrados:" -ForegroundColor Red
    @($ParserErrors) |
        Format-Table ErrorId, Message -AutoSize

    throw @"
La validación PowerShell falló.
El instalador original fue restaurado automáticamente.
Respaldo: $BackupPath
"@
}

Write-Step "Verificando la inserción"

$Verified = [System.IO.File]::ReadAllText(
    $InstallerPath,
    [System.Text.Encoding]::UTF8
)

foreach ($Required in @(
    "# SGD-116B-PREFLIGHT-SAFE-INJECTION-v2.0.2",
    "artifacts/roadmap/",
    "config/roadmap/",
    "src/sgoda/roadmap/",
    "tests/roadmap/",
    "Invoke-SGD116-MasterRoadmap.ps1"
)) {
    if (-not $Verified.Contains($Required)) {
        Copy-Item `
            -LiteralPath $BackupPath `
            -Destination $InstallerPath `
            -Force

        throw "No se confirmó el elemento requerido: $Required"
    }
}

Write-Step "Resultado final"

Write-Host "SGD-116B v2.0.2: preflight corregido de forma segura." `
    -ForegroundColor Green
Write-Host "Sintaxis PowerShell: APROBADA." `
    -ForegroundColor Green
Write-Host "Formato y finales de línea: CONSERVADOS." `
    -ForegroundColor Green
Write-Host "Archivos previos de SGD-116: PERMITIDOS." `
    -ForegroundColor Green
Write-Host "Cambios ajenos al Roadmap: BLOQUEADOS." `
    -ForegroundColor Green
Write-Host "Respaldo: $BackupPath" `
    -ForegroundColor Cyan

Write-Host ""
Write-Host "Ejecute ahora:" -ForegroundColor Yellow
Write-Host ".\Install-SGD116B-Institutional-Roadmap-Closure.ps1" `
    -ForegroundColor Yellow
