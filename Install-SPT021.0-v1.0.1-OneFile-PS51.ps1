<#
.SYNOPSIS
    SPT-021.0 - Institutional Technology Baseline & Gap Analyzer v1.0.1
    One File Installer - Windows PowerShell 5.1

.DESCRIPTION
    Analiza la linea base tecnologica institucional de SGODA-PUINAVE y
    reconcilia explicitamente el estado local contra el repositorio remoto
    oficial GitHub:

        https://github.com/Poliyoko/APP-PUINAVE

    No publica cambios. No hace push. No crea tags remotos. No crea releases.

    Dimensiones:
      - inventario local de capacidades y componentes;
      - documentacion institucional;
      - releases locales;
      - estado Git local;
      - commits local vs remoto;
      - archivos local vs remoto;
      - tags local vs remoto;
      - releases GitHub;
      - solapamientos;
      - gaps;
      - clasificacion institucional:
          IMPLEMENTED_LOCAL
          DOCUMENTED
          PUBLISHED_REMOTE
          RELEASED
          SYNCHRONIZED

    Clasificacion de capacidades:
          EXISTING
          REUSABLE
          EXTEND
          INTEGRATE
          MISSING
          DEPRECATED

    Requisitos institucionales:
      - reutilizar SPT-020 como linea base cerrada;
      - no duplicar capacidades;
      - no instalar n8n;
      - no usar servicios de pago;
      - ejecutar suite completa;
      - cerrar solo con cero errores tecnicos.

.PARAMETER ProjectRoot
    Raiz del repositorio. Por defecto usa la carpeta actual.

.PARAMETER ExpectedRemote
    Repositorio GitHub oficial esperado.

.EXAMPLE
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    .\Install-SPT021.0-v1.0.1-OneFile-PS51.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$ExpectedRemote = "https://github.com/Poliyoko/APP-PUINAVE.git"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-021.0"
$Version = "1.0.1"
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

