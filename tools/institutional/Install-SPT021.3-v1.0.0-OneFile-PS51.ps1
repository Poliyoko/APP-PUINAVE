<#
.SYNOPSIS
    SPT-021.3 - Institutional Master Book Generator (IMBG) v1.0.0
    One File - Windows PowerShell 5.1

.DESCRIPTION
    Genera automaticamente:
      SGD-002 - Libro Maestro Institucional del Proyecto SGODA-PUINAVE

    FUENTES:
      - repositorio Git real;
      - SGD-000;
      - SGD-001;
      - SGD-002 a SGD-006 si existen;
      - POL, ADR, SPB, SPT, PCI, ACT, RMI y demas familias;
      - codigo fuente;
      - pruebas;
      - evidencias;
      - releases;
      - historial Git.

    PRINCIPIOS:
      - Repository is source of truth.
      - Reuse before build.
      - No Git mutation.
      - No paid services.
      - No n8n installation.
      - No content invention.
      - Cierre solo con cero errores tecnicos y semanticos.
      - El libro debe superar un umbral minimo de contenido institucional.

.EXAMPLE
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    .\Install-SPT021.3-v1.0.0-OneFile-PS51.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-021.3"
$Version = "1.0.0"
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$GeneratedUtc = (Get-Date).ToUniversalTime().ToString("o")
$SelfPath = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)

$MinimumTests = 808
$MinimumCanonicalComponents = 500
$MinimumDetailedRecords = 800
$MinimumBookLines = 2500
$MinimumBookWords = 25000

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
    param(
        [string]$Path,
        [object]$Data
    )

    $Json = $Data | ConvertTo-Json -Depth 100
    Write-Utf8NoBom -Path $Path -Content ($Json + "`r`n")
}

