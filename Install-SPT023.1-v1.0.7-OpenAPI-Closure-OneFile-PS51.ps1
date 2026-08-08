<#
.SYNOPSIS
SPT-023.1 v1.0.7 - Correccion definitiva de integracion FastAPI y cierre tecnico.
Windows PowerShell 5.1 / ASCII.

.DESCRIPTION
NO reconstruye el detector ni el router.
Corrige exclusivamente la ubicacion de:
    application.include_router(spt0231_router)
en src\sgoda\kernel\application.py.

La inclusion debe quedar dentro de la fabrica FastAPI y antes de:
    return application

Luego:
- valida estructura;
- compila Python;
- valida router real (2 rutas);
- ejecuta pruebas SPT-023.1;
- ejecuta suite institucional;
- confirma SGD-002;
- ejecuta PREPARE;
- no ejecuta PUBLISH.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-023.1"
$Version = "1.0.7"
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")

function Step([string]$Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Utf8NoBom(
    [string]$Path,
    [AllowEmptyString()][string]$Content
) {
    $Parent = Split-Path -Parent $Path

    if (
        $Parent -and
        -not (Test-Path -LiteralPath $Parent)
    ) {
        New-Item -ItemType Directory -Path $Parent -Force |
            Out-Null
    }

    [IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object Text.UTF8Encoding($false))
    )
}

function Write-Json(
    [string]$Path,
    [object]$Data
) {
    Write-Utf8NoBom `
        -Path $Path `
        -Content (
            ($Data | ConvertTo-Json -Depth 60) +
            "`r`n"
        )
}

function Root() {
    $Output = @(
        & git rev-parse --show-toplevel 2>$null
    )

    if (
        $LASTEXITCODE -ne 0 -or
        $Output.Count -eq 0
    ) {
        throw "Ejecute desde SGODA-PUINAVE."
    }

    return [IO.Path]::GetFullPath(
        ([string]$Output[0]).Trim()
    )
}

$ProjectRoot = Root
Set-Location -LiteralPath $ProjectRoot

$SrcRoot = Join-Path $ProjectRoot "src"

$ApplicationPath = Join-Path `
    $SrcRoot `
    "sgoda\kernel\application.py"

$RouterPath = Join-Path `
    $SrcRoot `
    "sgoda\api\spt0231_routes.py"

$DetectorRoot = Join-Path `
    $SrcRoot `
    "sgoda\integration\spt0231"

$SpecificTest = Join-Path `
    $ProjectRoot `
    "tests\integration\test_spt0231_detector.py"

$Updater = Join-Path `
    $ProjectRoot `
    "tools\institutional\Invoke-SGD002-AutoUpdate.ps1"

$Publisher = Join-Path `
    $ProjectRoot `
    "tools\institutional\Publish-SGODA-WithMasterBook.ps1"

$DocsRoot = Join-Path `
    $ProjectRoot `
    "docs\06_Tecnologia\SPT-023.1"

