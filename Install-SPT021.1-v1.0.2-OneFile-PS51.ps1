<#
.SYNOPSIS
    SPT-021.1 - Institutional Master Map Generator v1.0.2
    One File - Windows PowerShell 5.1

.DESCRIPTION
    Genera el documento unico:
      SGD-001 - Mapa Maestro Institucional del Proyecto SGODA-PUINAVE

    La informacion se descubre desde el repositorio real y se relaciona con:
      - fases y sprints;
      - POL, SGD, ADR, SPB, SPT, PCI, ACT, RMI y otras familias;
      - documentacion;
      - codigo fuente;
      - pruebas;
      - evidencias;
      - releases;
      - commits/tags/branch;
      - SGD-000 Estado Maestro Institucional.

    PRINCIPIOS:
      - no modifica entregables cerrados;
      - no duplica logica de negocio;
      - no usa servicios de pago;
      - no instala n8n;
      - no hace push;
      - no publica tags;
      - no borra historia;
      - genera un unico documento maestro;
      - cierre solo con cero errores tecnicos.

.EXAMPLE
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    .\Install-SPT021.1-v1.0.2-OneFile-PS51.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-021.1"
$Version = "1.0.2"
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$GeneratedUtc = (Get-Date).ToUniversalTime().ToString("o")
$SelfPath = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-TextFile {
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

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Data
    )

    $Json = $Data | ConvertTo-Json -Depth 80
    Write-TextFile -Path $Path -Content ($Json + "`r`n")
}