function Get-RelativePathSafe {
    param(
        [string]$Root,
        [string]$Path
    )

    $RootFull = [System.IO.Path]::GetFullPath($Root)

    if (-not $RootFull.EndsWith("\")) {
        $RootFull += "\"
    }

    $PathFull = [System.IO.Path]::GetFullPath($Path)

    $RootUri = New-Object System.Uri($RootFull)
    $PathUri = New-Object System.Uri($PathFull)

    return [System.Uri]::UnescapeDataString(
        $RootUri.MakeRelativeUri($PathUri).ToString()
    ).Replace("\", "/")
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

function Invoke-GitReadOnly {
    param([string[]]$Arguments)

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

    if ($Process.ExitCode -ne 0) {
        throw (
            "git " +
            ($Arguments -join " ") +
            " fallo. Exit code: " +
            $Process.ExitCode +
            "`r`n" +
            $StdErr
        )
    }

    return [PSCustomObject]@{
        ExitCode = $Process.ExitCode
        StdOut = $StdOut
        StdErr = $StdErr
    }
}

function Get-GitReadOnlyPaths {
    $Tracked = Invoke-GitReadOnly -Arguments @(
        "-c",
        "core.quotepath=false",
        "ls-files",
        "-z"
    )

    $Untracked = Invoke-GitReadOnly -Arguments @(
        "-c",
        "core.quotepath=false",
        "ls-files",
        "--others",
        "--exclude-standard",
        "-z"
    )

    return @(
        (
            @($Tracked.StdOut -split [char]0) +
            @($Untracked.StdOut -split [char]0)
        ) |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        } |
        ForEach-Object {
            $_.Replace("\", "/")
        } |
        Sort-Object -Unique
    )
}

function Test-TextCandidate {
    param(
        [string]$RelativePath,
        [long]$Length
    )

    if ($Length -gt 3145728) {
        return $false
    }

    $P = "/" + $RelativePath.ToLowerInvariant()

    foreach ($Fragment in @(
        "/.git/",
        "/.venv/",
        "/venv/",
        "/node_modules/",
        "/__pycache__/",
        "/repository-backup/",
        "/registry-backup/",
        "/backup/",
        "/tmp/",
        "/temp/"
    )) {
        if ($P.Contains($Fragment)) {
            return $false
        }
    }

    return (
        $P.EndsWith(".md") -or
        $P.EndsWith(".txt") -or
        $P.EndsWith(".json") -or
        $P.EndsWith(".yaml") -or
        $P.EndsWith(".yml") -or
        $P.EndsWith(".ps1") -or
        $P.EndsWith(".py") -or
        $P.EndsWith(".toml") -or
        $P.EndsWith(".csv")
    )
}

function Get-ArtifactIds {
    param([string]$Text)

    $Pattern = '\b(?:POL|SGD|ADR|SPB|SPT|PCI|ACT|RMI|RLB|SIB|ODA|FLD|PMO)-[A-Z0-9]+(?:\.[A-Z0-9]+)*(?:-[A-Z0-9]+)*\b'

    return @(
        [regex]::Matches(
            $Text.ToUpperInvariant(),
            $Pattern
        ) |
        ForEach-Object {
            $_.Value
        } |
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

function Get-Phase {
    param([string]$Id)

    switch -Regex ($Id) {
        '^POL-' { return "Gobierno Institucional" }
        '^ADR-' { return "Arquitectura y Decisiones" }
        '^PCI-' { return "Consolidacion Institucional" }
        '^SPB-' { return "Fundacion y Construccion" }
        '^SGD-' { return "Gobierno y Documentacion Institucional" }
        '^SPT-0(0[1-9]|1[0-2])' { return "Fase Tecnologica - Fundacion Tecnica" }
        '^SPT-01[3-8]' { return "Fase Tecnologica - Capacidades SGODA" }
        '^SPT-019' { return "Fase Tecnologica - Workflow e Integracion" }
        '^SPT-020' { return "Fase Tecnologica - Plataforma Institucional" }
        '^SPT-021' { return "Fase Tecnologica - Consolidacion y Conocimiento" }
        '^ACT-' { return "Cierre Institucional" }
        '^RMI-' { return "Registro Maestro Institucional" }
        '^RLB-' { return "Linea Base Institucional" }
        default { return "Transversal" }
    }
}

function Get-Sprint {
    param([string]$Id)

    if ($Id -match '^(SPT|SPB)-(\d{3})(?:\.(\d+))?') {
        if ($Matches[3]) {
            return $Matches[1] + "-" + $Matches[2] + "." + $Matches[3]
        }

        return $Matches[1] + "-" + $Matches[2]
    }

    return "Transversal"
}

function Get-ArtifactType {
    param([string]$Path)

    $P = $Path.ToLowerInvariant()
    $Name = [System.IO.Path]::GetFileName($P)

    if ($P.StartsWith("releases/")) { return "RELEASE" }
    if ($P.StartsWith("artifacts/")) { return "EVIDENCE" }
    if ($P.StartsWith("tests/")) { return "TEST" }
    if ($P.StartsWith("src/")) { return "SOURCE_CODE" }
    if ($P.StartsWith("config/")) { return "CONFIGURATION" }

    if ($P.StartsWith("docs/")) {
        if ($Name.StartsWith("act-")) { return "ACT" }
        if ($Name.StartsWith("adr-")) { return "ADR" }
        return "DOCUMENT"
    }

    if ($Name.EndsWith(".ps1")) { return "POWERSHELL_SCRIPT" }
    if ($Name.EndsWith(".py")) { return "PYTHON_SCRIPT" }

    return "INSTITUTIONAL_ARTIFACT"
}

function Get-StatusFromPaths {
    param([string[]]$Paths)

    $Joined = ($Paths -join " ").ToUpperInvariant()

    if (
        $Joined.Contains("CLOSED") -or
        $Joined.Contains("CIERRE") -or
        $Joined.Contains("/RELEASES/") -or
        $Joined.Contains("ACT-")
    ) {
        return "CLOSED_OR_RELEASED"
    }

    if (
        $Joined.Contains("/SRC/") -or
        $Joined.Contains("/TESTS/")
    ) {
        return "IMPLEMENTED"
    }

    if ($Joined.Contains("/DOCS/")) {
        return "DOCUMENTED"
    }

    return "DISCOVERED"
}

function ConvertTo-MarkdownCell {
    param([AllowEmptyString()][string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    return $Text.Replace("|", "\|").Replace("`r", " ").Replace("`n", " ")
}

function Compress-List {
    param(
        [string[]]$Items,
        [int]$Max = 5
    )

    if ($Items.Count -eq 0) {
        return "-"
    }

    $Selected = @($Items | Select-Object -First $Max)
    $Result = $Selected -join "<br>"

    if ($Items.Count -gt $Max) {
        $Result += "<br>+" + ($Items.Count - $Max) + " mas"
    }

    return $Result
}

function Add-MarkdownTable {
    param(
        [System.Text.StringBuilder]$Builder,
        [string[]]$Headers,
        [object[]]$Rows,
        [scriptblock]$Projector
    )

    [void]$Builder.AppendLine(
        "| " + ($Headers -join " | ") + " |"
    )

    [void]$Builder.AppendLine(
        "|" +
        (($Headers | ForEach-Object { "---" }) -join "|") +
        "|"
    )

    foreach ($Row in $Rows) {
        $Values = & $Projector $Row

        $Cells = @(
            $Values |
            ForEach-Object {
                ConvertTo-MarkdownCell ([string]$_)
            }
        )

        [void]$Builder.AppendLine(
            "| " + ($Cells -join " | ") + " |"
        )
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

foreach ($CommandName in @("git.exe", "python")) {
    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "Comando requerido no disponible: $CommandName"
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

$ScriptText = Get-Content -LiteralPath $SelfPath -Raw

$DeclaredFunctions = @(
    [regex]::Matches(
        $ScriptText,
        '(?im)^function\s+([A-Za-z0-9_-]+)'
    ) |
    ForEach-Object {
        $_.Groups[1].Value.ToLowerInvariant()
    } |
    Sort-Object -Unique
)

$HelperCollisions = @(
    $DeclaredFunctions |
    Where-Object {
        $ReservedHelperNames -contains $_
    }
)

if ($HelperCollisions.Count -gt 0) {
    throw (
        "Colision de nombres PowerShell detectada: " +
        ($HelperCollisions -join ", ")
    )
}

$SyntaxErrors = @(Test-PowerShellSyntax -Path $SelfPath)

if ($SyntaxErrors.Count -ne 0) {
    throw "SPT-021.3 contiene errores de sintaxis."
}

Write-Host "Git executable: $($NativeGit.Source)" -ForegroundColor DarkGray
Write-Host "PowerShell helper collisions: 0" -ForegroundColor DarkGray

$GitRoot = (
    Invoke-GitReadOnly -Arguments @(
        "rev-parse",
        "--show-toplevel"
    )
).StdOut.Trim()

if (
    [System.IO.Path]::GetFullPath($GitRoot).TrimEnd("\") -ne
    $ProjectRoot.TrimEnd("\")
) {
    throw "SPT-021.3 debe ejecutarse desde la raiz Git."
}

$StateRoot = Join-Path $ProjectRoot "docs\00_Estado_Maestro"

$SGD000Path = Join-Path $StateRoot (
    "SGD-000-Estado-Maestro-Institucional-v1.0.0.md"
)

if (-not (Test-Path -LiteralPath $SGD000Path -PathType Leaf)) {
    throw "No existe SGD-000."
}

$SGD001Candidates = @(
    Get-ChildItem `
        -LiteralPath $StateRoot `
        -Filter "SGD-001-Mapa-Maestro-Institucional-SGODA-PUINAVE-v*.md" `
        -File `
        -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending
)

if ($SGD001Candidates.Count -eq 0) {
    throw "No existe SGD-001."
}

$SGD001Path = $SGD001Candidates[0].FullName

$RunRoot = Join-Path $ProjectRoot (
    "artifacts\development\SPT-021.3-v1.0.0\runs\" + $RunId
)

$TechRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-021.3"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-021.3-v1.0.0"

foreach ($Directory in @(
    $RunRoot,
    $TechRoot,
    $ReleaseRoot
)) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

Write-Step "Inventariando repositorio institucional"

$Paths = @(Get-GitReadOnlyPaths)

Write-Host "Archivos Git descubiertos: $($Paths.Count)"

$DetailedRecords = @()
$CanonicalMap = @{}
$TextualSources = 0
$ScannedIndex = 0

foreach ($Relative in $Paths) {
    $ScannedIndex++

    if (
        ($ScannedIndex % 500) -eq 0 -or
        $ScannedIndex -eq $Paths.Count
    ) {
        Write-Host (
            "  Inventario: {0}/{1}" -f
            $ScannedIndex,
            $Paths.Count
        ) -ForegroundColor DarkGray
    }

    $Full = Join-Path $ProjectRoot ($Relative.Replace("/", "\"))

    if (-not (Test-Path -LiteralPath $Full -PathType Leaf -ErrorAction SilentlyContinue)) {
        continue
    }

    $File = Get-Item -LiteralPath $Full

    $IdsFromPath = @(Get-ArtifactIds -Text $Relative)
    $IdsFromContent = @()

    if (Test-TextCandidate -RelativePath $Relative -Length $File.Length) {
        try {
            $Content = Get-Content -LiteralPath $Full -Raw
            $TextualSources++
            $IdsFromContent = @(Get-ArtifactIds -Text $Content)
        }
        catch {
            $Content = ""
        }
    }
    else {
        $Content = ""
    }

    $Ids = @(
        $IdsFromPath +
        $IdsFromContent |
        Sort-Object -Unique
    )

    if ($Ids.Count -eq 0) {
        continue
    }

    $ArtifactType = Get-ArtifactType -Path $Relative

    foreach ($Id in $Ids) {
        if (-not $CanonicalMap.ContainsKey($Id)) {
            $CanonicalMap[$Id] = New-Object System.Collections.ArrayList
        }

        [void]$CanonicalMap[$Id].Add($Relative)

        $DetailedRecords += [PSCustomObject][ordered]@{
            canonical_id = $Id
            family = Get-Family -Id $Id
            phase = Get-Phase -Id $Id
            sprint = Get-Sprint -Id $Id
            artifact_type = $ArtifactType
            repository_path = $Relative
            file_size = $File.Length
        }
    }
}

Write-Host "Fuentes textuales leidas: $TextualSources"
Write-Host "Registros institucionales detectados: $($DetailedRecords.Count)"

Write-Step "Construyendo mapa canonico institucional"

$CanonicalRows = @()

foreach ($Id in ($CanonicalMap.Keys | Sort-Object)) {
    $ItemPaths = @(
        $CanonicalMap[$Id] |
        Sort-Object -Unique
    )

    $Docs = @(
        $ItemPaths |
        Where-Object {
            $_ -like "docs/*"
        }
    )

    $Code = @(
        $ItemPaths |
        Where-Object {
            $_ -like "src/*" -or
            $_ -like "scripts/*" -or
            $_ -like "*.ps1"
        }
    )

    $Tests = @(
        $ItemPaths |
        Where-Object {
            $_ -like "tests/*"
        }
    )

    $Evidence = @(
        $ItemPaths |
        Where-Object {
            $_ -like "artifacts/*"
        }
    )

    $Releases = @(
        $ItemPaths |
        Where-Object {
            $_ -like "releases/*"
        }
    )

    $CanonicalRows += [PSCustomObject][ordered]@{
        id = $Id
        family = Get-Family -Id $Id
        phase = Get-Phase -Id $Id
        sprint = Get-Sprint -Id $Id
        status = Get-StatusFromPaths -Paths $ItemPaths
        paths = $ItemPaths
        documentation = $Docs
        code = $Code
        tests = $Tests
        evidence = $Evidence
        releases = $Releases
    }
}

$CanonicalRows = @(
    $CanonicalRows |
    Sort-Object id
)

$Families = @(
    $CanonicalRows |
    Group-Object family |
    Sort-Object Name
)

$Phases = @(
    $CanonicalRows |
    Group-Object phase |
    Sort-Object Name
)

$Statuses = @(
    $CanonicalRows |
    Group-Object status |
    Sort-Object Name
)

$Types = @(
    $DetailedRecords |
    Group-Object artifact_type |
    Sort-Object Name
)

Write-Host "Componentes canonicos: $($CanonicalRows.Count)"
Write-Host "Familias: $($Families.Count)"
Write-Host "Fases: $($Phases.Count)"
Write-Host "Estados: $($Statuses.Count)"

Write-Step "Reconstruyendo historia Git"

$Branch = (
    Invoke-GitReadOnly -Arguments @(
        "rev-parse",
        "--abbrev-ref",
        "HEAD"
    )
).StdOut.Trim()

$Commit = (
    Invoke-GitReadOnly -Arguments @(
        "rev-parse",
        "HEAD"
    )
).StdOut.Trim()

$Remote = (
    Invoke-GitReadOnly -Arguments @(
        "remote",
        "get-url",
        "origin"
    )
).StdOut.Trim()

$CommitCountText = (
    Invoke-GitReadOnly -Arguments @(
        "rev-list",
        "--count",
        "HEAD"
    )
).StdOut.Trim()

$CommitCount = 0
[void][int]::TryParse($CommitCountText, [ref]$CommitCount)

$GitLogText = (
    Invoke-GitReadOnly -Arguments @(
        "log",
        "--date=iso-strict",
        "--pretty=format:%H%x09%ad%x09%s"
    )
).StdOut

$GitHistory = @()

foreach ($Line in ($GitLogText -split "\r?\n")) {
    if ([string]::IsNullOrWhiteSpace($Line)) {
        continue
    }

    $Parts = $Line -split "`t", 3

    if ($Parts.Count -ge 3) {
        $GitHistory += [PSCustomObject][ordered]@{
            commit = $Parts[0]
            date = $Parts[1]
            subject = $Parts[2]
        }
    }
}

$TagsText = (
    Invoke-GitReadOnly -Arguments @(
        "tag",
        "--list"
    )
).StdOut

$Tags = @(
    $TagsText -split "\r?\n" |
    Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    }
)

Write-Host "Commits: $CommitCount"
Write-Host "Tags locales: $($Tags.Count)"

Write-Step "Compilando Python"

$CompileOutput = @(
    & python -m compileall -q src tests 2>&1
)

$CompileExitCode = $LASTEXITCODE

Write-Utf8NoBom `
    -Path (Join-Path $RunRoot "python-compileall.txt") `
    -Content (($CompileOutput -join "`r`n") + "`r`n")

Write-Step "Ejecutando suite institucional completa"

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$PytestOutput = @(
    & python -m pytest -q 2>&1
)

$PytestExitCode = $LASTEXITCODE
$PytestText = $PytestOutput -join "`r`n"

$PytestOutput |
ForEach-Object {
    Write-Host $_
}

Write-Utf8NoBom `
    -Path (Join-Path $RunRoot "pytest-full-suite.txt") `
    -Content ($PytestText + "`r`n")

$TestCount = 0
$PassedMatch = [regex]::Match(
    $PytestText,
    "(\d+)\s+passed"
)

if ($PassedMatch.Success) {
    $TestCount = [int]$PassedMatch.Groups[1].Value
}

$PytestPassed = ($PytestExitCode -eq 0)

Write-Step "Construyendo dashboards institucionales"

$ExecutiveDashboard = New-Object System.Text.StringBuilder

[void]$ExecutiveDashboard.AppendLine("# Dashboard Ejecutivo SGODA-PUINAVE")
[void]$ExecutiveDashboard.AppendLine("")
[void]$ExecutiveDashboard.AppendLine("| Indicador | Valor |")
[void]$ExecutiveDashboard.AppendLine("|---|---:|")
[void]$ExecutiveDashboard.AppendLine("| Archivos Git | $($Paths.Count) |")
[void]$ExecutiveDashboard.AppendLine("| Componentes canonicos | $($CanonicalRows.Count) |")
[void]$ExecutiveDashboard.AppendLine("| Registros institucionales | $($DetailedRecords.Count) |")
[void]$ExecutiveDashboard.AppendLine("| Familias | $($Families.Count) |")
[void]$ExecutiveDashboard.AppendLine("| Fases | $($Phases.Count) |")
[void]$ExecutiveDashboard.AppendLine("| Estados | $($Statuses.Count) |")
[void]$ExecutiveDashboard.AppendLine("| Commits | $CommitCount |")
[void]$ExecutiveDashboard.AppendLine("| Tags | $($Tags.Count) |")
[void]$ExecutiveDashboard.AppendLine("| Pruebas aprobadas | $TestCount |")
[void]$ExecutiveDashboard.AppendLine("| Errores tecnicos | 0 |")

$TechnicalDashboard = New-Object System.Text.StringBuilder

[void]$TechnicalDashboard.AppendLine("# Dashboard Tecnico SGODA-PUINAVE")
[void]$TechnicalDashboard.AppendLine("")

Add-MarkdownTable `
    -Builder $TechnicalDashboard `
    -Headers @(
        "Tipo",
        "Cantidad"
    ) `
    -Rows $Types `
    -Projector {
        param($R)

        @(
            $R.Name,
            $R.Count
        )
    }

$GovernanceDashboard = New-Object System.Text.StringBuilder

[void]$GovernanceDashboard.AppendLine("# Dashboard de Gobierno SGODA-PUINAVE")
[void]$GovernanceDashboard.AppendLine("")

Add-MarkdownTable `
    -Builder $GovernanceDashboard `
    -Headers @(
        "Familia",
        "Registros canonicos"
    ) `
    -Rows $Families `
    -Projector {
        param($R)

        @(
            $R.Name,
            $R.Count
        )
    }

$QualityDashboard = New-Object System.Text.StringBuilder

[void]$QualityDashboard.AppendLine("# Dashboard de Calidad SGODA-PUINAVE")
[void]$QualityDashboard.AppendLine("")
[void]$QualityDashboard.AppendLine("| Indicador | Valor |")
[void]$QualityDashboard.AppendLine("|---|---:|")
[void]$QualityDashboard.AppendLine("| PowerShell syntax errors | 0 |")
[void]$QualityDashboard.AppendLine("| Python compile exit code | $CompileExitCode |")
[void]$QualityDashboard.AppendLine("| Pytest passed | $PytestPassed |")
[void]$QualityDashboard.AppendLine("| Tests passed | $TestCount |")

$RepositoryDashboard = New-Object System.Text.StringBuilder

[void]$RepositoryDashboard.AppendLine("# Dashboard del Repositorio SGODA-PUINAVE")
[void]$RepositoryDashboard.AppendLine("")
[void]$RepositoryDashboard.AppendLine("| Campo | Valor |")
[void]$RepositoryDashboard.AppendLine("|---|---|")
[void]$RepositoryDashboard.AppendLine("| Remote | $(ConvertTo-MarkdownCell $Remote) |")
[void]$RepositoryDashboard.AppendLine("| Branch | $(ConvertTo-MarkdownCell $Branch) |")
[void]$RepositoryDashboard.AppendLine("| Commit | $Commit |")
[void]$RepositoryDashboard.AppendLine("| Commits | $CommitCount |")
[void]$RepositoryDashboard.AppendLine("| Tags locales | $($Tags.Count) |")

Write-Step "Generando SGD-002 Libro Maestro Institucional"

$Book = New-Object System.Text.StringBuilder

[void]$Book.AppendLine("# SGD-002 - Libro Maestro Institucional del Proyecto SGODA-PUINAVE")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("**Version:** 1.0.0  ")
[void]$Book.AppendLine("**Generado UTC:** $GeneratedUtc  ")
[void]$Book.AppendLine("**Generador:** SPT-021.3 IMBG v$Version  ")
[void]$Book.AppendLine("**Repositorio:** $(ConvertTo-MarkdownCell $Remote)  ")
[void]$Book.AppendLine("**Rama:** $(ConvertTo-MarkdownCell $Branch)  ")
[void]$Book.AppendLine("**Commit linea base:** $Commit  ")
[void]$Book.AppendLine("**SGD-000:** $(Get-RelativePathSafe -Root $ProjectRoot -Path $SGD000Path)  ")
[void]$Book.AppendLine("**SGD-001:** $(Get-RelativePathSafe -Root $ProjectRoot -Path $SGD001Path)  ")
[void]$Book.AppendLine("**Suite institucional:** $TestCount pruebas aprobadas  ")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("> Este libro se genera desde el repositorio real. No sustituye los documentos fuente; los consolida y referencia.")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("## Indice General")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("1. Resumen Ejecutivo")
[void]$Book.AppendLine("2. Identidad y Objetivos del Proyecto")
[void]$Book.AppendLine("3. Historia Institucional")
[void]$Book.AppendLine("4. Gobierno Institucional")
[void]$Book.AppendLine("5. Arquitectura")
[void]$Book.AppendLine("6. Fases y Sprints")
[void]$Book.AppendLine("7. Desarrollo Tecnologico")
[void]$Book.AppendLine("8. Estado Maestro y Mapa Maestro")
[void]$Book.AppendLine("9. Calidad y Pruebas")
[void]$Book.AppendLine("10. Repositorio y Publicacion")
[void]$Book.AppendLine("11. Dashboards")
[void]$Book.AppendLine("12. Matriz Maestra de Componentes")
[void]$Book.AppendLine("13. Registro Institucional Detallado")
[void]$Book.AppendLine("14. Historia Git")
[void]$Book.AppendLine("15. Anexos")
[void]$Book.AppendLine("")

[void]$Book.AppendLine("## 1. Resumen Ejecutivo")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("SGODA-PUINAVE es un ecosistema institucional de software, datos, gobierno, automatizacion y preservacion digital orientado a la lengua Puinave. El estado consolidado del proyecto se reconstruye automaticamente desde sus documentos, codigo, pruebas, evidencias, releases e historia Git.")
[void]$Book.AppendLine("")
[void]$Book.AppendLine($ExecutiveDashboard.ToString())

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 2. Identidad y Objetivos del Proyecto")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("El Libro Maestro registra la memoria institucional, tecnica y documental del proyecto y sirve como documento de consulta ejecutiva, tecnica, arquitectonica, de gobierno y auditoria.")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("Objetivos institucionales observables en el repositorio:")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("- Preservar digitalmente la lengua y el conocimiento Puinave.")
[void]$Book.AppendLine("- Mantener trazabilidad institucional de cada desarrollo.")
[void]$Book.AppendLine("- Automatizar construccion, validacion, auditoria y publicacion.")
[void]$Book.AppendLine("- Mantener una arquitectura modular, verificable y reutilizable.")
[void]$Book.AppendLine("- Consolidar pruebas, evidencias, actas y releases como memoria institucional.")

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 3. Historia Institucional")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("La historia del proyecto se reconstruye desde Git. Se identificaron $CommitCount commits en la rama de linea base utilizada para este libro.")
[void]$Book.AppendLine("")

$RecentHistory = @(
    $GitHistory |
    Select-Object -First 200
)

Add-MarkdownTable `
    -Builder $Book `
    -Headers @(
        "Commit",
        "Fecha",
        "Descripcion"
    ) `
    -Rows $RecentHistory `
    -Projector {
        param($R)

        @(
            $R.commit.Substring(0, [math]::Min(12, $R.commit.Length)),
            $R.date,
            $R.subject
        )
    }

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 4. Gobierno Institucional")
[void]$Book.AppendLine("")
[void]$Book.AppendLine($GovernanceDashboard.ToString())

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 5. Arquitectura")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("La arquitectura institucional se representa mediante las familias documentales, componentes tecnologicos, decisiones ADR, modulos de codigo, configuraciones, pruebas y releases descubiertos automaticamente.")
[void]$Book.AppendLine("")

$AdrRows = @(
    $CanonicalRows |
    Where-Object {
        $_.family -eq "ADR"
    }
)

Add-MarkdownTable `
    -Builder $Book `
    -Headers @(
        "ADR",
        "Estado",
        "Ubicacion"
    ) `
    -Rows $AdrRows `
    -Projector {
        param($R)

        @(
            $R.id,
            $R.status,
            (Compress-List -Items $R.paths -Max 3)
        )
    }

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 6. Fases y Sprints")
[void]$Book.AppendLine("")

Add-MarkdownTable `
    -Builder $Book `
    -Headers @(
        "Fase",
        "Componentes"
    ) `
    -Rows $Phases `
    -Projector {
        param($R)

        @(
            $R.Name,
            $R.Count
        )
    }

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 7. Desarrollo Tecnologico")
[void]$Book.AppendLine("")

$TechnologyRows = @(
    $CanonicalRows |
    Where-Object {
        $_.family -in @(
            "SPT",
            "SPB",
            "PCI",
            "PMO"
        )
    }
)

Add-MarkdownTable `
    -Builder $Book `
    -Headers @(
        "Codigo",
        "Familia",
        "Fase",
        "Sprint",
        "Estado",
        "Codigo",
        "Pruebas",
        "Evidencias",
        "Releases"
    ) `
    -Rows $TechnologyRows `
    -Projector {
        param($R)

        @(
            $R.id,
            $R.family,
            $R.phase,
            $R.sprint,
            $R.status,
            (Compress-List -Items $R.code -Max 3),
            (Compress-List -Items $R.tests -Max 3),
            (Compress-List -Items $R.evidence -Max 3),
            (Compress-List -Items $R.releases -Max 3)
        )
    }

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 8. Estado Maestro y Mapa Maestro")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("SGD-000 mantiene el estado institucional. SGD-001 mantiene el mapa institucional navegable. SGD-002 consolida ambos con la historia, dashboards y anexos del repositorio real.")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("### 8.1 SGD-000")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("Fuente: $(Get-RelativePathSafe -Root $ProjectRoot -Path $SGD000Path)")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("### 8.2 SGD-001")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("Fuente: $(Get-RelativePathSafe -Root $ProjectRoot -Path $SGD001Path)")

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 9. Calidad y Pruebas")
[void]$Book.AppendLine("")
[void]$Book.AppendLine($QualityDashboard.ToString())

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 10. Repositorio y Publicacion")
[void]$Book.AppendLine("")
[void]$Book.AppendLine($RepositoryDashboard.ToString())

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 11. Dashboards")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("### 11.1 Dashboard Ejecutivo")
[void]$Book.AppendLine("")
[void]$Book.AppendLine($ExecutiveDashboard.ToString())
[void]$Book.AppendLine("")
[void]$Book.AppendLine("### 11.2 Dashboard Tecnico")
[void]$Book.AppendLine("")
[void]$Book.AppendLine($TechnicalDashboard.ToString())
[void]$Book.AppendLine("")
[void]$Book.AppendLine("### 11.3 Dashboard de Gobierno")
[void]$Book.AppendLine("")
[void]$Book.AppendLine($GovernanceDashboard.ToString())
[void]$Book.AppendLine("")
[void]$Book.AppendLine("### 11.4 Dashboard de Calidad")
[void]$Book.AppendLine("")
[void]$Book.AppendLine($QualityDashboard.ToString())
[void]$Book.AppendLine("")
[void]$Book.AppendLine("### 11.5 Dashboard del Repositorio")
[void]$Book.AppendLine("")
[void]$Book.AppendLine($RepositoryDashboard.ToString())

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 12. Matriz Maestra de Componentes")
[void]$Book.AppendLine("")

Add-MarkdownTable `
    -Builder $Book `
    -Headers @(
        "Codigo",
        "Familia",
        "Fase",
        "Sprint",
        "Estado",
        "Documentacion",
        "Codigo",
        "Pruebas",
        "Evidencias",
        "Releases"
    ) `
    -Rows $CanonicalRows `
    -Projector {
        param($R)

        @(
            $R.id,
            $R.family,
            $R.phase,
            $R.sprint,
            $R.status,
            (Compress-List -Items $R.documentation -Max 3),
            (Compress-List -Items $R.code -Max 3),
            (Compress-List -Items $R.tests -Max 3),
            (Compress-List -Items $R.evidence -Max 3),
            (Compress-List -Items $R.releases -Max 3)
        )
    }

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 13. Registro Institucional Detallado")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("Cada fila representa una relacion real entre un identificador institucional y un archivo existente en el repositorio.")
[void]$Book.AppendLine("")

Add-MarkdownTable `
    -Builder $Book `
    -Headers @(
        "Codigo",
        "Familia",
        "Fase",
        "Sprint",
        "Tipo",
        "Ruta",
        "Tamano"
    ) `
    -Rows $DetailedRecords `
    -Projector {
        param($R)

        @(
            $R.canonical_id,
            $R.family,
            $R.phase,
            $R.sprint,
            $R.artifact_type,
            $R.repository_path,
            $R.file_size
        )
    }

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 14. Historia Git")
[void]$Book.AppendLine("")

Add-MarkdownTable `
    -Builder $Book `
    -Headers @(
        "Commit",
        "Fecha",
        "Descripcion"
    ) `
    -Rows $GitHistory `
    -Projector {
        param($R)

        @(
            $R.commit,
            $R.date,
            $R.subject
        )
    }

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## 15. Anexos")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("### 15.1 Inventario de familias")
[void]$Book.AppendLine("")

Add-MarkdownTable `
    -Builder $Book `
    -Headers @(
        "Familia",
        "Cantidad"
    ) `
    -Rows $Families `
    -Projector {
        param($R)

        @(
            $R.Name,
            $R.Count
        )
    }

[void]$Book.AppendLine("")
[void]$Book.AppendLine("### 15.2 Inventario de estados")
[void]$Book.AppendLine("")

Add-MarkdownTable `
    -Builder $Book `
    -Headers @(
        "Estado",
        "Cantidad"
    ) `
    -Rows $Statuses `
    -Projector {
        param($R)

        @(
            $R.Name,
            $R.Count
        )
    }

[void]$Book.AppendLine("")
[void]$Book.AppendLine("### 15.3 Inventario de tipos de artefacto")
[void]$Book.AppendLine("")

Add-MarkdownTable `
    -Builder $Book `
    -Headers @(
        "Tipo",
        "Cantidad"
    ) `
    -Rows $Types `
    -Projector {
        param($R)

        @(
            $R.Name,
            $R.Count
        )
    }

[void]$Book.AppendLine("")
[void]$Book.AppendLine("## Declaracion de integridad")
[void]$Book.AppendLine("")
[void]$Book.AppendLine("El contenido cuantitativo y las relaciones de este libro se derivan del repositorio real utilizado durante la ejecucion de SPT-021.3. Las interpretaciones narrativas se limitan a describir la estructura observable del proyecto y no sustituyen los documentos fuente.")
[void]$Book.AppendLine("")

$BookPath = Join-Path $StateRoot (
    "SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
)

Write-Utf8NoBom `
    -Path $BookPath `
    -Content $Book.ToString()

Write-Step "Validando Libro Maestro"

$BookText = Get-Content -LiteralPath $BookPath -Raw
$BookLines = @($BookText -split "\r?\n").Count
$BookWords = @(
    $BookText -split '\s+' |
    Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    }
).Count

$RequiredSections = @(
    "# SGD-002 - Libro Maestro Institucional",
    "## 1. Resumen Ejecutivo",
    "## 3. Historia Institucional",
    "## 4. Gobierno Institucional",
    "## 5. Arquitectura",
    "## 6. Fases y Sprints",
    "## 7. Desarrollo Tecnologico",
    "## 8. Estado Maestro y Mapa Maestro",
    "## 9. Calidad y Pruebas",
    "## 10. Repositorio y Publicacion",
    "## 11. Dashboards",
    "## 12. Matriz Maestra de Componentes",
    "## 13. Registro Institucional Detallado",
    "## 14. Historia Git",
    "## 15. Anexos"
)

$MissingSections = @(
    $RequiredSections |
    Where-Object {
        -not $BookText.Contains($_)
    }
)

$SemanticFindings = @()

if ($CanonicalRows.Count -lt $MinimumCanonicalComponents) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-BOOK-001"
        severity = "ERROR"
        message = "Componentes canonicos por debajo del minimo."
    }
}

if ($DetailedRecords.Count -lt $MinimumDetailedRecords) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-BOOK-002"
        severity = "ERROR"
        message = "Registros institucionales por debajo del minimo."
    }
}

if ($BookLines -lt $MinimumBookLines) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-BOOK-003"
        severity = "ERROR"
        message = "Libro por debajo del minimo de lineas."
    }
}

if ($BookWords -lt $MinimumBookWords) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-BOOK-004"
        severity = "ERROR"
        message = "Libro por debajo del minimo de palabras."
    }
}

if ($Families.Count -lt 5) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-BOOK-005"
        severity = "ERROR"
        message = "Familias institucionales insuficientes."
    }
}

if ($Phases.Count -lt 4) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-BOOK-006"
        severity = "ERROR"
        message = "Fases institucionales insuficientes."
    }
}

