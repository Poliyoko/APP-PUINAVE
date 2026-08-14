<#
.SYNOPSIS
Repair institucional de nomenclatura:
SGD-002 Registro Maestro de Reglas -> SGD-007 Registro Maestro de Reglas.

.DESCRIPTION
Corrige atomicamente la colision documental detectada entre:
  - SGD-002 Libro Maestro Institucional (SE CONSERVA)
  - SGD-002 Registro Maestro de Reglas (SE RECIFICA A SGD-007)

Acciones:
  1. Verifica que SGD-007 este libre.
  2. Crea respaldo de todos los archivos que va a modificar.
  3. Renombra el documento de reglas a SGD-007.
  4. Actualiza SOLO referencias especificas al antiguo Registro Maestro,
     sin reemplazar referencias legitimas al Libro Maestro SGD-002.
  5. Parchea el generador SPT-021.2 para evitar que regenere SGD-002.
  6. Valida unicidad SGD-002/SGD-007.
  7. Valida sintaxis PowerShell de archivos modificados.
  8. Compila Python y ejecuta suite institucional completa.
  9. Fuerza actualizacion de SGD-002 mediante el auto-updater existente.
 10. Ejecuta PREPARE institucional mediante wrapper canonico.
No ejecuta PUBLISH, push, tag ni force.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepairId = "REPAIR-SGD007-RULE-REGISTRY"
$Version = "1.0.6"
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [AllowEmptyString()][string]$Content
    )
    $Parent = Split-Path -Parent $Path
    if ($Parent -and -not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Write-Json {
    param([string]$Path,[object]$Data)
    Write-Utf8NoBom -Path $Path -Content (
        (($Data | ConvertTo-Json -Depth 50) + "`r`n")
    )
}

function Test-PowerShellSyntax {
    param([string]$Path)
    $Tokens = $null
    $Errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $Path,[ref]$Tokens,[ref]$Errors
    )
    return @($Errors)
}

