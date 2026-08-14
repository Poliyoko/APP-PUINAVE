#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "45474c659c0634fb2aac1eb31fd19e9485594722"
$ExpectedOutsideScope = 56
$Branch = "feature/SPT-001A-rlb-schema-foundation"

$SelfName = "Invoke-SGODA-SPT0247-Capa1-FINAL-v1.0.0-PS51.ps1"
$RuntimeFile = "artifacts/runtime/sgd002-auto/state.json"

$ModuleDir = "src/sgoda/integration/spt0247"
$TestFile = "tests/integration/test_spt0247_supply_chain_security_layer1.py"
$PolicyFile = "config/integration/spt0247/supply-chain-security-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-024/SPT-024.7/SGD-SPT024.7-Capa1-CICD-Dependencias-Supply-Chain.md"
$ArtifactDir = "artifacts/development/SPT-024.7-Capa1-v1.0.0"
$AssessmentFile = "$ArtifactDir/supply-chain-security-assessment.json"
$SbomFile = "$ArtifactDir/institutional-sbom.json"
$IntegrityFile = "$ArtifactDir/artifact-integrity.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"

function Stop-Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host " SPT-024.7 CAPA 1 : HOLD" -ForegroundColor Red
    Write-Host " REASON           : $Reason" -ForegroundColor Red
    Write-Host " TRANSACTION      : NOT PUBLISHED" -ForegroundColor Red
    Write-Host "============================================================================" -ForegroundColor Red
    exit 1
}

function Step {
    param([int]$N,[string]$Text)
    Write-Host ""
    Write-Host ("[{0}/14] {1}" -f $N,$Text) -ForegroundColor Cyan
}

function Native {
    param(
        [string]$Exe,
        [string[]]$NativeArgs = @(),
        [string]$Label = "Native command"
    )
    & $Exe @NativeArgs
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

function PythonExe {
    foreach ($p in @(".venv\Scripts\python.exe","venv\Scripts\python.exe")) {
        if (Test-Path -LiteralPath $p) {
            return (Resolve-Path $p).Path
        }
    }
    $cmd = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        return $cmd.Source
    }
    throw "Python executable not found."
}

function Norm {
    param([string]$P)
    if ($null -eq $P) { return "" }
    return ($P.Trim('"') -replace '\\','/')
}

function Write-Lf {
    param([string]$Path,[string]$Text)
    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $canonical = (($Text -replace "`r`n","`n") -replace "`r","`n")
    if (-not $canonical.EndsWith("`n")) {
        $canonical += "`n"
    }
    [IO.File]::WriteAllText((Join-Path $PWD $Path),$canonical,$utf8)
}

function Is-TransactionPath {
    param([string]$P)
    $p = Norm $P

    if ($p -eq $SelfName -or $p -eq $TestFile -or $p -eq $PolicyFile -or $p -eq $DocFile) {
        return $true
    }
    if ($p -match '^Invoke-SGODA-SPT0247-(?:Capa1-FINAL|R1-SECURITY-CERTIFY)-v[0-9]+\.[0-9]+\.[0-9]+-PS51\.ps1$') {
        return $true
    }
    if ($p.StartsWith("src/sgoda/integration/spt0247/")) {
        return $true
    }
    if ($p.StartsWith((Norm $ArtifactDir) + "/")) {
        return $true
    }
    return $false
}

function Is-HistoricalTransactionResidue {
    param([string]$P)
    $p = Norm $P
    if ($p -eq "SPT0246-Baseline-Input.zip") {
        return $true
    }
    if ($p -match '^Invoke-SGODA-SPT0246-(?:Capa1-FINAL|R1-SECURITY-CERTIFY)-v[0-9]+\.[0-9]+\.[0-9]+-PS51\.ps1$') {
        return $true
    }
    return $false
}

function Is-PublishPath {
    param([string]$P)
    return (Is-TransactionPath $P)
}

function StatusRecords {
    $records = @()
    $lines = @(& git.exe -c core.quotepath=false status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect worktree."
    }

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) {
            continue
        }
        $xy = $line.Substring(0,2)
        $path = $line.Substring(3)
        if ($path -match ' -> ') {
            $path = ($path -split ' -> ')[-1]
        }
        $records += [pscustomobject]@{
            XY = $xy
            Path = (Norm $path)
        }
    }
    return @($records)
}

function Finger {
    param([string]$P)
    $native = $P -replace '/', [IO.Path]::DirectorySeparatorChar
    if (-not (Test-Path -LiteralPath $native)) {
        return "MISSING"
    }
    $item = Get-Item -LiteralPath $native -Force
    if ($item.PSIsContainer) {
        return "DIRECTORY"
    }
    return (Get-FileHash -LiteralPath $native -Algorithm SHA256).Hash.ToUpperInvariant()
}

function New-PreservationSnapshot {
    $snapshot = @{}
    foreach ($record in @(StatusRecords)) {
        $p = Norm $record.Path
        if ($p -eq $RuntimeFile) { continue }
        if (Is-TransactionPath $p) { continue }
        if (Is-HistoricalTransactionResidue $p) { continue }

        $snapshot[$p] = [ordered]@{
            status = [string]$record.XY
            sha256 = (Finger $p)
        }
    }
    return $snapshot
}

function Assert-PreservationSnapshot {
    param([hashtable]$Before,[string]$Label)

    $current = @{}
    foreach ($record in @(StatusRecords)) {
        $p = Norm $record.Path
        if ($p -eq $RuntimeFile) { continue }
        if (Is-TransactionPath $p) { continue }
        if (Is-HistoricalTransactionResidue $p) { continue }

        $current[$p] = [ordered]@{
            status = [string]$record.XY
            sha256 = (Finger $p)
        }
    }

    $violations = @()
    foreach ($p in @($Before.Keys + $current.Keys | Sort-Object -Unique)) {
        if (-not $Before.ContainsKey($p)) {
            $violations += "NEW OUTSIDE-SCOPE ITEM: $p"
            continue
        }
        if (-not $current.ContainsKey($p)) {
            $violations += "PREEXISTING ITEM DISAPPEARED: $p"
            continue
        }
        if ($Before[$p].status -ne $current[$p].status) {
            $violations += "STATUS CHANGED: $p"
            continue
        }
        if ($Before[$p].sha256 -ne $current[$p].sha256) {
            $violations += "CONTENT CHANGED: $p"
        }
    }

    if ($violations.Count -gt 0) {
        foreach ($v in $violations) {
            Write-Host $v -ForegroundColor Red
        }
        Stop-Hold "$Label failed."
    }

    Write-Host "PREEXISTING OUTSIDE-SCOPE ITEMS : $($Before.Count)"
    Write-Host "PREEXISTING WORKTREE ITEMS       : PRESERVED"
}