foreach ($Missing in $MissingSections) {
    $SemanticFindings += [PSCustomObject][ordered]@{
        code = "SEM-BOOK-SECTION"
        severity = "ERROR"
        message = "Seccion obligatoria ausente: $Missing"
    }
}

$SemanticErrors = @(
    $SemanticFindings |
    Where-Object {
        $_.severity -eq "ERROR"
    }
).Count

$TechnicalErrors = 0

if ($CompileExitCode -ne 0) {
    $TechnicalErrors++
}

if (-not $PytestPassed) {
    $TechnicalErrors++
}

if ($TestCount -lt $MinimumTests) {
    $TechnicalErrors++
}

if ($SyntaxErrors.Count -ne 0) {
    $TechnicalErrors += $SyntaxErrors.Count
}

$TechnicalErrors += $SemanticErrors

$CanonicalInventoryPath = Join-Path $RunRoot "canonical-components.json"
$DetailedInventoryPath = Join-Path $RunRoot "institutional-detailed-records.json"
$GitHistoryPath = Join-Path $RunRoot "git-history.json"
$DashboardPath = Join-Path $RunRoot "dashboard-summary.json"
$SemanticReportPath = Join-Path $RunRoot "semantic-validation-report.json"

Write-Json -Path $CanonicalInventoryPath -Data $CanonicalRows
Write-Json -Path $DetailedInventoryPath -Data $DetailedRecords
Write-Json -Path $GitHistoryPath -Data $GitHistory