$RunRoot = Join-Path `
    $ProjectRoot `
    ("artifacts\development\SPT-023.1-v1.0.7\runs\" + $RunId)

$ActPath = Join-Path `
    $DocsRoot `
    "ACT-023.1-Cierre-Tecnico-Integracion.md"

New-Item `
    -ItemType Directory `
    -Path $RunRoot `
    -Force |
    Out-Null

Step "Verificando implementacion existente"

$Required = @(
    $ApplicationPath,
    $RouterPath,
    $DetectorRoot,
    $SpecificTest,
    $Updater,
    $Publisher
)

$Missing = @(
    $Required |
    Where-Object {
        -not (Test-Path -LiteralPath $_)
    }
)

if ($Missing.Count -gt 0) {
    throw (
        "Faltan componentes requeridos: " +
        ($Missing -join ", ")
    )
}

Write-Host "Detector existing: YES"
Write-Host "Detector rebuild: NO"
Write-Host "Router existing: YES"

Step "Confirmando router real SPT-023.1"

$env:PYTHONPATH = $SrcRoot

$RouterProbe = Join-Path `
    $RunRoot `
    "probe_router.py"

$RouterProbeContent = @'
import json
from sgoda.api.spt0231_routes import router

routes = [
    {
        "path": getattr(route, "path", ""),
        "methods": sorted(getattr(route, "methods", set()) or set()),
    }
    for route in router.routes
]

print(json.dumps({
    "prefix": router.prefix,
    "count": len(routes),
    "routes": routes,
}, ensure_ascii=False))
'@

Write-Utf8NoBom `
    -Path $RouterProbe `
    -Content $RouterProbeContent

$RouterRaw = @(
    & python $RouterProbe 2>&1
)

$RouterExit = $LASTEXITCODE

if ($RouterExit -ne 0) {
    $RouterRaw |
        ForEach-Object { Write-Host $_ }

    throw "No fue posible inspeccionar el router SPT-023.1."
}

$RouterPayload = (
    ($RouterRaw -join "`n") |
    ConvertFrom-Json
)

$RouterRoutes = @($RouterPayload.routes)

if ($RouterRoutes.Count -ne 2) {
    throw (
        "Se esperaban 2 rutas SPT-023.1. Detectadas: " +
        $RouterRoutes.Count
    )
}

$RoutePaths = @(
    $RouterRoutes |
    ForEach-Object { [string]$_.path }
)

if ($RoutePaths -notcontains "/api/spt0231/health") {
    throw "El router no contiene /api/spt0231/health."
}

if ($RoutePaths -notcontains "/api/spt0231/detect") {
    throw "El router no contiene /api/spt0231/detect."
}

Write-Host "Router prefix: $($RouterPayload.prefix)"
Write-Host "Router route count: $($RouterRoutes.Count)"
Write-Host "Router /api/spt0231/health: CONFIRMED"
Write-Host "Router /api/spt0231/detect: CONFIRMED"

Step "Corrigiendo ubicacion de include_router en FastAPI canonico"

$ApplicationText = Get-Content `
    -LiteralPath $ApplicationPath `
    -Raw

$ImportLine = (
    "from sgoda.api.spt0231_routes import " +
    "router as spt0231_router"
)

if ($ApplicationText -notmatch "spt0231_routes") {
    throw "El import spt0231_routes no existe en application.py."
}

$BackupPath = Join-Path `
    $RunRoot `
    "application.py.before-spt0231-integration-fix"