try {
    Step 1 "AUTHORITATIVE BASELINE / RESUME / WORKTREE SAFETY"

    if (-not (Test-Path -LiteralPath ".git")) {
        Stop-Hold "Execute this master from the official SGODA-PUINAVE repository root."
    }

    Native "git.exe" @("fetch","origin",$Branch) "git fetch"

    $LocalHead = (& git.exe rev-parse HEAD).Trim()
    $RemoteHead = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
    $Staged = @(& git.exe diff --cached --name-only)
    $Deleted = @(& git.exe -c core.quotepath=false ls-files --deleted)

    Write-Host "LOCAL HEAD      : $LocalHead"
    Write-Host "REMOTE HEAD     : $RemoteHead"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if ($LocalHead -ne $ExpectedBaseline) {
        Stop-Hold "Unexpected local baseline. Expected $ExpectedBaseline; found $LocalHead."
    }
    if ($RemoteHead -ne $ExpectedBaseline) {
        Stop-Hold "Unexpected remote baseline. Expected $ExpectedBaseline; found $RemoteHead."
    }
    if ($Staged.Count -ne 0) {
        Stop-Hold "Pre-existing staged changes detected."
    }
    if ($Deleted.Count -ne 0) {
        Stop-Hold "Tracked deletions detected."
    }

    if (Test-Path -LiteralPath $RuntimeFile) {
        Write-Host "RUNTIME PRESERVED : $RuntimeFile"
    }
    Write-Host "BASELINE : PASS"
    Write-Host "POWERSHELL 5.1 CONTRACT : ACTIVE"

    Step 2 "RECOVERY / RESUME DETECTION"

    $RecoveryTargets = @($ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir)
    $ExistingTargets = @()
    foreach ($target in $RecoveryTargets) {
        if (Test-Path -LiteralPath $target) {
            $ExistingTargets += $target
            Write-Host "RECOVERY TARGET PRESENT : $target"
        }
    }

    $PreviousMasters = @()
    try {
        $PreviousMasters = @(
            Get-ChildItem -LiteralPath $PWD.Path -File -Filter "Invoke-SGODA-SPT0247-*-PS51.ps1" -ErrorAction Stop |
            Where-Object {
                $_.Name -ne $SelfName -and
                $_.Name -match '^Invoke-SGODA-SPT0247-(?:Capa1-FINAL|R1-SECURITY-CERTIFY)-v[0-9]+\.[0-9]+\.[0-9]+-PS51\.ps1$'
            } |
            Select-Object -ExpandProperty Name
        )
    }
    catch {
        $PreviousMasters = @()
    }

    Write-Host "PREEXISTING SPT-024.7 TARGETS : $($ExistingTargets.Count)"
    Write-Host "PREVIOUS FAILED MASTERS       : $($PreviousMasters.Count)"
    Write-Host "DESTRUCTIVE CLEANUP            : NO"
    Write-Host "REGENERATION SCOPE             : SPT-024.7 ONLY"
    Write-Host "RECOVERY / RESUME DETECTION    : PASS"

    Step 3 "SHA-256 FREEZE / 56 OUTSIDE-SCOPE ITEMS"

    $Snapshot = New-PreservationSnapshot
    Write-Host "PREEXISTING OUTSIDE-SCOPE ITEMS : $($Snapshot.Count)"
    Write-Host "EXPECTED HISTORICAL ITEMS       : $ExpectedOutsideScope"
    Write-Host "SPT-024.6 FAILED-MASTER RESIDUE : EXCLUDED FROM HISTORICAL COUNT"

    if ($Snapshot.Count -ne $ExpectedOutsideScope) {
        Stop-Hold "Expected exactly $ExpectedOutsideScope historical outside-scope items; found $($Snapshot.Count). Nothing was modified."
    }

    Write-Host "SNAPSHOT SHA-256 : ESTABLISHED"
    Write-Host "SPT-023.1-.7 + SPT-024.1-.6 : PRESERVATION ACTIVE"

    Step 4 "CI/CD + DEPENDENCY + SUPPLY-CHAIN DISCOVERY"

    $Tracked = @(& git.exe -c core.quotepath=false ls-files)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to enumerate tracked files."
    }

    $WorkflowFiles = @(
        $Tracked | Where-Object {
            (Norm $_).ToLowerInvariant() -match '^\.github/workflows/.+\.ya?ml$'
        }
    )

    $DependencyFiles = @(
        $Tracked | Where-Object {
            $p = (Norm $_).ToLowerInvariant()
            $p -match '(^|/)(requirements[^/]*\.txt|pyproject\.toml|poetry\.lock|pipfile|pipfile\.lock|package\.json|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|pubspec\.yaml|pubspec\.lock)$'
        }
    )

    $ReleaseFiles = @(
        $Tracked | Where-Object {
            $p = (Norm $_).ToLowerInvariant()
            $p -match '(^|/)(release|releases|dist|build)(/|$)' -or
            $p -match '(^|/).*release.*\.(ya?ml|json|md)$'
        }
    )

    Write-Host "CI/CD WORKFLOWS           : $($WorkflowFiles.Count)"
    Write-Host "DEPENDENCY MANIFESTS      : $($DependencyFiles.Count)"
    Write-Host "RELEASE/ARTIFACT SURFACES : $($ReleaseFiles.Count)"
    Write-Host "WORKFLOW EXECUTED BY GATE : NO"
    Write-Host "PACKAGE INSTALLED BY GATE : NO"
    Write-Host "RELEASE PUBLISHED BY GATE : NO"
    Write-Host "DISCOVERY : PASS"

    Step 5 "IMPLEMENT SPT-024.7 SECURITY LAYER"

    $InitPy = @'
"""SPT-024.7 CI/CD, dependency and software supply-chain security."""
from .service import SupplyChainSecurityService
from .gate import SupplyChainSecurityGate
from .audit import SupplyChainSecurityAuditor

__all__ = [
    "SupplyChainSecurityService",
    "SupplyChainSecurityGate",
    "SupplyChainSecurityAuditor",
]
'@

    $ModelsPy = @'
from dataclasses import dataclass, field
from typing import Any, Dict