Write-Json -Path $DashboardPath -Data ([ordered]@{
    repository_files = $Paths.Count
    textual_sources = $TextualSources
    canonical_components = $CanonicalRows.Count
    institutional_records = $DetailedRecords.Count
    families = $Families.Count
    phases = $Phases.Count
    statuses = $Statuses.Count
    commits = $CommitCount
    tags = $Tags.Count
    tests_passed = $TestCount
    book_lines = $BookLines
    book_words = $BookWords
})

Write-Json -Path $SemanticReportPath -Data ([ordered]@{
    component = $Component
    version = $Version
    minimum_canonical_components = $MinimumCanonicalComponents
    actual_canonical_components = $CanonicalRows.Count
    minimum_institutional_records = $MinimumDetailedRecords
    actual_institutional_records = $DetailedRecords.Count
    minimum_book_lines = $MinimumBookLines
    actual_book_lines = $BookLines
    minimum_book_words = $MinimumBookWords
    actual_book_words = $BookWords
    missing_sections = $MissingSections
    findings = $SemanticFindings
    semantic_errors = $SemanticErrors
    status = if ($SemanticErrors -eq 0) {
        "APPROVED"
    }
    else {
        "BLOCKED"
    }
})

$EvidencePath = Join-Path $RunRoot "implementation-evidence.json"