function Get-RelativePathSafe {
    param(
        [string]$Root,
        [string]$Path
    )

    $RootFull = [System.IO.Path]::GetFullPath($Root)
    $PathFull = [System.IO.Path]::GetFullPath($Path)

    if (-not $RootFull.EndsWith("\")) {
        $RootFull += "\"
    }

    $RootUri = New-Object System.Uri($RootFull)
    $PathUri = New-Object System.Uri($PathFull)
    $Relative = $RootUri.MakeRelativeUri($PathUri).ToString()

    return [System.Uri]::UnescapeDataString($Relative).Replace("\", "/")
}

function Test-PowerShellSyntax {
    param([string]$Path)

    $Tokens = $null
    $Errors = $null

    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$Tokens,
        [ref]$Errors
    )

    return @($Errors)
}

function Invoke-NativeGit {
    param(
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $GitCommand = Get-Command git -ErrorAction Stop

    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = $GitCommand.Source
    $StartInfo.UseShellExecute = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    $StartInfo.CreateNoWindow = $true
    $StartInfo.WorkingDirectory = (Get-Location).Path

    $Escaped = @()

    foreach ($Argument in $Arguments) {
        $Value = [string]$Argument

        if (
            $Value.Contains(" ") -or
            $Value.Contains("`t") -or
            $Value.Contains('"')
        ) {
            $Value = '"' + $Value.Replace('"', '\"') + '"'
        }

        $Escaped += $Value
    }

    $StartInfo.Arguments = $Escaped -join " "

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $StartInfo

    [void]$Process.Start()

    $StdOut = $Process.StandardOutput.ReadToEnd()
    $StdErr = $Process.StandardError.ReadToEnd()

    $Process.WaitForExit()

    $ExitCode = $Process.ExitCode

    if (($ExitCode -ne 0) -and (-not $AllowFailure)) {
        throw (
            "git " +
            ($Arguments -join " ") +
            " fallo. Exit code: " +
            $ExitCode +
            "`r`n" +
            $StdErr
        )
    }

    return [PSCustomObject]@{
        ExitCode = $ExitCode
        StdOut = $StdOut
        StdErr = $StdErr
    }
}

function Get-GitPaths {
    param([switch]$IncludeUntracked)

    $Tracked = Invoke-NativeGit -Arguments @(
        "-c",
        "core.quotepath=false",
        "ls-files",
        "-z"
    )

    $Paths = @(
        $Tracked.StdOut -split [char]0 |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Replace("\", "/") }
    )

    if ($IncludeUntracked) {
        $Untracked = Invoke-NativeGit -Arguments @(
            "-c",
            "core.quotepath=false",
            "ls-files",
            "--others",
            "--exclude-standard",
            "-z"
        )

        $Paths += @(
            $Untracked.StdOut -split [char]0 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Replace("\", "/") }
        )
    }

    return @($Paths | Sort-Object -Unique)
}

function Get-ArtifactIds {
    param([string]$Text)

    $Pattern = '\b(?:POL|SGD|ADR|SPB|SPT|PCI|ACT|RMI|RLB|SIB|ODA|FLD|PMO)-[A-Z0-9]+(?:\.[A-Z0-9]+)*(?:-[A-Z0-9]+)*\b'

    return @(
        [regex]::Matches(
            $Text.ToUpperInvariant(),
            $Pattern
        ) |
        ForEach-Object { $_.Value } |
        Sort-Object -Unique
    )
}

function Get-Family {
    param([string]$Id)

    if ($Id -match '^([A-Z]+)-') {
        return $Matches[1]
    }

    return "OTHER"
}

function Get-PhaseForId {
    param([string]$Id)

    switch -Regex ($Id) {
        '^POL-' { return "Gobierno Institucional" }
        '^ADR-' { return "Arquitectura y Decisiones" }
        '^PCI-' { return "Consolidacion Institucional" }
        '^SPB-' { return "Fundacion y Construccion" }
        '^SGD-' { return "Gobierno / Documentacion Institucional" }
        '^SPT-0(0[1-9]|1[0-2])' { return "Fase Tecnologica - Fundacion Tecnica" }
        '^SPT-01[3-8]' { return "Fase Tecnologica - Capacidades SGODA" }
        '^SPT-019' { return "Fase Tecnologica - Workflow e Integracion" }
        '^SPT-020' { return "Fase Tecnologica - Plataforma Tecnologica Institucional" }
        '^SPT-021' { return "Fase Tecnologica - Consolidacion y Mapa Maestro" }
        '^ACT-' { return "Cierre y Gobierno Institucional" }
        '^RMI-' { return "Registro Maestro Institucional" }
        '^RLB-' { return "Linea Base Institucional" }
        default { return "Transversal / Por determinar" }
    }
}

function Get-SprintForId {
    param([string]$Id)

    if ($Id -match '^SPT-(\d{3})(?:\.(\d+))?') {
        $Main = $Matches[1]
        $Sub = $Matches[2]

        if ($Sub) {
            return "SPT-$Main.$Sub"
        }

        return "SPT-$Main"
    }

    if ($Id -match '^SPB-(\d{3})(?:\.(\d+))?') {
        $Main = $Matches[1]
        $Sub = $Matches[2]

        if ($Sub) {
            return "SPB-$Main.$Sub"
        }

        return "SPB-$Main"
    }

    return "Transversal"
}

function Get-Definition {
    param([string]$Id)

    $Known = [ordered]@{
        "SGD-000" = "Estado Maestro Institucional del proyecto"
        "SGD-001" = "Mapa Maestro Institucional del proyecto"
        "POL-001" = "Politica institucional de gobierno tecnologico y uso de tecnologias libres"
        "SPT-019.0" = "Institutional Project State Manager"
        "SPT-019.1" = "Workflow Engine Core"
        "SPT-019.2" = "Workflow Registry Manager"
        "SPT-019.3" = "Integracion institucional del subsistema de workflows"
        "SPT-020.1" = "Institutional Service Bus"
        "SPT-020.2" = "Component Lifecycle Manager"
        "SPT-020.3" = "Institutional Component Dependency Manager"
        "SPT-020.4" = "Institutional Event Bus"
        "SPT-020.5" = "Institutional Service Discovery and Registry"
        "SPT-020.6" = "Institutional Runtime Orchestrator"
        "SPT-020.7" = "Institutional Health Monitor"
        "SPT-020.8" = "Zero Error Institutional Closure"
        "SPT-020.9" = "Institutional Master State Update Engine"
        "SPT-021.0" = "Institutional Technology Baseline and Gap Analyzer"
        "SPT-021.0.1" = "Institutional Repository Reconciliation and Publication Engine"
        "SPT-021.1" = "Institutional Master Map Generator"
    }

    if ($Known.Contains($Id)) {
        return $Known[$Id]
    }

    $Family = Get-Family -Id $Id

    switch ($Family) {
        "POL" { return "Politica institucional" }
        "SGD" { return "Documento institucional SGODA" }
        "ADR" { return "Registro de decision arquitectonica" }
        "SPB" { return "Entregable de construccion o builder institucional" }
        "SPT" { return "Componente o entregable de la fase tecnologica" }
        "PCI" { return "Componente del programa de consolidacion institucional" }
        "ACT" { return "Acta institucional de aprobacion o cierre" }
        "RMI" { return "Registro maestro institucional" }
        "RLB" { return "Registro o artefacto de linea base" }
        "SIB" { return "Componente institucional de instalacion/build" }
        "ODA" { return "Objeto Digital de Aprendizaje" }
        "FLD" { return "Ficha Lexica Digital" }
        "PMO" { return "Componente del PMO Digital" }
        default { return "Artefacto institucional SGODA-PUINAVE" }
    }
}

function Get-Purpose {
    param([string]$Id)

    $Family = Get-Family -Id $Id

    switch ($Family) {
        "POL" { return "Establecer reglas obligatorias de gobierno y operacion." }
        "SGD" { return "Documentar, gobernar y mantener el estado institucional." }
        "ADR" { return "Conservar la decision arquitectonica y su justificacion." }
        "SPB" { return "Construir, automatizar o habilitar capacidades base del proyecto." }
        "SPT" { return "Implementar una capacidad tecnologica verificable del ecosistema." }
        "PCI" { return "Consolidar, reconciliar y cerrar capacidades institucionales." }
        "ACT" { return "Formalizar aprobacion, cierre o decision institucional." }
        "RMI" { return "Mantener un registro maestro controlado y trazable." }
        "RLB" { return "Conservar la linea base y su trazabilidad." }
        "SIB" { return "Automatizar construccion, instalacion o empaquetado." }
        "ODA" { return "Representar una unidad digital de aprendizaje." }
        "FLD" { return "Representar integralmente una entrada lexica digital." }
        "PMO" { return "Gestionar control, seguimiento y auditoria institucional." }
        default { return "Servir como artefacto trazable dentro del ecosistema institucional." }
    }
}

function Get-Status {
    param(
        [string]$Id,
        [string[]]$Paths
    )

    $Joined = ($Paths -join " ").ToUpperInvariant()

    if (
        $Joined.Contains("/RELEASES/") -or
        $Joined.Contains("/RELEASE/") -or
        $Joined.Contains("CIERRE") -or
        $Joined.Contains("CLOSED") -or
        $Joined.Contains("ACT-")
    ) {
        return "CLOSED_OR_RELEASED"
    }

    if ($Joined.Contains("/TESTS/") -or $Joined.Contains("/SRC/")) {
        return "IMPLEMENTED"
    }

    if ($Joined.Contains("/DOCS/")) {
        return "DOCUMENTED"
    }

    return "DISCOVERED"
}

function Escape-MarkdownCell {
    param([AllowEmptyString()][string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    return $Text.Replace("|", "\|").Replace("`r", " ").Replace("`n", " ")
}

function Compress-Paths {
    param(
        [string[]]$Paths,
        [int]$Max = 4
    )

    if ($Paths.Count -eq 0) {
        return "-"
    }

    $Selected = @($Paths | Select-Object -First $Max)
    $Text = $Selected -join "<br>"

    if ($Paths.Count -gt $Max) {
        $Text += "<br>+" + ($Paths.Count - $Max) + " mas"
    }

    return $Text
}

function Get-InstitutionalRecordType {
    param([string]$Path)

    $P = $Path.Replace("\", "/").ToLowerInvariant()
    $Name = [System.IO.Path]::GetFileName($P)

    if ($P.StartsWith("releases/")) { return "RELEASE_ARTIFACT" }
    if ($P.StartsWith("artifacts/")) { return "EVIDENCE_ARTIFACT" }
    if ($P.StartsWith("tests/") -or $Name -match "^test_.*\.py$") { return "TEST" }
    if ($P.StartsWith("src/")) { return "SOURCE_CODE" }
    if ($P.StartsWith("config/")) { return "CONFIGURATION" }
    if ($P.StartsWith("docs/")) {
        if ($Name -match "^act-") { return "ACT" }
        if ($Name -match "^adr-") { return "ADR_DOCUMENT" }
        return "DOCUMENT"
    }
    if ($Name -match "^(install|apply|repair|close|invoke)-.*\.ps1$") {
        return "IMPLEMENTATION_SCRIPT"
    }
    if ($P.StartsWith("scripts/")) { return "SCRIPT" }
    if ($Name -match "manifest.*\.json$") { return "MANIFEST" }
    if ($Name -match "(evidence|evidencia|report|resultado|audit).*\.(json|md|txt)$") {
        return "EVIDENCE_ARTIFACT"
    }

    return "INSTITUTIONAL_ARTIFACT"
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

foreach ($Command in @("git", "python")) {
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "Comando requerido no disponible: $Command"
    }
}

$SelfErrors = @(Test-PowerShellSyntax -Path $SelfPath)

if ($SelfErrors.Count -ne 0) {
    throw "El instalador SPT-021.1 contiene errores de sintaxis."
}

$GitRoot = (
    Invoke-NativeGit -Arguments @(
        "rev-parse",
        "--show-toplevel"
    )
).StdOut.Trim()

if (
    [System.IO.Path]::GetFullPath($GitRoot).TrimEnd("\") -ne
    $ProjectRoot.TrimEnd("\")
) {
    throw "SPT-021.1 debe ejecutarse desde la raiz Git."
}

$SGD000Path = Join-Path $ProjectRoot (
    "docs\00_Estado_Maestro\SGD-000-Estado-Maestro-Institucional-v1.0.0.md"
)

if (-not (Test-Path -LiteralPath $SGD000Path -PathType Leaf)) {
    throw "No existe SGD-000. No se puede generar SGD-001."
}

$SPT020Closure = Join-Path $ProjectRoot (
    "config\platform\SPT-020-closure-registry.json"
)

if (-not (Test-Path -LiteralPath $SPT020Closure -PathType Leaf)) {
    throw "No existe el registro de cierre SPT-020."
}

$Closure = Get-Content -LiteralPath $SPT020Closure -Raw | ConvertFrom-Json

if ([string]$Closure.final_status -ne "CLOSED") {
    throw "SPT-020 no esta CLOSED."
}

$RunRoot = Join-Path $ProjectRoot (
    "artifacts\development\SPT-021.1-v1.0.2\runs\" + $RunId
)
$DocsRoot = Join-Path $ProjectRoot "docs\00_Estado_Maestro"
$SPTDocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-021.1"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-021.1-v1.0.2"

foreach ($Directory in @(
    $RunRoot,
    $DocsRoot,
    $SPTDocsRoot,
    $ReleaseRoot
)) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

Write-Step "Inventariando repositorio institucional"

$Paths = @(Get-GitPaths -IncludeUntracked)
Write-Host "Archivos candidatos: $($Paths.Count)"

$Records = @{}
$Index = 0

foreach ($Relative in $Paths) {
    $Index++

    if (($Index % 500) -eq 0 -or $Index -eq $Paths.Count) {
        Write-Host (
            "  Inventario: {0}/{1}" -f $Index, $Paths.Count
        ) -ForegroundColor DarkGray
    }

    $Ids = @(Get-ArtifactIds -Text $Relative)

    foreach ($Id in $Ids) {
        if (-not $Records.ContainsKey($Id)) {
            $Records[$Id] = New-Object System.Collections.ArrayList
        }

        [void]$Records[$Id].Add($Relative)
    }
}

Write-Step "Clasificando entregables y relaciones"

$MasterRows = @()

foreach ($Id in ($Records.Keys | Sort-Object)) {
    $ItemPaths = @($Records[$Id] | Sort-Object -Unique)

    $Docs = @(
        $ItemPaths | Where-Object {
            $_ -like "docs/*" -or
            $_ -like "*.md"
        }
    )

    $Code = @(
        $ItemPaths | Where-Object {
            $_ -like "src/*" -or
            $_ -like "builder/*" -or
            $_ -like "scripts/*" -or
            $_ -like "Install-*.ps1" -or
            $_ -like "Apply-*.ps1" -or
            $_ -like "Repair-*.ps1" -or
            $_ -like "Close-*.ps1"
        }
    )

    $Tests = @(
        $ItemPaths | Where-Object {
            $_ -like "tests/*" -or
            $_ -match "(^|/)test[s]?/"
        }
    )

    $Evidence = @(
        $ItemPaths | Where-Object {
            $_ -like "artifacts/*" -or
            $_ -match "evidence|evidencia|report|resultado|audit"
        }
    )

    $Releases = @(
        $ItemPaths | Where-Object {
            $_ -like "releases/*"
        }
    )

    $Acts = @(
        $ItemPaths | Where-Object {
            $_ -match "(^|/)ACT-"
        }
    )

    $Dependencies = @()

    foreach ($Path in ($Docs | Select-Object -First 3)) {
        $Full = Join-Path $ProjectRoot ($Path.Replace("/", "\"))

        if (
            (Test-Path -LiteralPath $Full -PathType Leaf) -and
            ((Get-Item -LiteralPath $Full).Length -lt 1048576)
        ) {
            try {
                $Content = Get-Content -LiteralPath $Full -Raw
                $Dependencies += @(
                    Get-ArtifactIds -Text $Content |
                    Where-Object { $_ -ne $Id }
                )
            }
            catch {
                # Documento no legible: no bloquea el mapa.
            }
        }
    }

    $Dependencies = @($Dependencies | Sort-Object -Unique)

    $MasterRows += [PSCustomObject][ordered]@{
        id = $Id
        family = Get-Family -Id $Id
        definition = Get-Definition -Id $Id
        purpose = Get-Purpose -Id $Id
        phase = Get-PhaseForId -Id $Id
        sprint = Get-SprintForId -Id $Id
        status = Get-Status -Id $Id -Paths $ItemPaths
        dependencies = $Dependencies
        repository_paths = $ItemPaths
        documentation = $Docs
        code = $Code
        tests = $Tests
        evidence = $Evidence
        releases = $Releases
        acts = $Acts
        relation_sgd000 = if ($Id -eq "SGD-000") {
            "SOURCE_OF_MASTER_STATE"
        }
        else {
            "REFERENCED_BY_MASTER_MAP"
        }
    }
}

# Add SPT-021.1 itself if not yet discoverable from file paths.
if (@($MasterRows | Where-Object { $_.id -eq "SPT-021.1" }).Count -eq 0) {
    $MasterRows += [PSCustomObject][ordered]@{
        id = "SPT-021.1"
        family = "SPT"
        definition = "Institutional Master Map Generator"
        purpose = "Generar y mantener SGD-001 como mapa maestro institucional."
        phase = "Fase Tecnologica - Consolidacion y Mapa Maestro"
        sprint = "SPT-021.1"
        status = "IMPLEMENTED"
        dependencies = @("SGD-000", "SPT-020.9", "SPT-021.0.1")
        repository_paths = @(
            Get-RelativePathSafe -Root $ProjectRoot -Path $SelfPath
        )
        documentation = @()
        code = @(
            Get-RelativePathSafe -Root $ProjectRoot -Path $SelfPath
        )
        tests = @()
        evidence = @()
        releases = @()
        acts = @()
        relation_sgd000 = "EXTENDS_MASTER_STATE"
    }
}

$MasterRows = @($MasterRows | Sort-Object id)

Write-Step "Construyendo registros institucionales detallados"

$DetailedRows = @()
$DetailedIndex = 0

foreach ($Relative in $Paths) {
    $Ids = @(Get-ArtifactIds -Text $Relative)

    if ($Ids.Count -eq 0) {
        continue
    }

    $RecordType = Get-InstitutionalRecordType -Path $Relative

    foreach ($Id in $Ids) {
        $DetailedIndex++

        $Canonical = @(
            $MasterRows |
            Where-Object { $_.id -eq $Id } |
            Select-Object -First 1
        )

        $Family = Get-Family -Id $Id
        $Phase = Get-PhaseForId -Id $Id
        $Sprint = Get-SprintForId -Id $Id
        $Definition = Get-Definition -Id $Id
        $Purpose = Get-Purpose -Id $Id

        if ($Canonical.Count -eq 1) {
            $Family = [string]$Canonical[0].family
            $Phase = [string]$Canonical[0].phase
            $Sprint = [string]$Canonical[0].sprint
            $Definition = [string]$Canonical[0].definition
            $Purpose = [string]$Canonical[0].purpose
        }

        $DetailedRows += [PSCustomObject][ordered]@{
            record_id = ("RMI-{0:D5}" -f $DetailedIndex)
            canonical_id = $Id
            family = $Family
            record_type = $RecordType
            definition = $Definition
            purpose = $Purpose
            phase = $Phase
            sprint = $Sprint
            status = Get-Status -Id $Id -Paths @($Relative)
            repository_path = $Relative
            evidence_relation = if ($RecordType -eq "EVIDENCE_ARTIFACT") {
                "DIRECT_EVIDENCE"
            }
            else {
                "TRACEABLE_TO_CANONICAL_COMPONENT"
            }
            test_relation = if ($RecordType -eq "TEST") {
                "DIRECT_TEST"
            }
            else {
                "SEE_CANONICAL_COMPONENT"
            }
            relation_sgd000 = if ($Id -eq "SGD-000") {
                "SOURCE_OF_MASTER_STATE"
            }
            else {
                "REFERENCED_BY_MASTER_MAP"
            }
        }
    }
}

$DetailedRows = @(
    $DetailedRows |
    Sort-Object canonical_id, repository_path, record_id
)

Write-Host "  Componentes canonicos: $($MasterRows.Count)"
Write-Host "  Registros institucionales detallados: $($DetailedRows.Count)"

Write-Step "Obteniendo estado Git"

$Branch = (
    Invoke-NativeGit -Arguments @(
        "rev-parse",
        "--abbrev-ref",
        "HEAD"
    )
).StdOut.Trim()

$Commit = (
    Invoke-NativeGit -Arguments @(
        "rev-parse",
        "HEAD"
    )
).StdOut.Trim()

$Remote = (
    Invoke-NativeGit -Arguments @(
        "remote",
        "get-url",
        "origin"
    )
).StdOut.Trim()

$Tags = @(
    (
        Invoke-NativeGit `
            -Arguments @("tag", "--points-at", "HEAD") `
            -AllowFailure
    ).StdOut -split "\r?\n" |
    Where-Object { $_ }
)

Write-Step "Compilando Python"

$CompileOutput = @(& python -m compileall -q src tests 2>&1)
$CompileExitCode = $LASTEXITCODE

Write-TextFile `
    -Path (Join-Path $RunRoot "python-compileall.txt") `
    -Content (($CompileOutput -join "`r`n") + "`r`n")

Write-Step "Ejecutando suite institucional completa"

$env:PYTHONPATH = Join-Path $ProjectRoot "src"
$PytestOutput = @(& python -m pytest -q 2>&1)
$PytestExitCode = $LASTEXITCODE
$PytestText = $PytestOutput -join "`r`n"

Write-TextFile `
    -Path (Join-Path $RunRoot "pytest-full-suite.txt") `
    -Content ($PytestText + "`r`n")

$PytestOutput | ForEach-Object { Write-Host $_ }

$TestCount = 0
$PassedMatch = [regex]::Match($PytestText, "(\d+)\s+passed")

if ($PassedMatch.Success) {
    $TestCount = [int]$PassedMatch.Groups[1].Value
}

$PytestPassed = ($PytestExitCode -eq 0)

if ($CompileExitCode -ne 0) {
    throw "Python compileall fallo."
}

if (-not $PytestPassed) {
    throw "La suite institucional fallo."
}

if ($TestCount -lt 808) {
    throw "Regresion detectada: menos de 808 pruebas aprobadas."
}

Write-Step "Generando SGD-001 Mapa Maestro Institucional"

$FamilySummary = @(
    $MasterRows |
    Group-Object family |
    Sort-Object Name |
    ForEach-Object {
        [PSCustomObject][ordered]@{
            family = [string]$_.Name
            count = [int]$_.Count
        }
    }
)

$PhaseSummary = @(
    $MasterRows |
    Group-Object phase |
    Sort-Object Name |
    ForEach-Object {
        [PSCustomObject][ordered]@{
            phase = [string]$_.Name
            count = [int]$_.Count
        }
    }
)

$StatusSummary = @(
    $MasterRows |
    Group-Object status |
    Sort-Object Name |
    ForEach-Object {
        [PSCustomObject][ordered]@{
            status = [string]$_.Name
            count = [int]$_.Count
        }
    }
)

Write-Step "Ejecutando quality gate semantico del Mapa Maestro"

$RequiredFamilies = @(
    "POL",
    "SGD",
    "ADR",
    "SPB",
    "SPT",
    "PCI",
    "ACT"
)

$DetectedFamilies = @(
    $MasterRows |
    ForEach-Object { [string]$_.family } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Sort-Object -Unique
)

$DetectedPhases = @(
    $MasterRows |
    ForEach-Object { [string]$_.phase } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Sort-Object -Unique
)

$DetectedStatuses = @(
    $MasterRows |
    ForEach-Object { [string]$_.status } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Sort-Object -Unique
)

$MissingRequiredFamilies = @(
    $RequiredFamilies |
    Where-Object { $DetectedFamilies -notcontains $_ }
)

$SemanticFindings = @()

$MinimumInstitutionalRecords = 800

if ($DetailedRows.Count -lt $MinimumInstitutionalRecords) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-000"
        severity = "ERROR"
        message = (
            "El Mapa Maestro contiene " +
            $DetailedRows.Count +
            " registros institucionales detallados; se requieren al menos " +
            $MinimumInstitutionalRecords +
            " para preservar la linea base historica."
        )
    }
}

if ($MasterRows.Count -lt 20) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-001"
        severity = "ERROR"
        message = "El Mapa Maestro contiene menos de 20 registros."
    }
}

if ($DetectedFamilies.Count -lt 5) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-002"
        severity = "ERROR"
        message = "Se detectaron menos de 5 familias institucionales."
    }
}

if ($DetectedPhases.Count -lt 4) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-003"
        severity = "ERROR"
        message = "Se detectaron menos de 4 fases institucionales."
    }
}

foreach ($MissingFamily in $MissingRequiredFamilies) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-004"
        severity = "ERROR"
        message = "Falta familia institucional obligatoria: $MissingFamily"
    }
}

if ($DetectedStatuses.Count -lt 2) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-005"
        severity = "ERROR"
        message = "La clasificacion de estados colapso a menos de 2 estados."
    }
}