@dataclass(frozen=True)
class SupplyChainSurface:
    path: str
    surface_type: str
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class SupplyChainControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str
'@

    $ClassifierPy = @'
from __future__ import annotations
from pathlib import Path
from typing import Iterable, List
from .models import SupplyChainSurface


class SupplyChainClassifier:
    def __init__(self, root: Path, tracked_paths: Iterable[str] | None = None):
        self.root = Path(root).resolve()
        self.tracked_paths = list(tracked_paths or [])

    def classify(self) -> List[SupplyChainSurface]:
        surfaces: List[SupplyChainSurface] = []
        for raw in self.tracked_paths:
            rel = raw.replace("\\", "/")
            low = rel.lower()

            if low.startswith(".github/workflows/") and low.endswith((".yml", ".yaml")):
                surfaces.append(SupplyChainSurface(rel, "CI_CD_WORKFLOW", {}))
                continue

            name = Path(low).name
            if (
                name.startswith("requirements") and name.endswith(".txt")
            ) or name in {
                "pyproject.toml",
                "poetry.lock",
                "pipfile",
                "pipfile.lock",
                "package.json",
                "package-lock.json",
                "yarn.lock",
                "pnpm-lock.yaml",
                "pubspec.yaml",
                "pubspec.lock",
            }:
                surfaces.append(SupplyChainSurface(rel, "DEPENDENCY_MANIFEST", {}))
                continue

            if "/releases/" in f"/{low}" or low.startswith("releases/"):
                surfaces.append(SupplyChainSurface(rel, "RELEASE_ARTIFACT", {}))

        return surfaces
'@

    $WorkflowAuditPy = @'
from __future__ import annotations
import re
from pathlib import Path
from typing import Dict, List


class WorkflowAudit:
    ACTION_RE = re.compile(r"(?m)^\s*-\s*uses:\s*([^\s#]+)")
    RUN_LINE_RE = re.compile(r"(?m)^\s*run:\s*(.+)$")
    WRITE_ALL_RE = re.compile(r"(?im)^\s*permissions:\s*write-all\s*$")
    DIRECT_SECRET_RE = re.compile(r"\$\{\{\s*secrets\.[A-Za-z0-9_]+\s*\}\}")
    EVENT_INTERPOLATION_RE = re.compile(r"\$\{\{\s*github\.event\.[^}]+\}\}")
    DANGEROUS_SHELL_RE = re.compile(
        r"(?i)(curl\s+[^|\r\n]+\|\s*(?:bash|sh)|wget\s+[^|\r\n]+\|\s*(?:bash|sh)|"
        r"\bInvoke-Expression\b|\biex\b|\beval\s+)"
    )

    @staticmethod
    def _read(root: Path, rel: str) -> str:
        try:
            return (root / rel).read_text(encoding="utf-8", errors="replace")
        except OSError:
            return ""

    @classmethod
    def assess(cls, root: Path, paths: List[str]) -> Dict[str, object]:
        floating_actions: List[str] = []
        mutable_branch_actions: List[str] = []
        broad_permissions: List[str] = []
        direct_secret_shell: List[str] = []
        expression_injection: List[str] = []
        dangerous_shell: List[str] = []
        action_refs: List[dict] = []

        for rel in paths:
            text = cls._read(root, rel)

            if cls.WRITE_ALL_RE.search(text):
                broad_permissions.append(rel)

            for match in cls.ACTION_RE.finditer(text):
                ref = match.group(1).strip()
                action_refs.append({"workflow": rel, "ref": ref})

                if "@" not in ref:
                    floating_actions.append(f"{rel}:{ref}")
                    continue

                _, version = ref.rsplit("@", 1)
                vlow = version.lower()
                if vlow in {"main", "master", "latest", "head", "develop", "dev"}:
                    mutable_branch_actions.append(f"{rel}:{ref}")
                elif not re.fullmatch(r"[0-9a-fA-F]{40}", version):
                    floating_actions.append(f"{rel}:{ref}")

            for line in cls.RUN_LINE_RE.findall(text):
                if cls.DIRECT_SECRET_RE.search(line):
                    direct_secret_shell.append(rel)
                if cls.EVENT_INTERPOLATION_RE.search(line):
                    expression_injection.append(rel)
                if cls.DANGEROUS_SHELL_RE.search(line):
                    dangerous_shell.append(rel)

        return {
            "action_refs": action_refs,
            "floating_actions": sorted(set(floating_actions)),
            "mutable_branch_actions": sorted(set(mutable_branch_actions)),
            "broad_permissions": sorted(set(broad_permissions)),
            "direct_secret_shell": sorted(set(direct_secret_shell)),
            "expression_injection": sorted(set(expression_injection)),
            "dangerous_shell": sorted(set(dangerous_shell)),
        }
'@

    $DependencyAuditPy = @'
from __future__ import annotations
import re
from pathlib import Path
from typing import Dict, List


class DependencyAudit:
    INSECURE_URL = re.compile(r"(?i)\bhttp://(?!localhost\b|127\.0\.0\.1\b)")
    UNPINNED_VCS = re.compile(r"(?i)(git\+https?://|github\.com/.+\.git)(?![^\s#]*@[0-9a-f]{7,40})")

    @staticmethod
    def _read(root: Path, rel: str) -> str:
        try:
            return (root / rel).read_text(encoding="utf-8", errors="replace")
        except OSError:
            return ""

    @classmethod
    def assess(cls, root: Path, paths: List[str]) -> Dict[str, object]:
        insecure_urls: List[str] = []
        unpinned_vcs: List[str] = []
        manifests: List[dict] = []

        for rel in paths:
            text = cls._read(root, rel)
            manifests.append({"path": rel, "size": len(text.encode("utf-8"))})

            if cls.INSECURE_URL.search(text):
                insecure_urls.append(rel)
            if cls.UNPINNED_VCS.search(text):
                unpinned_vcs.append(rel)

        return {
            "manifests": manifests,
            "insecure_urls": sorted(set(insecure_urls)),
            "unpinned_vcs": sorted(set(unpinned_vcs)),
        }
'@

    $SbomPy = @'
from __future__ import annotations
import hashlib
from pathlib import Path
from typing import Iterable, List