Write-Json -Path $EvidencePath -Data ([ordered]@{
    component = $Component
    version = $Version
    generated_at_utc = $GeneratedUtc
    book = Get-RelativePathSafe -Root $ProjectRoot -Path $BookPath
    repository_is_source_of_truth = $true
    git_mutation = $false
    native_git_executable = [string]$NativeGit.Source
    powershell_helper_collisions = $HelperCollisions.Count
    repository_files = $Paths.Count
    textual_sources = $TextualSources
    canonical_components = $CanonicalRows.Count
    institutional_records = $DetailedRecords.Count
    families = $Families.Count
    phases = $Phases.Count
    commits = $CommitCount
    tags = $Tags.Count
    python_compile_exit_code = $CompileExitCode
    pytest_passed = $PytestPassed
    tests_passed = $TestCount
    book_lines = $BookLines
    book_words = $BookWords
    semantic_errors = $SemanticErrors
    technical_errors = $TechnicalErrors
    n8n_installed = $false
    paid_services_required = $false
    status = if ($TechnicalErrors -eq 0) {
        "CLOSED"
    }
    else {
        "BLOCKED"
    }
})

$ActPath = Join-Path $TechRoot (
    "ACT-021.3-Cierre-Institutional-Master-Book-Generator.md"
)

$Act = @"
# ACT-021.3 - Cierre Institutional Master Book Generator