Copy-Item `
    -LiteralPath $ApplicationPath `
    -Destination $BackupPath `
    -Force

# Remove every exact include line first, regardless of its previous position.
$Lines = @(
    $ApplicationText -split "`r?`n"
)

$CleanLines = @()

foreach ($Line in $Lines) {
    if (
        $Line.Trim() -eq
        "application.include_router(spt0231_router)"
    ) {
        continue
    }

    $CleanLines += $Line
}

# Find the first return application. This is the return from the FastAPI
# factory confirmed in the repository diagnostics.
$ReturnIndex = -1

for ($Index = 0; $Index -lt $CleanLines.Count; $Index++) {
    if (
        $CleanLines[$Index] -match
        '^(\s+)return\s+application\s*$'
    ) {
        $ReturnIndex = $Index
        break
    }
}

if ($ReturnIndex -lt 0) {
    throw "No se encontro 'return application' dentro de la fabrica."
}

$ReturnLine = [string]$CleanLines[$ReturnIndex]

$IndentMatch = [regex]::Match(
    $ReturnLine,
    '^(\s+)'
)

if (-not $IndentMatch.Success) {
    throw "return application no esta indentado dentro de una funcion."
}

$Indent = $IndentMatch.Groups[1].Value

$IncludeLine = (
    $Indent +
    "application.include_router(spt0231_router)"
)

$Before = @()

if ($ReturnIndex -gt 0) {
    $Before = @(
        $CleanLines[0..($ReturnIndex - 1)]
    )
}

$After = @(
    $CleanLines[$ReturnIndex..($CleanLines.Count - 1)]
)

$FixedLines = @(
    $Before +
    $IncludeLine +
    $After
)

$FixedText = (
    $FixedLines -join "`r`n"
).TrimEnd() + "`r`n"

Write-Utf8NoBom `
    -Path $ApplicationPath `
    -Content $FixedText

Write-Host "Misplaced include_router removed: YES"
Write-Host "Canonical include_router inserted before return: YES"

Step "Validando estructura canonica application.py"

$AfterText = Get-Content `
    -LiteralPath $ApplicationPath `
    -Raw

$IncludeOccurrences = @(
    [regex]::Matches(
        $AfterText,
        '(?m)^\s*application\.include_router\(spt0231_router\)\s*$'
    )
).Count

if ($IncludeOccurrences -ne 1) {
    throw (
        "Se esperaba exactamente 1 include_router SPT-023.1. " +
        "Detectados: " +
        $IncludeOccurrences
    )
}

$LinesAfter = @(
    $AfterText -split "`r?`n"
)

$IncludeIndex = -1
$ReturnIndexAfter = -1

for ($Index = 0; $Index -lt $LinesAfter.Count; $Index++) {
    if (
        $LinesAfter[$Index].Trim() -eq
        "application.include_router(spt0231_router)"
    ) {
        $IncludeIndex = $Index
    }

    if (
        $LinesAfter[$Index] -match
        '^(\s+)return\s+application\s*$'
    ) {
        $ReturnIndexAfter = $Index
        break
    }
}

if ($IncludeIndex -lt 0) {
    throw "include_router SPT-023.1 no fue encontrado."
}

if ($ReturnIndexAfter -lt 0) {
    throw "return application no fue encontrado."
}

if ($IncludeIndex -ge $ReturnIndexAfter) {
    throw "include_router SPT-023.1 sigue despues de return application."
}

$IncludeIndent = [regex]::Match(
    [string]$LinesAfter[$IncludeIndex],
    '^(\s+)'
).Groups[1].Value

$ReturnIndent = [regex]::Match(
    [string]$LinesAfter[$ReturnIndexAfter],
    '^(\s+)'
).Groups[1].Value

if ($IncludeIndent -ne $ReturnIndent) {
    throw (
        "include_router y return application no tienen " +
        "la misma indentacion de fabrica."
    )
}

Write-Host "SPT-023.1 include occurrences: 1"
Write-Host "Include before return: CONFIRMED"
Write-Host "Factory indentation: CONFIRMED"

Step "Compilando integracion FastAPI"

& python -m py_compile `
    $ApplicationPath `
    $RouterPath

if ($LASTEXITCODE -ne 0) {
    throw "py_compile FastAPI fallo."
}

Write-Host "FastAPI py_compile exit code: 0"

Step "Validando integracion FastAPI mediante OpenAPI"

# FastAPI 0.140.x may represent included routers internally as
# fastapi.routing._IncludedRouter entries with path=None in application.routes.
# Therefore application.routes / route.path is NOT a reliable integration gate.
# The generated OpenAPI schema is used as the functional source of truth.

$OpenApiProbe = Join-Path `
    $RunRoot `
    "probe_application_openapi.py"

$OpenApiProbeContent = @'
import json
import fastapi
import starlette

from sgoda.kernel.application import create_application

app = create_application()
schema = app.openapi()
paths = schema.get("paths", {})

required = {
    "/api/spt0231/health": {"get"},
    "/api/spt0231/detect": {"post"},
}

missing = []
wrong_methods = []

for path, expected_methods in required.items():
    if path not in paths:
        missing.append(path)
        continue

    actual_methods = {
        str(method).lower()
        for method in paths[path].keys()
    }

    if not expected_methods.issubset(actual_methods):
        wrong_methods.append({
            "path": path,
            "expected": sorted(expected_methods),
            "actual": sorted(actual_methods),
        })

payload = {
    "status": (
        "CONFIRMED"
        if not missing and not wrong_methods
        else "FAILED"
    ),
    "fastapi_version": fastapi.__version__,
    "starlette_version": starlette.__version__,
    "required_paths": sorted(required.keys()),
    "openapi_paths": sorted(paths.keys()),
    "missing": missing,
    "wrong_methods": wrong_methods,
}

print(json.dumps(payload, ensure_ascii=False, sort_keys=True))

if missing or wrong_methods:
    raise SystemExit(2)
'@

Write-Utf8NoBom `
    -Path $OpenApiProbe `
    -Content $OpenApiProbeContent

$OpenApiOutput = @(
    & python $OpenApiProbe 2>&1
)

$OpenApiExit = $LASTEXITCODE
$OpenApiText = $OpenApiOutput -join "`n"

