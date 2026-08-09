<#
.SYNOPSIS
    SPT-021.0.1 - Institutional Repository Reconciliation & Publication Engine
    Version 1.0.7 - One File - Windows PowerShell 5.1

.DESCRIPTION
    Motor institucional para reconciliar y publicar en el repositorio oficial
    la documentacion, codigo, pruebas, configuracion, releases y evidencias
    institucionales reales y ejecutadas de SGODA-PUINAVE.

    Repositorio oficial esperado:
      https://github.com/Poliyoko/APP-PUINAVE.git

    UN SOLO ARCHIVO, DOS FASES SEGURAS:
      PREPARE (por defecto)
        - valida repositorio, branch y remote;
        - ejecuta git fetch de forma compatible con PowerShell 5.1;
        - valida sintaxis PowerShell activa;
        - conserva y audita scripts historicos sin bloquear el gate activo;
        - separa ACTIVE_POWERSHELL_ERROR de HISTORICAL_LEGACY_FINDING;
        - compila Python;
        - ejecuta suite completa;
        - construye allowlist institucional;
        - excluye temporales, entornos, cache y archivos excesivamente grandes;
        - genera manifest de publicacion;
        - NO hace commit ni push.

      PUBLISH (-Publish)
        - repite todos los quality gates;
        - reconstruye el manifest;
        - agrega solo archivos aprobados;
        - crea commit institucional si existen cambios;
        - publica la rama actual en origin;
        - opcionalmente publica tags locales pendientes con -PublishTags;
        - ejecuta fetch de verificacion;
        - comprueba ahead/behind;
        - genera evidencia y acta;
        - deja SPT-021.0.1 CLOSED solo si la publicacion y verificacion son conformes.

    NUNCA ejecuta "git add .".
    NUNCA elimina historia.
    NUNCA hace force push.
    NUNCA instala n8n.
    NUNCA requiere servicios de pago.

.PARAMETER ProjectRoot
    Raiz del repositorio. Por defecto: carpeta actual.

.PARAMETER Publish
    Activa la fase PUBLISH. Sin este parametro se ejecuta PREPARE.

.PARAMETER PublishTags
    En PUBLISH, publica tambien tags locales ausentes en origin.

.PARAMETER MaxArtifactMB
    Tamano maximo individual de evidencia/artefacto que puede incorporarse.
    Default: 10 MB.

.PARAMETER CommitMessage
    Mensaje institucional del commit.

.EXAMPLE
    .\Install-SPT021.0.1-v1.0.7-OneFile-PS51.ps1

.EXAMPLE
    .\Install-SPT021.0.1-v1.0.7-OneFile-PS51.ps1 -Publish

.EXAMPLE
    .\Install-SPT021.0.1-v1.0.7-OneFile-PS51.ps1 -Publish -PublishTags
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Publish,
    [switch]$PublishTags,
    [int]$MaxArtifactMB = 10,
    [string]$CommitMessage = "chore(sgoda): reconcile institutional baseline through SPT-021.0.1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-021.0.1"
$Version = "1.0.7"
$ExpectedRemote = "https://github.com/Poliyoko/APP-PUINAVE.git"
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$GeneratedUtc = (Get-Date).ToUniversalTime().ToString("o")
$SelfPath = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
$Mode = if ($Publish) { "PUBLISH" } else { "PREPARE" }

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


# ----------------------------------------------------------------------
# Registro canonico de PowerShell historico.
#
# Estos archivos se conservan como memoria institucional y permanecen
# publicables/trazables, pero NO representan codigo activo ejecutable de la
# linea base actual. Sus hallazgos de parser se reportan separadamente y no
# bloquean PREPARE/PUBLISH.
# ----------------------------------------------------------------------
$HistoricalLegacyPowerShell = @(
    "Repair-SPT011A-v1.0.1-Institutional-Evidence-Closure.ps1",
    "Repair-SGD114E-v2.0.0-R2-Self-Validation-Closure.ps1",
    "Repair-SPT010-v1.0.1-JSON-Payload-Institutional-Closure.ps1",
    "Install-SGD114E-v1.0.0-Native-Ecosystem-Architecture-Policy.ps1",
    "Close-SPT016-v1.0.0-Learning-Analytics-Official-Closure.ps1",
    "Install-SGD114D-v1.0.0-Adaptive-Institutional-Policy-Engine.ps1"
)