function Get-RelativePathSafe {
    param([string]$Root,[string]$Path)

    $R = [System.IO.Path]::GetFullPath($Root)
    if (-not $R.EndsWith("\")) { $R += "\" }

    $P = [System.IO.Path]::GetFullPath($Path)

    $RU = New-Object System.Uri($R)
    $PU = New-Object System.Uri($P)

    return [System.Uri]::UnescapeDataString(
        $RU.MakeRelativeUri($PU).ToString()
    ).Replace("\","/")
}

function Test-TextFile {
    param([string]$Path)

    $Ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()

    return $Ext -in @(
        ".md",".txt",".json",".yaml",".yml",
        ".ps1",".py",".toml",".csv"
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot ".git"))) {
    throw "Ejecute desde la raiz Git."
}

$StateRoot = Join-Path $ProjectRoot "docs\00_Estado_Maestro"
$OldName = "SGD-002-Registro-Maestro-Reglas-Institucionales-v1.0.0.md"
$NewName = "SGD-007-Registro-Maestro-Reglas-Institucionales-v1.0.0.md"

$OldPath = Join-Path $StateRoot $OldName
$NewPath = Join-Path $StateRoot $NewName

$MigrationState = if (
    (Test-Path -LiteralPath $OldPath -PathType Leaf) -and
    (-not (Test-Path -LiteralPath $NewPath -PathType Leaf))
) {
    "ORIGINAL"
}
elseif (
    (-not (Test-Path -LiteralPath $OldPath -PathType Leaf)) -and
    (Test-Path -LiteralPath $NewPath -PathType Leaf)
) {
    "PARTIALLY_OR_ALREADY_MIGRATED"
}
elseif (
    (Test-Path -LiteralPath $OldPath -PathType Leaf) -and
    (Test-Path -LiteralPath $NewPath -PathType Leaf)
) {
    "BOTH_PRESENT"
}
else {
    "NEITHER_PRESENT"
}

$BookPath = Join-Path $StateRoot (
    "SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
)

if (-not (Test-Path -LiteralPath $BookPath -PathType Leaf)) {
    throw "No existe el Libro Maestro SGD-002."
}

if (-not (Test-Path -LiteralPath $OldPath -PathType Leaf)) {
    if (Test-Path -LiteralPath $NewPath -PathType Leaf) {
        Write-Host "SGD-007 ya fue migrado anteriormente." -ForegroundColor Yellow
    }
    else {
        throw "No existe el Registro Maestro antiguo SGD-002."
    }
}

Write-Step "Verificando disponibilidad institucional SGD-007"

$Existing007 = @(
    Get-ChildItem `
        -LiteralPath (Join-Path $ProjectRoot "docs") `
        -Recurse `
        -File `
        -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -match "^SGD-007" -and
        $_.FullName -ne $NewPath
    }
)

if ($Existing007.Count -gt 0) {
    throw "SGD-007 ya esta ocupado por otro entregable."
}

$OldExactTokens = @(
    $OldName,
    "# SGD-002 - Registro Maestro de Reglas Institucionales",
    "SGD-002 - Registro Maestro de Reglas Institucionales",
    '"SGD-002-Registro-Maestro-Reglas-Institucionales-v1.0.0.md"',
    "'SGD-002-Registro-Maestro-Reglas-Institucionales-v1.0.0.md'"
)

$ReplacementPairs = @(
    [PSCustomObject]@{
        Old = $OldName
        New = $NewName
    }

    [PSCustomObject]@{
        Old = "# SGD-002 - Registro Maestro de Reglas Institucionales"
        New = "# SGD-007 - Registro Maestro de Reglas Institucionales"
    }

    [PSCustomObject]@{
        Old = "SGD-002 - Registro Maestro de Reglas Institucionales"
        New = "SGD-007 - Registro Maestro de Reglas Institucionales"
    }

)

$RunRoot = Join-Path $ProjectRoot (
    "artifacts\repair\SGD-007-rule-registry\runs\" + $RunId
)
$BackupRoot = Join-Path $RunRoot "backup"
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null

Write-Step "Localizando referencias especificas a corregir"

$CandidateFiles = @(
    Get-ChildItem `
        -LiteralPath $ProjectRoot `
        -Recurse `
        -File `
        -ErrorAction SilentlyContinue |
    Where-Object {
        $Rel = Get-RelativePathSafe -Root $ProjectRoot -Path $_.FullName
        (
            Test-TextFile -Path $_.FullName
        ) -and
        ($_.Length -le 20MB) -and
        ($Rel -notmatch '(^|/)\.git(/|$)') -and
        ($Rel -notmatch '(^|/)\.venv(/|$)') -and
        ($Rel -notmatch '(^|/)venv(/|$)') -and
        ($Rel -notmatch '(^|/)node_modules(/|$)') -and
        ($Rel -notmatch '/repository-backup/') -and
        ($Rel -notmatch '/registry-backup/') -and
        ($Rel -notmatch '/backup/') -and
        ($Rel -notmatch '^artifacts/repair/SGD-007-rule-registry/')
    }
)

$FilesToModify = New-Object System.Collections.ArrayList
$MatchReport = @()

foreach ($File in $CandidateFiles) {
    try {
        $Content = Get-Content -LiteralPath $File.FullName -Raw
    }
    catch {
        continue
    }

    if ($null -eq $Content) {
        $Content = ""
    }

    $Hits = @()

    foreach ($Pair in $ReplacementPairs) {
        if ($Content.Contains($Pair.Old)) {
            $Hits += $Pair.Old
        }
    }

    # El generador SPT-021.2 puede contener el nombre como clave literal
    # aunque no incluya el encabezado.
    if ($Hits.Count -gt 0) {
        [void]$FilesToModify.Add($File.FullName)

        $MatchReport += [PSCustomObject]@{
            path = Get-RelativePathSafe `
                -Root $ProjectRoot `
                -Path $File.FullName
            matches = @($Hits | Sort-Object -Unique)
        }
    }
}

$FilesToModify = @(
    $FilesToModify |
    Sort-Object -Unique
)

Write-Host "Archivos con referencias especificas: $($FilesToModify.Count)"

Write-Step "Respaldando archivos afectados"

foreach ($FilePath in $FilesToModify) {
    $Rel = Get-RelativePathSafe -Root $ProjectRoot -Path $FilePath
    $BackupPath = Join-Path $BackupRoot ($Rel.Replace("/","\"))
    $BackupParent = Split-Path -Parent $BackupPath

    if (-not (Test-Path -LiteralPath $BackupParent)) {
        New-Item -ItemType Directory -Path $BackupParent -Force | Out-Null
    }

    Copy-Item -LiteralPath $FilePath -Destination $BackupPath -Force
}

if (Test-Path -LiteralPath $OldPath -PathType Leaf) {
    $OldRel = Get-RelativePathSafe -Root $ProjectRoot -Path $OldPath
    $OldBackup = Join-Path $BackupRoot ($OldRel.Replace("/","\"))
    $OldBackupParent = Split-Path -Parent $OldBackup

    if (-not (Test-Path -LiteralPath $OldBackupParent)) {
        New-Item -ItemType Directory -Path $OldBackupParent -Force | Out-Null
    }

    Copy-Item -LiteralPath $OldPath -Destination $OldBackup -Force
}

Write-Step "Aplicando recodificacion SGD-002 -> SGD-007"

$Changed = @()

foreach ($FilePath in $FilesToModify) {
    $Content = Get-Content -LiteralPath $FilePath -Raw

    if ($null -eq $Content) {
        $Content = ""
    }

    $NewContent = $Content

    foreach ($Pair in $ReplacementPairs) {
        $NewContent = $NewContent.Replace(
            [string]$Pair.Old,
            [string]$Pair.New
        )
    }

    if ($NewContent -ne $Content) {
        Write-Utf8NoBom -Path $FilePath -Content $NewContent
        $Changed += $FilePath
    }
}

if (Test-Path -LiteralPath $OldPath -PathType Leaf) {
    if (Test-Path -LiteralPath $NewPath -PathType Leaf) {
        $OldText = Get-Content -LiteralPath $OldPath -Raw
        $NewText = Get-Content -LiteralPath $NewPath -Raw

        if ($null -eq $OldText) { $OldText = "" }
        if ($null -eq $NewText) { $NewText = "" }

        if ($OldText -ne $NewText) {
            throw (
                "Existen simultaneamente SGD-002-reglas y SGD-007-reglas " +
                "con contenido diferente. Se bloquea para evitar perdida."
            )
        }

        Remove-Item -LiteralPath $OldPath -Force
    }
    else {
        Move-Item -LiteralPath $OldPath -Destination $NewPath
    }
}

# Asegurar encabezado correcto en el nuevo documento.
if (-not (Test-Path -LiteralPath $NewPath -PathType Leaf)) {
    throw "No se pudo crear SGD-007."
}

$NewDocumentText = Get-Content -LiteralPath $NewPath -Raw

if ($null -eq $NewDocumentText) {
    $NewDocumentText = ""
}
$NewDocumentText = $NewDocumentText.Replace(
    "# SGD-002 - Registro Maestro de Reglas Institucionales",
    "# SGD-007 - Registro Maestro de Reglas Institucionales"
)
$NewDocumentText = $NewDocumentText.Replace(
    "SGD-002 - Registro Maestro de Reglas Institucionales",
    "SGD-007 - Registro Maestro de Reglas Institucionales"
)
Write-Utf8NoBom -Path $NewPath -Content $NewDocumentText

Write-Step "Validando ausencia de la colision antigua"

$RemainingOldReferences = @()

foreach ($File in $CandidateFiles) {
    if (-not (Test-Path -LiteralPath $File.FullName -PathType Leaf)) {
        continue
    }

    try {
        $Content = Get-Content -LiteralPath $File.FullName -Raw
    }
    catch {
        continue
    }

    if ($null -eq $Content) {
        $Content = ""
    }

    foreach ($Token in $OldExactTokens) {
        if ($Content.Contains($Token)) {
            $RemainingOldReferences += [PSCustomObject]@{
                path = Get-RelativePathSafe `
                    -Root $ProjectRoot `
                    -Path $File.FullName
                token = $Token
            }
        }
    }
}

$RemainingOldReferences = @(
    $RemainingOldReferences |
    Where-Object {
        $_.path -notmatch '^artifacts/repair/SGD-007-rule-registry/'
    }
)

$SGD002Files = @(
    Get-ChildItem -LiteralPath $StateRoot -File |
    Where-Object { $_.Name -like "SGD-002*" }
)

$SGD007Files = @(
    Get-ChildItem -LiteralPath $StateRoot -File |
    Where-Object { $_.Name -like "SGD-007*" }
)

$SemanticErrors = 0

if ($SGD002Files.Count -ne 1) { $SemanticErrors++ }
if ($SGD002Files[0].Name -ne (
    "SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
)) {
    $SemanticErrors++
}
if ($SGD007Files.Count -ne 1) { $SemanticErrors++ }
if ($SGD007Files[0].Name -ne $NewName) { $SemanticErrors++ }
if ($RemainingOldReferences.Count -ne 0) {
    $SemanticErrors += $RemainingOldReferences.Count
}

Write-Host "SGD-002 files: $($SGD002Files.Count)"
Write-Host "SGD-007 files: $($SGD007Files.Count)"
Write-Host "Old specific references remaining: $($RemainingOldReferences.Count)"
Write-Host "Semantic errors: $SemanticErrors"

if ($SemanticErrors -ne 0) {
    Write-Json `
        -Path (Join-Path $RunRoot "remaining-old-references.json") `
        -Data $RemainingOldReferences

    throw "La recodificacion documental no supero el gate semantico."
}

Write-Step "Validando sintaxis PowerShell modificada"

$PowerShellErrors = @()

$ModifiedPowerShell = @(
    $Changed |
    Where-Object {
        [System.IO.Path]::GetExtension($_).ToLowerInvariant() -eq ".ps1"
    } |
    Sort-Object -Unique
)

foreach ($Ps1 in $ModifiedPowerShell) {
    $Errors = @(Test-PowerShellSyntax -Path $Ps1)

    foreach ($ErrorItem in $Errors) {
        $PowerShellErrors += [PSCustomObject]@{
            path = Get-RelativePathSafe -Root $ProjectRoot -Path $Ps1
            message = [string]$ErrorItem.Message
        }
    }
}

Write-Host "PowerShell files modified: $($ModifiedPowerShell.Count)"
Write-Host "PowerShell syntax errors: $($PowerShellErrors.Count)"

if ($PowerShellErrors.Count -ne 0) {
    Write-Json `
        -Path (Join-Path $RunRoot "powershell-syntax-errors.json") `
        -Data $PowerShellErrors

    throw "Errores de sintaxis PowerShell tras la recodificacion."
}

Write-Step "Compilando Python"

$CompileOutput = @(
    & python -m compileall -q src tests 2>&1
)
$CompileExitCode = $LASTEXITCODE

$CompileOutput | Set-Content `
    -LiteralPath (Join-Path $RunRoot "python-compileall.txt") `
    -Encoding UTF8

if ($CompileExitCode -ne 0) {
    throw "Python compileall fallo."
}

Write-Step "Ejecutando suite institucional completa"

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$PytestOutput = @(
    & python -m pytest -q 2>&1
)

$PytestExitCode = $LASTEXITCODE
$PytestText = $PytestOutput -join "`r`n"

$PytestOutput | ForEach-Object { Write-Host $_ }

Write-Utf8NoBom `
    -Path (Join-Path $RunRoot "pytest-full-suite.txt") `
    -Content ($PytestText + "`r`n")

$TestsPassed = 0
$Match = [regex]::Match($PytestText,"(\d+)\s+passed")
if ($Match.Success) {
    $TestsPassed = [int]$Match.Groups[1].Value
}

if ($PytestExitCode -ne 0 -or $TestsPassed -lt 808) {
    throw "Suite institucional no aprobada."
}

Write-Step "Forzando actualizacion del Libro Maestro"

$AutoUpdater = Join-Path $ProjectRoot (
    "tools\institutional\Invoke-SGD002-AutoUpdate.ps1"
)

if (-not (Test-Path -LiteralPath $AutoUpdater -PathType Leaf)) {
    throw "No existe el auto-updater SGD-002."
}

$PowerShellExe = Join-Path $env:SystemRoot (
    "System32\WindowsPowerShell\v1.0\powershell.exe"
)

$UpdaterPsi = New-Object System.Diagnostics.ProcessStartInfo
$UpdaterPsi.FileName = $PowerShellExe
$UpdaterPsi.WorkingDirectory = $ProjectRoot
$UpdaterPsi.UseShellExecute = $false
$UpdaterPsi.RedirectStandardOutput = $true
$UpdaterPsi.RedirectStandardError = $true
$UpdaterPsi.CreateNoWindow = $true
$UpdaterPsi.Arguments = (
    '-NoProfile -ExecutionPolicy Bypass -File "' +
    $AutoUpdater +
    '" -ProjectRoot "' +
    $ProjectRoot +
    '" -ForceUpdate'
)

$UpdaterProcess = New-Object System.Diagnostics.Process
$UpdaterProcess.StartInfo = $UpdaterPsi
[void]$UpdaterProcess.Start()

$UpdaterOut = $UpdaterProcess.StandardOutput.ReadToEnd()
$UpdaterErr = $UpdaterProcess.StandardError.ReadToEnd()
$UpdaterProcess.WaitForExit()

if (-not [string]::IsNullOrWhiteSpace($UpdaterOut)) {
    $UpdaterOut.TrimEnd() -split "\r?\n" |
        ForEach-Object { Write-Host $_ }
}

if (-not [string]::IsNullOrWhiteSpace($UpdaterErr)) {
    $UpdaterErr.TrimEnd() -split "\r?\n" |
        ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
}

if ($UpdaterProcess.ExitCode -ne 0) {
    throw "Auto-actualizacion del Libro Maestro fallo."
}

Write-Step "Ejecutando PREPARE institucional"

$Wrapper = Join-Path $ProjectRoot (
    "tools\institutional\Publish-SGODA-WithMasterBook.ps1"
)

if (-not (Test-Path -LiteralPath $Wrapper -PathType Leaf)) {
    throw "No existe wrapper institucional de publicacion."
}

$PreparePsi = New-Object System.Diagnostics.ProcessStartInfo
$PreparePsi.FileName = $PowerShellExe
$PreparePsi.WorkingDirectory = $ProjectRoot
$PreparePsi.UseShellExecute = $false
$PreparePsi.RedirectStandardOutput = $true
$PreparePsi.RedirectStandardError = $true
$PreparePsi.CreateNoWindow = $true
$PreparePsi.Arguments = (
    '-NoProfile -ExecutionPolicy Bypass -File "' +
    $Wrapper +
    '" -PrepareOnly'
)

$PrepareProcess = New-Object System.Diagnostics.Process
$PrepareProcess.StartInfo = $PreparePsi
[void]$PrepareProcess.Start()

$PrepareOut = $PrepareProcess.StandardOutput.ReadToEnd()
$PrepareErr = $PrepareProcess.StandardError.ReadToEnd()
$PrepareProcess.WaitForExit()

Write-Utf8NoBom `
    -Path (Join-Path $RunRoot "prepare-output.txt") `
    -Content (
        $PrepareOut +
        "`r`n" +
        $PrepareErr
    )

if (-not [string]::IsNullOrWhiteSpace($PrepareOut)) {
    $PrepareOut.TrimEnd() -split "\r?\n" |
        ForEach-Object { Write-Host $_ }
}

if (-not [string]::IsNullOrWhiteSpace($PrepareErr)) {
    $PrepareErr.TrimEnd() -split "\r?\n" |
        ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
}

if ($PrepareProcess.ExitCode -ne 0) {
    throw "PREPARE institucional fallo."
}

$PrepareReady = $PrepareOut.Contains(
    "Repository status: READY_FOR_PUBLICATION"
)

$PrepareTechnicalZero = $PrepareOut.Contains(
    "Technical errors: 0"
)

if (-not $PrepareReady -or -not $PrepareTechnicalZero) {
    throw "PREPARE no alcanzo READY_FOR_PUBLICATION con cero errores."
}

Write-Step "Generando evidencia de reparacion"

$ReportPath = Join-Path $RunRoot "repair-report.json"

Write-Json -Path $ReportPath -Data ([ordered]@{
    repair_id = $RepairId
    migration_state_at_start = $MigrationState
    version = $Version
    migrated_from = "SGD-002 Registro Maestro de Reglas Institucionales"
    migrated_to = "SGD-007 Registro Maestro de Reglas Institucionales"
    sgd_002_reserved_for_master_book = $true
    sgd_002_files = @($SGD002Files | ForEach-Object { $_.Name })
    sgd_007_files = @($SGD007Files | ForEach-Object { $_.Name })
    files_with_specific_references_found = $FilesToModify.Count
    files_changed = $Changed.Count
    remaining_old_specific_references = $RemainingOldReferences.Count
    powershell_syntax_errors = $PowerShellErrors.Count
    python_compile_exit_code = $CompileExitCode
    tests_passed = $TestsPassed
    semantic_errors = $SemanticErrors
    master_book_auto_update_exit_code = $UpdaterProcess.ExitCode
    prepare_exit_code = $PrepareProcess.ExitCode
    repository_ready_for_publication = $PrepareReady
    technical_errors = 0
    publish_executed = $false
    status = "READY_FOR_PUBLICATION"
})

Write-Json `
    -Path (Join-Path $RunRoot "reference-match-report.json") `
    -Data $MatchReport

Write-Step "Resultado final"

Write-Host "Migration state at start: $MigrationState"
Write-Host "SGD-002 canonical role: MASTER BOOK"
Write-Host "SGD-007 canonical role: INSTITUTIONAL RULE REGISTRY"
Write-Host "Files changed: $($Changed.Count)"
Write-Host "Old specific references remaining: 0"
Write-Host "PowerShell syntax errors: 0"
Write-Host "Python compile exit code: 0"
Write-Host "Tests passed: $TestsPassed"
Write-Host "Semantic errors: 0"
Write-Host "Master Book auto-update: PASSED"
Write-Host "PREPARE exit code: $($PrepareProcess.ExitCode)"
Write-Host "Repository status: READY_FOR_PUBLICATION"
Write-Host "Technical errors: 0"
Write-Host "Publish executed: NO"
Write-Host "Report: $ReportPath" -ForegroundColor Cyan
Write-Host "SGD-007 NOMENCLATURE RECONCILIATION: COMPLETED." `
    -ForegroundColor Green