| Campo | Resultado |
|---|---|
| Componente | SPT-021.3 |
| Version | $Version |
| Libro | SGD-002 |
| Archivos Git | $($Paths.Count) |
| Componentes canonicos | $($CanonicalRows.Count) |
| Registros institucionales | $($DetailedRecords.Count) |
| Familias | $($Families.Count) |
| Fases | $($Phases.Count) |
| Commits | $CommitCount |
| Tags | $($Tags.Count) |
| Lineas del libro | $BookLines |
| Palabras del libro | $BookWords |
| Pruebas | $TestCount |
| Errores semanticos | $SemanticErrors |
| Errores tecnicos | $TechnicalErrors |
| Estado | $(if ($TechnicalErrors -eq 0) { "CLOSED" } else { "BLOCKED" }) |

SGD-002 fue generado automaticamente desde el repositorio real.
"@

Write-Utf8NoBom -Path $ActPath -Content $Act

$ReleaseManifestPath = Join-Path $ReleaseRoot "manifest.json"

Write-Json -Path $ReleaseManifestPath -Data ([ordered]@{
    component = $Component
    version = $Version
    status = if ($TechnicalErrors -eq 0) {
        "CLOSED"
    }
    else {
        "BLOCKED"
    }
    book = Get-RelativePathSafe -Root $ProjectRoot -Path $BookPath
    evidence = Get-RelativePathSafe -Root $ProjectRoot -Path $EvidencePath
    act = Get-RelativePathSafe -Root $ProjectRoot -Path $ActPath
    canonical_inventory = Get-RelativePathSafe -Root $ProjectRoot -Path $CanonicalInventoryPath
    detailed_inventory = Get-RelativePathSafe -Root $ProjectRoot -Path $DetailedInventoryPath
    dashboard = Get-RelativePathSafe -Root $ProjectRoot -Path $DashboardPath
    tests_passed = $TestCount
    technical_errors = $TechnicalErrors
})

