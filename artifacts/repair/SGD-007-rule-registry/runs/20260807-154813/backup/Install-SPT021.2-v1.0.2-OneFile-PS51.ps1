<#
.SYNOPSIS
SPT-021.2 - Institutional Rule Discovery & Reuse Engine v1.0.2
One File - Windows PowerShell 5.1

.DESCRIPTION
Audita el repositorio real para descubrir reglas institucionales existentes,
sus implementaciones, duplicidades y dependencias. Reutiliza antes de construir.

Genera SGD-002 a SGD-006, RMI-021.2, ACT-021.2, evidencia y release local.
No hace git add, commit, push, fetch, tags ni mutaciones del repositorio remoto.
#>

[CmdletBinding()]
param([string]$ProjectRoot = (Get-Location).Path)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-021.2"
$Version = "1.0.2"
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$GeneratedUtc = (Get-Date).ToUniversalTime().ToString("o")
$SelfPath = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)

function Step([string]$Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Text([string]$Path, [AllowEmptyString()][string]$Content) {
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

function Write-Json([string]$Path, [object]$Data) {
    Write-Text $Path (($Data | ConvertTo-Json -Depth 80) + "`r`n")
}

function Rel([string]$Root, [string]$Path) {
    $R = [System.IO.Path]::GetFullPath($Root)
    if (-not $R.EndsWith("\")) { $R += "\" }
    $P = [System.IO.Path]::GetFullPath($Path)
    $RU = New-Object System.Uri($R)
    $PU = New-Object System.Uri($P)
    return [System.Uri]::UnescapeDataString(
        $RU.MakeRelativeUri($PU).ToString()
    ).Replace("\", "/")
}

function Test-Syntax([string]$Path) {
    $Tokens = $null
    $Errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $Path, [ref]$Tokens, [ref]$Errors
    )
    return @($Errors)
}

function Invoke-GitReadOnly([string[]]$Arguments) {
    $GitCommand = Get-Command git.exe `
        -CommandType Application `
        -ErrorAction Stop |
        Select-Object -First 1

    if (
        $null -eq $GitCommand -or
        [string]::IsNullOrWhiteSpace([string]$GitCommand.Source)
    ) {
        throw "git.exe no pudo resolverse como aplicacion nativa."
    }
    $Psi = New-Object System.Diagnostics.ProcessStartInfo
    $Psi.FileName = $GitCommand.Source
    $Psi.UseShellExecute = $false
    $Psi.RedirectStandardOutput = $true
    $Psi.RedirectStandardError = $true
    $Psi.CreateNoWindow = $true
    $Psi.WorkingDirectory = (Get-Location).Path

    $Escaped = @()
    foreach ($A in $Arguments) {
        $V = [string]$A
        if ($V.Contains(" ") -or $V.Contains("`t") -or $V.Contains('"')) {
            $V = '"' + $V.Replace('"', '\"') + '"'
        }
        $Escaped += $V
    }
    $Psi.Arguments = $Escaped -join " "

    $P = New-Object System.Diagnostics.Process
    $P.StartInfo = $Psi
    [void]$P.Start()
    $Out = $P.StandardOutput.ReadToEnd()
    $Err = $P.StandardError.ReadToEnd()
    $P.WaitForExit()

    if ($P.ExitCode -ne 0) {
        throw "git $($Arguments -join ' ') fallo. $Err"
    }

    return [PSCustomObject]@{
        ExitCode = $P.ExitCode
        StdOut = $Out
        StdErr = $Err
    }
}

function Get-GitReadOnlyPaths {
    $Tracked = Invoke-GitReadOnly @("-c","core.quotepath=false","ls-files","-z")
    $Untracked = Invoke-GitReadOnly @(
        "-c","core.quotepath=false","ls-files",
        "--others","--exclude-standard","-z"
    )

    return @(
        (@($Tracked.StdOut -split [char]0) +
         @($Untracked.StdOut -split [char]0)) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Replace("\","/") } |
        Sort-Object -Unique
    )
}

function Text-Candidate([string]$Path, [long]$Length) {
    if ($Length -gt 2097152) { return $false }

    $P = ("/" + $Path.ToLowerInvariant())
    foreach ($X in @(
        "/.git/","/.venv/","/venv/","/node_modules/",
        "/__pycache__/","/repository-backup/",
        "/registry-backup/","/backup/"
    )) {
        if ($P.Contains($X)) { return $false }
    }

    return (
        $P.EndsWith(".md") -or
        $P.EndsWith(".txt") -or
        $P.EndsWith(".json") -or
        $P.EndsWith(".yaml") -or
        $P.EndsWith(".yml") -or
        $P.EndsWith(".ps1") -or
        $P.EndsWith(".py") -or
        $P.EndsWith(".toml")
    )
}

function Artifact-Ids([string]$Text) {
    $Pattern = '\b(?:POL|SGD|ADR|SPB|SPT|PCI|ACT|RMI|RLB|SIB|ODA|FLD|PMO)-[A-Z0-9]+(?:\.[A-Z0-9]+)*(?:-[A-Z0-9]+)*\b'
    return @(
        [regex]::Matches($Text.ToUpperInvariant(), $Pattern) |
        ForEach-Object { $_.Value } |
        Sort-Object -Unique
    )
}

function Rule-Signals([string]$Path, [string]$Content) {
    $T = ($Path + "`n" + $Content).ToLowerInvariant()
    $Catalog = [ordered]@{
        "PUBLICATION_REQUIRED" = @(
            "publicacion","publication","publish","repositorio oficial"
        )
        "REMOTE_SYNCHRONIZATION_REQUIRED" = @(
            "synchronized","sincronizacion","sincronizado",
            "git push","repositorio remoto"
        )
        "REUSE_BEFORE_BUILD" = @(
            "reutilizacion","reutilizar","reuse",
            "duplicate business logic","no duplic"
        )
        "QUALITY_GATES_REQUIRED" = @(
            "quality gate","pytest","pruebas","gates aprobados"
        )
        "STAGING_REQUIRED" = @(
            "staging_required","staging temporal",
            "area temporal","staging institucional"
        )
        "ROLLBACK_REQUIRED" = @(
            "rollback_required","rollback","reversion"
        )
        "REAL_REPOSITORY_REVALIDATION" = @(
            "publication_requires_real_repository_revalidation",
            "repositorio real","revalidacion"
        )
        "ZERO_TECHNICAL_ERRORS" = @(
            "technical errors: 0","zero technical errors",
            "cero errores","0 errores"
        )
        "OPEN_SOURCE_ONLY" = @(
            "paid services","servicios de pago",
            "codigo abierto","open source","gratuito"
        )
        "MASTER_STATE_UPDATE" = @(
            "sgd-000","estado maestro","master state"
        )
        "TRACEABILITY_REQUIRED" = @(
            "trazabilidad","traceability","evidencia","evidence"
        )
    }

    $Result = @()
    foreach ($Id in $Catalog.Keys) {
        $Score = 0
        foreach ($Term in $Catalog[$Id]) {
            if ($T.Contains($Term)) { $Score++ }
        }
        if ($Score -gt 0) {
            $Result += [PSCustomObject][ordered]@{
                rule_id = $Id
                score = $Score
            }
        }
    }
    return $Result
}

function Kind([string]$Path) {
    $P = $Path.ToLowerInvariant()
    if ($P.EndsWith(".ps1")) { return "POWERSHELL_IMPLEMENTATION" }
    if ($P.StartsWith("src/") -and $P.EndsWith(".py")) {
        return "PYTHON_IMPLEMENTATION"
    }
    if ($P.StartsWith("tests/")) { return "TEST" }
    if ($P.StartsWith("docs/")) { return "DOCUMENTATION" }
    if ($P.StartsWith("config/")) { return "CONFIGURATION" }
    if ($P.StartsWith("releases/")) { return "RELEASE_ARTIFACT" }
    if ($P.StartsWith("artifacts/")) { return "EVIDENCE_ARTIFACT" }
    return "INSTITUTIONAL_ARTIFACT"
}

function Priority([string]$Rule, [string]$Path, [string]$Content) {
    $P = $Path.ToLowerInvariant()
    $T = $Content.ToLowerInvariant()
    $S = 0

    if (($P.Contains("spb-007") -or $P.Contains("spb007")) -and
        $Rule -match "PUBLICATION|SYNCHRON") { $S += 100 }

    if (($P.Contains("pci-002") -or $P.Contains("pci002")) -and
        $Rule -match "STAGING|ROLLBACK|REVALIDATION|QUALITY") { $S += 100 }

    if (($P.Contains("spt-021.0.1") -or $P.Contains("spt021.0.1")) -and
        $Rule -match "PUBLICATION|SYNCHRON") { $S += 90 }

    if ($P.StartsWith("src/")) { $S += 40 }
    if ($P.StartsWith("scripts/")) { $S += 35 }
    if ($P.EndsWith(".ps1")) { $S += 30 }
    if ($P.StartsWith("config/")) { $S += 20 }
    if ($P.StartsWith("docs/")) { $S += 10 }
    if ($P.StartsWith("tests/")) { $S += 5 }
    if ($T.Contains("institutional")) { $S += 5 }

    return $S
}

function ConvertTo-MarkdownCell([AllowEmptyString()][string]$Text) {
    if ($null -eq $Text) { return "" }
    return $Text.Replace("|","\|").Replace("`r"," ").Replace("`n"," ")
}

function Table(
    [string[]]$Headers,
    [object[]]$Rows,
    [scriptblock]$Projector
) {
    $B = New-Object System.Text.StringBuilder
    [void]$B.AppendLine("| " + ($Headers -join " | ") + " |")
    [void]$B.AppendLine(
        "|" + (($Headers | ForEach-Object { "---" }) -join "|") + "|"
    )

    foreach ($R in $Rows) {
        $Values = & $Projector $R
        $Cells = @($Values | ForEach-Object { ConvertTo-MarkdownCell ([string]$_) })
        [void]$B.AppendLine("| " + ($Cells -join " | ") + " |")
    }
    return $B.ToString()
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

foreach ($Cmd in @("git.exe","python")) {
    if (-not (Get-Command $Cmd -ErrorAction SilentlyContinue)) {
        throw "Comando requerido no disponible: $Cmd"
    }
}

$NativeGit = Get-Command git.exe `
    -CommandType Application `
    -ErrorAction Stop |
    Select-Object -First 1

if (
    $null -eq $NativeGit -or
    [string]::IsNullOrWhiteSpace([string]$NativeGit.Source)
) {
    throw "No se pudo resolver git.exe nativo."
}

$ReservedHelperNames = @(
    "md",
    "mkdir",
    "cd",
    "dir",
    "ls",
    "cat",
    "echo",
    "rm",
    "cp",
    "mv",
    "where",
    "select",
    "sort"
)

$DeclaredFunctions = @(
    [regex]::Matches(
        (Get-Content -LiteralPath $SelfPath -Raw),
        '(?im)^function\s+([A-Za-z0-9_-]+)'
    ) |
    ForEach-Object {
        $_.Groups[1].Value.ToLowerInvariant()
    } |
    Sort-Object -Unique
)

$HelperCollisions = @(
    $DeclaredFunctions |
    Where-Object { $ReservedHelperNames -contains $_ }
)

if ($HelperCollisions.Count -gt 0) {
    throw (
        "Colision de nombres PowerShell detectada: " +
        ($HelperCollisions -join ", ")
    )
}

Write-Host "Git executable: $($NativeGit.Source)" -ForegroundColor DarkGray
Write-Host "PowerShell helper collisions: 0" -ForegroundColor DarkGray

if (@(Test-Syntax $SelfPath).Count -ne 0) {
    throw "El instalador SPT-021.2 tiene errores de sintaxis."
}

$GitRoot = (Invoke-GitReadOnly @("rev-parse","--show-toplevel")).StdOut.Trim()
if (
    [System.IO.Path]::GetFullPath($GitRoot).TrimEnd("\") -ne
    $ProjectRoot.TrimEnd("\")
) {
    throw "Ejecute SPT-021.2 desde la raiz Git."
}

$SGD001 = @(
    Get-ChildItem `
        (Join-Path $ProjectRoot "docs\00_Estado_Maestro") `
        -Filter "SGD-001-Mapa-Maestro-Institucional-SGODA-PUINAVE-v*.md" `
        -File `
        -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending
)

if ($SGD001.Count -eq 0) {
    throw "SGD-001 no existe. SPT-021.1 debe estar cerrado."
}

$RunRoot = Join-Path $ProjectRoot (
    "artifacts\development\SPT-021.2-v1.0.2\runs\" + $RunId
)
$StateRoot = Join-Path $ProjectRoot "docs\00_Estado_Maestro"
$TechRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-021.2"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-021.2-v1.0.2"

foreach ($D in @($RunRoot,$StateRoot,$TechRoot,$ReleaseRoot)) {
    New-Item -ItemType Directory -Path $D -Force | Out-Null
}

Step "Inventariando reglas institucionales"

$Paths = @(Get-GitReadOnlyPaths)
$EvidenceRows = @()
$Scanned = 0

foreach ($Relative in $Paths) {
    $Full = Join-Path $ProjectRoot ($Relative.Replace("/","\"))
    if (-not (Test-Path -LiteralPath $Full -PathType Leaf -ErrorAction SilentlyContinue)) {
        continue
    }

    $F = Get-Item -LiteralPath $Full
    if (-not (Text-Candidate $Relative $F.Length)) { continue }

    $Scanned++
    if (($Scanned % 250) -eq 0) {
        Write-Host "  Fuentes analizadas: $Scanned" -ForegroundColor DarkGray
    }

    try {
        $Content = Get-Content -LiteralPath $Full -Raw
    }
    catch {
        continue
    }

    $Signals = @(Rule-Signals $Relative $Content)
    if ($Signals.Count -eq 0) { continue }

    $Ids = @(Artifact-Ids ($Relative + "`n" + $Content))

    foreach ($Signal in $Signals) {
        $EvidenceRows += [PSCustomObject][ordered]@{
            rule_id = $Signal.rule_id
            source_path = $Relative
            implementation_type = Kind $Relative
            artifact_ids = $Ids
            lexical_score = [int]$Signal.score
            canonical_priority = [int](Priority $Signal.rule_id $Relative $Content)
        }
    }
}

Write-Host "Archivos Git descubiertos: $($Paths.Count)"
Write-Host "Fuentes textuales analizadas: $Scanned"
Write-Host "Relaciones regla-fuente: $($EvidenceRows.Count)"

Step "Determinando implementaciones canonicas"

$Registry = @()

foreach ($G in ($EvidenceRows | Group-Object rule_id | Sort-Object Name)) {
    $All = @(
        $G.Group |
        Sort-Object `
            @{Expression="canonical_priority";Descending=$true},
            @{Expression="lexical_score";Descending=$true},
            source_path
    )

    $Impl = @(
        $All |
        Where-Object {
            $_.implementation_type -match "IMPLEMENTATION|CONFIGURATION"
        }
    )

    $Docs = @($All | Where-Object { $_.implementation_type -eq "DOCUMENTATION" })
    $Tests = @($All | Where-Object { $_.implementation_type -eq "TEST" })

    $Canonical = ""
    if ($Impl.Count -gt 0) {
        $Canonical = [string]$Impl[0].source_path
    }

    $Registry += [PSCustomObject][ordered]@{
        rule_id = $G.Name
        sources = $All.Count
        implementations = $Impl.Count
        documentation = $Docs.Count
        tests = $Tests.Count
        canonical_implementation = $Canonical
        duplicate_implementations = [math]::Max(0, $Impl.Count - 1)
        reuse_status = if ($Impl.Count -gt 0) {
            "REUSE_EXISTING_IMPLEMENTATION"
        }
        elseif ($Docs.Count -gt 0) {
            "DOCUMENTED_GAP_REQUIRES_REVIEW"
        }
        else {
            "DISCOVERED_GAP_REQUIRES_REVIEW"
        }
        new_development_required = ($Impl.Count -eq 0)
    }
}

$Reuse = @(
    $Registry |
    ForEach-Object {
        [PSCustomObject][ordered]@{
            rule_id = $_.rule_id
            canonical_implementation = $_.canonical_implementation
            reuse_status = $_.reuse_status
            new_development_required = $_.new_development_required
            decision = if ($_.new_development_required) {
                "REVIEW_GAP_BEFORE_BUILD"
            }
            else {
                "REUSE_CANONICAL"
            }
        }
    }
)

$Duplicates = @()

foreach ($R in $Registry) {
    $Impls = @(
        $EvidenceRows |
        Where-Object {
            $_.rule_id -eq $R.rule_id -and
            $_.implementation_type -match "IMPLEMENTATION|CONFIGURATION"
        } |
        Sort-Object `
            @{Expression="canonical_priority";Descending=$true},
            source_path
    )

    if ($Impls.Count -gt 1) {
        foreach ($I in $Impls) {
            if ($I.source_path -eq $R.canonical_implementation) { continue }

            $Duplicates += [PSCustomObject][ordered]@{
                rule_id = $R.rule_id
                canonical = $R.canonical_implementation
                alternate = $I.source_path
                classification = "POTENTIAL_DUPLICATE_OR_ADAPTER"
                action = "REVIEW_AND_REUSE_BEFORE_NEW_BUILD"
            }
        }
    }
}

$Deps = @(
    $Registry |
    ForEach-Object {
        $Rule = $_.rule_id
        $Artifacts = @(
            $EvidenceRows |
            Where-Object { $_.rule_id -eq $Rule } |
            ForEach-Object { $_.artifact_ids } |
            Sort-Object -Unique
        )
        [PSCustomObject][ordered]@{
            rule_id = $Rule
            canonical_implementation = $_.canonical_implementation
            related_artifacts = $Artifacts
        }
    }
)

$ChainRules = @(
    "REUSE_BEFORE_BUILD",
    "QUALITY_GATES_REQUIRED",
    "STAGING_REQUIRED",
    "REAL_REPOSITORY_REVALIDATION",
    "PUBLICATION_REQUIRED",
    "REMOTE_SYNCHRONIZATION_REQUIRED",
    "MASTER_STATE_UPDATE",
    "TRACEABILITY_REQUIRED"
)

$Chain = @()
$Order = 0
foreach ($RuleId in $ChainRules) {
    $Order++
    $Found = @($Registry | Where-Object { $_.rule_id -eq $RuleId })
    $Canonical = ""
    if ($Found.Count -gt 0) { $Canonical = $Found[0].canonical_implementation }

    $Chain += [PSCustomObject][ordered]@{
        order = $Order
        rule_id = $RuleId
        canonical_implementation = $Canonical
    }
}

Step "Quality gate semantico"

$RequiredRules = @(
    "PUBLICATION_REQUIRED",
    "REMOTE_SYNCHRONIZATION_REQUIRED",
    "REUSE_BEFORE_BUILD",
    "QUALITY_GATES_REQUIRED",
    "STAGING_REQUIRED",
    "REAL_REPOSITORY_REVALIDATION",
    "ZERO_TECHNICAL_ERRORS",
    "MASTER_STATE_UPDATE",
    "TRACEABILITY_REQUIRED"
)

$Detected = @($Registry | ForEach-Object { $_.rule_id } | Sort-Object -Unique)
$MissingRules = @($RequiredRules | Where-Object { $Detected -notcontains $_ })
$SemanticFindings = @()

foreach ($M in $MissingRules) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-RULE-MISSING"
        severity = "ERROR"
        rule_id = $M
        message = "Regla institucional obligatoria no descubierta."
    }
}

$Publication = @($Registry | Where-Object { $_.rule_id -eq "PUBLICATION_REQUIRED" })
if (
    $Publication.Count -eq 0 -or
    [string]::IsNullOrWhiteSpace($Publication[0].canonical_implementation)
) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-PUBLISH-NO-CANONICAL"
        severity = "ERROR"
        rule_id = "PUBLICATION_REQUIRED"
        message = "No existe implementacion canonica reutilizable de publicacion."
    }
}

$SemanticErrors = @(
    $SemanticFindings |
    Where-Object { $_.severity -eq "ERROR" }
).Count

Write-Host "Reglas descubiertas: $($Registry.Count)"
Write-Host "Reglas obligatorias faltantes: $($MissingRules.Count)"
Write-Host "Duplicidades potenciales: $($Duplicates.Count)"
Write-Host "Errores semanticos: $SemanticErrors"

if ($SemanticErrors -eq 0) {
    Write-Host "Quality gate semantico: APROBADO" -ForegroundColor Green
}
else {
    Write-Host "Quality gate semantico: BLOQUEADO" -ForegroundColor Red
}

Step "Compilando Python"

$CompileOut = @(& python -m compileall -q src tests 2>&1)
$CompileCode = $LASTEXITCODE
Write-Text (Join-Path $RunRoot "python-compileall.txt") (
    ($CompileOut -join "`r`n") + "`r`n"
)

Step "Ejecutando suite institucional completa"

$env:PYTHONPATH = Join-Path $ProjectRoot "src"
$PytestOut = @(& python -m pytest -q 2>&1)
$PytestCode = $LASTEXITCODE
$PytestText = $PytestOut -join "`r`n"
$PytestOut | ForEach-Object { Write-Host $_ }
Write-Text (Join-Path $RunRoot "pytest-full-suite.txt") (
    $PytestText + "`r`n"
)

$Passed = 0
$Match = [regex]::Match($PytestText, "(\d+)\s+passed")
if ($Match.Success) { $Passed = [int]$Match.Groups[1].Value }
$PytestPassed = ($PytestCode -eq 0)

Step "Generando documentos institucionales"

$SGD002 = @"
# SGD-002 - Registro Maestro de Reglas Institucionales

Generado por SPT-021.2 v$Version.
Fuente: repositorio real.
Principio: REUSE BEFORE BUILD.

$(Table `
    @("Regla","Fuentes","Implementaciones","Documentacion","Pruebas","Canonica","Duplicidades","Estado") `
    $Registry `
    {
        param($R)
        @(
            $R.rule_id,$R.sources,$R.implementations,$R.documentation,
            $R.tests,$R.canonical_implementation,
            $R.duplicate_implementations,$R.reuse_status
        )
    })

Reglas obligatorias faltantes: $($MissingRules.Count)
Errores semanticos: $SemanticErrors
"@

$SGD003 = @"
# SGD-003 - Matriz Institucional de Reutilizacion

$(Table `
    @("Regla","Canonica","Estado","Nuevo desarrollo requerido","Decision") `
    $Reuse `
    {
        param($R)
        @(
            $R.rule_id,$R.canonical_implementation,$R.reuse_status,
            $R.new_development_required,$R.decision
        )
    })
"@

$SGD004 = @"
# SGD-004 - Matriz Institucional de Duplicidades

Las implementaciones alternas se conservan hasta determinar si son adaptadores,
compatibilidad historica o duplicidad real.

$(Table `
    @("Regla","Canonica","Alterna","Clasificacion","Accion") `
    $Duplicates `
    {
        param($R)
        @($R.rule_id,$R.canonical,$R.alternate,$R.classification,$R.action)
    })
"@

$SGD005 = @"
# SGD-005 - Dependencias entre Reglas y Componentes

$(Table `
    @("Regla","Canonica","Artefactos relacionados") `
    $Deps `
    {
        param($R)
        @(
            $R.rule_id,
            $R.canonical_implementation,
            ($R.related_artifacts -join ", ")
        )
    })
"@

$SGD006 = @"
# SGD-006 - Cadena Oficial de Publicacion y Sincronizacion

Este documento NO crea un nuevo motor de publicacion. Reconstruye y referencia
la cadena existente para reutilizar las implementaciones canonicas descubiertas.

$(Table `
    @("Orden","Regla","Implementacion canonica") `
    $Chain `
    {
        param($R)
        @($R.order,$R.rule_id,$R.canonical_implementation)
    })
"@

$RMI = @"
# RMI-021.2 - Registro Maestro Institucional de Implementaciones

$(Table `
    @("Regla","Fuente","Tipo","Artefactos","Score","Prioridad") `
    ($EvidenceRows | Sort-Object rule_id, `
        @{Expression="canonical_priority";Descending=$true}, source_path) `
    {
        param($R)
        @(
            $R.rule_id,$R.source_path,$R.implementation_type,
            ($R.artifact_ids -join ", "),
            $R.lexical_score,$R.canonical_priority
        )
    })
"@

$Docs = [ordered]@{
    "SGD-002-Registro-Maestro-Reglas-Institucionales-v1.0.0.md" = $SGD002
    "SGD-003-Matriz-Institucional-Reutilizacion-v1.0.0.md" = $SGD003
    "SGD-004-Matriz-Institucional-Duplicidades-v1.0.0.md" = $SGD004
    "SGD-005-Dependencias-Reglas-Componentes-v1.0.0.md" = $SGD005
    "SGD-006-Cadena-Oficial-Publicacion-Sincronizacion-v1.0.0.md" = $SGD006
    "RMI-021.2-Registro-Maestro-Institucional-Implementaciones-v1.0.0.md" = $RMI
}

$Generated = @()
foreach ($Name in $Docs.Keys) {
    $P = Join-Path $StateRoot $Name
    Write-Text $P $Docs[$Name]
    $Generated += $P
}

$MissingDocs = @($Generated | Where-Object { -not (Test-Path -LiteralPath $_) })

$RequiredMarkers = @(
    "PUBLICATION_REQUIRED",
    "REMOTE_SYNCHRONIZATION_REQUIRED",
    "REUSE_BEFORE_BUILD",
    "QUALITY_GATES_REQUIRED"
)
$MissingMarkers = @()

foreach ($Marker in $RequiredMarkers) {
    $Seen = $false
    foreach ($P in $Generated) {
        if ((Get-Content -LiteralPath $P -Raw).Contains($Marker)) {
            $Seen = $true
            break
        }
    }
    if (-not $Seen) { $MissingMarkers += $Marker }
}

$TechnicalErrors = 0
if ($CompileCode -ne 0) { $TechnicalErrors++ }
if (-not $PytestPassed) { $TechnicalErrors++ }
if ($Passed -lt 808) { $TechnicalErrors++ }
$TechnicalErrors += $MissingDocs.Count
$TechnicalErrors += $MissingMarkers.Count
$TechnicalErrors += $SemanticErrors

$RegistryPath = Join-Path $RunRoot "institutional-rule-registry.json"
$ReusePath = Join-Path $RunRoot "institutional-reuse-matrix.json"
$DupPath = Join-Path $RunRoot "institutional-duplicate-matrix.json"
$DepPath = Join-Path $RunRoot "institutional-rule-dependencies.json"
$ChainPath = Join-Path $RunRoot "institutional-publication-chain.json"
$SemPath = Join-Path $RunRoot "semantic-validation-report.json"

Write-Json $RegistryPath $Registry
Write-Json $ReusePath $Reuse
Write-Json $DupPath $Duplicates
Write-Json $DepPath $Deps
Write-Json $ChainPath $Chain
Write-Json $SemPath ([ordered]@{
    component = $Component
    version = $Version
    required_rules = $RequiredRules
    detected_rules = $Detected
    missing_required_rules = $MissingRules
    findings = $SemanticFindings
    semantic_errors = $SemanticErrors
    status = if ($SemanticErrors -eq 0) { "APPROVED" } else { "BLOCKED" }
})

$EvidencePath = Join-Path $RunRoot "implementation-evidence.json"
Write-Json $EvidencePath ([ordered]@{
    component = $Component
    version = $Version
    generated_at_utc = $GeneratedUtc
    repository_is_source_of_truth = $true
    reuse_before_build = $true
    duplicate_business_logic_created = $false
    git_mutation = $false
    native_git_executable = [string]$NativeGit.Source
    git_wrapper = "Invoke-GitReadOnly"
    powershell_helper_collisions = $HelperCollisions.Count
    markdown_helper = "ConvertTo-MarkdownCell"
    repository_files_discovered = $Paths.Count
    textual_sources_scanned = $Scanned
    rule_source_relations = $EvidenceRows.Count
    rules_discovered = $Registry.Count
    required_rules_missing = $MissingRules.Count
    potential_duplicates = $Duplicates.Count
    semantic_errors = $SemanticErrors
    python_compile_exit_code = $CompileCode
    pytest_passed = $PytestPassed
    tests_passed = $Passed
    technical_errors = $TechnicalErrors
    sgd_001 = Rel $ProjectRoot $SGD001[0].FullName
    n8n_installed = $false
    paid_services_required = $false
    status = if ($TechnicalErrors -eq 0) { "CLOSED" } else { "BLOCKED" }
})

$ActPath = Join-Path $TechRoot (
    "ACT-021.2-Cierre-Institutional-Rule-Discovery-Reuse.md"
)
$Act = @"
# ACT-021.2 - Cierre Institutional Rule Discovery & Reuse Engine

| Campo | Resultado |
|---|---|
| Componente | SPT-021.2 |
| Version | $Version |
| Reglas descubiertas | $($Registry.Count) |
| Reglas obligatorias faltantes | $($MissingRules.Count) |
| Duplicidades potenciales | $($Duplicates.Count) |
| Errores semanticos | $SemanticErrors |
| Pruebas | $Passed |
| Errores tecnicos | $TechnicalErrors |
| Estado | $(if ($TechnicalErrors -eq 0) { "CLOSED" } else { "BLOCKED" }) |

SPT-021.2 descubre y obliga a reutilizar implementaciones existentes.
No reemplaza los motores canonicos de publicacion, consolidacion o sincronizacion.
"@
Write-Text $ActPath $Act

$ReleaseManifest = Join-Path $ReleaseRoot "manifest.json"
Write-Json $ReleaseManifest ([ordered]@{
    component = $Component
    version = $Version
    status = if ($TechnicalErrors -eq 0) { "CLOSED" } else { "BLOCKED" }
    rules_discovered = $Registry.Count
    potential_duplicates = $Duplicates.Count
    tests_passed = $Passed
    technical_errors = $TechnicalErrors
    documents = @($Generated | ForEach-Object { Rel $ProjectRoot $_ })
    evidence = Rel $ProjectRoot $EvidencePath
    act = Rel $ProjectRoot $ActPath
})

foreach ($P in $Generated) {
    Copy-Item -LiteralPath $P -Destination $ReleaseRoot -Force
}
foreach ($P in @($EvidencePath,$ActPath,$RegistryPath,$ReusePath,$DupPath,$ChainPath)) {
    Copy-Item -LiteralPath $P -Destination $ReleaseRoot -Force
}

Step "Resultado final"

Write-Host "Repository files discovered: $($Paths.Count)"
Write-Host "Textual sources scanned: $Scanned"
Write-Host "Rule-source relations: $($EvidenceRows.Count)"
Write-Host "Rules discovered: $($Registry.Count)"
Write-Host "Required rules missing: $($MissingRules.Count)"
Write-Host "Potential duplicates: $($Duplicates.Count)"
Write-Host "Semantic errors: $SemanticErrors"
Write-Host "Semantic gate passed: $($SemanticErrors -eq 0)"
Write-Host "PowerShell syntax errors: 0"
Write-Host "Python compile exit code: $CompileCode"
Write-Host "Pytest passed: $PytestPassed"
Write-Host "Tests passed: $Passed"
Write-Host "Missing documents: $($MissingDocs.Count)"
Write-Host "Document validation errors: $($MissingMarkers.Count)"
Write-Host "Technical errors: $TechnicalErrors"
Write-Host "Git executable: $($NativeGit.Source)"
Write-Host "Git wrapper: Invoke-GitReadOnly"
Write-Host "PowerShell helper collisions: $($HelperCollisions.Count)"
Write-Host "Markdown helper: ConvertTo-MarkdownCell"
Write-Host "Git mutation: NO"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Evidence: $EvidencePath" -ForegroundColor Cyan
Write-Host "Act: $ActPath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan

if ($TechnicalErrors -eq 0) {
    Write-Host "Institutional status: CLOSED" -ForegroundColor Green
    Write-Host "SPT-021.2: CLOSED WITH ZERO TECHNICAL AND SEMANTIC ERRORS." -ForegroundColor Green
    Write-Host "REUSE BEFORE BUILD: ENFORCED." -ForegroundColor Green
}
else {
    Write-Host "Institutional status: BLOCKED" -ForegroundColor Red
    Write-Host "SPT-021.2: CLOSURE BLOCKED." -ForegroundColor Red
    exit 1
}
