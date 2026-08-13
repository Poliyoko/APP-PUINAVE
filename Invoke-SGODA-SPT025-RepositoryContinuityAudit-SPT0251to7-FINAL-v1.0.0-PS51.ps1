#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "1d6756e2335f5a130290c2e8ca6169f660007f9b"
$Branch = "feature/SPT-001A-rlb-schema-foundation"

$ManifestFile = "config/integration/spt025audit/repository-continuity-required-paths.json"
$PolicyFile = "config/integration/spt025audit/repository-continuity-audit-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-025/AUDIT/SGD-SPT025-Auditoria-Continuidad-Repositorio-SPT025.1-SPT025.7.md"

$ArtifactDir = "artifacts/development/SPT-025.RepositoryContinuityAudit-v1.0.0"
$CoverageFile = "$ArtifactDir/spt0251-to-spt0257-repository-coverage-matrix.json"
$AssessmentFile = "$ArtifactDir/repository-continuity-assessment.json"
$HashFile = "$ArtifactDir/repository-continuity-sha256-manifest.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"
$PrepareFile = "$ArtifactDir/spt0258-repository-continuity-prepare.json"

function Step {
    param([int]$Number, [string]$Title)
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $Number, $Title) -ForegroundColor Cyan
}

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SPT-025 REPOSITORY CONTINUITY AUDIT : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    Write-Host "TRANSACTION : NOT PUBLISHED"
    exit 1
}

function Fetch-Authoritative {
    for ($Attempt = 1; $Attempt -le 4; $Attempt++) {
        Write-Host ("GIT FETCH ATTEMPT : {0}/4" -f $Attempt)
        & git.exe fetch origin $Branch
        if ($LASTEXITCODE -eq 0) {
            Write-Host "GIT FETCH : PASS"
            return
        }
        Start-Sleep -Seconds 2
    }
    Hold "git fetch failed"
}