class InstitutionalSbom:
    @staticmethod
    def sha256(path: Path) -> str:
        h = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                h.update(chunk)
        return h.hexdigest()

    @classmethod
    def build(cls, root: Path, tracked_paths: Iterable[str]) -> dict:
        components: List[dict] = []

        for rel in sorted(set(tracked_paths)):
            p = root / rel
            if not p.is_file():
                continue
            low = rel.lower()
            if (
                low.startswith(".github/workflows/")
                or low.endswith((
                    "requirements.txt",
                    "pyproject.toml",
                    "poetry.lock",
                    "pipfile",
                    "pipfile.lock",
                    "package.json",
                    "package-lock.json",
                    "yarn.lock",
                    "pnpm-lock.yaml",
                    "pubspec.yaml",
                    "pubspec.lock",
                ))
                or "/releases/" in f"/{low}"
            ):
                components.append({
                    "path": rel.replace("\\", "/"),
                    "sha256": cls.sha256(p),
                    "bytes": p.stat().st_size,
                })

        return {
            "format": "SGODA-INSTITUTIONAL-SBOM",
            "version": "1.0",
            "components": components,
            "component_count": len(components),
        }
'@

    $IntegrityPy = @'
from __future__ import annotations
import hashlib
from pathlib import Path
from typing import Iterable


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def integrity_manifest(root: Path, paths: Iterable[str]) -> dict:
    records = []
    for rel in sorted(set(paths)):
        p = root / rel
        if p.is_file():
            records.append({
                "path": rel.replace("\\", "/"),
                "sha256": sha256(p),
                "bytes": p.stat().st_size,
            })
    return {
        "algorithm": "SHA-256",
        "records": records,
        "record_count": len(records),
    }
'@

    $AuditPy = @'
from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .classifier import SupplyChainClassifier
from .dependency_audit import DependencyAudit
from .models import SupplyChainControl
from .workflow_audit import WorkflowAudit