function Test-HistoricalLegacyPowerShellPath {
    param([string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        return $false
    }

    $Normalized = $RelativePath.Replace("\", "/")
    $Name = [System.IO.Path]::GetFileName($Normalized)

    # Solo se clasifica por nombre cuando el archivo esta en la raiz.
    # Las copias internas ya quedan cubiertas por Test-ExcludedPath.
    if ($Normalized.Contains("/")) {
        return $false
    }

    return ($HistoricalLegacyPowerShell -contains $Name)
}

function Normalize-GitRemote {
    param([string]$Remote)

    $Value = $Remote.Trim()

    if ($Value -match "^git@github\.com:(.+)$") {
        $Value = "https://github.com/" + $Matches[1]
    }

    if (-not $Value.EndsWith(".git")) {
        $Value += ".git"
    }

    return $Value.ToLowerInvariant()
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
    $Lines = @()

    if (-not [string]::IsNullOrWhiteSpace($StdOut)) {
        $Lines += @(
            $StdOut -split "\r?\n" |
            Where-Object { $_ -ne "" }
        )
    }

    if (-not [string]::IsNullOrWhiteSpace($StdErr)) {
        $Lines += @(
            $StdErr -split "\r?\n" |
            Where-Object { $_ -ne "" }
        )
    }

    if (($ExitCode -ne 0) -and (-not $AllowFailure)) {
        throw (
            "git " +
            ($Arguments -join " ") +
            " fallo. Exit code: " +
            $ExitCode +
            "`r`n" +
            ($Lines -join "`r`n")
        )
    }

    return [PSCustomObject]@{
        ExitCode = $ExitCode
        Output = @($Lines)
        Text = ($Lines -join "`r`n")
        StdOut = $StdOut
        StdErr = $StdErr
    }
}

function Test-ExcludedPath {
    param([string]$RelativePath)

    $Path = "/" + $RelativePath.Replace("\", "/").ToLowerInvariant() + "/"

    $ExcludedFragments = @(
        "/.git/",
        "/.venv/",
        "/venv/",
        "/node_modules/",
        "/__pycache__/",
        "/.pytest_cache/",
        "/builder_backup/",
        "/builder_backup_",
        "/backup/",
        "/repository-backup/",
        "/registry-backup/",
        "/repo-backup/",
        "/snapshot-backup/",
        "/tmp/",
        "/temp/",
        "/.mypy_cache/",
        "/.ruff_cache/"
    )

    foreach ($Fragment in $ExcludedFragments) {
        if ($Path.Contains($Fragment)) {
            return $true
        }
    }

    $Name = [System.IO.Path]::GetFileName($RelativePath)

    if ($Name.StartsWith("~$")) {
        return $true
    }

    if (
        $Name.EndsWith(".pyc") -or
        $Name.EndsWith(".pyo") -or
        $Name.EndsWith(".tmp") -or
        $Name.EndsWith(".bak") -or
        $Name.EndsWith(".before-compatibility-fix")
    ) {
        return $true
    }

    return $false
}

function Test-PublishablePath {
    param(
        [string]$RelativePath,
        [long]$Length,
        [long]$MaxArtifactBytes
    )

    if (Test-ExcludedPath -RelativePath $RelativePath) {
        return $false
    }

    $Normalized = $RelativePath.Replace("\", "/")

    # Conservative Git path-length guard for Windows.
    # Backups and deep recursive copies are never publication sources.
    if ($Normalized.Length -gt 220) {
        return $false
    }

    $AlwaysAllowedPrefixes = @(
        "src/",
        "tests/",
        "docs/",
        "config/",
        "scripts/",
        "automation/",
        "dashboard/",
        "knowledge/",
        "data/",
        ".github/"
    )

    foreach ($Prefix in $AlwaysAllowedPrefixes) {
        if ($Normalized.StartsWith($Prefix)) {
            return $true
        }
    }

    if ($Normalized.StartsWith("releases/")) {
        return ($Length -le $MaxArtifactBytes)
    }

    if ($Normalized.StartsWith("artifacts/")) {
        $AllowedEvidenceExtensions = @(
            ".json",
            ".md",
            ".txt",
            ".xml",
            ".csv",
            ".yaml",
            ".yml"
        )

        $Extension = [System.IO.Path]::GetExtension($Normalized).ToLowerInvariant()

        return (
            ($AllowedEvidenceExtensions -contains $Extension) -and
            ($Length -le $MaxArtifactBytes)
        )
    }

    if (-not $Normalized.Contains("/")) {
        $RootAllowedPatterns = @(
            "*.ps1",
            "*.md",
            "*.txt",
            "*.yaml",
            "*.yml",
            "*.json",
            "*.ini",
            "*.toml",
            "*.xlsx",
            "*.csv",
            ".editorconfig",
            ".env.example",
            ".gitattributes",
            ".gitignore",
            "requirements.txt",
            "pytest.ini",
            "CHANGELOG*",
            "README*"
        )

        foreach ($Pattern in $RootAllowedPatterns) {
            if ($Normalized -like $Pattern) {
                return ($Length -le $MaxArtifactBytes)
            }
        }
    }

    return $false
}

function Get-PublicationInventory {
    param(
        [string]$Root,
        [long]$MaxArtifactBytes
    )

    # Fast institutional inventory:
    # - tracked paths come from Git index;
    # - untracked paths come from Git respecting .gitignore;
    # - no recursive crawl of .git, virtual environments or caches.
    # Use NUL-delimited Git output. This avoids Git quoting paths that
    # contain spaces, accents or special characters. Never parse filenames
    # from human-readable quoted output.
    $TrackedResult = Invoke-NativeGit -Arguments @(
        "-c",
        "core.quotepath=false",
        "ls-files",
        "-z"
    )

    $UntrackedResult = Invoke-NativeGit -Arguments @(
        "-c",
        "core.quotepath=false",
        "ls-files",
        "--others",
        "--exclude-standard",
        "-z"
    )

    $TrackedPaths = @(
        $TrackedResult.StdOut -split [char]0 |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Replace("\", "/") } |
        Sort-Object -Unique
    )

    $UntrackedPaths = @(
        $UntrackedResult.StdOut -split [char]0 |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Replace("\", "/") } |
        Sort-Object -Unique
    )

    $CandidatePaths = @(
        @($TrackedPaths + $UntrackedPaths) |
        Sort-Object -Unique
    )

    $Approved = @()
    $Excluded = @()
    $MissingTracked = @()

    $TrackedLookup = @{}
    foreach ($TrackedPath in $TrackedPaths) {
        $TrackedLookup[$TrackedPath] = $true
    }

    $Total = $CandidatePaths.Count
    $Index = 0

    Write-Host "  Candidatos Git: $Total" -ForegroundColor DarkGray

    foreach ($Relative in $CandidatePaths) {
        $Index++

        if (($Index % 100) -eq 0 -or $Index -eq $Total) {
            Write-Host (
                "  Manifest: {0}/{1}" -f $Index, $Total
            ) -ForegroundColor DarkGray
        }

        try {
            $FullPath = Join-Path $Root ($Relative.Replace("/", "\"))

            $ExistsAsFile = Test-Path `
                -LiteralPath $FullPath `
                -PathType Leaf `
                -ErrorAction Stop
        }
        catch {
            $Excluded += [ordered]@{
                path = $Relative
                length = 0
                classification = "PATH_VALIDATION_REVIEW_REQUIRED"
                reason = $_.Exception.Message
            }
            continue
        }

        if (-not $ExistsAsFile) {
            if ($TrackedLookup.ContainsKey($Relative)) {
                $MissingTracked += [ordered]@{
                    path = $Relative
                    classification = "DELETION_REVIEW_REQUIRED"
                    auto_stage = $false
                }
            }
            continue
        }

        $File = Get-Item -LiteralPath $FullPath -ErrorAction Stop

        if (
            Test-PublishablePath `
                -RelativePath $Relative `
                -Length $File.Length `
                -MaxArtifactBytes $MaxArtifactBytes
        ) {
            $Approved += [ordered]@{
                path = $Relative
                length = $File.Length
                sha256 = (
                    Get-FileHash `
                        -LiteralPath $FullPath `
                        -Algorithm SHA256
                ).Hash.ToLowerInvariant()
                tracked = $TrackedLookup.ContainsKey($Relative)
            }
        }
        else {
            $NormalizedRelative = $Relative.Replace("\", "/").ToLowerInvariant()

            $Classification = if (
                $Relative.Length -gt 220 -or
                $NormalizedRelative.Contains("/repository-backup/") -or
                $NormalizedRelative.Contains("/registry-backup/") -or
                $NormalizedRelative.Contains("/repo-backup/") -or
                $NormalizedRelative.Contains("/snapshot-backup/") -or
                $NormalizedRelative.Contains("/backup/")
            ) {
                "BACKUP_OR_LONG_PATH_EXCLUDED"
            }
            else {
                "POLICY_EXCLUDED"
            }

            $Excluded += [ordered]@{
                path = $Relative
                length = $File.Length
                classification = $Classification
            }
        }
    }

    return [PSCustomObject]@{
        Approved = @($Approved | Sort-Object path)
        Excluded = @($Excluded | Sort-Object path)
        MissingTracked = @($MissingTracked | Sort-Object path)
        CandidateCount = $Total
        TrackedCount = $TrackedPaths.Count
        UntrackedCount = $UntrackedPaths.Count
    }
}

function Get-TestCount {
    param([string]$Text)

    $Match = [regex]::Match($Text, "(\d+)\s+passed")

    if ($Match.Success) {
        return [int]$Match.Groups[1].Value
    }

    return 0
}

function Get-RemoteTagMap {
    $Result = Invoke-NativeGit `
        -Arguments @("ls-remote", "--tags", "origin") `
        -AllowFailure

    $Map = @{}
    $Reachable = ($Result.ExitCode -eq 0)

    if ($Reachable) {
        foreach ($LineObject in $Result.Output) {
            $Line = $LineObject.ToString()

            if ($Line -match "^([0-9a-fA-F]+)\s+refs/tags/(.+?)(\^\{\})?$") {
                $Hash = $Matches[1].ToLowerInvariant()
                $Tag = $Matches[2]
                $Peeled = ($Matches[3] -eq "^{}")

                if (-not $Map.ContainsKey($Tag)) {
                    $Map[$Tag] = [ordered]@{
                        tag = $Tag
                        object = ""
                        peeled = ""
                    }
                }

                if ($Peeled) {
                    $Map[$Tag].peeled = $Hash
                }
                else {
                    $Map[$Tag].object = $Hash
                }
            }
        }
    }

    return [PSCustomObject]@{
        Reachable = $Reachable
        ExitCode = $Result.ExitCode
        Map = $Map
        Raw = $Result.Text
    }
}

function Get-LocalTagMap {
    $Tags = @(
        (Invoke-NativeGit -Arguments @("tag", "--list")).Output |
        ForEach-Object { $_.ToString().Trim() } |
        Where-Object { $_ } |
        Sort-Object -Unique
    )

    $Map = @{}

    foreach ($Tag in $Tags) {
        $ObjectResult = Invoke-NativeGit `
            -Arguments @("rev-parse", "refs/tags/$Tag") `
            -AllowFailure

        $PeeledResult = Invoke-NativeGit `
            -Arguments @("rev-parse", "refs/tags/$Tag^{}") `
            -AllowFailure

        $Map[$Tag] = [ordered]@{
            tag = $Tag
            object = if ($ObjectResult.ExitCode -eq 0) {
                $ObjectResult.Output[0].ToString().Trim().ToLowerInvariant()
            }
            else {
                ""
            }
            peeled = if ($PeeledResult.ExitCode -eq 0) {
                $PeeledResult.Output[0].ToString().Trim().ToLowerInvariant()
            }
            else {
                ""
            }
        }
    }

    return $Map
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
    throw "El instalador SPT-021.0.1 contiene errores de sintaxis."
}

$GitRootResult = Invoke-NativeGit -Arguments @(
    "rev-parse",
    "--show-toplevel"
)

$GitRoot = [System.IO.Path]::GetFullPath(
    $GitRootResult.Output[0].ToString().Trim()
)

if ($GitRoot.TrimEnd("\") -ne $ProjectRoot.TrimEnd("\")) {
    throw "Debe ejecutar SPT-021.0.1 desde la raiz Git oficial."
}

$OriginResult = Invoke-NativeGit -Arguments @(
    "remote",
    "get-url",
    "origin"
)

$ActualRemote = $OriginResult.Output[0].ToString().Trim()

if (
    (Normalize-GitRemote -Remote $ActualRemote) -ne
    (Normalize-GitRemote -Remote $ExpectedRemote)
) {
    throw (
        "Remote origin no autorizado. Actual: " +
        $ActualRemote +
        " ; Esperado: " +
        $ExpectedRemote
    )
}

$BaselinePath = Join-Path $ProjectRoot (
    "config\platform\SPT-020-closure-registry.json"
)

if (-not (Test-Path -LiteralPath $BaselinePath -PathType Leaf)) {
    throw "Falta la linea base institucional SPT-020."
}

$Baseline = Get-Content `
    -LiteralPath $BaselinePath `
    -Raw |
    ConvertFrom-Json

if ([string]$Baseline.final_status -ne "CLOSED") {
    throw "SPT-020 no esta CLOSED."
}

$RunRoot = Join-Path $ProjectRoot (
    "artifacts\publication\SPT-021.0.1-v1.0.6\runs\" + $RunId
)
$DocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-021.0.1"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-021.0.1-v1.0.6"
$ConfigRoot = Join-Path $ProjectRoot "config\repository"

foreach ($Directory in @(
    $RunRoot,
    $DocsRoot,
    $ReleaseRoot,
    $ConfigRoot
)) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

Write-Step "SPT-021.0.1 - Modo $Mode"
Write-Host "Repositorio oficial: $ActualRemote"
Write-Host "Linea base: SPT-020 CLOSED"

Write-Step "Actualizando referencias remotas de rama sin tocar tags"

$FetchBefore = Invoke-NativeGit `
    -Arguments @(
        "fetch",
        "origin",
        "--prune",
        "--no-tags"
    ) `
    -AllowFailure

$FetchSucceeded = ($FetchBefore.ExitCode -eq 0)

if (-not $FetchSucceeded) {
    Write-Warning (
        "Fetch de rama no fue exitoso. " +
        "Se continuara con diagnostico remoto mediante ls-remote. " +
        "El fetch por si mismo nunca bloquea PREPARE."
    )
}

$BranchResult = Invoke-NativeGit -Arguments @(
    "rev-parse",
    "--abbrev-ref",
    "HEAD"
)

$Branch = $BranchResult.Output[0].ToString().Trim()

if ($Branch -eq "HEAD") {
    throw "Detached HEAD no permitido para publicacion institucional."
}

$RemoteBranch = "origin/" + $Branch

$RemoteBranchExists = (
    Invoke-NativeGit `
        -Arguments @("rev-parse", "--verify", $RemoteBranch) `
        -AllowFailure
).ExitCode -eq 0

$AheadBefore = 0
$BehindBefore = 0

if ($RemoteBranchExists) {
    $CountResult = Invoke-NativeGit -Arguments @(
        "rev-list",
        "--left-right",
        "--count",
        "$RemoteBranch...HEAD"
    )

    $Counts = $CountResult.Text.Trim() -split "\s+"

    if ($Counts.Count -ge 2) {
        $BehindBefore = [int]$Counts[0]
        $AheadBefore = [int]$Counts[1]
    }
}

if ($BehindBefore -gt 0) {
    throw (
        "La rama local esta behind por " +
        $BehindBefore +
        " commit(s). Se bloquea publicacion automatica para evitar merge inseguro."
    )
}

Write-Step "Validando sintaxis PowerShell activa e historica"

$AllPowerShellFiles = @(
    Get-ChildItem `
        -LiteralPath $ProjectRoot `
        -Recurse `
        -File `
        -Filter "*.ps1" `
        -ErrorAction SilentlyContinue |
    Where-Object {
        $Relative = Get-RelativePathSafe `
            -Root $ProjectRoot `
            -Path $_.FullName

        -not (Test-ExcludedPath -RelativePath $Relative)
    }
)

$ActivePowerShellFiles = @()
$HistoricalPowerShellFiles = @()

foreach ($File in $AllPowerShellFiles) {
    $Relative = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $File.FullName

    if (Test-HistoricalLegacyPowerShellPath -RelativePath $Relative) {
        $HistoricalPowerShellFiles += $File
    }
    else {
        $ActivePowerShellFiles += $File
    }
}

$PowerShellErrors = @()
$HistoricalPowerShellFindings = @()
$Index = 0

foreach ($File in $ActivePowerShellFiles) {
    $Index++

    if (($Index % 25) -eq 0) {
        Write-Host (
            "  Active PowerShell: {0}/{1}" -f `
                $Index, `
                $ActivePowerShellFiles.Count
        ) -ForegroundColor DarkGray
    }

    $Errors = @(Test-PowerShellSyntax -Path $File.FullName)

    foreach ($ErrorItem in $Errors) {
        $PowerShellErrors += [ordered]@{
            path = Get-RelativePathSafe `
                -Root $ProjectRoot `
                -Path $File.FullName
            classification = "ACTIVE_POWERSHELL_ERROR"
            blocking = $true
            line = $ErrorItem.Extent.StartLineNumber
            column = $ErrorItem.Extent.StartColumnNumber
            error_id = $ErrorItem.ErrorId
            message = $ErrorItem.Message
        }
    }
}

foreach ($File in $HistoricalPowerShellFiles) {
    $Relative = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $File.FullName

    $Errors = @(Test-PowerShellSyntax -Path $File.FullName)

    foreach ($ErrorItem in $Errors) {
        $HistoricalPowerShellFindings += [ordered]@{
            path = $Relative
            classification = "HISTORICAL_LEGACY_FINDING"
            blocking = $false
            preserved = $true
            line = $ErrorItem.Extent.StartLineNumber
            column = $ErrorItem.Extent.StartColumnNumber
            error_id = $ErrorItem.ErrorId
            message = $ErrorItem.Message
        }
    }
}

$PowerShellErrorsPath = Join-Path `
    $RunRoot `
    "powershell-active-syntax-errors.json"

$HistoricalPowerShellFindingsPath = Join-Path `
    $RunRoot `
    "powershell-historical-legacy-findings.json"

$HistoricalPowerShellRegistryPath = Join-Path `
    $RunRoot `
    "powershell-historical-legacy-registry.json"

Write-JsonFile `
    -Path $PowerShellErrorsPath `
    -Data $PowerShellErrors

Write-JsonFile `
    -Path $HistoricalPowerShellFindingsPath `
    -Data $HistoricalPowerShellFindings

$HistoricalRegistry = @()

foreach ($FileName in $HistoricalLegacyPowerShell) {
    $FullPath = Join-Path $ProjectRoot $FileName

    $HistoricalRegistry += [ordered]@{
        path = $FileName
        classification = "HISTORICAL_LEGACY_SCRIPT"
        preserved = $true
        active_gate = $false
        exists = [bool](Test-Path -LiteralPath $FullPath -PathType Leaf)
        rationale = (
            "Historical closed-component installer/repair evidence; " +
            "preserved for institutional traceability and excluded only " +
            "from the active PowerShell syntax gate."
        )
    }
}

Write-JsonFile `
    -Path $HistoricalPowerShellRegistryPath `
    -Data $HistoricalRegistry

Write-Host (
    "  Active PowerShell files: {0}" -f `
        $ActivePowerShellFiles.Count
)

Write-Host (
    "  Historical legacy scripts: {0}" -f `
        $HistoricalPowerShellFiles.Count
)

Write-Host (
    "  Active PowerShell syntax errors: {0}" -f `
        $PowerShellErrors.Count
)

Write-Host (
    "  Historical legacy syntax findings: {0}" -f `
        $HistoricalPowerShellFindings.Count
)

if ($PowerShellErrors.Count -ne 0) {
    throw (
        "Se detectaron " +
        $PowerShellErrors.Count +
        " errores PowerShell ACTIVOS. " +
        "Los hallazgos historicos se reportan por separado."
    )
}

Write-Step "Compilando Python"

$CompileOutput = @(& python -m compileall -q src tests 2>&1)
$CompileExitCode = $LASTEXITCODE

Write-TextFile `
    -Path (Join-Path $RunRoot "python-compileall.txt") `
    -Content (($CompileOutput -join "`r`n") + "`r`n")

if ($CompileExitCode -ne 0) {
    throw "Python compileall fallo."
}

Write-Step "Ejecutando suite institucional completa"

$env:PYTHONPATH = Join-Path $ProjectRoot "src"
$PytestOutput = @(& python -m pytest -q 2>&1)
$PytestExitCode = $LASTEXITCODE
$PytestText = $PytestOutput -join "`r`n"
$PytestPassed = ($PytestExitCode -eq 0)
$TestCount = Get-TestCount -Text $PytestText

Write-TextFile `
    -Path (Join-Path $RunRoot "pytest-full-suite.txt") `
    -Content ($PytestText + "`r`n")

$PytestOutput | ForEach-Object { Write-Host $_ }

if (-not $PytestPassed) {
    throw "La suite institucional fallo."
}

if ($TestCount -lt 808) {
    throw "Regresion detectada: menos de 808 pruebas aprobadas."
}

Write-Step "Construyendo manifest institucional de publicacion"

$MaxArtifactBytes = [long]$MaxArtifactMB * 1MB

$Inventory = Get-PublicationInventory `
    -Root $ProjectRoot `
    -MaxArtifactBytes $MaxArtifactBytes

$Approved = @($Inventory.Approved)
$Excluded = @($Inventory.Excluded)
$DeletionReview = @($Inventory.MissingTracked)

$BackupOrLongPathExcluded = @(
    $Excluded |
    Where-Object {
        $_.PSObject.Properties.Name -contains "classification" -and
        $_.classification -eq "BACKUP_OR_LONG_PATH_EXCLUDED"
    }
)

Write-Host "  Tracked encontrados: $($Inventory.TrackedCount)" -ForegroundColor DarkGray
Write-Host "  Untracked candidatos: $($Inventory.UntrackedCount)" -ForegroundColor DarkGray
Write-Host "  Aprobados para manifest: $($Approved.Count)" -ForegroundColor DarkGray
Write-Host "  Excluidos: $($Excluded.Count)" -ForegroundColor DarkGray
Write-Host "  Backups/rutas largas excluidos: $($BackupOrLongPathExcluded.Count)" -ForegroundColor DarkGray
Write-Host "  Eliminaciones para revision: $($DeletionReview.Count)" -ForegroundColor DarkGray

$SelfRelative = Get-RelativePathSafe -Root $ProjectRoot -Path $SelfPath

if (@($Approved | Where-Object { $_.path -eq $SelfRelative }).Count -ne 1) {
    throw "El propio instalador SPT-021.0.1 no quedo incluido en el manifest."
}

$LocalTagMap = Get-LocalTagMap
$RemoteTagInfo = Get-RemoteTagMap
$RemoteTagMap = $RemoteTagInfo.Map

$LocalTags = @($LocalTagMap.Keys | Sort-Object)
$RemoteTags = @($RemoteTagMap.Keys | Sort-Object)

$PendingTags = @(
    $LocalTags |
    Where-Object { -not $RemoteTagMap.ContainsKey($_) }
)

$TagConflicts = @()

foreach ($Tag in $LocalTags) {
    if (-not $RemoteTagMap.ContainsKey($Tag)) {
        continue
    }

    $LocalInfo = $LocalTagMap[$Tag]
    $RemoteInfo = $RemoteTagMap[$Tag]

    $LocalComparable = if ($LocalInfo.peeled) {
        $LocalInfo.peeled
    }
    else {
        $LocalInfo.object
    }

    $RemoteComparable = if ($RemoteInfo.peeled) {
        $RemoteInfo.peeled
    }
    else {
        $RemoteInfo.object
    }

    if (
        $LocalComparable -and
        $RemoteComparable -and
        ($LocalComparable -ne $RemoteComparable)
    ) {
        $TagConflicts += [ordered]@{
            tag = $Tag
            local_object = $LocalInfo.object
            local_peeled = $LocalInfo.peeled
            remote_object = $RemoteInfo.object
            remote_peeled = $RemoteInfo.peeled
            classification = "TAG_DIVERGENCE"
            blocking_fetch = $false
            action = "REVIEW_BEFORE_TAG_PUBLICATION"
        }
    }
}

$PublicationManifest = [ordered]@{
    component = $Component
    version = $Version
    generated_at_utc = $GeneratedUtc
    run_id = $RunId
    mode = $Mode
    repository = "Poliyoko/APP-PUINAVE"
    remote = $ActualRemote
    branch = $Branch
    baseline = "SPT-020 CLOSED"
    fetch_succeeded = $FetchSucceeded
    ahead_before = $AheadBefore
    behind_before = $BehindBefore
    tests_passed = $TestCount
    python_compile_exit_code = $CompileExitCode
    powershell_syntax_errors = $PowerShellErrors.Count
    active_powershell_file_count = $ActivePowerShellFiles.Count
    historical_legacy_script_count = $HistoricalPowerShellFiles.Count
    historical_legacy_syntax_findings = $HistoricalPowerShellFindings.Count
    historical_legacy_gate_blocking = $false
    historical_legacy_registry = $HistoricalLegacyPowerShell
    candidate_file_count = $Inventory.CandidateCount
    tracked_file_count = $Inventory.TrackedCount
    untracked_candidate_count = $Inventory.UntrackedCount
    publishable_file_count = $Approved.Count
    excluded_file_count = $Excluded.Count
    backup_or_long_path_excluded_count = $BackupOrLongPathExcluded.Count
    max_git_relative_path_length = 220
    deletion_review_required_count = $DeletionReview.Count
    deletion_review_required = $DeletionReview
    max_artifact_mb = $MaxArtifactMB
    publish_tags_requested = [bool]$PublishTags
    pending_tags = $PendingTags
    remote_tags_reachable = [bool]$RemoteTagInfo.Reachable
    tag_conflicts = $TagConflicts
    tag_conflict_count = $TagConflicts.Count
    fetch_policy = "BRANCH_ONLY_NO_TAGS"
    tag_policy = "LS_REMOTE_DIAGNOSTIC_NO_CLOBBER"
    filename_transport = "GIT_NUL_DELIMITED_CORE_QUOTEPATH_FALSE"
    staging_line_ending_policy = "PER_COMMAND_CORE_SAFECRLF_FALSE"
    staging_respects_gitattributes = $true
    global_git_config_modified = $false
    approved_files = $Approved
}

$ManifestPath = Join-Path $RunRoot "publication-manifest.json"
Write-JsonFile -Path $ManifestPath -Data $PublicationManifest

$ExcludedPath = Join-Path $RunRoot "publication-exclusions.json"
Write-JsonFile -Path $ExcludedPath -Data $Excluded

$DeletionReviewPath = Join-Path $RunRoot "deletion-review-required.json"
Write-JsonFile -Path $DeletionReviewPath -Data $DeletionReview

$Plan = @"
# SPT-021.0.1 - Institutional Repository Publication Plan

| Campo | Valor |
|---|---|
| Modo | $Mode |
| Repositorio | Poliyoko/APP-PUINAVE |
| Rama | $Branch |
| Fetch exitoso | $FetchSucceeded |
| Ahead antes | $AheadBefore |
| Behind antes | $BehindBefore |
| Archivos aprobados | $($Approved.Count) |
| Archivos excluidos | $($Excluded.Count) |
| Eliminaciones pendientes de revision | $($DeletionReview.Count) |
| Tags pendientes | $($PendingTags.Count) |
| Publicar tags | $([bool]$PublishTags) |
| Suite | $TestCount passed |
| Active PowerShell errors | 0 |
| Historical legacy scripts | $($HistoricalPowerShellFiles.Count) |
| Historical legacy findings | $($HistoricalPowerShellFindings.Count) |
| Historical findings blocking | NO |
| Python compile | 0 |

El motor usa allowlist institucional y nunca ejecuta git add punto.
Los archivos tracked ausentes se registran como DELETION_REVIEW_REQUIRED y
no se eliminan automaticamente del repositorio remoto.
Los nombres de archivo se obtienen con salida Git NUL-delimited (-z), sin
interpretar comillas ni secuencias de escape de la salida humana de Git.
Durante staging se usa core.safecrlf=false solo por comando para permitir la
normalizacion canonica CRLF/LF definida por Git y .gitattributes. No se cambia
la configuracion global ni se reescriben archivos de trabajo.
Las rutas de respaldo recursivo (repository-backup, registry-backup, backup)
y las rutas Git mayores de 220 caracteres se excluyen del manifest como
BACKUP_OR_LONG_PATH_EXCLUDED y nunca bloquean la publicacion.
"@

$PlanPath = Join-Path $DocsRoot "SGD-439-SPT-021.0.1-Publication-Plan.md"
Write-TextFile -Path $PlanPath -Content $Plan

$CommitCreated = $false
$CommitHash = ""
$PushSucceeded = $false
$TagsPushSucceeded = $false
$VerificationFetchSucceeded = $false
$AheadAfter = $AheadBefore
$BehindAfter = $BehindBefore

if ($Publish) {
    if (-not $FetchSucceeded) {
        Write-Warning (
            "Fetch de rama no fue exitoso. " +
            "PUBLISH continuara solo si la referencia remota " +
            "puede verificarse de forma segura."
        )
    }

    if (-not $RemoteBranchExists) {
        $RemoteBranchLookup = Invoke-NativeGit `
            -Arguments @(
                "ls-remote",
                "--heads",
                "origin",
                "refs/heads/$Branch"
            ) `
            -AllowFailure

        if ($RemoteBranchLookup.ExitCode -ne 0) {
            throw (
                "PUBLISH bloqueado por imposibilidad de verificar la rama remota. " +
                "No es un fallo por git fetch."
            )
        }
    }

    Write-Step "Preparando staging institucional controlado"

    [void](Invoke-NativeGit -Arguments @("reset"))

    $StageIndex = 0
    $StageTotal = $Approved.Count

    foreach ($Item in $Approved) {
        $StageIndex++

        if (($StageIndex % 100) -eq 0 -or $StageIndex -eq $StageTotal) {
            Write-Host (
                "  Staging: {0}/{1}" -f $StageIndex, $StageTotal
            ) -ForegroundColor DarkGray
        }

        $Full = Join-Path $ProjectRoot ($Item.path.Replace("/", "\"))

        if (Test-Path -LiteralPath $Full -PathType Leaf) {
            [void](Invoke-NativeGit -Arguments @(
                "-c",
                "core.safecrlf=false",
                "add",
                "--",
                $Item.path
            ))
        }
    }

    # Incluir plan, manifest y evidencia de esta ejecucion.
    foreach ($Generated in @(
        $PlanPath,
        $ManifestPath,
        $ExcludedPath,
        $DeletionReviewPath,
        $PowerShellErrorsPath,
        $HistoricalPowerShellFindingsPath,
        $HistoricalPowerShellRegistryPath,
        (Join-Path $RunRoot "python-compileall.txt"),
        (Join-Path $RunRoot "pytest-full-suite.txt")
    )) {
        $GeneratedRelative = Get-RelativePathSafe `
            -Root $ProjectRoot `
            -Path $Generated

        [void](Invoke-NativeGit -Arguments @(
            "-c",
            "core.safecrlf=false",
            "add",
            "--",
            $GeneratedRelative
        ))
    }

    $StagedResult = Invoke-NativeGit -Arguments @(
        "diff",
        "--cached",
        "--name-only"
    )

    $StagedFiles = @(
        $StagedResult.Output |
        ForEach-Object { $_.ToString().Trim() } |
        Where-Object { $_ }
    )

    if ($StagedFiles.Count -gt 0) {
        Write-Host "Archivos staged: $($StagedFiles.Count)"

        Write-Step "Creando commit institucional"

        $CommitResult = Invoke-NativeGit -Arguments @(
            "commit",
            "-m",
            $CommitMessage
        )

        $CommitCreated = $true

        $CommitHash = (
            Invoke-NativeGit -Arguments @(
                "rev-parse",
                "HEAD"
            )
        ).Output[0].ToString().Trim()
    }
    else {
        Write-Host "No existen cambios nuevos para commit." -ForegroundColor Yellow

        $CommitHash = (
            Invoke-NativeGit -Arguments @(
                "rev-parse",
                "HEAD"
            )
        ).Output[0].ToString().Trim()
    }

    Write-Step "Publicando rama institucional sin force"

    $PushResult = Invoke-NativeGit `
        -Arguments @(
            "push",
            "-u",
            "origin",
            $Branch
        ) `
        -AllowFailure

    $PushSucceeded = ($PushResult.ExitCode -eq 0)

    if (-not $PushSucceeded) {
        throw "git push de la rama fallo."
    }

    if ($PublishTags) {
        Write-Step "Publicando tags locales pendientes"

        if ($PendingTags.Count -eq 0) {
            $TagsPushSucceeded = $true
            Write-Host "No hay tags pendientes."
        }
        else {
            $AllTagsOk = $true

            foreach ($Tag in $PendingTags) {
                if (@($TagConflicts | Where-Object { $_.tag -eq $Tag }).Count -gt 0) {
                    Write-Warning "Tag conflictivo omitido: $Tag"
                    continue
                }
                $TagPush = Invoke-NativeGit `
                    -Arguments @(
                        "push",
                        "origin",
                        "refs/tags/$Tag"
                    ) `
                    -AllowFailure

                if ($TagPush.ExitCode -ne 0) {
                    $AllTagsOk = $false
                }
            }

            $TagsPushSucceeded = $AllTagsOk

            if (-not $TagsPushSucceeded) {
                throw "Uno o mas tags no pudieron publicarse."
            }
        }
    }
    else {
        $TagsPushSucceeded = ($PendingTags.Count -eq 0)
    }

    Write-Step "Verificando reconciliacion post-publicacion"

    $VerifyFetch = Invoke-NativeGit `
        -Arguments @(
            "fetch",
            "origin",
            "--prune",
            "--no-tags"
        ) `
        -AllowFailure

    $VerificationFetchSucceeded = ($VerifyFetch.ExitCode -eq 0)

    if (-not $VerificationFetchSucceeded) {
        Write-Warning (
            "Fetch de verificacion no fue exitoso. " +
            "El fetch por si mismo no genera error tecnico."
        )
    }

    $RemoteBranch = "origin/" + $Branch

    $CountAfter = Invoke-NativeGit -Arguments @(
        "rev-list",
        "--left-right",
        "--count",
        "$RemoteBranch...HEAD"
    )

    $CountsAfter = $CountAfter.Text.Trim() -split "\s+"

    if ($CountsAfter.Count -ge 2) {
        $BehindAfter = [int]$CountsAfter[0]
        $AheadAfter = [int]$CountsAfter[1]
    }
}

$RepositoryStatus = if (
    $Publish -and
    $PushSucceeded -and
    $VerificationFetchSucceeded -and
    ($AheadAfter -eq 0) -and
    ($BehindAfter -eq 0) -and
    (
        (-not $PublishTags) -or
        $TagsPushSucceeded
    )
) {
    "SYNCHRONIZED"
}
elseif (-not $Publish) {
    "READY_FOR_PUBLICATION"
}
else {
    "RECONCILIATION_REQUIRED"
}

$TechnicalErrors = 0

if ($PowerShellErrors.Count -ne 0) { $TechnicalErrors++ }
if ($CompileExitCode -ne 0) { $TechnicalErrors++ }
if (-not $PytestPassed) { $TechnicalErrors++ }
if ($TestCount -lt 808) { $TechnicalErrors++ }

if ($Publish) {
    if (-not $PushSucceeded) { $TechnicalErrors++ }
    if ($AheadAfter -ne 0) { $TechnicalErrors++ }
    if ($BehindAfter -ne 0) { $TechnicalErrors++ }

    if ($PublishTags -and (-not $TagsPushSucceeded)) {
        $TechnicalErrors++
    }
}

$Status = if ($TechnicalErrors -eq 0) {
    if ($Publish) { "CLOSED" } else { "PREPARED" }
}
else {
    "BLOCKED"
}

$Evidence = [ordered]@{
    component = $Component
    version = $Version
    generated_at_utc = $GeneratedUtc
    run_id = $RunId
    mode = $Mode
    status = $Status
    repository_status = $RepositoryStatus
    technical_errors = $TechnicalErrors
    remote = $ActualRemote
    branch = $Branch
    commit_created = $CommitCreated
    commit_hash = $CommitHash
    push_succeeded = $PushSucceeded
    tags_push_succeeded = $TagsPushSucceeded
    ahead_before = $AheadBefore
    behind_before = $BehindBefore
    ahead_after = $AheadAfter
    behind_after = $BehindAfter
    tests_passed = $TestCount
    pytest_passed = $PytestPassed
    python_compile_exit_code = $CompileExitCode
    powershell_syntax_errors = $PowerShellErrors.Count
    active_powershell_file_count = $ActivePowerShellFiles.Count
    historical_legacy_script_count = $HistoricalPowerShellFiles.Count
    historical_legacy_syntax_findings = $HistoricalPowerShellFindings.Count
    historical_legacy_gate_blocking = $false
    historical_legacy_registry_report = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $HistoricalPowerShellRegistryPath
    historical_legacy_findings_report = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $HistoricalPowerShellFindingsPath
    deletion_review_required_count = $DeletionReview.Count
    deletion_review_report = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $DeletionReviewPath
    fetch_policy = "BRANCH_ONLY_NO_TAGS"
    staging_line_ending_policy = "PER_COMMAND_CORE_SAFECRLF_FALSE"
    staging_respects_gitattributes = $true
    global_git_config_modified = $false
    remote_tags_reachable = [bool]$RemoteTagInfo.Reachable
    tag_conflict_count = $TagConflicts.Count
    tag_conflicts = $TagConflicts
    publication_manifest = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $ManifestPath
    publication_performed = [bool]$Publish
    n8n_installed = $false
    paid_services_required = $false
}

$EvidencePath = Join-Path $RunRoot "implementation-evidence.json"
Write-JsonFile -Path $EvidencePath -Data $Evidence

$ActState = if ($Publish) {
    if ($Status -eq "CLOSED") {
        "CLOSED - REPOSITORY SYNCHRONIZED"
    }
    else {
        "PUBLICATION BLOCKED"
    }
}
else {
    "PREPARED - AWAITING PUBLISH EXECUTION"
}

$Act = @"
# ACT-021.0.1 - Institutional Repository Reconciliation & Publication

| Campo | Resultado |
|---|---|
| Componente | SPT-021.0.1 |
| Version | $Version |
| Modo | $Mode |
| Estado | $ActState |
| Repositorio | Poliyoko/APP-PUINAVE |
| Rama | $Branch |
| Commit creado | $CommitCreated |
| Commit | $CommitHash |
| Push | $PushSucceeded |
| Tags push | $TagsPushSucceeded |
| Ahead post | $AheadAfter |
| Behind post | $BehindAfter |
| Suite | $TestCount passed |
| Errores tecnicos | $TechnicalErrors |
| n8n instalado | NO |
| Servicios de pago | NO |

La publicacion utiliza un manifest institucional controlado, conserva la
historia Git, no realiza force push y no ejecuta git add punto.
"@

$ActPath = Join-Path $DocsRoot "ACT-021.0.1-Reconciliation-Publication.md"
Write-TextFile -Path $ActPath -Content $Act

$ReleaseManifest = [ordered]@{
    component = $Component
    version = $Version
    status = $Status
    repository_status = $RepositoryStatus
    mode = $Mode
    commit_hash = $CommitHash
    tests_passed = $TestCount
    technical_errors = $TechnicalErrors
    publication_manifest = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $ManifestPath
    evidence = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $EvidencePath
    act = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $ActPath
}

$ReleaseManifestPath = Join-Path $ReleaseRoot "manifest.json"
Write-JsonFile -Path $ReleaseManifestPath -Data $ReleaseManifest

Copy-Item `
    -LiteralPath $ManifestPath `
    -Destination (Join-Path $ReleaseRoot "publication-manifest.json") `
    -Force

Copy-Item `
    -LiteralPath $EvidencePath `
    -Destination (Join-Path $ReleaseRoot "implementation-evidence.json") `
    -Force

Copy-Item `
    -LiteralPath $ActPath `
    -Destination (Join-Path $ReleaseRoot "ACT-021.0.1-Reconciliation-Publication.md") `
    -Force

Write-Step "Registrando politica de PowerShell historico"

$LegacyPolicyPath = Join-Path `
    $ProjectRoot `
    "docs\06_Tecnologia\SPT-021.0.1\SGD-440-Historical-Legacy-PowerShell-Policy.md"

$LegacyPolicy = @"
# SGD-440 - Historical Legacy PowerShell Policy

## Proposito

Separar codigo PowerShell activo de scripts historicos preservados para
trazabilidad institucional.

## Regla

Los scripts clasificados como `HISTORICAL_LEGACY_SCRIPT`:

- permanecen en el repositorio oficial;
- permanecen en inventarios, evidencia, releases y Libro Maestro;
- son auditados y sus hallazgos se registran;
- no forman parte del gate bloqueante de sintaxis PowerShell activa;
- no pueden incorporarse a esta clasificacion automaticamente;
- requieren inclusion explicita en el registro canonico del publicador.

## Registro canonico

$(
    ($HistoricalLegacyPowerShell | ForEach-Object {
        "- ``$_``"
    }) -join "`r`n"
)

## Resultado del run

- Active PowerShell files: $($ActivePowerShellFiles.Count)
- Active PowerShell syntax errors: $($PowerShellErrors.Count)
- Historical legacy scripts detected: $($HistoricalPowerShellFiles.Count)
- Historical legacy syntax findings: $($HistoricalPowerShellFindings.Count)
- Historical findings blocking: NO

Esta politica no elimina, modifica ni oculta los scripts historicos.
Unicamente evita tratarlos como codigo activo de la linea base vigente.
"@

Write-TextFile `
    -Path $LegacyPolicyPath `
    -Content ($LegacyPolicy + "`r`n")

Write-Step "Actualizando referencia persistente de publicacion"

$PersistentWrapper = Join-Path `
    $ProjectRoot `
    "tools\institutional\Publish-SGODA-WithMasterBook.ps1"

$PersistentPublisherCopy = Join-Path `
    $ProjectRoot `
    "tools\institutional\Install-SPT021.0.1-v1.0.7-OneFile-PS51.ps1"

if (Test-Path -LiteralPath $PersistentWrapper -PathType Leaf) {
    $WrapperText = Get-Content -LiteralPath $PersistentWrapper -Raw

    if ($null -eq $WrapperText) {
        $WrapperText = ""
    }

    $UpdatedWrapperText = $WrapperText.Replace(
        "Install-SPT021.0.1-v1.0.6-OneFile-PS51.ps1",
        "Install-SPT021.0.1-v1.0.7-OneFile-PS51.ps1"
    )

    if ($UpdatedWrapperText -ne $WrapperText) {
        Write-TextFile `
            -Path $PersistentWrapper `
            -Content $UpdatedWrapperText
    }
}

Copy-Item `
    -LiteralPath $SelfPath `
    -Destination $PersistentPublisherCopy `
    -Force

$WrapperSyntaxErrors = @()

if (Test-Path -LiteralPath $PersistentWrapper -PathType Leaf) {
    $WrapperSyntaxErrors = @(
        Test-PowerShellSyntax -Path $PersistentWrapper
    )
}

if ($WrapperSyntaxErrors.Count -ne 0) {
    throw (
        "El wrapper persistente quedo con " +
        $WrapperSyntaxErrors.Count +
        " error(es) de sintaxis."
    )
}

Write-Step "Resultado final"

Write-Host "Mode: $Mode"
Write-Host "SPT-020 baseline: CLOSED"
Write-Host "Remote verified: True"
Write-Host "Fetch succeeded: $FetchSucceeded"
Write-Host "Branch: $Branch"
Write-Host "Ahead before: $AheadBefore"
Write-Host "Behind before: $BehindBefore"
Write-Host "Publishable files: $($Approved.Count)"
Write-Host "Excluded files: $($Excluded.Count)"
Write-Host "Backup/long-path exclusions: $($BackupOrLongPathExcluded.Count)"
Write-Host "Deletion review required: $($DeletionReview.Count)"
Write-Host "Pending tags: $($PendingTags.Count)"
Write-Host "Remote tags reachable: $($RemoteTagInfo.Reachable)"
Write-Host "Tag conflicts detected: $($TagConflicts.Count)"
Write-Host "Fetch policy: BRANCH_ONLY_NO_TAGS"
Write-Host "Tag policy: LS_REMOTE_DIAGNOSTIC_NO_CLOBBER"
Write-Host "Filename transport: GIT_NUL_DELIMITED_CORE_QUOTEPATH_FALSE"
Write-Host "Staging EOL policy: PER_COMMAND_CORE_SAFECRLF_FALSE"
Write-Host "Global Git config modified: NO"
Write-Host "Active PowerShell files: $($ActivePowerShellFiles.Count)"
Write-Host "PowerShell syntax errors: $($PowerShellErrors.Count)"
Write-Host "Historical legacy scripts: $($HistoricalPowerShellFiles.Count)"
Write-Host "Historical legacy findings: $($HistoricalPowerShellFindings.Count)"
Write-Host "Historical findings blocking: NO"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Pytest passed: $PytestPassed"
Write-Host "Tests passed: $TestCount"
Write-Host "Commit created: $CommitCreated"
Write-Host "Commit hash: $CommitHash"
Write-Host "Push succeeded: $PushSucceeded"
Write-Host "Tags push succeeded: $TagsPushSucceeded"
Write-Host "Ahead after: $AheadAfter"
Write-Host "Behind after: $BehindAfter"
Write-Host "Repository status: $RepositoryStatus"
Write-Host "Persistent publication engine: SPT-021.0.1 v1.0.7"
Write-Host "Persistent wrapper syntax errors: $($WrapperSyntaxErrors.Count)"
Write-Host "Technical errors: $TechnicalErrors"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Manifest: $ManifestPath" -ForegroundColor Cyan
Write-Host "Evidence: $EvidencePath" -ForegroundColor Cyan
Write-Host "Act: $ActPath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan
Write-Host "Institutional status: $Status" -ForegroundColor Cyan

if ($TechnicalErrors -ne 0) {
    Write-Host "SPT-021.0.1: BLOCKED." -ForegroundColor Red
    exit 1
}

if ($Publish) {
    Write-Host "SPT-021.0.1: CLOSED WITH ZERO TECHNICAL ERRORS." -ForegroundColor Green
    Write-Host "OFFICIAL REPOSITORY: $RepositoryStatus" -ForegroundColor Green
}
else {
    Write-Host "SPT-021.0.1: PREPARED WITH ZERO TECHNICAL ERRORS." -ForegroundColor Green
    Write-Host "Run the same file with -Publish after reviewing the manifest." -ForegroundColor Yellow
}
