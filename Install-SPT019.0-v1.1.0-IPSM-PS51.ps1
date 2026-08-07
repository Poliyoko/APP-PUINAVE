[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipTests
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Write-AsciiFile {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.Encoding]::ASCII)
}

function Write-JsonFile {
    param([string]$Path, [object]$Data)
    $json = $Data | ConvertTo-Json -Depth 20
    Write-AsciiFile -Path $Path -Content ($json + "`r`n")
}

function Get-RelativePath {
    param([string]$BasePath, [string]$TargetPath)
    $base = [System.IO.Path]::GetFullPath($BasePath)
    if (-not $base.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $base = $base + [System.IO.Path]::DirectorySeparatorChar
    }
    $baseUri = New-Object System.Uri($base)
    $targetUri = New-Object System.Uri([System.IO.Path]::GetFullPath($TargetPath))
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('\','/')
}

function Get-ComponentCodes {
    param([string]$Text)
    $pattern = '(?<![A-Z0-9])(?:SPT|SPB|SGD|ADR|POL|ACT|ABL|PCI|SIB)-[0-9]+(?:\.[0-9]+)?(?:[A-Z])?(?![A-Z0-9])'
    $values = @()
    $matches = [regex]::Matches($Text.ToUpperInvariant(), $pattern)
    foreach ($match in $matches) {
        $values += $match.Value
    }
    return @($values | Sort-Object -Unique)
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$required = @('src','tests','docs','artifacts','releases')
foreach ($name in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $name) -PathType Container)) {
        throw "Falta la carpeta obligatoria: $name"
    }
}