function Invoke-Git {
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

    $EscapedArguments = @()

    foreach ($Argument in $Arguments) {
        $Value = [string]$Argument

        if (
            $Value.Contains(" ") -or
            $Value.Contains("`t") -or
            $Value.Contains('"')
        ) {
            $Value = '"' + $Value.Replace('"', '\"') + '"'
        }

        $EscapedArguments += $Value
    }

    $StartInfo.Arguments = $EscapedArguments -join " "

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $StartInfo

    [void]$Process.Start()

    $StdOutText = $Process.StandardOutput.ReadToEnd()
    $StdErrText = $Process.StandardError.ReadToEnd()

    $Process.WaitForExit()

    $ExitCode = $Process.ExitCode

    $Output = @()

    if (-not [string]::IsNullOrWhiteSpace($StdOutText)) {
        $Output += @(
            $StdOutText -split "?
" |
            Where-Object { $_ -ne "" }
        )
    }

    if (-not [string]::IsNullOrWhiteSpace($StdErrText)) {
        $Output += @(
            $StdErrText -split "?
" |
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
            ($Output -join "`r`n")
        )
    }

    return [PSCustomObject]@{
        ExitCode = $ExitCode
        Output = @($Output)
        Text = ($Output -join "`r`n")
        StdOut = $StdOutText
        StdErr = $StdErrText
    }
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

function Get-ComponentIdsFromText {
    param([string]$Text)

    $Matches = [regex]::Matches(
        $Text,
        "\b(?:SPT|SPB|SGD|PCI|POL|SIB|ADR)-?\d+(?:\.\d+)?[A-Z]?\b",
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    return @(
        $Matches |
        ForEach-Object { $_.Value.ToUpperInvariant() } |
        Sort-Object -Unique
    )
}

function Get-LocalComponentInventory {
    param([string]$Root)

    $Roots = @(
        $Root,
        (Join-Path $Root "src"),
        (Join-Path $Root "docs"),
        (Join-Path $Root "config"),
        (Join-Path $Root "tests"),
        (Join-Path $Root "releases")
    )

    $Files = @()

    foreach ($ScanRoot in $Roots) {
        if (-not (Test-Path -LiteralPath $ScanRoot -PathType Container)) {
            continue
        }

        if ($ScanRoot -eq $Root) {
            $Files += @(
                Get-ChildItem `
                    -LiteralPath $ScanRoot `
                    -File `
                    -ErrorAction SilentlyContinue
            )
        }
        else {
            $Files += @(
                Get-ChildItem `
                    -LiteralPath $ScanRoot `
                    -Recurse `
                    -File `
                    -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.FullName -notmatch "\\__pycache__\\" -and
                    $_.FullName -notmatch "\\.pytest_cache\\" -and
                    $_.FullName -notmatch "\\backup\\" -and
                    $_.Length -lt 5242880
                }
            )
        }
    }

    $Map = @{}

    foreach ($File in ($Files | Sort-Object FullName -Unique)) {
        $Relative = Get-RelativePathSafe -Root $Root -Path $File.FullName
        $Ids = Get-ComponentIdsFromText -Text $Relative

        foreach ($Id in $Ids) {
            if (-not $Map.ContainsKey($Id)) {
                $Map[$Id] = New-Object System.Collections.ArrayList
            }

            [void]$Map[$Id].Add($Relative)
        }
    }

    $Results = @()

    foreach ($Id in ($Map.Keys | Sort-Object)) {
        $Paths = @($Map[$Id] | Sort-Object -Unique)

        $Documented = @(
            $Paths | Where-Object { $_ -like "docs/*" }
        ).Count -gt 0

        $ReleasedLocal = @(
            $Paths | Where-Object { $_ -like "releases/*" }
        ).Count -gt 0

        $ImplementedLocal = @(
            $Paths |
            Where-Object {
                $_ -like "src/*" -or
                $_ -like "tests/*" -or
                $_ -like "config/*" -or
                $_ -like "Install-*" -or
                $_ -like "Apply-*" -or
                $_ -like "Close-*"
            }
        ).Count -gt 0

        $Results += [ordered]@{
            component = $Id
            implemented_local = $ImplementedLocal
            documented = $Documented
            released_local = $ReleasedLocal
            local_paths = $Paths
        }
    }

    return @($Results)
}

function Test-RemoteComponentPublished {
    param(
        [string]$ComponentId,
        [string[]]$RemoteTree
    )

    $Needle = $ComponentId.ToLowerInvariant()

    return @(
        $RemoteTree |
        Where-Object {
            $_.ToLowerInvariant().Contains($Needle)
        }
    ).Count -gt 0
}

function Test-ComponentReleasedRemote {
    param(
        [string]$ComponentId,
        [object[]]$RemoteReleases,
        [string[]]$RemoteTags
    )

    $Needle = $ComponentId.ToLowerInvariant()

    foreach ($Release in $RemoteReleases) {
        $Title = ""
        $Tag = ""

        if ($Release.PSObject.Properties.Name -contains "name") {
            $Title = [string]$Release.name
        }

        if ($Release.PSObject.Properties.Name -contains "tag_name") {
            $Tag = [string]$Release.tag_name
        }

        if (
            $Title.ToLowerInvariant().Contains($Needle) -or
            $Tag.ToLowerInvariant().Contains($Needle)
        ) {
            return $true
        }
    }

    foreach ($Tag in $RemoteTags) {
        if ($Tag.ToLowerInvariant().Contains($Needle)) {
            return $true
        }
    }

    return $false
}

function Get-TechnologyCapability {
    param([string]$ComponentId)

    $Id = $ComponentId.ToUpperInvariant()

    $Known = [ordered]@{
        "SPT-002" = "ODA Engine"
        "SPT-003A" = "AI Multimedia Orchestrator"
        "SPT-003B" = "AI Multimedia Adapters"
        "SPT-003C" = "Controlled Provider Pilot"
        "SPT-004A" = "Institutional Assistant Foundation"
        "SPT-005" = "Configurable Cultural Identity"
        "SPT-006" = "Automated Multilingual Multimedia Pipeline"
        "SPT-006A" = "Free Local Multilingual Engine"
        "SPT-007A" = "Intelligent Lexical Engine"
        "SPT-007B" = "Semantic Lexical Engine"
        "SPT-007C" = "Linguistic Cultural Knowledge Engine"
        "SPT-010" = "Integrated Digital Platform"
        "SPT-011" = "Operational SGODA Platform"
        "SPT-012" = "SGODA Learning Platform"
        "SPT-013A" = "Learning Ecosystem Foundation"
        "SPT-013B" = "Institutional Digital Dictionary Manager"
        "SPT-014" = "Intelligent Multimedia Engine"
        "SPT-015" = "Adaptive Assessment Engine"
        "SPT-016" = "Learning Analytics Engine"
        "SPT-017" = "Puinave Knowledge Center"
        "SPT-018" = "SGODA Pedagogical AI"
        "SPT-019.0" = "Institutional Project State Manager"
        "SPT-019.1" = "Workflow Engine Core"
        "SPT-019.2" = "Workflow Registry Manager"
        "SPT-019.3" = "Workflow Institutional Integration"
        "SPT-020.1" = "Institutional Service Bus"
        "SPT-020.2" = "Component Lifecycle Manager"
        "SPT-020.3" = "Component Dependency Manager"
        "SPT-020.4" = "Institutional Event Bus"
        "SPT-020.5" = "Service Discovery and Registry"
        "SPT-020.6" = "Institutional Runtime Orchestrator"
        "SPT-020.7" = "Institutional Health Monitor"
        "SPT-020.8" = "Zero Error Institutional Closure"
        "SPT-020.9" = "Institutional Master State Update Engine"
        "SGD-114" = "Evidence and Traceability Governance"
        "SGD-115" = "Master Documentation System"
        "SGD-116" = "Master Ecosystem Roadmap"
        "SGD-117" = "Institutional Repository Manager"
        "SIB-001" = "SGODA Installer Builder"
        "SPB-007" = "Institutional Repository Publisher"
        "POL-001" = "Free and Open Source Governance"
        "PCI-001" = "Institutional Master Index"
        "PCI-002" = "Institutional Consolidation"
    }

    if ($Known.Contains($Id)) {
        return $Known[$Id]
    }

    return "Institutional component"
}

function Get-RecommendedCapabilityAction {
    param(
        [bool]$ImplementedLocal,
        [bool]$Documented,
        [bool]$PublishedRemote,
        [bool]$ReleasedRemote,
        [bool]$Synchronized
    )

    if ($Synchronized -and $ReleasedRemote) {
        return "REUSABLE"
    }

    if ($ImplementedLocal -and $Documented -and $PublishedRemote) {
        return "EXISTING"
    }

    if ($ImplementedLocal -and (-not $PublishedRemote)) {
        return "INTEGRATE"
    }

    if ($Documented -and (-not $ImplementedLocal)) {
        return "EXTEND"
    }

    if ((-not $ImplementedLocal) -and (-not $Documented)) {
        return "MISSING"
    }

    return "EXISTING"
}

function Get-StatusLabels {
    param(
        [bool]$ImplementedLocal,
        [bool]$Documented,
        [bool]$PublishedRemote,
        [bool]$ReleasedRemote,
        [bool]$Synchronized
    )

    $Labels = @()

    if ($ImplementedLocal) { $Labels += "IMPLEMENTED_LOCAL" }
    if ($Documented) { $Labels += "DOCUMENTED" }
    if ($PublishedRemote) { $Labels += "PUBLISHED_REMOTE" }
    if ($ReleasedRemote) { $Labels += "RELEASED" }
    if ($Synchronized) { $Labels += "SYNCHRONIZED" }

    return @($Labels)
}

function Get-GitHubReleases {
    param([string]$RepositorySlug)

    $Uri = "https://api.github.com/repos/$RepositorySlug/releases?per_page=100"

    try {
        $Headers = @{
            "User-Agent" = "SGODA-SPT-021.0"
            "Accept" = "application/vnd.github+json"
        }

        return @(
            Invoke-RestMethod `
                -Uri $Uri `
                -Headers $Headers `
                -Method Get `
                -UseBasicParsing `
                -ErrorAction Stop
        )
    }
    catch {
        Write-Warning (
            "No fue posible consultar GitHub Releases por API. " +
            "Se continuara con tags y refs Git."
        )
        return @()
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

foreach ($Required in @(
    "src",
    "tests",
    "docs",
    "config",
    "artifacts",
    "releases"
)) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $Required))) {
        throw "Falta carpeta institucional obligatoria: $Required"
    }
}

foreach ($Command in @("git", "python")) {
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "Comando requerido no disponible: $Command"
    }
}