$OpenApiOutput |
    ForEach-Object { Write-Host $_ }

if ($OpenApiExit -ne 0) {
    throw "La validacion OpenAPI de SPT-023.1 fallo."
}

try {
    $OpenApiPayload = $OpenApiText.Trim() |
        ConvertFrom-Json
}
catch {
    throw "La salida OpenAPI no fue JSON valido."
}

if ([string]$OpenApiPayload.status -ne "CONFIRMED") {
    throw "OpenAPI no confirmo las rutas SPT-023.1."
}

$OpenApiPaths = @($OpenApiPayload.openapi_paths)

if ($OpenApiPaths -notcontains "/api/spt0231/health") {
    throw "OpenAPI no contiene /api/spt0231/health."
}

if ($OpenApiPaths -notcontains "/api/spt0231/detect") {
    throw "OpenAPI no contiene /api/spt0231/detect."
}

Write-Host (
    "FastAPI version detected: " +
    [string]$OpenApiPayload.fastapi_version
)

Write-Host (
    "Starlette version detected: " +
    [string]$OpenApiPayload.starlette_version
)

Write-Host "OpenAPI /api/spt0231/health GET: CONFIRMED"
Write-Host "OpenAPI /api/spt0231/detect POST: CONFIRMED"
Write-Host "FastAPI OpenAPI integration gate: PASSED"
Write-Host "application.routes path-based gate: DISABLED"

Step "Ejecutando pruebas SPT-023.1 existentes"