$timestamp = [DateTime]::UtcNow.ToString('o')
$runId = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$docsDir = Join-Path $ProjectRoot 'docs\00_Estado_Maestro'
$artifactDir = Join-Path $ProjectRoot ("artifacts\pmo\SPT-019.0-v1.1.0\runs\" + $runId)
$releaseDir = Join-Path $ProjectRoot 'releases\SPT-019.0-v1.1.0'

New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

Write-Host 'SPT-019.0 IPSM v1.1.0' -ForegroundColor Cyan
Write-Host 'Inventariando repositorio...' -ForegroundColor Cyan

$allFiles = Get-ChildItem -LiteralPath $ProjectRoot -File -Recurse -Force | Where-Object {
    $relative = Get-RelativePath -BasePath $ProjectRoot -TargetPath $_.FullName
    $relative -notmatch '(^|/)(\.git|\.venv|venv|node_modules|__pycache__|\.pytest_cache|dist|build)(/|$)'
}

$componentMap = @{}
foreach ($file in $allFiles) {
    $relative = Get-RelativePath -BasePath $ProjectRoot -TargetPath $file.FullName
    $codes = Get-ComponentCodes -Text ($relative + ' ' + $file.BaseName)
    foreach ($code in $codes) {
        if (-not $componentMap.ContainsKey($code)) {
            $componentMap[$code] = @()
        }
        $componentMap[$code] += $relative
    }
}

$components = @()
foreach ($code in ($componentMap.Keys | Sort-Object)) {
    $sources = @($componentMap[$code] | Sort-Object -Unique)
    $components += [PSCustomObject]@{
        code = $code
        evidence_count = $sources.Count
        sources = $sources
    }
}

$testFiles = @($allFiles | Where-Object {
    $relative = Get-RelativePath -BasePath $ProjectRoot -TargetPath $_.FullName
    $_.Name -match '^test_.*\.py$' -and $relative -match '(^|/)tests/'
})

$markdownFiles = @($allFiles | Where-Object { $_.Extension -ieq '.md' })
$jsonFiles = @($allFiles | Where-Object { $_.Extension -ieq '.json' })
$releaseFiles = @($allFiles | Where-Object {
    $relative = Get-RelativePath -BasePath $ProjectRoot -TargetPath $_.FullName
    $relative -match '(^|/)releases/'
})
$evidenceFiles = @($allFiles | Where-Object {
    $relative = Get-RelativePath -BasePath $ProjectRoot -TargetPath $_.FullName
    $relative -match '(^|/)artifacts/'
})

$inventory = [ordered]@{
    component = 'SPT-019.0'
    version = '1.1.0'
    generated_at_utc = $timestamp
    repository_root = $ProjectRoot
    repository_is_source_of_truth = $true
    duplicate_store_created = $false
    n8n_installed = $false
    paid_services_required = $false
    counts = [ordered]@{
        files = @($allFiles).Count
        components = @($components).Count
        tests = $testFiles.Count
        markdown = $markdownFiles.Count
        json = $jsonFiles.Count
        release_files = $releaseFiles.Count
        evidence_files = $evidenceFiles.Count
    }
    components = $components
}

$inventoryPath = Join-Path $artifactDir 'institutional-inventory.json'
Write-JsonFile -Path $inventoryPath -Data $inventory

$criteria = @()
$criteria += [PSCustomObject]@{ code='MC-001'; name='Repositorio'; passed=(@($allFiles).Count -gt 0); weight=15 }
$criteria += [PSCustomObject]@{ code='MC-002'; name='Componentes'; passed=(@($components).Count -gt 0); weight=20 }
$criteria += [PSCustomObject]@{ code='MC-003'; name='Pruebas'; passed=($testFiles.Count -gt 0); weight=20 }
$criteria += [PSCustomObject]@{ code='MC-004'; name='Documentacion'; passed=($markdownFiles.Count -gt 0); weight=15 }
$criteria += [PSCustomObject]@{ code='MC-005'; name='Releases'; passed=($releaseFiles.Count -gt 0); weight=15 }
$criteria += [PSCustomObject]@{ code='MC-006'; name='Evidencias'; passed=($evidenceFiles.Count -gt 0); weight=15 }

$totalWeight = 0
$passedWeight = 0
foreach ($criterion in $criteria) {
    $totalWeight += [int]$criterion.weight
    if ($criterion.passed) {
        $passedWeight += [int]$criterion.weight
    }
}
$conformity = [Math]::Round(($passedWeight / $totalWeight) * 100, 2)

$findings = @()
foreach ($criterion in $criteria) {
    if (-not $criterion.passed) {
        $findings += [PSCustomObject]@{
            id = 'HA-' + ('{0:D3}' -f ($findings.Count + 1))
            priority = 'ALTO'
            category = $criterion.name
            description = 'Criterio institucional no satisfecho.'
            action = 'Revisar y restaurar las fuentes correspondientes en el repositorio.'
            status = 'ABIERTO'
        }
    }
}

$componentRows = @()
foreach ($component in $components) {
    $componentRows += ('| ' + $component.code + ' | ' + $component.evidence_count + ' |')
}
if ($componentRows.Count -eq 0) {
    $componentRows += '| - | 0 |'
}

$criterionRows = @()
foreach ($criterion in $criteria) {
    $state = 'PENDIENTE'
    if ($criterion.passed) { $state = 'CONFORME' }
    $criterionRows += ('| ' + $criterion.code + ' | ' + $criterion.name + ' | ' + $state + ' | ' + $criterion.weight + ' |')
}

$findingRows = @()
foreach ($finding in $findings) {
    $findingRows += ('| ' + $finding.id + ' | ' + $finding.priority + ' | ' + $finding.category + ' | ' + $finding.description + ' | ' + $finding.action + ' | ' + $finding.status + ' |')
}
if ($findingRows.Count -eq 0) {
    $findingRows += '| - | - | - | No se detectaron hallazgos. | - | CERRADO |'
}

$state = 'NO APROBADO'
if ($conformity -ge 90 -and $findings.Count -eq 0) {
    $state = 'CANDIDATO TECNICO A APROBACION'
}

$lines = @()
$lines += '# SGD-000 - Estado Maestro Institucional del Proyecto SGODA-PUINAVE'
$lines += ''
$lines += '## Control documental'
$lines += ''
$lines += '| Campo | Valor |'
$lines += '|---|---|'
$lines += '| Codigo | SGD-000 |'
$lines += '| Version | 1.0.0 |'
$lines += '| Generador | SPT-019.0 IPSM v1.1.0 |'
$lines += ('| Fecha UTC | ' + $timestamp + ' |')
$lines += ('| Estado | ' + $state + ' |')
$lines += '| Fuente oficial | Repositorio SGODA-PUINAVE |'
$lines += ''
$lines += '## Principios'
$lines += ''
$lines += '- El repositorio es la fuente unica de verdad.'
$lines += '- PowerShell es el mecanismo oficial de ejecucion.'
$lines += '- No se duplican datos ni logica de negocio.'
$lines += '- No se instala n8n.'
$lines += '- No se requieren servicios de pago.'
$lines += ''
$lines += '## Resumen'
$lines += ''
$lines += '| Indicador | Resultado |'
$lines += '|---|---:|'
$lines += ('| Archivos | ' + @($allFiles).Count + ' |')
$lines += ('| Componentes | ' + @($components).Count + ' |')
$lines += ('| Pruebas | ' + $testFiles.Count + ' |')
$lines += ('| Documentos Markdown | ' + $markdownFiles.Count + ' |')
$lines += ('| Archivos de release | ' + $releaseFiles.Count + ' |')
$lines += ('| Evidencias | ' + $evidenceFiles.Count + ' |')
$lines += ('| Conformidad | ' + $conformity + ' % |')
$lines += ''
$lines += '## Registro Maestro de Componentes'
$lines += ''
$lines += '| Codigo | Evidencias |'
$lines += '|---|---:|'
$lines += $componentRows
$lines += ''
$lines += '## Matriz de Conformidad'
$lines += ''
$lines += '| Codigo | Criterio | Estado | Peso |'
$lines += '|---|---|---|---:|'
$lines += $criterionRows
$lines += ''
$lines += '## Hallazgos y acciones correctivas'
$lines += ''
$lines += '| ID | Prioridad | Categoria | Hallazgo | Accion | Estado |'
$lines += '|---|---|---|---|---|---|'
$lines += $findingRows
$lines += ''
$lines += '## Estado de SPT-019'
$lines += ''
$lines += '- SPT-019.0 IPSM: implementado y sujeto a pruebas.'
$lines += '- SPT-019.1 y SPT-019.2: estados derivados de fuentes existentes.'
$lines += '- n8n: no instalado.'
$lines += '- Instalador unico final: no autorizado hasta completar validaciones.'
$lines += ''
$lines += '## Trazabilidad'
$lines += ''
$lines += ('- Inventario: `' + (Get-RelativePath -BasePath $ProjectRoot -TargetPath $inventoryPath) + '`')

$sgdPath = Join-Path $docsDir 'SGD-000-Estado-Maestro-Institucional-v1.0.0.md'
Write-AsciiFile -Path $sgdPath -Content (($lines -join "`r`n") + "`r`n")

$testResult = [ordered]@{
    requested = (-not $SkipTests.IsPresent)
    executed = $false
    passed = $null
    exit_code = $null
}

if (-not $SkipTests.IsPresent) {
    Write-Host 'Ejecutando pytest...' -ForegroundColor Cyan
    $env:PYTHONPATH = Join-Path $ProjectRoot 'src'
    $testLog = Join-Path $artifactDir 'pytest-full-suite.txt'
    $output = & python -m pytest -q 2>&1
    $exitCode = $LASTEXITCODE
    Write-AsciiFile -Path $testLog -Content (($output -join "`r`n") + "`r`n")
    $testResult.executed = $true
    $testResult.exit_code = $exitCode
    $testResult.passed = ($exitCode -eq 0)
    if ($exitCode -ne 0) {
        Write-JsonFile -Path (Join-Path $artifactDir 'test-result.json') -Data $testResult
        throw 'La suite de pruebas fallo. Revise pytest-full-suite.txt.'
    }
}

Write-JsonFile -Path (Join-Path $artifactDir 'test-result.json') -Data $testResult

$evidence = [ordered]@{
    component = 'SPT-019.0'
    version = '1.1.0'
    generated_at_utc = $timestamp
    repository_is_source_of_truth = $true
    duplicate_store_created = $false
    duplicate_business_logic = $false
    powershell_execution = $true
    n8n_installed = $false
    paid_services_required = $false
    conformity_percent = $conformity
    findings = $findings.Count
    tests = $testResult
    sgd_000 = Get-RelativePath -BasePath $ProjectRoot -TargetPath $sgdPath
}
$evidencePath = Join-Path $artifactDir 'implementation-evidence.json'
Write-JsonFile -Path $evidencePath -Data $evidence

Copy-Item -LiteralPath $sgdPath -Destination $releaseDir -Force
Copy-Item -LiteralPath $inventoryPath -Destination $releaseDir -Force
Copy-Item -LiteralPath $evidencePath -Destination $releaseDir -Force

$manifest = [ordered]@{
    component = 'SPT-019.0'
    version = '1.1.0'
    status = 'implemented_candidate'
    conformity_percent = $conformity
    findings = $findings.Count
    tests_executed = $testResult.executed
    tests_passed = $testResult.passed
    n8n_required = $false
    paid_services_required = $false
}
Write-JsonFile -Path (Join-Path $releaseDir 'manifest.json') -Data $manifest

Write-Host ''
Write-Host 'SPT-019.0 IPSM IMPLEMENTADO.' -ForegroundColor Green
Write-Host ('Conformidad: ' + $conformity + ' %') -ForegroundColor Cyan
Write-Host ('Hallazgos: ' + $findings.Count) -ForegroundColor Cyan
Write-Host ('SGD-000: ' + $sgdPath) -ForegroundColor Cyan
Write-Host ('Evidencia: ' + $evidencePath) -ForegroundColor Cyan
Write-Host 'n8n instalado: NO' -ForegroundColor Green
Write-Host 'Servicios de pago: NO' -ForegroundColor Green