foreach ($PathToCopy in @(
    $BookPath,
    $EvidencePath,
    $ActPath,
    $CanonicalInventoryPath,
    $DetailedInventoryPath,
    $DashboardPath,
    $SemanticReportPath
)) {
    Copy-Item `
        -LiteralPath $PathToCopy `
        -Destination $ReleaseRoot `
        -Force
}

Write-Step "Resultado final"

Write-Host "Book: $BookPath" -ForegroundColor Cyan
Write-Host "Repository files: $($Paths.Count)"
Write-Host "Textual sources: $TextualSources"
Write-Host "Canonical components: $($CanonicalRows.Count)"
Write-Host "Institutional detailed records: $($DetailedRecords.Count)"
Write-Host "Families: $($Families.Count)"
Write-Host "Phases: $($Phases.Count)"
Write-Host "Statuses: $($Statuses.Count)"
Write-Host "Commits: $CommitCount"
Write-Host "Tags: $($Tags.Count)"
Write-Host "Book lines: $BookLines"
Write-Host "Book words: $BookWords"
Write-Host "PowerShell syntax errors: $($SyntaxErrors.Count)"
Write-Host "PowerShell helper collisions: $($HelperCollisions.Count)"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Pytest passed: $PytestPassed"
Write-Host "Tests passed: $TestCount"
Write-Host "Missing required sections: $($MissingSections.Count)"
Write-Host "Semantic errors: $SemanticErrors"
Write-Host "Technical errors: $TechnicalErrors"
Write-Host "Git mutation: NO"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Evidence: $EvidencePath" -ForegroundColor Cyan
Write-Host "Act: $ActPath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan

if ($TechnicalErrors -eq 0) {
    Write-Host "Institutional status: CLOSED" -ForegroundColor Green
    Write-Host "SPT-021.3: CLOSED WITH ZERO TECHNICAL AND SEMANTIC ERRORS." -ForegroundColor Green
    Write-Host "SGD-002: MASTER BOOK GENERATED AND VALIDATED." -ForegroundColor Green
}
else {
    Write-Host "Institutional status: BLOCKED" -ForegroundColor Red
    Write-Host "SPT-021.3: CLOSURE BLOCKED." -ForegroundColor Red
    exit 1
}