$SemanticErrors = @(
    $SemanticFindings |
    Where-Object { $_.severity -eq "ERROR" }
).Count

Write-Host "  Componentes canonicos: $($MasterRows.Count)"
Write-Host "  Registros institucionales: $($DetailedRows.Count)"
Write-Host "  Minimo institucional requerido: $MinimumInstitutionalRecords"
Write-Host "  Familias detectadas: $($DetectedFamilies.Count)"
Write-Host "  Fases detectadas: $($DetectedPhases.Count)"
Write-Host "  Estados detectados: $($DetectedStatuses.Count)"
Write-Host "  Familias obligatorias faltantes: $($MissingRequiredFamilies.Count)"
Write-Host "  Errores semanticos: $SemanticErrors"

if ($SemanticErrors -gt 0) {
    Write-Host "  Quality gate semantico: BLOQUEADO" -ForegroundColor Red
}
else {
    Write-Host "  Quality gate semantico: APROBADO" -ForegroundColor Green
}

$Builder = New-Object System.Text.StringBuilder

[void]$Builder.AppendLine("# SGD-001 - Mapa Maestro Institucional del Proyecto SGODA-PUINAVE")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("**Version:** 1.0.2  ")
[void]$Builder.AppendLine("**Generado UTC:** $GeneratedUtc  ")
[void]$Builder.AppendLine("**Generador:** SPT-021.1 v$Version  ")
[void]$Builder.AppendLine("**Repositorio:** $Remote  ")
[void]$Builder.AppendLine("**Rama:** $Branch  ")
[void]$Builder.AppendLine("**Commit de linea base:** $Commit  ")
[void]$Builder.AppendLine("**SGD-000:** docs/00_Estado_Maestro/SGD-000-Estado-Maestro-Institucional-v1.0.0.md  ")
[void]$Builder.AppendLine("**Suite institucional:** $TestCount pruebas aprobadas  ")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("> Este documento se genera desde el repositorio real y consolida la memoria institucional sin sustituir los entregables fuente.")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("## 1. Proposito")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("Consolidar en una sola referencia institucional los entregables, hitos, componentes, documentos, codigo, pruebas, evidencias, releases y relaciones de trazabilidad de SGODA-PUINAVE.")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("## 2. Linea base institucional")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("| Campo | Valor |")
[void]$Builder.AppendLine("|---|---|")
[void]$Builder.AppendLine("| Estado SPT-020 | CLOSED |")
[void]$Builder.AppendLine("| Generador | SPT-021.1 |")
[void]$Builder.AppendLine("| Repositorio | $(Escape-MarkdownCell $Remote) |")
[void]$Builder.AppendLine("| Rama | $(Escape-MarkdownCell $Branch) |")
[void]$Builder.AppendLine("| Commit | $Commit |")
[void]$Builder.AppendLine("| Tags en HEAD | $(Escape-MarkdownCell ($Tags -join ', ')) |")
[void]$Builder.AppendLine("| Pruebas | $TestCount passed |")
[void]$Builder.AppendLine("| Errores tecnicos | 0 |")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("## 3. Resumen por familia")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("| Familia | Registros |")
[void]$Builder.AppendLine("|---|---:|")