function Write-Lf {
    param([string]$Path, [string]$Text)
    $Absolute = Join-Path $Root $Path
    $Parent = Split-Path -Parent $Absolute
    if ($Parent -and -not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $Normalized = (($Text -replace "`r`n", "`n") -replace "`r", "`n")
    if (-not $Normalized.EndsWith("`n")) {
        $Normalized += "`n"
    }
    [System.IO.File]::WriteAllText($Absolute, $Normalized, $Utf8)
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Test-CommitPath {
    param([string]$Commit, [string]$Path)
    & git.exe cat-file -e ("{0}:{1}" -f $Commit, $Path) 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Read-CommitJson {
    param([string]$Commit, [string]$Path)
    $Text = (& git.exe show ("{0}:{1}" -f $Commit, $Path) 2>$null) -join "`n"
    if ($LASTEXITCODE -ne 0 -or -not $Text) {
        throw "Unable to read JSON from commit: $Path"
    }
    return ($Text | ConvertFrom-Json)
}

try {
    $Root = (& git.exe rev-parse --show-toplevel).Trim()
    if (-not $Root) {
        Hold "Not inside Git repository"
    }
    Set-Location $Root

    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
    Fetch-Authoritative

    $LocalHead = (& git.exe rev-parse HEAD).Trim()
    $RemoteHead = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
    $Staged = @(& git.exe diff --cached --name-only)
    $DeletedTracked = @(& git.exe ls-files --deleted)

    Write-Host "LOCAL HEAD      : $LocalHead"
    Write-Host "REMOTE HEAD     : $RemoteHead"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($DeletedTracked.Count)"

    if ($LocalHead -ne $ExpectedBaseline -or $RemoteHead -ne $ExpectedBaseline) {
        Hold "Authoritative baseline mismatch"
    }
    if ($Staged.Count -ne 0 -or $DeletedTracked.Count -ne 0) {
        Hold "Unsafe staged/deleted state"
    }

    Write-Host "BASELINE : PASS"
    Write-Host "SPT-025.1-.7 : AUDIT ONLY / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "SHA-256 FREEZE OF EXISTING TRACKED BASELINE"
    $Freeze = @{}
    foreach ($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)) {
        $AbsoluteTrackedPath = Join-Path $Root $TrackedPath
        if (Test-Path -LiteralPath $AbsoluteTrackedPath) {
            $Freeze[$TrackedPath] = Get-Sha256 $AbsoluteTrackedPath
        }
    }
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 3 "INSTALL AUDIT CONTRACT / REQUIRED-PATH MANIFEST"
    $ManifestText = @'
{
  "SPT-025.1": {
    "expected_status_file": "artifacts/development/SPT-025.1-v1.0.1/replicability-assessment.json",
    "expected_status_key": "support_languages_configurable",
    "expected_status_value": true,
    "paths": [
      "Invoke-SGODA-SPT0251-DecouplingMultifunctionReplicability-Audit-RECOVERY-v1.0.1-PS51.ps1",
      "artifacts/development/SPT-025.1-v1.0.1/implementation-evidence.json",
      "artifacts/development/SPT-025.1-v1.0.1/replicability-assessment.json",
      "artifacts/development/SPT-025.1-v1.0.1/replicability-integrity-manifest.json",
      "artifacts/development/SPT-025.1-v1.0.1/spt0252-prepare.json",
      "config/integration/spt0251/replicability-decoupling-policy.json",
      "docs/06_Tecnologia/SPT-025/SPT-025.1/SGD-SPT025.1-Auditoria-Desacoplamiento-Multifuncionalidad-Replicabilidad.md",
      "src/sgoda/integration/spt0251/__init__.py",
      "src/sgoda/integration/spt0251/core.py",
      "tests/integration/test_spt0251_decoupling_multifunction_replicability_audit.py"
    ]
  },
  "SPT-025.2": {
    "expected_status_file": "artifacts/development/SPT-025.2-v1.0.0/spt0252-contract-assessment.json",
    "expected_status_key": "one_native_language_per_platform",
    "expected_status_value": true,
    "paths": [
      "Invoke-SGODA-SPT0252-SGODACore-LanguagePlatformContract-FINAL-v1.0.0-PS51.ps1",
      "artifacts/development/SPT-025.2-v1.0.0/implementation-evidence.json",
      "artifacts/development/SPT-025.2-v1.0.0/spt0252-contract-assessment.json",
      "artifacts/development/SPT-025.2-v1.0.0/spt0252-integrity-manifest.json",
      "artifacts/development/SPT-025.2-v1.0.0/spt0253-prepare.json",
      "config/integration/spt0252/sgoda-core-language-platform-contract-policy.json",
      "docs/06_Tecnologia/SPT-025/SPT-025.2/SGD-SPT025.2-SGODA-Core-Contrato-Plataforma-Linguistica-Independiente.md",
      "src/sgoda/integration/spt0252/__init__.py",
      "src/sgoda/integration/spt0252/core.py",
      "tests/integration/test_spt0252_sgoda_core_language_platform_contract.py"
    ]
  },
  "SPT-025.3": {
    "expected_status_file": "artifacts/development/SPT-025.3-v1.0.0/spt0253-language-model-assessment.json",
    "expected_status_key": "status",
    "expected_status_value": "LANGUAGE_PLATFORM_MODEL_GATE_PASS",
    "paths": [
      "Invoke-SGODA-SPT0253-IndependentLanguagePlatform-LanguageConfig-FINAL-v1.0.0-PS51.ps1",
      "artifacts/development/SPT-025.3-v1.0.0/implementation-evidence.json",
      "artifacts/development/SPT-025.3-v1.0.0/spt0253-language-model-assessment.json",
      "artifacts/development/SPT-025.3-v1.0.0/spt0253-integrity-manifest.json",
      "artifacts/development/SPT-025.3-v1.0.0/spt0254-prepare.json",
      "config/integration/spt0253/independent-language-platform-language-policy.json",
      "docs/06_Tecnologia/SPT-025/SPT-025.3/SGD-SPT025.3-Modelo-Plataforma-Linguistica-Independiente-Idiomas-Auxiliares.md",
      "src/sgoda/integration/spt0253/__init__.py",
      "src/sgoda/integration/spt0253/core.py",
      "tests/integration/test_spt0253_independent_language_platform_language_config.py"
    ]
  },
  "SPT-025.4": {
    "expected_status_file": "artifacts/development/SPT-025.4-v1.0.0/spt0254-rlb-contract-assessment.json",
    "expected_status_key": "status",
    "expected_status_value": "PARAMETRIC_RLB_INSTANCE_DATA_GATE_PASS",
    "paths": [
      "Invoke-SGODA-SPT0254-ParametricRLB-InstanceDataContract-FINAL-v1.0.0-PS51.ps1",
      "artifacts/development/SPT-025.4-v1.0.0/implementation-evidence.json",
      "artifacts/development/SPT-025.4-v1.0.0/spt0254-rlb-contract-assessment.json",
      "artifacts/development/SPT-025.4-v1.0.0/spt0254-integrity-manifest.json",
      "artifacts/development/SPT-025.4-v1.0.0/spt0255-prepare.json",
      "config/integration/spt0254/parametric-rlb-instance-data-policy.json",
      "docs/06_Tecnologia/SPT-025/SPT-025.4/SGD-SPT025.4-RLB-Parametrizable-Contrato-Datos-Instancia.md",
      "src/sgoda/integration/spt0254/__init__.py",
      "src/sgoda/integration/spt0254/core.py",
      "tests/integration/test_spt0254_parametric_rlb_instance_data_contract.py"
    ]
  },
  "SPT-025.5": {
    "expected_status_file": "artifacts/development/SPT-025.5-v1.0.0/spt0255-resource-catalog-assessment.json",
    "expected_status_key": "status",
    "expected_status_value": "RESOURCE_BIBLE_GOVERNANCE_GATE_PASS",
    "paths": [
      "Invoke-SGODA-SPT0255-CulturalLinguisticResources-BibleCatalog-FINAL-v1.0.0-PS51.ps1",
      "artifacts/development/SPT-025.5-v1.0.0/implementation-evidence.json",
      "artifacts/development/SPT-025.5-v1.0.0/spt0255-resource-catalog-assessment.json",
      "artifacts/development/SPT-025.5-v1.0.0/spt0255-integrity-manifest.json",
      "artifacts/development/SPT-025.5-v1.0.0/spt0256-prepare.json",
      "config/integration/spt0255/platform-resource-catalog-policy.json",
      "docs/06_Tecnologia/SPT-025/SPT-025.5/SGD-SPT025.5-Recursos-Culturales-Linguisticos-Biblia-Catalogo.md",
      "src/sgoda/integration/spt0255/__init__.py",
      "src/sgoda/integration/spt0255/core.py",
      "tests/integration/test_spt0255_cultural_linguistic_resources_bible_catalog.py"
    ]
  },
  "SPT-025.6": {
    "expected_status_file": "artifacts/development/SPT-025.6-v1.0.0/spt0256-identity-assessment.json",
    "expected_status_key": "status",
    "expected_status_value": "IDENTITY_BRANDING_GOVERNANCE_GATE_PASS",
    "paths": [
      "Invoke-SGODA-SPT0256-CommunityIdentity-BrandingPlatformConfig-FINAL-v1.0.0-PS51.ps1",
      "artifacts/development/SPT-025.6-v1.0.0/implementation-evidence.json",
      "artifacts/development/SPT-025.6-v1.0.0/spt0256-identity-assessment.json",
      "artifacts/development/SPT-025.6-v1.0.0/spt0256-integrity-manifest.json",
      "artifacts/development/SPT-025.6-v1.0.0/spt0257-prepare.json",
      "config/integration/spt0256/platform-identity-branding-policy.json",
      "docs/06_Tecnologia/SPT-025/SPT-025.6/SGD-SPT025.6-Identidad-Comunitaria-Branding-Metadatos-Configuracion.md",
      "src/sgoda/integration/spt0256/__init__.py",
      "src/sgoda/integration/spt0256/core.py",
      "tests/integration/test_spt0256_community_identity_branding_platform_config.py"
    ]
  },
  "SPT-025.7": {
    "expected_status_file": "artifacts/development/SPT-025.7-v1.0.1/spt0257-bootstrap-assessment.json",
    "expected_status_key": "status",
    "expected_status_value": "LANGUAGE_INSTANCE_BOOTSTRAP_GATE_PASS",
    "paths": [
      "Invoke-SGODA-SPT0257-LanguageInstanceBootstrap-Factory-RECOVERY-v1.0.1-PS51.ps1",
      "artifacts/development/SPT-025.7-v1.0.1/implementation-evidence.json",
      "artifacts/development/SPT-025.7-v1.0.1/spt0257-bootstrap-assessment.json",
      "artifacts/development/SPT-025.7-v1.0.1/spt0257-integrity-manifest.json",
      "artifacts/development/SPT-025.7-v1.0.1/spt0258-prepare.json",
      "config/integration/spt0257/language-instance-bootstrap-policy.json",
      "docs/06_Tecnologia/SPT-025/SPT-025.7/SGD-SPT025.7-Generador-Instancias-Linguisticas-Bootstrap.md",
      "src/sgoda/integration/spt0257/__init__.py",
      "src/sgoda/integration/spt0257/core.py",
      "tests/integration/test_spt0257_language_instance_bootstrap_factory.py"
    ]
  }
}
'@
    $PolicyText = @'
{
  "component": "SPT-025.RepositoryContinuityAudit",
  "version": "1.0.0",
  "authoritative_baseline": "1d6756e2335f5a130290c2e8ca6169f660007f9b",
  "scope": [
    "SPT-025.1",
    "SPT-025.2",
    "SPT-025.3",
    "SPT-025.4",
    "SPT-025.5",
    "SPT-025.6",
    "SPT-025.7"
  ],
  "audit_source": "GIT_COMMIT_TREE",
  "modify_closed_components": false,
  "production_change": false,
  "require_100_percent_critical_path_coverage": true,
  "require_gate_validation": true,
  "commit_push_required": true,
  "local_remote_head_equality_required": true
}
'@
    $DocumentationText = @'
# SPT-025 — Auditoría de Continuidad del Repositorio (SPT-025.1 a SPT-025.7)

Línea base autoritativa auditada: `1d6756e2335f5a130290c2e8ca6169f660007f9b`.

## Objetivo
Comprobar directamente contra el árbol Git de la línea base que SPT-025.1 a SPT-025.7, sus ejecutables oficiales, código, pruebas, configuración, documentación, evidencias, manifests y PREPARE estén realmente versionados.

## Método
La auditoría usa `git cat-file -e <commit>:<ruta>` y `git show <commit>:<ruta>` para verificar el contenido del commit autoritativo, no solamente la presencia de archivos en el directorio de trabajo.

## Condición de aprobación
Los siete componentes deben:
1. tener 100 % de las rutas críticas declaradas;
2. tener su assessment institucional en el commit;
3. conservar el estado/gate esperado;
4. producir una matriz SHA-256 verificable;
5. mantener intactos todos los archivos tracked que existían al iniciar la auditoría;
6. terminar publicados mediante commit/push y `LOCAL_HEAD=REMOTE_HEAD`.

Esta auditoría no reabre ni modifica SPT-025.1–SPT-025.7.

'@
    Write-Lf $ManifestFile $ManifestText
    Write-Lf $PolicyFile $PolicyText
    Write-Lf $DocFile $DocumentationText
    Write-Host "AUDIT CONTRACT : CREATED"

    Step 4 "LOAD SPT-025.1-.7 AUDIT MANIFEST"
    $AuditManifest = Get-Content -Raw -LiteralPath (Join-Path $Root $ManifestFile) | ConvertFrom-Json
    $ComponentNames = @($AuditManifest.PSObject.Properties.Name)
    Write-Host "EXPECTED COMPONENTS : $($ComponentNames.Count)"
    if ($ComponentNames.Count -ne 7) {
        Hold "Audit manifest does not contain exactly 7 components"
    }
    Write-Host "MANIFEST LOAD : PASS"

    Step 5 "GIT COMMIT-TREE PRESENCE AUDIT"
    $CoverageRecords = @()
    $GlobalMissing = @()

    foreach ($ComponentName in $ComponentNames) {
        $Definition = $AuditManifest.$ComponentName
        $RequiredPaths = @($Definition.paths)
        $Present = 0
        $Missing = @()

        foreach ($RequiredPath in $RequiredPaths) {
            if (Test-CommitPath $ExpectedBaseline $RequiredPath) {
                $Present++
            }
            else {
                $Missing += [string]$RequiredPath
                $GlobalMissing += ("{0}::{1}" -f $ComponentName, $RequiredPath)
            }
        }

        $CoveragePercent = 0
        if ($RequiredPaths.Count -gt 0) {
            $CoveragePercent = [math]::Round(($Present * 100.0) / $RequiredPaths.Count, 2)
        }

        $CoverageRecords += [ordered]@{
            component = $ComponentName
            required_paths = $RequiredPaths.Count
            present_paths = $Present
            missing_paths = $Missing
            coverage_percent = $CoveragePercent
        }

        Write-Host ("{0} : {1}/{2} paths present ({3} %)" -f $ComponentName, $Present, $RequiredPaths.Count, $CoveragePercent)
    }

    if ($GlobalMissing.Count -ne 0) {
        Write-Host "MISSING CRITICAL PATHS : $($GlobalMissing.Count)"
        foreach ($MissingItem in $GlobalMissing) {
            Write-Host ("  - " + $MissingItem)
        }
        Hold "One or more SPT-025.1-.7 critical repository paths are absent from authoritative baseline"
    }

    Write-Host "CRITICAL PATH COVERAGE : 100 % / PASS"

    Step 6 "INSTITUTIONAL GATE / ASSESSMENT VALIDATION"
    $GateRecords = @()
    $GateFailures = @()

    foreach ($ComponentName in $ComponentNames) {
        $Definition = $AuditManifest.$ComponentName
        $StatusPath = [string]$Definition.expected_status_file
        $StatusKey = [string]$Definition.expected_status_key
        $ExpectedValue = $Definition.expected_status_value

        $Assessment = Read-CommitJson $ExpectedBaseline $StatusPath
        $ActualValue = $Assessment.$StatusKey

        $Pass = $false
        if ($ExpectedValue -is [bool]) {
            $Pass = ([bool]$ActualValue -eq [bool]$ExpectedValue)
        }
        else {
            $Pass = ([string]$ActualValue -eq [string]$ExpectedValue)
        }

        $GateRecords += [ordered]@{
            component = $ComponentName
            assessment_path = $StatusPath
            key = $StatusKey
            expected = $ExpectedValue
            actual = $ActualValue
            pass = $Pass
        }

        if (-not $Pass) {
            $GateFailures += $ComponentName
        }

        Write-Host ("{0} GATE CHECK : {1}" -f $ComponentName, $(if ($Pass) { "PASS" } else { "FAIL" }))
    }

    if ($GateFailures.Count -ne 0) {
        Hold ("Institutional gate validation failed for: " + ($GateFailures -join ", "))
    }

    Write-Host "ASSESSMENT / GATE VALIDATION : PASS"

    Step 7 "EVIDENCE / MANIFEST / PREPARE COVERAGE AUDIT"
    foreach ($Record in $CoverageRecords) {
        if ([double]$Record.coverage_percent -ne 100.0) {
            Hold ("Coverage below 100 % for " + $Record.component)
        }
    }
    Write-Host "EXECUTABLE COVERAGE : PASS"
    Write-Host "CODE COVERAGE       : PASS"
    Write-Host "TEST COVERAGE       : PASS"
    Write-Host "CONFIG COVERAGE     : PASS"
    Write-Host "DOCUMENT COVERAGE   : PASS"
    Write-Host "EVIDENCE COVERAGE   : PASS"
    Write-Host "PREPARE COVERAGE    : PASS"

    Step 8 "AUTHORITATIVE BASELINE SHA-256 MATRIX"
    $HashRecords = @()
    foreach ($ComponentName in $ComponentNames) {
        $Definition = $AuditManifest.$ComponentName
        foreach ($RequiredPath in @($Definition.paths)) {
            $Blob = (& git.exe show ("{0}:{1}" -f $ExpectedBaseline, $RequiredPath) 2>$null) -join "`n"
            if ($LASTEXITCODE -ne 0) {
                Hold ("Unable to hash authoritative path: " + $RequiredPath)
            }
            $TempFile = Join-Path ([System.IO.Path]::GetTempPath()) ("spt025-audit-" + [guid]::NewGuid().ToString("N"))
            try {
                $Utf8 = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($TempFile, $Blob, $Utf8)
                $Hash = Get-Sha256 $TempFile
            }
            finally {
                Remove-Item -LiteralPath $TempFile -Force -ErrorAction SilentlyContinue
            }

            $HashRecords += [ordered]@{
                component = $ComponentName
                path = [string]$RequiredPath
                sha256 = $Hash
            }
        }
    }
    Write-Host "SHA-256 AUDIT RECORDS : $($HashRecords.Count)"
    Write-Host "SHA-256 MATRIX : PASS"

    Step 9 "GENERATE AUDIT EVIDENCE"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir) | Out-Null

    $Assessment = [ordered]@{
        component = "SPT-025.RepositoryContinuityAudit"
        version = "1.0.0"
        audited_baseline = $ExpectedBaseline
        status = "REPOSITORY_CONTINUITY_GATE_PASS"
        expected_components = 7
        covered_components = 7
        missing_components = 0
        critical_path_coverage_percent = 100
        institutional_gate_validation = "PASS"
        closed_components_modified = $false
        production_change = $false
    }

    $Evidence = [ordered]@{
        component = "SPT-025.RepositoryContinuityAudit"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        source = "GIT_COMMIT_TREE"
        components = @($ComponentNames)
        critical_paths_missing = 0
        repository_continuity = "PASS"
        closed_components_preserved = $true
        production_change = $false
    }

    $Prepare = [ordered]@{
        next_deliverable = "SPT-025.8"
        source_baseline = $ExpectedBaseline
        repository_continuity_gate = "PASS"
        spt0251_to_spt0257_present = $true
        evidence_present = $true
    }

    Write-Lf $CoverageFile (
        [ordered]@{
            audited_baseline = $ExpectedBaseline
            records = $CoverageRecords
            gates = $GateRecords
        } | ConvertTo-Json -Depth 12
    )
    Write-Lf $AssessmentFile ($Assessment | ConvertTo-Json -Depth 8)
    Write-Lf $HashFile (
        [ordered]@{
            algorithm = "SHA-256"
            audited_baseline = $ExpectedBaseline
            records = $HashRecords
        } | ConvertTo-Json -Depth 12
    )
    Write-Lf $EvidenceFile ($Evidence | ConvertTo-Json -Depth 8)
    Write-Lf $PrepareFile ($Prepare | ConvertTo-Json -Depth 8)

    Write-Host "COVERAGE MATRIX : CREATED"
    Write-Host "ASSESSMENT      : CREATED"
    Write-Host "SHA-256 MANIFEST: CREATED"
    Write-Host "EVIDENCE        : CREATED"
    Write-Host "SPT-025.8 PREPARE: CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"
    foreach ($TrackedPath in $Freeze.Keys) {
        $AbsoluteTrackedPath = Join-Path $Root $TrackedPath
        if (-not (Test-Path -LiteralPath $AbsoluteTrackedPath)) {
            Hold ("Protected tracked file disappeared: " + $TrackedPath)
        }
        if ((Get-Sha256 $AbsoluteTrackedPath) -ne $Freeze[$TrackedPath]) {
            Hold ("Protected tracked file changed: " + $TrackedPath)
        }
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-025.1-.7 : PRESERVED / NOT REOPENED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed = @(
        "Invoke-SGODA-SPT025-RepositoryContinuityAudit-SPT0251to7-FINAL-v1.0.0-PS51.ps1",
        $ManifestFile,
        $PolicyFile,
        $DocFile,
        $CoverageFile,
        $AssessmentFile,
        $HashFile,
        $EvidenceFile,
        $PrepareFile
    )

    foreach ($AllowedPath in $Allowed) {
        $AbsoluteAllowed = Join-Path $Root $AllowedPath
        if (-not (Test-Path -LiteralPath $AbsoluteAllowed)) {
            Hold ("Missing expected audit target: " + $AllowedPath)
        }
        & git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $AllowedPath
        if ($LASTEXITCODE -ne 0) {
            Hold ("git add failed: " + $AllowedPath)
        }
    }

    $StagedNames = @(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Unexpected = @(
        $StagedNames | Where-Object {
            $Allowed -notcontains ($_ -replace "\\", "/")
        }
    )

    Write-Host "STAGED     : $($StagedNames.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if ($Unexpected.Count -ne 0 -or $StagedNames.Count -ne $Allowed.Count) {
        Hold "Exact staging mismatch"
    }
    Write-Host "STAGING QUALITY : PASS"

    Step 12 "INDEX-WIDE GITHUB SIZE GATE"
    $Oversized = @()
    foreach ($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)) {
        $BlobSizeText = @(& git.exe cat-file -s (":" + $TrackedPath) 2>$null)
        if ($LASTEXITCODE -eq 0 -and $BlobSizeText.Count -gt 0) {
            [Int64]$BlobSize = 0
            if ([Int64]::TryParse(([string]$BlobSizeText[0]).Trim(), [ref]$BlobSize)) {
                if ($BlobSize -ge 100MB) {
                    $Oversized += $TrackedPath
                }
            }
        }
    }
    Write-Host "INDEX BLOBS >=100MB : $($Oversized.Count)"
    if ($Oversized.Count -ne 0) {
        Hold "GitHub size gate failed"
    }
    Write-Host "GITHUB SIZE GATE : PASS"

    Step 13 "FINAL REMOTE / PRESERVATION GATE"
    Fetch-Authoritative

    $RemoteBeforeCommit = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
    if ($RemoteBeforeCommit -ne $ExpectedBaseline) {
        Hold "Remote advanced during audit transaction"
    }

    foreach ($TrackedPath in $Freeze.Keys) {
        $AbsoluteTrackedPath = Join-Path $Root $TrackedPath
        if ((Get-Sha256 $AbsoluteTrackedPath) -ne $Freeze[$TrackedPath]) {
            Hold ("Preservation failure before commit: " + $TrackedPath)
        }
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"
    & git.exe commit -m "audit(spt-025): verify repository continuity for SPT-025.1 through SPT-025.7"
    if ($LASTEXITCODE -ne 0) {
        Hold "git commit failed"
    }

    $NewCommit = (& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if ($LASTEXITCODE -ne 0) {
        Hold "git push failed"
    }
    Write-Host "PUSH : PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION / AUDIT CLOSURE"
    Fetch-Authoritative

    $FinalLocal = (& git.exe rev-parse HEAD).Trim()
    $FinalRemote = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
    $Behind = (& git.exe rev-list --count ("HEAD..origin/" + $Branch)).Trim()
    $Ahead = (& git.exe rev-list --count ("origin/" + $Branch + "..HEAD")).Trim()
    $FinalStaged = @(& git.exe diff --cached --name-only)
    $FinalDeleted = @(& git.exe ls-files --deleted)

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "BEHIND          : $Behind"
    Write-Host "AHEAD           : $Ahead"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if ($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0") {
        Hold "Final local/remote synchronization failed"
    }
    if ($FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0) {
        Hold "Final repository state is not clean enough for closure"
    }

    Write-Host ""
    Write-Host "SPT-025 REPOSITORY CONTINUITY AUDIT : TECHNICALLY CLOSED" -ForegroundColor Green
    Write-Host "AUDITED_BASELINE=1d6756e2335f5a130290c2e8ca6169f660007f9b"
    Write-Host "SPT025_COMPONENTS_EXPECTED=7"
    Write-Host "SPT025_COMPONENTS_COVERED=7"
    Write-Host "SPT025_COMPONENTS_MISSING=0"
    Write-Host "CRITICAL_PATH_COVERAGE=100_PERCENT"
    Write-Host "EXECUTABLE_COVERAGE=PASS"
    Write-Host "CODE_COVERAGE=PASS"
    Write-Host "TEST_COVERAGE=PASS"
    Write-Host "CONFIG_COVERAGE=PASS"
    Write-Host "DOCUMENT_COVERAGE=PASS"
    Write-Host "EVIDENCE_COVERAGE=PASS"
    Write-Host "PREPARE_COVERAGE=PASS"
    Write-Host "INSTITUTIONAL_GATE_VALIDATION=PASS"
    Write-Host "SHA256_MANIFEST=CREATED"
    Write-Host "CLOSED_COMPONENTS_PRESERVED=PASS"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "NEXT_DELIVERABLE=SPT-025.8"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