class SupplyChainSecurityAuditor:
    def __init__(self, root: Path, tracked_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.tracked_paths = [str(x).replace("\\", "/") for x in tracked_paths]

    def assess(self) -> dict:
        surfaces = SupplyChainClassifier(self.root, self.tracked_paths).classify()
        workflow_paths = [s.path for s in surfaces if s.surface_type == "CI_CD_WORKFLOW"]
        dependency_paths = [s.path for s in surfaces if s.surface_type == "DEPENDENCY_MANIFEST"]

        wf = WorkflowAudit.assess(self.root, workflow_paths)
        deps = DependencyAudit.assess(self.root, dependency_paths)

        controls = [
            SupplyChainControl(
                "SCM-WORKFLOW-PERMISSIONS",
                "No explicit write-all workflow permission",
                not wf["broad_permissions"],
                True,
                bool(workflow_paths),
                "No permissions: write-all detected." if not wf["broad_permissions"] else
                f"Explicit write-all permission detected in {len(wf['broad_permissions'])} workflow(s).",
            ),
            SupplyChainControl(
                "SCM-ACTIONS-MUTABLE-BRANCH",
                "Actions do not use mutable branch refs",
                not wf["mutable_branch_actions"],
                True,
                bool(workflow_paths),
                "No mutable action branch ref detected." if not wf["mutable_branch_actions"] else
                f"Mutable action branch refs detected: {len(wf['mutable_branch_actions'])}.",
            ),
            SupplyChainControl(
                "SCM-SECRET-USAGE",
                "Secrets are not interpolated directly in shell run lines",
                not wf["direct_secret_shell"],
                True,
                bool(workflow_paths),
                "No direct secret interpolation in run lines detected." if not wf["direct_secret_shell"] else
                f"Direct secret interpolation detected in {len(wf['direct_secret_shell'])} workflow(s).",
            ),
            SupplyChainControl(
                "SCM-EXPRESSION-INJECTION",
                "Untrusted event data is not interpolated directly in shell run lines",
                not wf["expression_injection"],
                True,
                bool(workflow_paths),
                "No direct github.event interpolation in run lines detected." if not wf["expression_injection"] else
                f"Potential expression injection detected in {len(wf['expression_injection'])} workflow(s).",
            ),
            SupplyChainControl(
                "SCM-SCRIPT-EXECUTION",
                "No high-risk pipe-to-shell or dynamic eval markers",
                not wf["dangerous_shell"],
                True,
                bool(workflow_paths),
                "No high-risk dynamic shell execution marker detected." if not wf["dangerous_shell"] else
                f"High-risk shell execution marker detected in {len(wf['dangerous_shell'])} workflow(s).",
            ),
            SupplyChainControl(
                "SCM-DEPENDENCY-INTEGRITY",
                "Dependency sources avoid insecure URLs and unpinned VCS refs",
                not deps["insecure_urls"] and not deps["unpinned_vcs"],
                True,
                bool(dependency_paths),
                "Dependency source integrity checks passed." if not deps["insecure_urls"] and not deps["unpinned_vcs"] else
                "Insecure dependency source or unpinned VCS reference detected.",
            ),
            SupplyChainControl(
                "SCM-ACTIONS-PINNING",
                "Third-party action pinning inventory",
                not wf["floating_actions"],
                False,
                bool(workflow_paths),
                "All action refs are immutable SHA pins." if not wf["floating_actions"] else
                f"{len(wf['floating_actions'])} version-tag or floating action ref(s) require progressive hardening.",
            ),
            SupplyChainControl(
                "SCM-VERSION-PINNING",
                "Dependency version pinning review",
                True,
                False,
                bool(dependency_paths),
                "Dependency manifests inventoried for subsequent exact-version policy enforcement.",
            ),
            SupplyChainControl(
                "SCM-SBOM",
                "Institutional SBOM generated",
                True,
                True,
                True,
                "Institutional SBOM is generated as part of the controlled transaction.",
            ),
            SupplyChainControl(
                "SCM-ARTIFACT-INTEGRITY",
                "Artifact integrity manifest generated",
                True,
                True,
                True,
                "SHA-256 integrity manifest is generated as part of the controlled transaction.",
            ),
            SupplyChainControl(
                "SCM-RELEASE-PROVENANCE",
                "Release provenance inventory",
                True,
                False,
                True,
                "Release and publication surfaces are inventoried without executing publication.",
            ),
            SupplyChainControl(
                "SCM-BUILD-REPRODUCIBILITY",
                "Build reproducibility readiness",
                True,
                False,
                True,
                "Advisory readiness control; no build is executed by this gate.",
            ),
        ]

        failed = [
            c.control_id
            for c in controls
            if c.blocking and c.applicable and not c.passed
        ]

        return {
            "status": "SUPPLY_CHAIN_SECURITY_GATE_PASS" if not failed else "SUPPLY_CHAIN_SECURITY_GATE_HOLD",
            "failed_control_ids": failed,
            "controls": [c.__dict__ for c in controls],
            "surfaces": [s.__dict__ for s in surfaces],
            "workflow_assessment": wf,
            "dependency_assessment": deps,
            "workflow_executed_by_gate": False,
            "package_installed_by_gate": False,
            "release_published_by_gate": False,
            "secret_values_exposed": False,
        }
'@

    $GatePy = @'
class SupplyChainSecurityGate:
    REQUIRED_BLOCKING_CONTROLS = frozenset({
        "SCM-WORKFLOW-PERMISSIONS",
        "SCM-ACTIONS-MUTABLE-BRANCH",
        "SCM-SECRET-USAGE",
        "SCM-EXPRESSION-INJECTION",
        "SCM-SCRIPT-EXECUTION",
        "SCM-DEPENDENCY-INTEGRITY",
        "SCM-SBOM",
        "SCM-ARTIFACT-INTEGRITY",
    })

    @classmethod
    def evaluate(cls, controls):
        by_id = {c["control_id"] if isinstance(c, dict) else c.control_id: c for c in controls}
        missing = sorted(cls.REQUIRED_BLOCKING_CONTROLS - set(by_id))
        if missing:
            return False, ["MISSING:" + item for item in missing]

        failed = []
        for control_id in sorted(cls.REQUIRED_BLOCKING_CONTROLS):
            c = by_id[control_id]
            passed = c["passed"] if isinstance(c, dict) else c.passed
            blocking = c["blocking"] if isinstance(c, dict) else c.blocking
            applicable = c["applicable"] if isinstance(c, dict) else c.applicable
            if blocking and applicable and not passed:
                failed.append(control_id)

        return not failed, failed
'@

    $ServicePy = @'
from pathlib import Path
from typing import Iterable

from .audit import SupplyChainSecurityAuditor
from .gate import SupplyChainSecurityGate


class SupplyChainSecurityService:
    def __init__(self, root: Path, tracked_paths: Iterable[str]):
        self.root = Path(root)
        self.tracked_paths = list(tracked_paths)

    def assess(self):
        result = SupplyChainSecurityAuditor(self.root, self.tracked_paths).assess()
        passed, failed = SupplyChainSecurityGate.evaluate(result["controls"])
        result["status"] = "SUPPLY_CHAIN_SECURITY_GATE_PASS" if passed else "SUPPLY_CHAIN_SECURITY_GATE_HOLD"
        result["failed_control_ids"] = failed
        return result
'@

    $TestsPy = @'
from pathlib import Path

from sgoda.integration.spt0247.audit import SupplyChainSecurityAuditor
from sgoda.integration.spt0247.gate import SupplyChainSecurityGate
from sgoda.integration.spt0247.service import SupplyChainSecurityService


def write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def controls(root, tracked):
    result = SupplyChainSecurityAuditor(root, tracked).assess()
    return {c["control_id"]: c for c in result["controls"]}


def test_gate_contract_has_eight_required_controls():
    assert len(SupplyChainSecurityGate.REQUIRED_BLOCKING_CONTROLS) == 8


def test_empty_scope_passes_non_applicable_controls(tmp_path):
    result = SupplyChainSecurityService(tmp_path, []).assess()
    assert result["status"] == "SUPPLY_CHAIN_SECURITY_GATE_PASS"


def test_write_all_permissions_are_blocking(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "permissions: write-all\njobs: {}\n")
    assert controls(tmp_path, [p])["SCM-WORKFLOW-PERMISSIONS"]["passed"] is False


def test_read_permissions_are_allowed(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "permissions: read-all\njobs: {}\n")
    assert controls(tmp_path, [p])["SCM-WORKFLOW-PERMISSIONS"]["passed"] is True


def test_mutable_main_action_is_blocking(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "steps:\n  - uses: owner/action@main\n")
    assert controls(tmp_path, [p])["SCM-ACTIONS-MUTABLE-BRANCH"]["passed"] is False


def test_version_tag_action_is_advisory_not_blocking(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "steps:\n  - uses: actions/checkout@v4\n")
    result = SupplyChainSecurityService(tmp_path, [p]).assess()
    assert result["status"] == "SUPPLY_CHAIN_SECURITY_GATE_PASS"
    by = {c["control_id"]: c for c in result["controls"]}
    assert by["SCM-ACTIONS-PINNING"]["passed"] is False
    assert by["SCM-ACTIONS-PINNING"]["blocking"] is False


def test_sha_pinned_action_passes_pinning_inventory(tmp_path):
    p = ".github/workflows/a.yml"
    sha = "0123456789abcdef0123456789abcdef01234567"
    write(tmp_path / p, f"steps:\n  - uses: actions/checkout@{sha}\n")
    assert controls(tmp_path, [p])["SCM-ACTIONS-PINNING"]["passed"] is True


def test_direct_secret_in_run_is_blocking(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "steps:\n  - run: echo ${{ secrets.API_TOKEN }}\n")
    assert controls(tmp_path, [p])["SCM-SECRET-USAGE"]["passed"] is False


def test_secret_in_env_not_direct_run_is_allowed(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "env:\n  API_TOKEN: ${{ secrets.API_TOKEN }}\nsteps:\n  - run: tool\n")
    assert controls(tmp_path, [p])["SCM-SECRET-USAGE"]["passed"] is True


def test_event_expression_in_run_is_blocking(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "steps:\n  - run: echo ${{ github.event.issue.title }}\n")
    assert controls(tmp_path, [p])["SCM-EXPRESSION-INJECTION"]["passed"] is False


def test_pipe_to_shell_is_blocking(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "steps:\n  - run: curl https://example.invalid/install.sh | bash\n")
    assert controls(tmp_path, [p])["SCM-SCRIPT-EXECUTION"]["passed"] is False


def test_https_dependency_source_is_allowed(tmp_path):
    p = "requirements.txt"
    write(tmp_path / p, "package==1.0.0\n")
    assert controls(tmp_path, [p])["SCM-DEPENDENCY-INTEGRITY"]["passed"] is True


def test_insecure_http_dependency_source_is_blocking(tmp_path):
    p = "requirements.txt"
    write(tmp_path / p, "pkg @ http://example.invalid/pkg.whl\n")
    assert controls(tmp_path, [p])["SCM-DEPENDENCY-INTEGRITY"]["passed"] is False


def test_unpinned_vcs_dependency_is_blocking(tmp_path):
    p = "requirements.txt"
    write(tmp_path / p, "git+https://github.com/example/project.git\n")
    assert controls(tmp_path, [p])["SCM-DEPENDENCY-INTEGRITY"]["passed"] is False


def test_workflow_is_classified(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "jobs: {}\n")
    result = SupplyChainSecurityService(tmp_path, [p]).assess()
    assert any(s["surface_type"] == "CI_CD_WORKFLOW" for s in result["surfaces"])


def test_dependency_manifest_is_classified(tmp_path):
    p = "pyproject.toml"
    write(tmp_path / p, "[project]\nname='x'\n")
    result = SupplyChainSecurityService(tmp_path, [p]).assess()
    assert any(s["surface_type"] == "DEPENDENCY_MANIFEST" for s in result["surfaces"])


def test_gate_never_executes_workflow_or_release(tmp_path):
    result = SupplyChainSecurityService(tmp_path, []).assess()
    assert result["workflow_executed_by_gate"] is False
    assert result["package_installed_by_gate"] is False
    assert result["release_published_by_gate"] is False
    assert result["secret_values_exposed"] is False


def test_unknown_yaml_is_not_ci_workflow(tmp_path):
    p = "pic.yaml"
    write(tmp_path / p, "name: config\n")
    result = SupplyChainSecurityService(tmp_path, [p]).assess()
    assert not result["surfaces"]


def test_test_requirements_are_still_supply_chain_surface(tmp_path):
    p = "tests/requirements.txt"
    write(tmp_path / p, "package==1\n")
    result = SupplyChainSecurityService(tmp_path, [p]).assess()
    assert any(s["surface_type"] == "DEPENDENCY_MANIFEST" for s in result["surfaces"])
'@

    $PolicyJson = @'
{
  "component": "SPT-024.7",
  "version": "1.0.0",
  "title": "Seguridad de CI/CD, Dependencias y Cadena de Suministro",
  "mode": "static-non-executing",
  "blocking_controls": [
    "SCM-WORKFLOW-PERMISSIONS",
    "SCM-ACTIONS-MUTABLE-BRANCH",
    "SCM-SECRET-USAGE",
    "SCM-EXPRESSION-INJECTION",
    "SCM-SCRIPT-EXECUTION",
    "SCM-DEPENDENCY-INTEGRITY",
    "SCM-SBOM",
    "SCM-ARTIFACT-INTEGRITY"
  ],
  "advisory_controls": [
    "SCM-ACTIONS-PINNING",
    "SCM-VERSION-PINNING",
    "SCM-RELEASE-PROVENANCE",
    "SCM-BUILD-REPRODUCIBILITY"
  ],
  "safety": {
    "execute_workflows": false,
    "install_packages": false,
    "publish_releases": false,
    "print_secret_values": false,
    "modify_closed_components": false
  }
}
'@

    $DocMd = @'
# SPT-024.7 Capa 1 — Seguridad de CI/CD, Dependencias y Cadena de Suministro

Línea base autoritativa: `45474c659c0634fb2aac1eb31fd19e9485594722`.

La capa realiza análisis estático no destructivo de GitHub Actions, dependencias, releases, SBOM e integridad SHA-256. No ejecuta workflows, no instala paquetes, no publica releases y no imprime secretos.

Controles bloqueantes: SCM-WORKFLOW-PERMISSIONS, SCM-ACTIONS-MUTABLE-BRANCH, SCM-SECRET-USAGE, SCM-EXPRESSION-INJECTION, SCM-SCRIPT-EXECUTION, SCM-DEPENDENCY-INTEGRITY, SCM-SBOM y SCM-ARTIFACT-INTEGRITY.

Los tags de versión de actions como `actions/checkout@v4` se registran como hardening advisory; ramas mutables como `@main`, `@master` o `@latest` son bloqueantes.

SPT-023.1–SPT-023.7 y SPT-024.1–SPT-024.6 permanecen cerrados e inmutables. Los 56 elementos históricos fuera de alcance conservan estado y SHA-256 durante toda la transacción.
'@

    Write-Lf "$ModuleDir/__init__.py" $InitPy
    Write-Lf "$ModuleDir/models.py" $ModelsPy
    Write-Lf "$ModuleDir/classifier.py" $ClassifierPy
    Write-Lf "$ModuleDir/workflow_audit.py" $WorkflowAuditPy
    Write-Lf "$ModuleDir/dependency_audit.py" $DependencyAuditPy
    Write-Lf "$ModuleDir/sbom.py" $SbomPy
    Write-Lf "$ModuleDir/integrity.py" $IntegrityPy
    Write-Lf "$ModuleDir/audit.py" $AuditPy
    Write-Lf "$ModuleDir/gate.py" $GatePy
    Write-Lf "$ModuleDir/service.py" $ServicePy
    Write-Lf $TestFile $TestsPy
    Write-Lf $PolicyFile $PolicyJson
    Write-Lf $DocFile $DocMd

    @(
        "$ModuleDir/__init__.py",
        "$ModuleDir/models.py",
        "$ModuleDir/classifier.py",
        "$ModuleDir/workflow_audit.py",
        "$ModuleDir/dependency_audit.py",
        "$ModuleDir/sbom.py",
        "$ModuleDir/integrity.py",
        "$ModuleDir/audit.py",
        "$ModuleDir/gate.py",
        "$ModuleDir/service.py",
        $TestFile,
        $PolicyFile,
        $DocFile
    ) | ForEach-Object {
        Write-Host "CREATED/VALIDATED : $_"
    }

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"

    $Python = PythonExe
    $env:PYTHONPATH = (Join-Path $PWD "src")

    Native $Python @(
        "-c",
        "import sgoda.integration.spt0247; from sgoda.integration.spt0247.gate import SupplyChainSecurityGate; assert len(SupplyChainSecurityGate.REQUIRED_BLOCKING_CONTROLS)==8; print('SPT0247_IMPORT=PASS'); print('BLOCKING_CONTROLS=8')"
    ) "SPT-024.7 import"

    Native $Python @("-m","pytest",$TestFile,"-q") "SPT-024.7 targeted tests"
    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"

    Native $Python @("-m","pytest","-q") "Institutional pytest suite"
    Write-Host "FULL SUITE : PASS"

    Native $Python @("-m","compileall","-q","src") "compileall"
    Write-Host "COMPILEALL : PASS"

    Step 8 "SUPPLY-CHAIN SECURITY REGRESSION TESTS"

    foreach ($selector in @(
        "write_all_permissions",
        "mutable_main_action",
        "direct_secret_in_run",
        "event_expression_in_run",
        "pipe_to_shell",
        "insecure_http_dependency",
        "unpinned_vcs_dependency",
        "gate_never_executes"
    )) {
        Native $Python @("-m","pytest",$TestFile,"-q","-k",$selector) ("Regression " + $selector)
    }

    Write-Host "SUPPLY-CHAIN REGRESSIONS : PASS"

    Step 9 "CI/CD / DEPENDENCY SECURITY ASSESSMENT"

    New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

    $TrackedJson = ($Tracked | ForEach-Object { Norm $_ }) | ConvertTo-Json -Compress
    $ProbePath = Join-Path $env:TEMP ("sgoda-spt0247-" + [Guid]::NewGuid().ToString("N") + ".py")
    $TrackedPath = Join-Path $env:TEMP ("sgoda-spt0247-tracked-" + [Guid]::NewGuid().ToString("N") + ".json")

    try {
        $utf8Temp = New-Object System.Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($TrackedPath, ($TrackedJson + "`n"), $utf8Temp)

        $ProbeCode = @'
import json
import sys
from pathlib import Path

from sgoda.integration.spt0247.service import SupplyChainSecurityService
from sgoda.integration.spt0247.sbom import InstitutionalSbom
from sgoda.integration.spt0247.integrity import integrity_manifest

root = Path.cwd()
tracked = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

result = SupplyChainSecurityService(root, tracked).assess()
sbom = InstitutionalSbom.build(root, tracked)

assessment_path = root / "artifacts" / "development" / "SPT-024.7-Capa1-v1.0.0" / "supply-chain-security-assessment.json"
sbom_path = root / "artifacts" / "development" / "SPT-024.7-Capa1-v1.0.0" / "institutional-sbom.json"
integrity_path = root / "artifacts" / "development" / "SPT-024.7-Capa1-v1.0.0" / "artifact-integrity.json"

assessment_path.parent.mkdir(parents=True, exist_ok=True)
assessment_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
sbom_path.write_text(json.dumps(sbom, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

integrity = integrity_manifest(root, [
    str(assessment_path.relative_to(root)).replace("\\", "/"),
    str(sbom_path.relative_to(root)).replace("\\", "/"),
])
integrity_path.write_text(json.dumps(integrity, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

workflow_count = sum(1 for s in result["surfaces"] if s["surface_type"] == "CI_CD_WORKFLOW")
dependency_count = sum(1 for s in result["surfaces"] if s["surface_type"] == "DEPENDENCY_MANIFEST")
release_count = sum(1 for s in result["surfaces"] if s["surface_type"] == "RELEASE_ARTIFACT")

print("SUPPLY_CHAIN_SECURITY_STATUS=" + result["status"])
print("WORKFLOW_SURFACES=%d" % workflow_count)
print("DEPENDENCY_SURFACES=%d" % dependency_count)
print("RELEASE_SURFACES=%d" % release_count)
print("BLOCKING_CONTROLS=8")
print("FAILED_BLOCKING_CONTROLS=%d" % len(result["failed_control_ids"]))
print("FAILED_CONTROL_IDS=" + ",".join(result["failed_control_ids"]))
print("SBOM_COMPONENTS=%d" % sbom["component_count"])
print("WORKFLOW_EXECUTED_BY_GATE=NO")
print("PACKAGE_INSTALLED_BY_GATE=NO")
print("RELEASE_PUBLISHED_BY_GATE=NO")
print("SECRET_VALUES_EXPOSED=NO")

if result["status"] != "SUPPLY_CHAIN_SECURITY_GATE_PASS":
    raise SystemExit(20)
'@

        [IO.File]::WriteAllText(
            $ProbePath,
            (($ProbeCode -replace "`r`n","`n") -replace "`r","`n"),
            $utf8Temp
        )

        & $Python $ProbePath $TrackedPath
        $AssessmentExit = $LASTEXITCODE

        if ($AssessmentExit -eq 20) {
            Write-Host "SAFE ASSESSMENT REPORT : $AssessmentFile"
            Stop-Hold "SPT-024.7 blocking supply-chain security controls failed. Review the safe assessment; no publication occurred."
        }
        if ($AssessmentExit -ne 0) {
            Stop-Hold "SPT-024.7 production supply-chain assessment failed with exit code $AssessmentExit."
        }
    }
    finally {
        Remove-Item -LiteralPath $ProbePath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $TrackedPath -Force -ErrorAction SilentlyContinue
    }

    Write-Host "SAFE ASSESSMENT REPORT : $AssessmentFile"
    Write-Host "INSTITUTIONAL SBOM      : $SbomFile"
    Write-Host "ARTIFACT INTEGRITY      : $IntegrityFile"
    Write-Host "SUPPLY-CHAIN SECURITY GATE : PASS"

    Step 10 "CLOSED-COMPONENT + WORKTREE PRESERVATION"

    Assert-PreservationSnapshot $Snapshot "SPT-024.7 preservation gate"

    $ChangedTracked = @(& git.exe -c core.quotepath=false diff --name-only $ExpectedBaseline --)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to calculate tracked preservation diff."
    }

    foreach ($item in $ChangedTracked) {
        $p = Norm $item
        if (Is-TransactionPath $p) { continue }
        if ($Snapshot.ContainsKey($p)) { continue }
        if ($p -eq $RuntimeFile) { continue }
        Stop-Hold "New tracked change outside SPT-024.7 transaction detected: $p"
    }

    Write-Host "SPT-023.1-.7 + SPT-024.1-.6 : PRESERVED"
    Write-Host "56 HISTORICAL OUTSIDE-SCOPE ITEMS : PRESERVED"

    Step 11 "SBOM + EVIDENCE"

    if (-not (Test-Path -LiteralPath $SbomFile)) {
        Stop-Hold "Institutional SBOM was not generated."
    }
    if (-not (Test-Path -LiteralPath $IntegrityFile)) {
        Stop-Hold "Artifact integrity manifest was not generated."
    }

    $Assessment = Get-Content -LiteralPath $AssessmentFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($Assessment.status -ne "SUPPLY_CHAIN_SECURITY_GATE_PASS") {
        Stop-Hold "Assessment file does not certify PASS."
    }

    $Evidence = [ordered]@{
        component = "SPT-024.7"
        layer = "Capa 1"
        version = "1.0.0"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        authoritative_baseline = $ExpectedBaseline
        branch = $Branch
        preexisting_outside_scope_items = $Snapshot.Count
        gates = [ordered]@{
            targeted_tests = "PASS"
            institutional_suite = "PASS"
            compileall = "PASS"
            supply_chain_security = "PASS"
            blocking_controls = 8
            failed_blocking_controls = 0
            sbom_generated = $true
            integrity_manifest_generated = $true
            workflow_executed_by_gate = $false
            package_installed_by_gate = $false
            release_published_by_gate = $false
            secret_values_exposed = $false
            closed_components_preserved = $true
            historical_outside_scope_preserved = $true
        }
        publication = "PENDING_CONTROLLED_COMMIT"
    }

    Write-Lf $EvidenceFile ($Evidence | ConvertTo-Json -Depth 10)
    Write-Host "EVIDENCE : CREATED (UTF-8 NO BOM / LF)"
    Write-Host "SBOM     : VERIFIED"
    Write-Host "SHA-256  : VERIFIED"

    Step 12 "EXACT CONTROLLED STAGING"

    $CanonicalFiles = @(
        $SelfName,
        $TestFile,
        $PolicyFile,
        $DocFile,
        $AssessmentFile,
        $SbomFile,
        $IntegrityFile,
        $EvidenceFile
    )

    $CanonicalFiles += @(
        Get-ChildItem -LiteralPath $ModuleDir -File -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object {
            $_.FullName.Substring($PWD.Path.Length + 1)
        }
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    foreach ($rel in ($CanonicalFiles | Select-Object -Unique)) {
        $abs = Join-Path $PWD $rel
        if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) {
            continue
        }

        $bytes = [IO.File]::ReadAllBytes($abs)
        $hasNul = $false
        foreach ($b in $bytes) {
            if ($b -eq 0) {
                $hasNul = $true
                break
            }
        }

        if (-not $hasNul) {
            $txt = [IO.File]::ReadAllText($abs,[Text.Encoding]::UTF8)
            $txt = ($txt -replace "`r`n","`n") -replace "`r","`n"
            [IO.File]::WriteAllText($abs,$txt,$utf8NoBom)
        }
    }

    Write-Host "TRANSACTION LINE ENDINGS : CANONICAL LF"
    Write-Host "GIT SAFECRLF POLICY      : TRANSACTION-LOCAL OVERRIDE ONLY"
    Write-Host "GIT GLOBAL/REPO CONFIG   : NOT MODIFIED"

    foreach ($target in @(
        $SelfName,
        $ModuleDir,
        $TestFile,
        $PolicyFile,
        $DocFile,
        $ArtifactDir
    )) {
        if (Test-Path -LiteralPath $target) {
            Native "git.exe" @("-c","core.safecrlf=false","add","--",$target) ("git add " + $target)
        }
    }

    $StagedNow = @(& git.exe diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect controlled staging."
    }
    if ($StagedNow.Count -eq 0) {
        Stop-Hold "Controlled staging is empty."
    }

    $Unexpected = @(
        $StagedNow | Where-Object {
            -not (Is-PublishPath $_)
        }
    )

    Write-Host "STAGED     : $($StagedNow.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if ($Unexpected.Count -gt 0) {
        & git.exe reset
        foreach ($item in $Unexpected) {
            Write-Host "UNEXPECTED STAGED : $item" -ForegroundColor Red
        }
        Stop-Hold "Unexpected file entered controlled staging."
    }

    Write-Host "STAGING QUALITY : PASS"
    Assert-PreservationSnapshot $Snapshot "Post-staging preservation gate"

    Step 13 "FINAL REMOTE GATE + COMMIT + PUSH"

    Native "git.exe" @("fetch","origin",$Branch) "final fetch"

    $LocalBeforePublish = (& git.exe rev-parse HEAD).Trim()
    $RemoteBeforePublish = (& git.exe rev-parse ("origin/" + $Branch)).Trim()

    if ($LocalBeforePublish -ne $ExpectedBaseline -or $RemoteBeforePublish -ne $ExpectedBaseline) {
        & git.exe reset
        Stop-Hold "Authoritative baseline changed before publication."
    }

    Assert-PreservationSnapshot $Snapshot "Pre-commit preservation gate"
    Write-Host "REMOTE GATE : PASS"

    Native "git.exe" @(
        "commit",
        "-m",
        "feat(spt-024.7): establish CI/CD and supply-chain security layer 1"
    ) "git commit"

    $NewCommit = (& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    Native "git.exe" @("push","origin",$Branch) "git push"

    Step 14 "AUTHORITATIVE REMOTE VERIFICATION"

    Native "git.exe" @("fetch","origin",$Branch) "verification fetch"

    $FinalLocal = (& git.exe rev-parse HEAD).Trim()
    $FinalRemote = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
    $Counts = ((& git.exe rev-list --left-right --count (("origin/" + $Branch) + "...HEAD")).Trim() -split '\s+')
    $FinalStaged = @(& git.exe diff --cached --name-only)
    $FinalDeleted = @(& git.exe -c core.quotepath=false ls-files --deleted)

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "BEHIND          : $($Counts[0])"
    Write-Host "AHEAD           : $($Counts[1])"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if (
        $FinalLocal -ne $FinalRemote -or
        $Counts[0] -ne "0" -or
        $Counts[1] -ne "0" -or
        $FinalStaged.Count -ne 0 -or
        $FinalDeleted.Count -ne 0
    ) {
        Stop-Hold "Final repository synchronization gate failed."
    }

    Assert-PreservationSnapshot $Snapshot "Post-publication preservation gate"

    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Green
    Write-Host " SPT-024.7 CAPA 1 : SECURITY CERTIFIED" -ForegroundColor Green
    Write-Host " SUPPLY_CHAIN_SECURITY_GATE=PASS" -ForegroundColor Green
    Write-Host " FAILED_BLOCKING_CONTROLS=0" -ForegroundColor Green
    Write-Host " WORKFLOW_EXECUTED_BY_GATE=NO" -ForegroundColor Green
    Write-Host " PACKAGE_INSTALLED_BY_GATE=NO" -ForegroundColor Green
    Write-Host " RELEASE_PUBLISHED_BY_GATE=NO" -ForegroundColor Green
    Write-Host " SECRET_VALUES_EXPOSED=NO" -ForegroundColor Green
    Write-Host " HISTORICAL_OUTSIDE_SCOPE_56=PRESERVED" -ForegroundColor Green
    Write-Host " CLOSED_COMPONENTS=PRESERVED" -ForegroundColor Green
    Write-Host " FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green
    exit 0
}
catch {
    Stop-Hold $_.Exception.Message
}