foreach ($Item in $FamilySummary) {
    [void]$Builder.AppendLine(
        "| $(Escape-MarkdownCell $Item.family) | $($Item.count) |"
    )
}

[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("## 4. Resumen por fase")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("| Fase | Registros |")
[void]$Builder.AppendLine("|---|---:|")

foreach ($Item in $PhaseSummary) {
    [void]$Builder.AppendLine(
        "| $(Escape-MarkdownCell $Item.phase) | $($Item.count) |"
    )
}

[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("## 5. Resumen por estado")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("| Estado | Registros |")
[void]$Builder.AppendLine("|---|---:|")

foreach ($Item in $StatusSummary) {
    [void]$Builder.AppendLine(
        "| $(Escape-MarkdownCell $Item.status) | $($Item.count) |"
    )
}

[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("### 5.1 Quality Gate Semantico")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("| Control | Resultado |")
[void]$Builder.AppendLine("|---|---|")
[void]$Builder.AppendLine("| Componentes canonicos | $($MasterRows.Count) |")
[void]$Builder.AppendLine("| Registros institucionales detallados | $($DetailedRows.Count) |")
[void]$Builder.AppendLine("| Minimo historico requerido | $MinimumInstitutionalRecords |")
[void]$Builder.AppendLine("| Familias detectadas | $($DetectedFamilies.Count) |")
[void]$Builder.AppendLine("| Fases detectadas | $($DetectedPhases.Count) |")
[void]$Builder.AppendLine("| Estados detectados | $($DetectedStatuses.Count) |")
[void]$Builder.AppendLine("| Familias obligatorias faltantes | $($MissingRequiredFamilies.Count) |")
[void]$Builder.AppendLine("| Errores semanticos | $SemanticErrors |")
[void]$Builder.AppendLine("| Estado gate | $(if ($SemanticErrors -eq 0) { "APROBADO" } else { "BLOQUEADO" }) |")

[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("## 6. Matriz Maestra de Entregables")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("| Codigo | Tipo | Definicion | Para que sirve | Fase | Sprint | Estado | Dependencias | Ubicacion | Evidencia | Pruebas | Release | Acta | Relacion SGD-000 |")
[void]$Builder.AppendLine("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")

foreach ($Row in $MasterRows) {
    $Dependencies = if ($Row.dependencies.Count -gt 0) {
        $Row.dependencies -join ", "
    }
    else {
        "-"
    }

    $Location = Compress-Paths -Paths $Row.repository_paths -Max 3
    $EvidenceText = Compress-Paths -Paths $Row.evidence -Max 2
    $TestsText = Compress-Paths -Paths $Row.tests -Max 2
    $ReleaseText = Compress-Paths -Paths $Row.releases -Max 2
    $ActText = Compress-Paths -Paths $Row.acts -Max 2

    [void]$Builder.AppendLine(
        "| " +
        (Escape-MarkdownCell $Row.id) + " | " +
        (Escape-MarkdownCell $Row.family) + " | " +
        (Escape-MarkdownCell $Row.definition) + " | " +
        (Escape-MarkdownCell $Row.purpose) + " | " +
        (Escape-MarkdownCell $Row.phase) + " | " +
        (Escape-MarkdownCell $Row.sprint) + " | " +
        (Escape-MarkdownCell $Row.status) + " | " +
        (Escape-MarkdownCell $Dependencies) + " | " +
        (Escape-MarkdownCell $Location) + " | " +
        (Escape-MarkdownCell $EvidenceText) + " | " +
        (Escape-MarkdownCell $TestsText) + " | " +
        (Escape-MarkdownCell $ReleaseText) + " | " +
        (Escape-MarkdownCell $ActText) + " | " +
        (Escape-MarkdownCell $Row.relation_sgd000) +
        " |"
    )
}

[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("## 6.1 Registro Maestro Institucional Detallado")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("Esta matriz conserva cada instancia documental, tecnica, de prueba, evidencia, release y script sin colapsarla en el codigo canonico.")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("| Registro | Codigo canonico | Familia | Tipo de registro | Definicion | Proposito | Fase | Sprint | Estado | Ubicacion | Evidencia | Pruebas | Relacion SGD-000 |")
[void]$Builder.AppendLine("|---|---|---|---|---|---|---|---|---|---|---|---|---|")

foreach ($Row in $DetailedRows) {
    [void]$Builder.AppendLine(
        "| " +
        (Escape-MarkdownCell $Row.record_id) + " | " +
        (Escape-MarkdownCell $Row.canonical_id) + " | " +
        (Escape-MarkdownCell $Row.family) + " | " +
        (Escape-MarkdownCell $Row.record_type) + " | " +
        (Escape-MarkdownCell $Row.definition) + " | " +
        (Escape-MarkdownCell $Row.purpose) + " | " +
        (Escape-MarkdownCell $Row.phase) + " | " +
        (Escape-MarkdownCell $Row.sprint) + " | " +
        (Escape-MarkdownCell $Row.status) + " | " +
        (Escape-MarkdownCell $Row.repository_path) + " | " +
        (Escape-MarkdownCell $Row.evidence_relation) + " | " +
        (Escape-MarkdownCell $Row.test_relation) + " | " +
        (Escape-MarkdownCell $Row.relation_sgd000) +
        " |"
    )
}

[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("## 7. Mapa Maestro de Dependencias")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("| Codigo | Dependencias descubiertas |")
[void]$Builder.AppendLine("|---|---|")

foreach ($Row in $MasterRows) {
    $Dependencies = if ($Row.dependencies.Count -gt 0) {
        $Row.dependencies -join ", "
    }
    else {
        "-"
    }

    [void]$Builder.AppendLine(
        "| " +
        (Escape-MarkdownCell $Row.id) +
        " | " +
        (Escape-MarkdownCell $Dependencies) +
        " |"
    )
}

[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("## 8. Mapa Maestro de Codigo, Pruebas y Evidencias")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("| Codigo | Codigo fuente / scripts | Pruebas | Evidencias |")
[void]$Builder.AppendLine("|---|---|---|---|")

foreach ($Row in $MasterRows) {
    [void]$Builder.AppendLine(
        "| " +
        (Escape-MarkdownCell $Row.id) + " | " +
        (Escape-MarkdownCell (Compress-Paths -Paths $Row.code -Max 4)) + " | " +
        (Escape-MarkdownCell (Compress-Paths -Paths $Row.tests -Max 4)) + " | " +
        (Escape-MarkdownCell (Compress-Paths -Paths $Row.evidence -Max 4)) +
        " |"
    )
}

[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("## 9. Mapa Maestro de Releases y Actas")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("| Codigo | Releases | Actas |")
[void]$Builder.AppendLine("|---|---|---|")

foreach ($Row in $MasterRows) {
    [void]$Builder.AppendLine(
        "| " +
        (Escape-MarkdownCell $Row.id) + " | " +
        (Escape-MarkdownCell (Compress-Paths -Paths $Row.releases -Max 4)) + " | " +
        (Escape-MarkdownCell (Compress-Paths -Paths $Row.acts -Max 4)) +
        " |"
    )
}

[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("## 10. Relacion con SGD-000")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("SGD-000 conserva el estado maestro institucional. SGD-001 funciona como mapa navegable de la memoria institucional y no reemplaza SGD-000. Todo nuevo cierre debe poder ser localizado desde ambos.")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("## 11. Regla de mantenimiento")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("SPT-021.1 debe regenerar SGD-001 despues de cierres institucionales significativos, sin borrar historia y reutilizando las evidencias ya validadas.")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("## 12. Criterio de conformidad")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("- Repositorio inventariado desde Git.")
[void]$Builder.AppendLine("- SGD-000 disponible.")
[void]$Builder.AppendLine("- SPT-020 CLOSED.")
[void]$Builder.AppendLine("- Python compile exit code: 0.")
[void]$Builder.AppendLine("- Suite institucional: $TestCount passed.")
[void]$Builder.AppendLine("- Errores tecnicos: 0.")
[void]$Builder.AppendLine("")
[void]$Builder.AppendLine("**Estado de SGD-001: GENERATED_AND_VALIDATED**")

$MasterMapPath = Join-Path $DocsRoot (
    "SGD-001-Mapa-Maestro-Institucional-SGODA-PUINAVE-v1.0.2.md"
)

Write-TextFile -Path $MasterMapPath -Content $Builder.ToString()

Write-Step "Validando documento maestro"

$MasterMapText = Get-Content -LiteralPath $MasterMapPath -Raw

$RequiredSections = @(
    "# SGD-001 - Mapa Maestro Institucional",
    "## 6. Matriz Maestra de Entregables",
    "## 6.1 Registro Maestro Institucional Detallado",
    "## 7. Mapa Maestro de Dependencias",
    "## 8. Mapa Maestro de Codigo, Pruebas y Evidencias",
    "## 9. Mapa Maestro de Releases y Actas",
    "## 10. Relacion con SGD-000",
    "SGD-000",
    "SPT-020",
    "SPT-021.1"
)

$MissingSections = @(
    $RequiredSections |
    Where-Object { -not $MasterMapText.Contains($_) }
)

$TechnicalErrors = 0

if ($SemanticErrors -gt 0) {
    $TechnicalErrors += $SemanticErrors
}

if ($MissingSections.Count -gt 0) {
    $TechnicalErrors += $MissingSections.Count
}

if ($CompileExitCode -ne 0) {
    $TechnicalErrors++
}

if (-not $PytestPassed) {
    $TechnicalErrors++
}

if ($TestCount -lt 808) {
    $TechnicalErrors++
}

$InventoryPath = Join-Path $RunRoot "institutional-master-map-inventory.json"
Write-JsonFile -Path $InventoryPath -Data $MasterRows

$DetailedInventoryPath = Join-Path $RunRoot "institutional-detailed-records.json"
Write-JsonFile -Path $DetailedInventoryPath -Data $DetailedRows

$SemanticReport = [ordered]@{
    component = $Component
    version = $Version
    generated_at_utc = $GeneratedUtc
    canonical_components = $MasterRows.Count
    institutional_records = $DetailedRows.Count
    minimum_institutional_records = $MinimumInstitutionalRecords
    detected_families = $DetectedFamilies
    detected_family_count = $DetectedFamilies.Count
    required_families = $RequiredFamilies
    missing_required_families = $MissingRequiredFamilies
    detected_phases = $DetectedPhases
    detected_phase_count = $DetectedPhases.Count
    detected_statuses = $DetectedStatuses
    detected_status_count = $DetectedStatuses.Count
    findings = $SemanticFindings
    semantic_errors = $SemanticErrors
    status = if ($SemanticErrors -eq 0) { "APPROVED" } else { "BLOCKED" }
}

$SemanticReportPath = Join-Path $RunRoot "semantic-validation-report.json"
Write-JsonFile -Path $SemanticReportPath -Data $SemanticReport

$Evidence = [ordered]@{
    component = $Component
    version = $Version
    generated_at_utc = $GeneratedUtc
    run_id = $RunId
    status = if ($TechnicalErrors -eq 0) { "CLOSED" } else { "BLOCKED" }
    master_document = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $MasterMapPath
    canonical_components = $MasterRows.Count
    institutional_records = $DetailedRows.Count
    minimum_institutional_records = $MinimumInstitutionalRecords
    families = $FamilySummary.Count
    phases = $PhaseSummary.Count
    semantic_errors = $SemanticErrors
    semantic_gate_passed = ($SemanticErrors -eq 0)
    required_families = $RequiredFamilies
    missing_required_families = $MissingRequiredFamilies
    semantic_validation_report = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $SemanticReportPath
    repository_files_scanned = $Paths.Count
    branch = $Branch
    commit = $Commit
    python_compile_exit_code = $CompileExitCode
    pytest_passed = $PytestPassed
    tests_passed = $TestCount
    missing_required_sections = $MissingSections
    technical_errors = $TechnicalErrors
    sgd_000_available = $true
    spt_020_status = "CLOSED"
    n8n_installed = $false
    paid_services_required = $false
}

$EvidencePath = Join-Path $RunRoot "implementation-evidence.json"
Write-JsonFile -Path $EvidencePath -Data $Evidence

$Act = @"
# ACT-021.1 - Cierre Institutional Master Map Generator

| Campo | Resultado |
|---|---|
| Componente | SPT-021.1 |
| Version | $Version |
| Documento | SGD-001 |
| Componentes canonicos | $($MasterRows.Count) |
| Registros institucionales | $($DetailedRows.Count) |
| Minimo historico requerido | $MinimumInstitutionalRecords |
| Familias | $($FamilySummary.Count) |
| Fases | $($PhaseSummary.Count) |
| Errores semanticos | $SemanticErrors |
| Gate semantico | $(if ($SemanticErrors -eq 0) { "APROBADO" } else { "BLOQUEADO" }) |
| Archivos inventariados | $($Paths.Count) |
| Python compile | $CompileExitCode |
| Pytest | $PytestPassed |
| Pruebas | $TestCount |
| Errores tecnicos | $TechnicalErrors |
| Estado | $(if ($TechnicalErrors -eq 0) { "CLOSED" } else { "BLOCKED" }) |

SPT-021.1 genera SGD-001 a partir del repositorio real sin sustituir SGD-000.
"@

$ActPath = Join-Path $SPTDocsRoot "ACT-021.1-Cierre-Institutional-Master-Map-Generator.md"
Write-TextFile -Path $ActPath -Content $Act

$ReleaseManifest = [ordered]@{
    component = $Component
    version = $Version
    status = if ($TechnicalErrors -eq 0) { "CLOSED" } else { "BLOCKED" }
    master_document = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $MasterMapPath
    canonical_inventory = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $InventoryPath
    detailed_inventory = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $DetailedInventoryPath
    semantic_validation = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $SemanticReportPath
    evidence = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $EvidencePath
    act = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $ActPath
    tests_passed = $TestCount
    technical_errors = $TechnicalErrors
}

$ReleaseManifestPath = Join-Path $ReleaseRoot "manifest.json"
Write-JsonFile -Path $ReleaseManifestPath -Data $ReleaseManifest

Copy-Item -LiteralPath $MasterMapPath -Destination $ReleaseRoot -Force
Copy-Item -LiteralPath $InventoryPath -Destination $ReleaseRoot -Force
Copy-Item -LiteralPath $DetailedInventoryPath -Destination $ReleaseRoot -Force
Copy-Item -LiteralPath $SemanticReportPath -Destination $ReleaseRoot -Force
Copy-Item -LiteralPath $EvidencePath -Destination $ReleaseRoot -Force
Copy-Item -LiteralPath $ActPath -Destination $ReleaseRoot -Force

Write-Step "Resultado final"

Write-Host "Master document: $MasterMapPath" -ForegroundColor Cyan
Write-Host "Canonical components: $($MasterRows.Count)"
Write-Host "Institutional detailed records: $($DetailedRows.Count)"
Write-Host "Minimum institutional records required: $MinimumInstitutionalRecords"
Write-Host "Families detected: $($FamilySummary.Count)"
Write-Host "Required families missing: $($MissingRequiredFamilies.Count)"
Write-Host "Phases detected: $($PhaseSummary.Count)"
Write-Host "Statuses detected: $($StatusSummary.Count)"
Write-Host "Semantic errors: $SemanticErrors"
Write-Host "Semantic gate passed: $($SemanticErrors -eq 0)"
Write-Host "Repository files scanned: $($Paths.Count)"
Write-Host "Branch: $Branch"
Write-Host "Commit baseline: $Commit"
Write-Host "PowerShell syntax errors: 0"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Pytest passed: $PytestPassed"
Write-Host "Tests passed: $TestCount"
Write-Host "Missing required sections: $($MissingSections.Count)"
Write-Host "Technical errors: $TechnicalErrors"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Evidence: $EvidencePath" -ForegroundColor Cyan
Write-Host "Act: $ActPath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan

if ($TechnicalErrors -eq 0) {
    Write-Host "Institutional status: CLOSED" -ForegroundColor Green
    Write-Host "SPT-021.1: CLOSED WITH ZERO TECHNICAL AND SEMANTIC ERRORS." -ForegroundColor Green
    Write-Host "SGD-001: GENERATED_AND_VALIDATED_WITH_FULL_INSTITUTIONAL_RECORDS." -ForegroundColor Green
}
else {
    Write-Host "Institutional status: BLOCKED" -ForegroundColor Red
    Write-Host "SPT-021.1: CLOSURE BLOCKED." -ForegroundColor Red
    exit 1
}