$SpecificOutput = @(
    & python -m pytest `
        -q `
        $SpecificTest `
        2>&1
)

$SpecificExit = $LASTEXITCODE
$SpecificText = $SpecificOutput -join "`n"

$SpecificOutput |
    ForEach-Object { Write-Host $_ }

if ($SpecificExit -ne 0) {
    throw "Pruebas SPT-023.1 fallaron."
}

$SpecificMatch = [regex]::Match(
    $SpecificText,
    '(\d+)\s+passed'
)

$SpecificPassed = if ($SpecificMatch.Success) {
    [int]$SpecificMatch.Groups[1].Value
}
else {
    0
}

if ($SpecificPassed -lt 10) {
    throw (
        "Se esperaban al menos 10 pruebas SPT-023.1. " +
        "Detectadas: " +
        $SpecificPassed
    )
}

Step "Ejecutando suite institucional completa"

$FullOutput = @(
    & python -m pytest -q 2>&1
)

$FullExit = $LASTEXITCODE
$FullText = $FullOutput -join "`n"

$FullOutput |
    ForEach-Object { Write-Host $_ }

if ($FullExit -ne 0) {
    throw "Suite institucional fallo."
}

$FullMatch = [regex]::Match(
    $FullText,
    '(\d+)\s+passed'
)

$TestsPassed = if ($FullMatch.Success) {
    [int]$FullMatch.Groups[1].Value
}
else {
    0
}

if ($TestsPassed -lt 828) {
    throw (
        "Linea base institucional >=828. Detectadas: " +
        $TestsPassed
    )
}

Step "Confirmando actualizacion SGD-002"

$TaskName = "SGODA-PUINAVE-SGD002-AutoUpdate"

$ScheduledTask = Get-ScheduledTask `
    -TaskName $TaskName `
    -ErrorAction SilentlyContinue

$TaskExists = ($null -ne $ScheduledTask)
$TaskInitialState = ""

if ($TaskExists) {
    $TaskInitialState = [string]$ScheduledTask.State
}

$MasterBookStatus = "NOT_CONFIRMED"
$TaskFinalPolicy = "NOT_AVAILABLE"

try {
    if ($TaskExists) {
        Disable-ScheduledTask `
            -TaskName $TaskName `
            -ErrorAction SilentlyContinue |
            Out-Null

        Stop-ScheduledTask `
            -TaskName $TaskName `
            -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 2
    }

    $UpdaterProcesses = @(
        Get-CimInstance Win32_Process `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -match
            "Invoke-SGD002-AutoUpdate"
        }
    )

    if ($UpdaterProcesses.Count -gt 0) {
        foreach ($Process in $UpdaterProcesses) {
            Stop-Process `
                -Id $Process.ProcessId `
                -Force `
                -ErrorAction SilentlyContinue
        }

        Start-Sleep -Seconds 2
    }

    $LockPath = Join-Path `
        $ProjectRoot `
        "artifacts\runtime\sgd002-auto\update.lock"

    $Remaining = @(
        Get-CimInstance Win32_Process `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -match
            "Invoke-SGD002-AutoUpdate"
        }
    )

    if (
        (Test-Path -LiteralPath $LockPath) -and
        $Remaining.Count -eq 0
    ) {
        Remove-Item `
            -LiteralPath $LockPath `
            -Force `
            -ErrorAction Stop

        Write-Host "Stale SGD-002 lock removed: YES"
    }

    $UpdaterOutput = @(
        & powershell.exe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $Updater `
            -ProjectRoot $ProjectRoot `
            -ForceUpdate `
            2>&1
    )

    $UpdaterExit = $LASTEXITCODE
    $UpdaterText = $UpdaterOutput -join "`n"

    $UpdaterOutput |
        ForEach-Object { Write-Host $_ }

    if ($UpdaterExit -ne 0) {
        throw "Actualizacion SGD-002 fallo."
    }

    if ($UpdaterText -match "SGD-002 AUTO-UPDATED") {
        $MasterBookStatus = "UPDATED"
    }
    elseif (
        $UpdaterText -match
        "repository fingerprint unchanged"
    ) {
        $MasterBookStatus = "UNCHANGED_ALREADY_CURRENT"
    }
    else {
        throw "SGD-002 no confirmo estado final valido."
    }
}
finally {
    if ($TaskExists) {
        Enable-ScheduledTask `
            -TaskName $TaskName `
            -ErrorAction SilentlyContinue |
            Out-Null

        $TaskFinalPolicy = "ENABLED"
    }
}

Write-Host "Master Book status: $MasterBookStatus"
Write-Host "SGD-002 scheduled task final policy: $TaskFinalPolicy"

Step "Ejecutando PREPARE institucional"

$PrepareOutput = @(
    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $Publisher `
        -PrepareOnly `
        2>&1
)

$PrepareExit = $LASTEXITCODE
$PrepareText = $PrepareOutput -join "`n"

$PrepareOutput |
    ForEach-Object { Write-Host $_ }

if ($PrepareExit -ne 0) {
    throw "PREPARE institucional fallo."
}

if (
    $PrepareText -notmatch "READY_FOR_PUBLICATION" -and
    $PrepareText -notmatch
    "Institutional status:\s*PREPARED"
) {
    throw "PREPARE no confirmo READY_FOR_PUBLICATION."
}

$PrepareStatus = "READY_FOR_PUBLICATION"

Step "Generando evidencia y acta"

$EvidencePath = Join-Path `
    $RunRoot `
    "implementation-evidence.json"

$Evidence = [ordered]@{
    component = $Component
    version = $Version
    detector_rebuilt = $false
    router_rebuilt = $false
    fastapi_application = "src/sgoda/kernel/application.py"
    router_prefix = [string]$RouterPayload.prefix
    router_routes = $RoutePaths
    router_prefix_validation = "FULL_PATHS_CONFIRMED"
    router_path_gate_fix = $true
    misplaced_include_removed = $true
    include_inserted_before_return = $true
    factory_indentation_confirmed = $true
    canonical_health_route = $true
    canonical_detect_route = $true
    fastapi_version = [string]$OpenApiPayload.fastapi_version
    starlette_version = [string]$OpenApiPayload.starlette_version
    integration_validation = "OPENAPI_SCHEMA"
    application_routes_path_gate = "DISABLED_FOR_FASTAPI_0_140_X"
    specific_tests_passed = $SpecificPassed
    institutional_tests_passed = $TestsPassed
    master_book_status = $MasterBookStatus
    sgd002_task_initial_state = $TaskInitialState
    sgd002_task_final_policy = $TaskFinalPolicy
    prepare_status = $PrepareStatus
    publication_executed = $false
    paid_services = $false
    technical_errors = 0
    institutional_status = "PREPARED"
}

Write-Json `
    -Path $EvidencePath `
    -Data $Evidence

$Act = @"
# ACT-023.1 - Cierre Tecnico de Integracion

Component: SPT-023.1
Version: 1.0.7

## Correccion
El router SPT-023.1 no fue reconstruido.
El detector no fue reconstruido.

Se corrigio exclusivamente la ubicacion de:
application.include_router(spt0231_router)

La inclusion quedo dentro de la fabrica FastAPI y antes de:
return application

## Rutas confirmadas por OpenAPI
- GET /api/spt0231/health
- POST /api/spt0231/detect

La validacion no usa application.routes/route.path debido a la representacion interna _IncludedRouter de FastAPI 0.140.x.

## Validacion
SPT-023.1 tests: $SpecificPassed
Institutional tests: $TestsPassed
Master Book: $MasterBookStatus
PREPARE: $PrepareStatus
Technical errors: 0

## Estado
READY_FOR_PUBLICATION

La publicacion no fue ejecutada automaticamente.
"@

Write-Utf8NoBom `
    -Path $ActPath `
    -Content $Act

Step "Resultado final"

Write-Host "Component: $Component"
Write-Host "Version: $Version"
Write-Host "Detector rebuilt: NO"
Write-Host "Router rebuilt: NO"
Write-Host "Router full-path validation: ENABLED"
Write-Host "FastAPI canonical file: $ApplicationPath"
Write-Host "Misplaced include_router removed: YES"
Write-Host "Include before return: CONFIRMED"
Write-Host "Canonical /api/spt0231/health: CONFIRMED BY OPENAPI"
Write-Host "Canonical /api/spt0231/detect: CONFIRMED BY OPENAPI"
Write-Host "Integration validation mechanism: OPENAPI_SCHEMA"
Write-Host "SPT-023.1 tests passed: $SpecificPassed"
Write-Host "Institutional tests passed: $TestsPassed"
Write-Host "Master Book status: $MasterBookStatus"
Write-Host "Prepare status: $PrepareStatus"
Write-Host "Publication executed: NO"
Write-Host "Paid services: NO"
Write-Host "Technical errors: 0"
Write-Host "Evidence: $EvidencePath"
Write-Host "Act: $ActPath"
Write-Host ""
Write-Host "SPT-023.1 v1.0.7: OPENAPI INTEGRATION VALIDATED."
Write-Host "SPT-023.1: READY FOR OFFICIAL PUBLICATION."