$SelfErrors = @(Test-PowerShellSyntax -Path $SelfPath)

if ($SelfErrors.Count -ne 0) {
    throw "SPT-021.0 contiene errores de sintaxis PowerShell."
}

$GitTop = Invoke-Git -Arguments @("rev-parse", "--show-toplevel")
$GitRoot = [System.IO.Path]::GetFullPath($GitTop.Output[0].ToString().Trim())

if ($GitRoot.TrimEnd("\") -ne $ProjectRoot.TrimEnd("\")) {
    throw (
        "La carpeta actual no coincide con la raiz Git. " +
        "ProjectRoot=$ProjectRoot ; GitRoot=$GitRoot"
    )
}

$ClosureRegistryPath = Join-Path $ProjectRoot "config\platform\SPT-020-closure-registry.json"

if (-not (Test-Path -LiteralPath $ClosureRegistryPath -PathType Leaf)) {
    throw "Falta la linea base SPT-020-closure-registry.json."
}

$ClosureRegistry = Get-Content `
    -LiteralPath $ClosureRegistryPath `
    -Raw |
    ConvertFrom-Json

if ([string]$ClosureRegistry.final_status -ne "CLOSED") {
    throw "SPT-020 no esta CLOSED. SPT-021.0 no puede abrirse."
}

$RunRoot = Join-Path $ProjectRoot (
    "artifacts\development\SPT-021.0-v1.0.1\runs\" + $RunId
)
$DocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-021.0"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-021.0-v1.0.1"
$ConfigRoot = Join-Path $ProjectRoot "config\technology"

foreach ($Directory in @(
    $RunRoot,
    $DocsRoot,
    $ReleaseRoot,
    $ConfigRoot
)) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

Write-Step "Validando repositorio remoto oficial"

$RemoteResult = Invoke-Git -Arguments @("remote", "get-url", "origin")
$ActualRemote = $RemoteResult.Output[0].ToString().Trim()

if (
    (Normalize-GitRemote -Remote $ActualRemote) -ne
    (Normalize-GitRemote -Remote $ExpectedRemote)
) {
    throw (
        "El remote origin no coincide con el repositorio oficial. " +
        "Actual=$ActualRemote ; Esperado=$ExpectedRemote"
    )
}

Write-Host "Remote origin: $ActualRemote"

Write-Step "Actualizando referencias remotas sin publicar cambios"

$FetchResult = Invoke-Git `
    -Arguments @("fetch", "origin", "--prune", "--tags") `
    -AllowFailure

$RemoteAvailable = ($FetchResult.ExitCode -eq 0)

if (-not $RemoteAvailable) {
    Write-Warning (
        "git fetch fallo. Se generara diagnostico local, " +
        "pero el cierre quedara bloqueado."
    )
}

$BranchResult = Invoke-Git -Arguments @(
    "rev-parse",
    "--abbrev-ref",
    "HEAD"
)

$LocalBranch = $BranchResult.Output[0].ToString().Trim()
$RemoteBranch = "origin/" + $LocalBranch

$RemoteBranchExistsResult = Invoke-Git `
    -Arguments @("rev-parse", "--verify", $RemoteBranch) `
    -AllowFailure

if ($RemoteBranchExistsResult.ExitCode -ne 0) {
    if ($LocalBranch -ne "master") {
        $RemoteBranch = "origin/master"
    }
}

$LocalHead = (
    Invoke-Git -Arguments @("rev-parse", "HEAD")
).Output[0].ToString().Trim()

$RemoteHeadResult = Invoke-Git `
    -Arguments @("rev-parse", $RemoteBranch) `
    -AllowFailure

$RemoteHead = ""

if ($RemoteHeadResult.ExitCode -eq 0) {
    $RemoteHead = $RemoteHeadResult.Output[0].ToString().Trim()
}

$Ahead = 0
$Behind = 0

if ($RemoteHead) {
    $CountResult = Invoke-Git -Arguments @(
        "rev-list",
        "--left-right",
        "--count",
        "$RemoteBranch...HEAD"
    )

    $Counts = $CountResult.Text.Trim() -split "\s+"

    if ($Counts.Count -ge 2) {
        $Behind = [int]$Counts[0]
        $Ahead = [int]$Counts[1]
    }
}

$TrackedChanges = @(
    (Invoke-Git -Arguments @("status", "--porcelain")).Output
)

$ModifiedOrStaged = @(
    $TrackedChanges |
    Where-Object {
        $_ -and (-not $_.ToString().StartsWith("??"))
    }
)

$Untracked = @(
    $TrackedChanges |
    Where-Object {
        $_ -and $_.ToString().StartsWith("??")
    }
)

Write-Step "Inventariando archivos Git local y remoto"

$LocalTrackedFiles = @(
    (Invoke-Git -Arguments @("ls-files")).Output |
    ForEach-Object { $_.ToString().Replace("\", "/") } |
    Where-Object { $_ } |
    Sort-Object -Unique
)

$RemoteTree = @()

if ($RemoteHead) {
    $RemoteTree = @(
        (Invoke-Git -Arguments @(
            "ls-tree",
            "-r",
            "--name-only",
            $RemoteBranch
        )).Output |
        ForEach-Object { $_.ToString().Replace("\", "/") } |
        Where-Object { $_ } |
        Sort-Object -Unique
    )
}

$RemoteLookup = @{}

foreach ($Path in $RemoteTree) {
    $RemoteLookup[$Path] = $true
}

$LocalOnlyTracked = @(
    $LocalTrackedFiles |
    Where-Object { -not $RemoteLookup.ContainsKey($_) }
)

$LocalLookup = @{}

foreach ($Path in $LocalTrackedFiles) {
    $LocalLookup[$Path] = $true
}

$RemoteOnlyTracked = @(
    $RemoteTree |
    Where-Object { -not $LocalLookup.ContainsKey($_) }
)

Write-Step "Inventariando tags y releases"

$LocalTags = @(
    (Invoke-Git -Arguments @("tag", "--list")).Output |
    ForEach-Object { $_.ToString().Trim() } |
    Where-Object { $_ } |
    Sort-Object -Unique
)

$RemoteTags = @()

if ($RemoteAvailable) {
    $LsRemoteTags = Invoke-Git `
        -Arguments @("ls-remote", "--tags", "origin") `
        -AllowFailure

    if ($LsRemoteTags.ExitCode -eq 0) {
        $RemoteTags = @(
            $LsRemoteTags.Output |
            ForEach-Object {
                $Line = $_.ToString()
                if ($Line -match "refs/tags/(.+?)(?:\^\{\})?$") {
                    $Matches[1]
                }
            } |
            Where-Object { $_ } |
            Sort-Object -Unique
        )
    }
}

$RepositorySlug = "Poliyoko/APP-PUINAVE"
$RemoteReleases = @(Get-GitHubReleases -RepositorySlug $RepositorySlug)

$RemoteTagLookup = @{}
foreach ($Tag in $RemoteTags) {
    $RemoteTagLookup[$Tag] = $true
}

$LocalTagsPendingPublication = @(
    $LocalTags |
    Where-Object { -not $RemoteTagLookup.ContainsKey($_) }
)

$LocalTagLookup = @{}
foreach ($Tag in $LocalTags) {
    $LocalTagLookup[$Tag] = $true
}

$RemoteTagsMissingLocal = @(
    $RemoteTags |
    Where-Object { -not $LocalTagLookup.ContainsKey($_) }
)

Write-Step "Construyendo Registro de Capacidades Tecnologicas"

$LocalInventory = @(Get-LocalComponentInventory -Root $ProjectRoot)

$CapabilityRegistry = @()

foreach ($Item in $LocalInventory) {
    $Id = [string]$Item.component
    $Implemented = [bool]$Item.implemented_local
    $Documented = [bool]$Item.documented
    $Published = Test-RemoteComponentPublished `
        -ComponentId $Id `
        -RemoteTree $RemoteTree

    $Released = Test-ComponentReleasedRemote `
        -ComponentId $Id `
        -RemoteReleases $RemoteReleases `
        -RemoteTags $RemoteTags

    $Synchronized = (
        $Published -and
        $RemoteHead -and
        ($Ahead -eq 0) -and
        ($Behind -eq 0) -and
        ($ModifiedOrStaged.Count -eq 0) -and
        ($Untracked.Count -eq 0)
    )

    $Labels = Get-StatusLabels `
        -ImplementedLocal $Implemented `
        -Documented $Documented `
        -PublishedRemote $Published `
        -ReleasedRemote $Released `
        -Synchronized $Synchronized

    $Action = Get-RecommendedCapabilityAction `
        -ImplementedLocal $Implemented `
        -Documented $Documented `
        -PublishedRemote $Published `
        -ReleasedRemote $Released `
        -Synchronized $Synchronized

    $CapabilityRegistry += [ordered]@{
        component = $Id
        capability = Get-TechnologyCapability -ComponentId $Id
        status_labels = $Labels
        capability_classification = $Action
        implemented_local = $Implemented
        documented = $Documented
        published_remote = $Published
        released = $Released
        synchronized = $Synchronized
        local_paths = @($Item.local_paths)
    }
}

$CapabilityRegistryPath = Join-Path $RunRoot "technology-capability-registry.json"
Write-JsonFile -Path $CapabilityRegistryPath -Data $CapabilityRegistry

Write-Step "Analizando solapamientos y gaps"

$OverlapGroups = @(
    [ordered]@{
        domain = "workflow_and_execution"
        components = @(
            "SPT-019.1",
            "SPT-019.2",
            "SPT-019.3",
            "SPT-020.6"
        )
        recommendation = "REUSE_BEFORE_EXTEND"
    },
    [ordered]@{
        domain = "registry_and_discovery"
        components = @(
            "SPT-019.2",
            "SPT-020.3",
            "SPT-020.5"
        )
        recommendation = "INTEGRATE"
    },
    [ordered]@{
        domain = "events_and_orchestration"
        components = @(
            "SPT-003A",
            "SPT-006",
            "SPT-020.1",
            "SPT-020.4",
            "SPT-020.6"
        )
        recommendation = "REUSE_BEFORE_EXTEND"
    },
    [ordered]@{
        domain = "audit_traceability_release"
        components = @(
            "SGD-114",
            "SGD-117",
            "SPB-007",
            "PCI-001",
            "PCI-002"
        )
        recommendation = "DO_NOT_DUPLICATE"
    },
    [ordered]@{
        domain = "documentation_and_roadmap"
        components = @(
            "SGD-115",
            "SGD-116",
            "SPT-020.9"
        )
        recommendation = "DO_NOT_DUPLICATE"
    }
)

$PresentComponentLookup = @{}
foreach ($Capability in $CapabilityRegistry) {
    $PresentComponentLookup[[string]$Capability.component] = $true
}

$OverlapReport = @()

foreach ($Group in $OverlapGroups) {
    $Present = @(
        $Group.components |
        Where-Object { $PresentComponentLookup.ContainsKey($_) }
    )

    $OverlapReport += [ordered]@{
        domain = $Group.domain
        expected_components = $Group.components
        present_components = $Present
        overlap_detected = ($Present.Count -gt 1)
        recommendation = $Group.recommendation
    }
}

$OverlapReportPath = Join-Path $RunRoot "technology-overlap-report.json"
Write-JsonFile -Path $OverlapReportPath -Data $OverlapReport

$GapCandidates = @(
    [ordered]@{
        capability = "institutional_execution_kernel"
        potential_overlap = @("SPT-019.1", "SPT-020.6")
        default_decision = "EXTEND_ONLY_IF_GAP_PROVEN"
    },
    [ordered]@{
        capability = "institutional_task_scheduler"
        potential_overlap = @("SPT-019.1", "SPT-019.3")
        default_decision = "ANALYZE"
    },
    [ordered]@{
        capability = "institutional_job_queue"
        potential_overlap = @("SPT-020.1", "SPT-020.4")
        default_decision = "ANALYZE"
    },
    [ordered]@{
        capability = "background_workers"
        potential_overlap = @("SPT-020.6")
        default_decision = "ANALYZE"
    },
    [ordered]@{
        capability = "distributed_execution_controller"
        potential_overlap = @("SPT-019.3", "SPT-020.6")
        default_decision = "ANALYZE"
    },
    [ordered]@{
        capability = "execution_resource_manager"
        potential_overlap = @("SPT-020.2", "SPT-020.3", "SPT-020.7")
        default_decision = "ANALYZE"
    }
)

$GapAnalysis = @()

foreach ($Gap in $GapCandidates) {
    $Existing = @(
        $Gap.potential_overlap |
        Where-Object { $PresentComponentLookup.ContainsKey($_) }
    )

    $Decision = if ($Existing.Count -gt 0) {
        "EXTEND_OR_INTEGRATE"
    }
    else {
        "MISSING"
    }

    $GapAnalysis += [ordered]@{
        capability = $Gap.capability
        related_existing_components = $Existing
        classification = $Decision
        rule = $Gap.default_decision
        new_component_authorized = ($Decision -eq "MISSING")
    }
}

$GapAnalysisPath = Join-Path $RunRoot "technology-gap-analysis.json"
Write-JsonFile -Path $GapAnalysisPath -Data $GapAnalysis

Write-Step "Generando mapa de dependencias y reconciliacion remota"

$DependencyMap = [ordered]@{
    baseline = "SPT-020"
    baseline_status = "CLOSED"
    next_block = "SPT-021"
    analyzer = $Component
    dependencies = @(
        "SPT-019.0",
        "SPT-019.1",
        "SPT-019.2",
        "SPT-019.3",
        "SPT-020.1",
        "SPT-020.2",
        "SPT-020.3",
        "SPT-020.4",
        "SPT-020.5",
        "SPT-020.6",
        "SPT-020.7",
        "SPT-020.8",
        "SPT-020.9",
        "SGD-114",
        "SGD-115",
        "SGD-116",
        "SGD-117",
        "PCI-001",
        "PCI-002",
        "POL-001",
        "SPB-007",
        "SIB-001"
    )
}

$DependencyMapPath = Join-Path $RunRoot "technology-dependency-map.json"
Write-JsonFile -Path $DependencyMapPath -Data $DependencyMap

$RemoteReconciliation = [ordered]@{
    repository = $RepositorySlug
    remote_url = $ActualRemote
    local_branch = $LocalBranch
    remote_branch = $RemoteBranch
    local_head = $LocalHead
    remote_head = $RemoteHead
    fetch_succeeded = $RemoteAvailable
    ahead_commits = $Ahead
    behind_commits = $Behind
    modified_or_staged_entries = $ModifiedOrStaged.Count
    untracked_entries = $Untracked.Count
    local_tracked_files = $LocalTrackedFiles.Count
    remote_tracked_files = $RemoteTree.Count
    local_only_tracked_files_count = $LocalOnlyTracked.Count
    remote_only_tracked_files_count = $RemoteOnlyTracked.Count
    local_only_tracked_files = $LocalOnlyTracked
    remote_only_tracked_files = $RemoteOnlyTracked
    local_tags = $LocalTags
    remote_tags = $RemoteTags
    local_tags_pending_publication = $LocalTagsPendingPublication
    remote_tags_missing_local = $RemoteTagsMissingLocal
    github_releases_detected = @(
        $RemoteReleases |
        ForEach-Object {
            [ordered]@{
                name = [string]$_.name
                tag_name = [string]$_.tag_name
                draft = [bool]$_.draft
                prerelease = [bool]$_.prerelease
                published_at = [string]$_.published_at
            }
        }
    )
    synchronized_repository = (
        $RemoteAvailable -and
        $RemoteHead -and
        ($Ahead -eq 0) -and
        ($Behind -eq 0) -and
        ($ModifiedOrStaged.Count -eq 0) -and
        ($Untracked.Count -eq 0)
    )
    publication_performed = $false
}

$RemoteReconciliationPath = Join-Path $RunRoot "remote-repository-reconciliation.json"
Write-JsonFile -Path $RemoteReconciliationPath -Data $RemoteReconciliation

$ScopeDefinition = [ordered]@{
    component = "SPT-021"
    opened_by = $Component
    generated_at_utc = $GeneratedUtc
    baseline = "SPT-020 CLOSED"
    rule = (
        "No crear nuevos subcomponentes que dupliquen capacidades " +
        "clasificadas EXISTING, REUSABLE o INTEGRATE."
    )
    authorized_new_components = @(
        $GapAnalysis |
        Where-Object { $_.new_component_authorized } |
        ForEach-Object { $_.capability }
    )
    conditional_extension_candidates = @(
        $GapAnalysis |
        Where-Object { -not $_.new_component_authorized } |
        ForEach-Object {
            [ordered]@{
                capability = $_.capability
                related_existing_components = $_.related_existing_components
                decision = "REVIEW_BEFORE_DESIGN"
            }
        }
    )
}

$ScopeDefinitionPath = Join-Path $RunRoot "SPT-021-scope-definition.json"
Write-JsonFile -Path $ScopeDefinitionPath -Data $ScopeDefinition

Write-Step "Compilando Python"

$CompileOutput = @(& python -m compileall -q src tests 2>&1)
$CompileExitCode = $LASTEXITCODE

Write-TextFile `
    -Path (Join-Path $RunRoot "python-compileall.txt") `
    -Content (($CompileOutput -join "`r`n") + "`r`n")

if ($CompileExitCode -ne 0) {
    throw "La compilacion Python fallo."
}

Write-Step "Ejecutando suite institucional completa"

$env:PYTHONPATH = Join-Path $ProjectRoot "src"
$PytestOutput = @(& python -m pytest -q 2>&1)
$PytestExitCode = $LASTEXITCODE
$PytestPassed = ($PytestExitCode -eq 0)

$PytestLogPath = Join-Path $RunRoot "pytest-full-suite.txt"

Write-TextFile `
    -Path $PytestLogPath `
    -Content (($PytestOutput -join "`r`n") + "`r`n")

$PytestOutput | ForEach-Object { Write-Host $_ }

$TestCount = 0
$PytestText = $PytestOutput -join "`r`n"
$PassedMatch = [regex]::Match($PytestText, "(\d+)\s+passed")

if ($PassedMatch.Success) {
    $TestCount = [int]$PassedMatch.Groups[1].Value
}

$TechnicalErrors = 0

if (-not $RemoteAvailable) { $TechnicalErrors++ }
if ($CompileExitCode -ne 0) { $TechnicalErrors++ }
if (-not $PytestPassed) { $TechnicalErrors++ }
if ($TestCount -lt 808) { $TechnicalErrors++ }

$AnalyzerStatus = if ($TechnicalErrors -eq 0) {
    "CLOSED"
}
else {
    "CLOSURE_BLOCKED"
}

$RepositorySyncStatus = if (
    $RemoteReconciliation.synchronized_repository
) {
    "SYNCHRONIZED"
}
else {
    "RECONCILIATION_REQUIRED"
}

$Evidence = [ordered]@{
    component = $Component
    version = $Version
    generated_at_utc = $GeneratedUtc
    run_id = $RunId
    status = $AnalyzerStatus
    technical_errors = $TechnicalErrors
    baseline = "SPT-020 CLOSED"
    remote_repository = $RepositorySlug
    repository_reconciliation_status = $RepositorySyncStatus
    publication_performed = $false
    capability_registry_count = $CapabilityRegistry.Count
    gap_count = @(
        $GapAnalysis |
        Where-Object { $_.classification -eq "MISSING" }
    ).Count
    integration_or_extension_count = @(
        $GapAnalysis |
        Where-Object {
            $_.classification -eq "EXTEND_OR_INTEGRATE"
        }
    ).Count
    python_compile_exit_code = $CompileExitCode
    pytest_passed = $PytestPassed
    tests_passed = $TestCount
    n8n_installed = $false
    paid_services_required = $false
    outputs = [ordered]@{
        technology_capability_registry = Get-RelativePathSafe `
            -Root $ProjectRoot `
            -Path $CapabilityRegistryPath
        technology_gap_analysis = Get-RelativePathSafe `
            -Root $ProjectRoot `
            -Path $GapAnalysisPath
        technology_dependency_map = Get-RelativePathSafe `
            -Root $ProjectRoot `
            -Path $DependencyMapPath
        technology_overlap_report = Get-RelativePathSafe `
            -Root $ProjectRoot `
            -Path $OverlapReportPath
        remote_repository_reconciliation = Get-RelativePathSafe `
            -Root $ProjectRoot `
            -Path $RemoteReconciliationPath
        scope_definition = Get-RelativePathSafe `
            -Root $ProjectRoot `
            -Path $ScopeDefinitionPath
    }
}

$EvidencePath = Join-Path $RunRoot "implementation-evidence.json"
Write-JsonFile -Path $EvidencePath -Data $Evidence

$Document = @"
# SGD-438 - SPT-021.0 Institutional Technology Baseline & Gap Analyzer

| Campo | Resultado |
|---|---|
| Componente | SPT-021.0 |
| Version | $Version |
| Linea base | SPT-020 CLOSED |
| Repositorio oficial | $RepositorySlug |
| Rama local | $LocalBranch |
| Rama remota | $RemoteBranch |
| Commits ahead | $Ahead |
| Commits behind | $Behind |
| Archivos tracked solo local | $($LocalOnlyTracked.Count) |
| Archivos tracked solo remoto | $($RemoteOnlyTracked.Count) |
| Tags locales pendientes | $($LocalTagsPendingPublication.Count) |
| Releases GitHub detectados | $($RemoteReleases.Count) |
| Estado reconciliacion | $RepositorySyncStatus |
| Suite institucional | $TestCount passed |
| Errores tecnicos del analizador | $TechnicalErrors |
| Publicacion realizada | NO |

## Regla de apertura de SPT-021

Ningun nuevo subcomponente SPT-021.x puede ser creado por duplicacion de una
capacidad clasificada EXISTING, REUSABLE o INTEGRATE.

La reconciliacion remota es diagnostica: este componente no hace push, no
crea tags y no publica releases.
"@

$DocumentPath = Join-Path $DocsRoot "SGD-438-SPT-021.0-Baseline-Gap-Analyzer.md"
Write-TextFile -Path $DocumentPath -Content $Document

$Act = @"
# ACT-021.0 - Apertura Institucional de SPT-021

| Campo | Resultado |
|---|---|
| Componente | SPT-021.0 |
| Version | $Version |
| Estado | $AnalyzerStatus |
| Baseline SPT-020 | CLOSED |
| Reconciliacion remota | $RepositorySyncStatus |
| Python compile exit code | $CompileExitCode |
| Pytest | $PytestPassed |
| Pruebas | $TestCount |
| Errores tecnicos | $TechnicalErrors |
| n8n instalado | NO |
| Servicios de pago | NO |

SPT-021 queda abierto bajo control de alcance. Los componentes posteriores
solo podran definirse a partir del Gap Analysis generado por SPT-021.0.
"@

$ActPath = Join-Path $DocsRoot "ACT-021.0-Apertura-Institucional-SPT-021.md"
Write-TextFile -Path $ActPath -Content $Act

$ReleaseManifest = [ordered]@{
    component = $Component
    version = $Version
    status = $AnalyzerStatus
    baseline = "SPT-020 CLOSED"
    repository_reconciliation_status = $RepositorySyncStatus
    technical_errors = $TechnicalErrors
    tests_passed = $TestCount
    publication_performed = $false
    evidence = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $EvidencePath
    act = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $ActPath
    report = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $DocumentPath
}

$ReleaseManifestPath = Join-Path $ReleaseRoot "manifest.json"
Write-JsonFile -Path $ReleaseManifestPath -Data $ReleaseManifest

foreach ($OutputFile in @(
    $CapabilityRegistryPath,
    $GapAnalysisPath,
    $DependencyMapPath,
    $OverlapReportPath,
    $RemoteReconciliationPath,
    $ScopeDefinitionPath,
    $EvidencePath,
    $DocumentPath,
    $ActPath
)) {
    Copy-Item `
        -LiteralPath $OutputFile `
        -Destination (Join-Path $ReleaseRoot (Split-Path $OutputFile -Leaf)) `
        -Force
}

Write-Step "Resultado final"

Write-Host "SPT-020 baseline status: CLOSED"
Write-Host "Remote origin verified: True"
Write-Host "Git fetch succeeded: $RemoteAvailable"
Write-Host "Local branch: $LocalBranch"
Write-Host "Remote branch: $RemoteBranch"
Write-Host "Ahead commits: $Ahead"
Write-Host "Behind commits: $Behind"
Write-Host "Modified/staged Git entries: $($ModifiedOrStaged.Count)"
Write-Host "Untracked Git entries: $($Untracked.Count)"
Write-Host "Local-only tracked files: $($LocalOnlyTracked.Count)"
Write-Host "Remote-only tracked files: $($RemoteOnlyTracked.Count)"
Write-Host "Local tags pending publication: $($LocalTagsPendingPublication.Count)"
Write-Host "GitHub releases detected: $($RemoteReleases.Count)"
Write-Host "Repository reconciliation: $RepositorySyncStatus"
Write-Host "Capabilities inventoried: $($CapabilityRegistry.Count)"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Pytest passed: $PytestPassed"
Write-Host "Tests passed: $TestCount"
Write-Host "Technical errors: $TechnicalErrors"
Write-Host "Publication performed: NO"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Evidence: $EvidencePath" -ForegroundColor Cyan
Write-Host "Gap analysis: $GapAnalysisPath" -ForegroundColor Cyan
Write-Host "Remote reconciliation: $RemoteReconciliationPath" -ForegroundColor Cyan
Write-Host "Scope definition: $ScopeDefinitionPath" -ForegroundColor Cyan
Write-Host "Act: $ActPath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan
Write-Host "Institutional status: $AnalyzerStatus" -ForegroundColor Cyan

if ($TechnicalErrors -eq 0) {
    Write-Host "SPT-021.0: CLOSED WITH ZERO TECHNICAL ERRORS." -ForegroundColor Green
    Write-Host "SPT-021: FORMALLY OPENED UNDER GAP-ANALYSIS CONTROL." -ForegroundColor Green
}
else {
    Write-Host "SPT-021.0: CLOSURE BLOCKED." -ForegroundColor Red
    exit 1
}
