#requires -Version 5.1
<#
SGODA-PUINAVE
SPT-023.7 - Auditoria Inteligente
Capa 1 - Motor de Auditoria Transversal
Maestro institucional unico / PowerShell 5.1

Linea base autorizada:
27ebc50911e36ae73989197d1ba2206c4e31267b

Alcance:
- auditar transversalmente SPT-023.1 a SPT-023.6;
- integridad, recursos faltantes, consistencia, nomenclatura,
  trazabilidad, calidad y conformidad institucional;
- preservar componentes cerrados mediante SHA-256;
- no modificar logica cerrada;
- crear codigo/configuracion/pruebas/documentacion/evidencia;
- actualizar SGD-002;
- commit, push y verificacion remota;
- no declarar cierre si existe cualquier error.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "27ebc50911e36ae73989197d1ba2206c4e31267b"
$ExpectedRemote = "https://github.com/Poliyoko/APP-PUINAVE.git"
$Component = "SPT-023.7"
$Layer = "Capa1"
$Version = "v1.0.0"
$SelfName = "Invoke-SGODA-SPT0237-Capa1-FINAL-v1.0.5-PS51.ps1"

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host $Text -ForegroundColor Cyan
}
function Fail([string]$Reason) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Red
    Write-Host " SPT-023.7 CAPA 1 : HOLD" -ForegroundColor Red
    Write-Host " REASON           : $Reason" -ForegroundColor Red
    Write-Host " ERRORS PENDING   : 1" -ForegroundColor Red
    Write-Host ("=" * 70) -ForegroundColor Red
    exit 1
}
function GitLines([string[]]$GitArgs) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $v = @(& git @GitArgs 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($exitCode -ne 0) {
        throw ($v -join [Environment]::NewLine)
    }

    return @(
        $v | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                [string]$_.Exception.Message
            }
            else {
                [string]$_
            }
        }
    )
}
function GitText([string[]]$GitArgs) {
    return ((GitLines $GitArgs) -join "`n").Trim()
}
function Write-Utf8NoBom([string]$Path,[string]$Content) {
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $normalized = $Content.Replace("`r`n","`n").Replace("`r","`n")
    if (-not $normalized.EndsWith("`n")) {
        $normalized += "`n"
    }

    [IO.File]::WriteAllText(
        $Path,
        $normalized,
        (New-Object Text.UTF8Encoding($false))
    )
}
function Get-Sha([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Assert-CleanTracked {
    $staged = @(GitLines @("diff","--cached","--name-only"))
    $deleted = @(GitLines @("ls-files","--deleted"))
    if ($staged.Count -ne 0) { Fail "Staged files exist before execution." }
    if ($deleted.Count -ne 0) { Fail "Deleted tracked files exist before execution." }
}
function Get-RepoRoot {
    try { return (GitText @("rev-parse","--show-toplevel")) } catch { Fail "Master script must be executed from inside the official repository." }
}
function Escape-Py([string]$s) { return $s.Replace("\","\\").Replace("'","\'") }

try {
    $Root = Get-RepoRoot
    Set-Location -LiteralPath $Root

    Write-Step "[1/12] AUTHORITATIVE BASELINE / RESUME CHECK"
    $origin = GitText @("remote","get-url","origin")
    if ($origin -notmatch "github\.com[/:]Poliyoko/APP-PUINAVE(?:\.git)?$") {
        Fail "Origin is not the official Poliyoko/APP-PUINAVE repository."
    }
    GitLines @("fetch","origin") | ForEach-Object { Write-Host $_ }
    $branch = GitText @("branch","--show-current")
    $localHead = GitText @("rev-parse","HEAD")
    $remoteHead = GitText @("rev-parse","origin/$branch")
    $staged0 = @(GitLines @("diff","--cached","--name-only")).Count
    $deleted0 = @(GitLines @("ls-files","--deleted")).Count
    Write-Host "  LOCAL HEAD      : $localHead"
    Write-Host "  REMOTE HEAD     : $remoteHead"
    Write-Host "  STAGED          : $staged0"
    Write-Host "  DELETED TRACKED : $deleted0"
    if ($localHead -ne $remoteHead) { Fail "Local and remote baseline differ." }
    if ($localHead -ne $ExpectedBaseline) { Fail "Authoritative baseline is not the expected SPT-023.6 closure commit." }
    Assert-CleanTracked
    Write-Host "  BASELINE : PASS" -ForegroundColor Green

    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $Root $SelfName),
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null
    if (@($parseErrors).Count -ne 0) { Fail "PowerShell syntax validation failed." }
    Write-Host "  POWERSHELL SYNTAX : PASS" -ForegroundColor Green

    # Recover only exact artifacts left by a previous failed pre-commit run.
    $staleEvidenceRel = "artifacts/development/SPT-023.7-Capa1-v1.0.0/implementation-evidence.json"
    $staleEvidenceAbs = Join-Path $Root ($staleEvidenceRel -replace '/', '\')
    if (Test-Path -LiteralPath $staleEvidenceAbs -PathType Leaf) {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $null = & git ls-files --error-unmatch -- $staleEvidenceRel 2>$null
            $staleEvidenceTrackedCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousPreference
        }

        if ($staleEvidenceTrackedCode -ne 0) {
            Remove-Item -LiteralPath $staleEvidenceAbs -Force
            Write-Host "STALE EVIDENCE   : REMOVED"
        }
    }

    # If the prior failed run updated SGD-002 before staging, restore only that
    # tracked master document to HEAD so this transaction starts from baseline
    # and reapplies the update deterministically.
    $modifiedTracked = @(
        GitLines @("-c","core.safecrlf=false","diff","--name-only") |
        Where-Object {
            $_ -and
            $_ -notmatch '^(warning:|hint:)'
        }
    )

    $modifiedSgd = @(
        $modifiedTracked | Where-Object {
            $_ -match 'SGD-002' -and $_ -match '\.(md|txt)$'
        }
    )

    foreach ($sgdModifiedRel in $modifiedSgd) {
        GitLines @("restore","--worktree","--source=HEAD","--",$sgdModifiedRel) | Out-Null
        Write-Host ("STALE SGD-002     : RESTORED TO BASELINE : " + $sgdModifiedRel)
    }

    $remainingModified = @(
        GitLines @("-c","core.safecrlf=false","diff","--name-only") |
        Where-Object {
            $_ -and
            $_ -notmatch '^(warning:|hint:)'
        }
    )

    $runtimeModified = @(
        $remainingModified | Where-Object {
            $_ -match '^artifacts/runtime/'
        }
    )

    $unexpectedModified = @(
        $remainingModified | Where-Object {
            $_ -notmatch '^artifacts/runtime/'
        }
    )

    Write-Host "PREEXISTING RUNTIME MODIFICATIONS : $($runtimeModified.Count)"
    if ($runtimeModified.Count -gt 0) {
        $runtimeModified | ForEach-Object {
            Write-Host ("RUNTIME PRESERVED : " + $_)
        }
    }

    if ($unexpectedModified.Count -ne 0) {
        Fail ("Unexpected non-runtime tracked worktree changes exist before execution: " + ($unexpectedModified -join ", "))
    }

    Write-Step "[2/12] SHA-256 FREEZE OF CLOSED COMPONENTS"
    $protected = @(GitLines @("ls-files") | Where-Object {
        $_ -match '(^|/)(src|config|docs|tests|artifacts|tools)/' -and
        (
            $_ -match 'SPT-023\.[1-6]' -or
            $_ -match 'spt023[1-6]' -or
            $_ -match 'SGD-002' -or
            $_ -match 'pmo' -or
            $_ -match 'audit'
        )
    } | Sort-Object -Unique)
    $freeze = @{}
    foreach ($rel in $protected) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        if (Test-Path -LiteralPath $abs -PathType Leaf) { $freeze[$rel] = Get-Sha $abs }
    }
    Write-Host "PROTECTED FILES : $($freeze.Count)"
    Write-Host "SHA-256 FREEZE  : PASS" -ForegroundColor Green

    $targets = @(
        "src/sgoda/integration/spt0237/__init__.py",
        "src/sgoda/integration/spt0237/models.py",
        "src/sgoda/integration/spt0237/rules.py",
        "src/sgoda/integration/spt0237/scanner.py",
        "src/sgoda/integration/spt0237/auditor.py",
        "src/sgoda/integration/spt0237/service.py",
        "config/integration/spt0237/audit-policy.json",
        "tests/integration/test_spt0237_intelligent_audit_layer1.py",
        "docs/06_Tecnologia/SPT-023.7/SGD-SPT023.7-Capa1-Auditoria-Transversal.md"
    )

    Write-Step "[3/12] TARGET COLLISION GATE"
    $collisions = @()
    $recoveredTargets = @()

    foreach ($rel in $targets) {
        $targetAbs = Join-Path $Root ($rel -replace '/', '\')

        if (Test-Path -LiteralPath $targetAbs) {
            $previousPreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"

            try {
                $null = & git ls-files --error-unmatch -- $rel 2>$null
                $trackedTargetExitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previousPreference
            }

            if ($trackedTargetExitCode -eq 0) {
                $collisions += $rel
            }
            else {
                Remove-Item -LiteralPath $targetAbs -Force
                $recoveredTargets += $rel
            }
        }
    }

    Write-Host "RECOVERED STALE UNTRACKED TARGETS : $($recoveredTargets.Count)"
    Write-Host "TARGET COLLISIONS                 : $($collisions.Count)"

    if ($collisions.Count -ne 0) {
        Fail ("Tracked target collision(s): " + ($collisions -join ", "))
    }

    $ObsoleteMasters = @(
        "Invoke-SGODA-SPT0237-Capa1-FINAL-v1.0.0-PS51.ps1",
        "Invoke-SGODA-SPT0237-Capa1-FINAL-v1.0.1-PS51.ps1",
        "Invoke-SGODA-SPT0237-Capa1-FINAL-v1.0.2-PS51.ps1",
        "Invoke-SGODA-SPT0237-Capa1-FINAL-v1.0.3-PS51.ps1",
        "Invoke-SGODA-SPT0237-Capa1-FINAL-v1.0.4-PS51.ps1"
    )

    foreach ($ObsoleteName in $ObsoleteMasters) {
        $ObsoleteMaster = Join-Path $Root $ObsoleteName

        if ($SelfName -ne $ObsoleteName -and (Test-Path -LiteralPath $ObsoleteMaster -PathType Leaf)) {
            $previousPreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"

            try {
                $null = & git ls-files --error-unmatch -- $ObsoleteName 2>$null
                $trackedOldExitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previousPreference
            }

            if ($trackedOldExitCode -ne 0) {
                Remove-Item -LiteralPath $ObsoleteMaster -Force
                Write-Host ("OBSOLETE FAILED MASTER : REMOVED : " + $ObsoleteName)
            }
            else {
                Write-Host ("OBSOLETE MASTER        : TRACKED / PRESERVED : " + $ObsoleteName)
            }
        }
    }

    Write-Step "[4/12] IMPLEMENT SPT-023.7 CAPA 1"

    $files = @{}

    $files["src/sgoda/integration/spt0237/__init__.py"] = @'
"""SPT-023.7 Intelligent Institutional Audit."""
from .models import AuditFinding, AuditReport
from .rules import AuditPolicy
from .scanner import TransversalScanner
from .auditor import IntelligentAuditor
from .service import Spt0237Layer1Service

__all__ = [
    "AuditFinding",
    "AuditReport",
    "AuditPolicy",
    "TransversalScanner",
    "IntelligentAuditor",
    "Spt0237Layer1Service",
]
'@

    $files["src/sgoda/integration/spt0237/models.py"] = @'
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class AuditFinding:
    dimension: str
    code: str
    severity: str
    message: str
    subject: str = ""
    evidence: dict[str, Any] = field(default_factory=dict)

    @property
    def blocking(self) -> bool:
        return self.severity.upper() in {"ERROR", "CRITICAL"}


@dataclass
class AuditReport:
    scope: tuple[str, ...]
    findings: list[AuditFinding] = field(default_factory=list)
    metrics: dict[str, Any] = field(default_factory=dict)

    @property
    def blocking_findings(self) -> list[AuditFinding]:
        return [item for item in self.findings if item.blocking]

    @property
    def conformant(self) -> bool:
        return not self.blocking_findings

    def count_by_dimension(self) -> dict[str, int]:
        result: dict[str, int] = {}
        for finding in self.findings:
            result[finding.dimension] = result.get(finding.dimension, 0) + 1
        return result

    def to_dict(self) -> dict[str, Any]:
        return {
            "scope": list(self.scope),
            "conformant": self.conformant,
            "blocking_count": len(self.blocking_findings),
            "metrics": dict(self.metrics),
            "findings": [
                {
                    "dimension": f.dimension,
                    "code": f.code,
                    "severity": f.severity,
                    "message": f.message,
                    "subject": f.subject,
                    "evidence": dict(f.evidence),
                }
                for f in self.findings
            ],
        }
'@

    $files["src/sgoda/integration/spt0237/rules.py"] = @'
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


DEFAULT_DIMENSIONS = (
    "integrity",
    "missing_resources",
    "consistency",
    "nomenclature",
    "traceability",
    "quality",
    "institutional_conformity",
)


@dataclass(frozen=True)
class AuditPolicy:
    scope: tuple[str, ...]
    dimensions: tuple[str, ...]
    required_files_per_component: int = 1
    require_sha256: bool = True
    require_tests: bool = True
    require_documentation: bool = True
    fail_on_error: bool = True

    @classmethod
    def default(cls) -> "AuditPolicy":
        return cls(
            scope=tuple(f"SPT-023.{i}" for i in range(1, 7)),
            dimensions=DEFAULT_DIMENSIONS,
        )

    @classmethod
    def from_json(cls, path: str | Path) -> "AuditPolicy":
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        return cls(
            scope=tuple(data.get("scope") or [f"SPT-023.{i}" for i in range(1, 7)]),
            dimensions=tuple(data.get("dimensions") or DEFAULT_DIMENSIONS),
            required_files_per_component=int(data.get("required_files_per_component", 1)),
            require_sha256=bool(data.get("require_sha256", True)),
            require_tests=bool(data.get("require_tests", True)),
            require_documentation=bool(data.get("require_documentation", True)),
            fail_on_error=bool(data.get("fail_on_error", True)),
        )
'@

    $files["src/sgoda/integration/spt0237/scanner.py"] = @'
from __future__ import annotations

import hashlib
import re
from pathlib import Path
from typing import Iterable


class TransversalScanner:
    """Read-only scanner over the institutional repository."""

    COMPONENT_RE = re.compile(r"spt[-_]?023[._-]?([1-6])", re.IGNORECASE)

    def __init__(self, root: str | Path):
        self.root = Path(root)

    def files(self) -> list[Path]:
        excluded = {".git", ".venv", "venv", "__pycache__", ".pytest_cache"}
        return sorted(
            p for p in self.root.rglob("*")
            if p.is_file() and not any(part in excluded for part in p.parts)
        )

    @staticmethod
    def sha256(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()

    def component_files(self, component: str) -> list[Path]:
        number = component.rsplit(".", 1)[-1]
        patterns = (
            f"spt023{number}",
            f"spt-023.{number}",
            f"spt-023-{number}",
            f"spt_023_{number}",
        )
        result = []
        for path in self.files():
            normalized = str(path.relative_to(self.root)).lower().replace("\\", "/")
            if any(token in normalized for token in patterns):
                result.append(path)
        return result

    def inventory(self, scope: Iterable[str]) -> dict[str, list[Path]]:
        return {component: self.component_files(component) for component in scope}
'@

    $files["src/sgoda/integration/spt0237/auditor.py"] = @'
from __future__ import annotations

import re
from pathlib import Path

from .models import AuditFinding, AuditReport
from .rules import AuditPolicy
from .scanner import TransversalScanner


class IntelligentAuditor:
    """Deterministic, read-only transversal audit engine."""

    VALID_NAME = re.compile(r"^[A-Za-z0-9_.\-/]+$")

    def __init__(self, root: str | Path, policy: AuditPolicy | None = None):
        self.root = Path(root)
        self.policy = policy or AuditPolicy.default()
        self.scanner = TransversalScanner(self.root)

    def run(self) -> AuditReport:
        report = AuditReport(scope=self.policy.scope)
        inventory = self.scanner.inventory(self.policy.scope)

        self._integrity(report, inventory)
        self._missing(report, inventory)
        self._consistency(report, inventory)
        self._nomenclature(report, inventory)
        self._traceability(report, inventory)
        self._quality(report, inventory)
        self._institutional(report, inventory)

        report.metrics.update({
            "components_scanned": len(inventory),
            "files_scanned": sum(len(v) for v in inventory.values()),
            "dimensions": len(self.policy.dimensions),
            "blocking_findings": len(report.blocking_findings),
        })
        return report

    def _add(self, report, dimension, code, severity, message, subject="", **evidence):
        report.findings.append(
            AuditFinding(dimension, code, severity, message, subject, evidence)
        )

    def _integrity(self, report, inventory):
        if "integrity" not in self.policy.dimensions:
            return
        for component, files in inventory.items():
            for path in files:
                try:
                    size = path.stat().st_size
                    digest = self.scanner.sha256(path) if self.policy.require_sha256 else ""
                    if size == 0:
                        self._add(report, "integrity", "EMPTY_FILE", "ERROR",
                                  "Tracked component resource is empty.",
                                  str(path.relative_to(self.root)))
                    if self.policy.require_sha256 and len(digest) != 64:
                        self._add(report, "integrity", "SHA256_INVALID", "ERROR",
                                  "SHA-256 could not be established.",
                                  str(path.relative_to(self.root)))
                except OSError as exc:
                    self._add(report, "integrity", "UNREADABLE", "ERROR",
                              "Resource cannot be read.",
                              str(path.relative_to(self.root)), error=str(exc))

    def _missing(self, report, inventory):
        if "missing_resources" not in self.policy.dimensions:
            return
        for component, files in inventory.items():
            if len(files) < self.policy.required_files_per_component:
                self._add(report, "missing_resources", "COMPONENT_RESOURCE_MISSING",
                          "ERROR", "No auditable resources were found.", component)

    def _consistency(self, report, inventory):
        if "consistency" not in self.policy.dimensions:
            return
        for component, files in inventory.items():
            if not files:
                continue
            suffixes = {p.suffix.lower() for p in files}
            if self.policy.require_tests and ".py" not in suffixes:
                self._add(report, "consistency", "PYTHON_FOOTPRINT_NOT_FOUND", "WARNING",
                          "No Python footprint detected for component.", component)

    def _nomenclature(self, report, inventory):
        if "nomenclature" not in self.policy.dimensions:
            return
        for files in inventory.values():
            for path in files:
                rel = str(path.relative_to(self.root)).replace("\\", "/")
                if not self.VALID_NAME.match(rel):
                    self._add(report, "nomenclature", "NON_STANDARD_PATH", "WARNING",
                              "Path contains characters outside institutional portable set.", rel)

    def _traceability(self, report, inventory):
        if "traceability" not in self.policy.dimensions:
            return
        for component, files in inventory.items():
            evidence = [
                p for p in files
                if "artifact" in str(p).lower() or "evidence" in p.name.lower()
            ]
            docs = [
                p for p in files
                if p.suffix.lower() == ".md" or "docs" in [part.lower() for part in p.parts]
            ]
            if not evidence:
                self._add(report, "traceability", "EVIDENCE_NOT_DISCOVERED", "WARNING",
                          "Evidence was not discovered by the transversal scanner.", component)
            if self.policy.require_documentation and not docs:
                self._add(report, "traceability", "DOCUMENTATION_NOT_DISCOVERED", "WARNING",
                          "Documentation was not discovered by the transversal scanner.", component)

    def _quality(self, report, inventory):
        if "quality" not in self.policy.dimensions:
            return
        for component, files in inventory.items():
            tests = [p for p in files if "test" in p.name.lower() and p.suffix.lower() == ".py"]
            if self.policy.require_tests and not tests:
                self._add(report, "quality", "TEST_RESOURCE_NOT_DISCOVERED", "WARNING",
                          "No component test resource was discovered.", component)

    def _institutional(self, report, inventory):
        if "institutional_conformity" not in self.policy.dimensions:
            return
        expected = set(self.policy.scope)
        present = {component for component, files in inventory.items() if files}
        missing = sorted(expected - present)
        for component in missing:
            self._add(report, "institutional_conformity", "SCOPE_GAP", "ERROR",
                      "Required closed component is absent from audit inventory.", component)
'@

    $files["src/sgoda/integration/spt0237/service.py"] = @'
from __future__ import annotations

import json
from pathlib import Path

from .auditor import IntelligentAuditor
from .models import AuditReport
from .rules import AuditPolicy


class Spt0237Layer1Service:
    def __init__(self, root: str | Path, policy: AuditPolicy | None = None):
        self.root = Path(root)
        self.policy = policy or AuditPolicy.default()

    def audit(self) -> AuditReport:
        return IntelligentAuditor(self.root, self.policy).run()

    def audit_to_json(self, destination: str | Path) -> AuditReport:
        report = self.audit()
        path = Path(destination)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(report.to_dict(), ensure_ascii=False, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        return report
'@

    $files["config/integration/spt0237/audit-policy.json"] = @'
{
  "component": "SPT-023.7",
  "layer": 1,
  "mode": "read-only-transversal-audit",
  "scope": [
    "SPT-023.1",
    "SPT-023.2",
    "SPT-023.3",
    "SPT-023.4",
    "SPT-023.5",
    "SPT-023.6"
  ],
  "dimensions": [
    "integrity",
    "missing_resources",
    "consistency",
    "nomenclature",
    "traceability",
    "quality",
    "institutional_conformity"
  ],
  "required_files_per_component": 1,
  "require_sha256": true,
  "require_tests": true,
  "require_documentation": true,
  "fail_on_error": true,
  "mutation_of_closed_components": false
}
'@

    $files["tests/integration/test_spt0237_intelligent_audit_layer1.py"] = @'
import json
from pathlib import Path

import pytest

from sgoda.integration.spt0237 import (
    AuditFinding,
    AuditPolicy,
    AuditReport,
    IntelligentAuditor,
    Spt0237Layer1Service,
    TransversalScanner,
)


def make_component(root: Path, number: int):
    base = root / "src" / "sgoda" / "integration" / f"spt023{number}"
    base.mkdir(parents=True, exist_ok=True)
    (base / "service.py").write_text("VALUE = 1\n", encoding="utf-8")
    tests = root / "tests" / "integration"
    tests.mkdir(parents=True, exist_ok=True)
    (tests / f"test_spt023{number}.py").write_text("def test_ok(): assert True\n", encoding="utf-8")
    docs = root / "docs" / f"SPT-023.{number}"
    docs.mkdir(parents=True, exist_ok=True)
    (docs / f"SGD-SPT023.{number}.md").write_text("# doc\n", encoding="utf-8")
    evidence = root / "artifacts" / "development" / f"SPT-023.{number}"
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / "implementation-evidence.json").write_text('{"ok": true}\n', encoding="utf-8")


def make_repo(root: Path):
    for number in range(1, 7):
        make_component(root, number)


def test_default_scope_has_six_closed_components():
    assert AuditPolicy.default().scope == tuple(f"SPT-023.{i}" for i in range(1, 7))


def test_default_policy_has_seven_dimensions():
    assert len(AuditPolicy.default().dimensions) == 7


def test_finding_error_is_blocking():
    assert AuditFinding("integrity", "X", "ERROR", "x").blocking


def test_finding_warning_is_not_blocking():
    assert not AuditFinding("quality", "X", "WARNING", "x").blocking


def test_empty_report_is_conformant():
    assert AuditReport(("SPT-023.1",)).conformant


def test_report_with_error_is_not_conformant():
    report = AuditReport(("SPT-023.1",), [AuditFinding("integrity", "X", "ERROR", "x")])
    assert not report.conformant


def test_report_serializes():
    report = AuditReport(("SPT-023.1",))
    assert report.to_dict()["conformant"] is True


def test_scanner_sha256(tmp_path):
    path = tmp_path / "x.txt"
    path.write_text("abc", encoding="utf-8")
    assert len(TransversalScanner.sha256(path)) == 64


def test_scanner_finds_component_files(tmp_path):
    make_component(tmp_path, 1)
    assert TransversalScanner(tmp_path).component_files("SPT-023.1")


def test_inventory_contains_all_requested_keys(tmp_path):
    make_repo(tmp_path)
    inv = TransversalScanner(tmp_path).inventory(AuditPolicy.default().scope)
    assert set(inv) == set(AuditPolicy.default().scope)


def test_complete_fixture_has_no_blocking_findings(tmp_path):
    make_repo(tmp_path)
    report = IntelligentAuditor(tmp_path).run()
    assert report.conformant


def test_missing_component_is_blocking(tmp_path):
    for number in range(1, 6):
        make_component(tmp_path, number)
    report = IntelligentAuditor(tmp_path).run()
    assert any(f.code == "COMPONENT_RESOURCE_MISSING" for f in report.blocking_findings)


def test_empty_component_file_is_blocking(tmp_path):
    make_repo(tmp_path)
    path = tmp_path / "src" / "sgoda" / "integration" / "spt0231" / "empty.py"
    path.write_bytes(b"")
    report = IntelligentAuditor(tmp_path).run()
    assert any(f.code == "EMPTY_FILE" for f in report.blocking_findings)


def test_metrics_report_six_components(tmp_path):
    make_repo(tmp_path)
    report = IntelligentAuditor(tmp_path).run()
    assert report.metrics["components_scanned"] == 6


def test_metrics_report_seven_dimensions(tmp_path):
    make_repo(tmp_path)
    report = IntelligentAuditor(tmp_path).run()
    assert report.metrics["dimensions"] == 7


def test_count_by_dimension(tmp_path):
    report = AuditReport(
        ("SPT-023.1",),
        [
            AuditFinding("quality", "A", "WARNING", "a"),
            AuditFinding("quality", "B", "WARNING", "b"),
        ],
    )
    assert report.count_by_dimension()["quality"] == 2


def test_service_runs(tmp_path):
    make_repo(tmp_path)
    assert Spt0237Layer1Service(tmp_path).audit().conformant


def test_service_writes_json(tmp_path):
    make_repo(tmp_path)
    destination = tmp_path / "out" / "audit.json"
    report = Spt0237Layer1Service(tmp_path).audit_to_json(destination)
    assert destination.exists()
    assert json.loads(destination.read_text(encoding="utf-8"))["conformant"] == report.conformant


def test_policy_can_load_json(tmp_path):
    p = tmp_path / "policy.json"
    p.write_text(json.dumps({"scope": ["SPT-023.1"], "dimensions": ["integrity"]}), encoding="utf-8")
    policy = AuditPolicy.from_json(p)
    assert policy.scope == ("SPT-023.1",)
    assert policy.dimensions == ("integrity",)


def test_policy_preserves_fail_on_error(tmp_path):
    p = tmp_path / "policy.json"
    p.write_text(json.dumps({"fail_on_error": False}), encoding="utf-8")
    assert AuditPolicy.from_json(p).fail_on_error is False


def test_auditor_is_read_only_for_fixture(tmp_path):
    make_repo(tmp_path)
    scanner = TransversalScanner(tmp_path)
    before = {str(p): scanner.sha256(p) for p in scanner.files()}
    IntelligentAuditor(tmp_path).run()
    after = {str(p): scanner.sha256(p) for p in scanner.files()}
    assert before == after


def test_scope_gap_code_is_institutional(tmp_path):
    make_component(tmp_path, 1)
    report = IntelligentAuditor(tmp_path).run()
    gaps = [f for f in report.findings if f.code == "SCOPE_GAP"]
    assert gaps and all(f.dimension == "institutional_conformity" for f in gaps)


def test_report_blocking_count_matches(tmp_path):
    make_component(tmp_path, 1)
    report = IntelligentAuditor(tmp_path).run()
    assert report.to_dict()["blocking_count"] == len(report.blocking_findings)


def test_complete_report_has_file_metric(tmp_path):
    make_repo(tmp_path)
    assert IntelligentAuditor(tmp_path).run().metrics["files_scanned"] >= 24


def test_all_scope_components_are_audited(tmp_path):
    make_repo(tmp_path)
    report = IntelligentAuditor(tmp_path).run()
    assert report.scope == AuditPolicy.default().scope


def test_warning_does_not_fail_conformity():
    report = AuditReport(
        ("SPT-023.1",),
        [AuditFinding("nomenclature", "WARN", "WARNING", "warning")],
    )
    assert report.conformant
'@

    $files["docs/06_Tecnologia/SPT-023.7/SGD-SPT023.7-Capa1-Auditoria-Transversal.md"] = @'
# SPT-023.7 Capa 1 — Motor de Auditoría Transversal

## Propósito

Implementar la primera capa de Auditoría Inteligente de SGODA-PUINAVE sin reabrir ni modificar los componentes cerrados SPT-023.1 a SPT-023.6.

## Dimensiones de auditoría

1. Integridad.
2. Recursos faltantes.
3. Consistencia.
4. Nomenclatura.
5. Trazabilidad.
6. Calidad.
7. Conformidad institucional.

## Principios

- Operación de auditoría en modo lectura.
- Preservación SHA-256 de componentes cerrados.
- Hallazgos estructurados por dimensión, código y severidad.
- ERROR y CRITICAL son bloqueantes.
- WARNING se registra sin falsear la conformidad técnica.
- Inventario transversal de SPT-023.1 a SPT-023.6.
- Reutilización de evidencia, documentación y pruebas existentes.
- Sin duplicación de lógica de los componentes auditados.

## Alcance de Capa 1

Capa 1 establece el motor, modelos, política, scanner, servicio y pruebas del auditor transversal. Las capas posteriores podrán incorporar correlación institucional avanzada, auditoría operacional y cierre integral de SPT-023.7 sobre esta base, sin reescribirla.
'@

    foreach ($rel in $files.Keys) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        Write-Utf8NoBom $abs $files[$rel]
        Write-Host "CREATED : $($rel -replace '/', '\')"
    }

    Write-Step "[5/12] PYTHON PREVALIDATION + TARGETED TESTS"
    $python = $null
    if (Test-Path -LiteralPath (Join-Path $Root ".venv\Scripts\python.exe")) {
        $python = Join-Path $Root ".venv\Scripts\python.exe"
    } else {
        $python = (Get-Command python -ErrorAction Stop).Source
    }

    $SrcPath = Join-Path $Root "src"

    if ([string]::IsNullOrWhiteSpace($env:PYTHONPATH)) {
        $env:PYTHONPATH = $SrcPath
    }
    else {
        $env:PYTHONPATH = $SrcPath + [IO.Path]::PathSeparator + $env:PYTHONPATH
    }

    Write-Host "PYTHON EXECUTABLE : $python"
    Write-Host "PYTHONPATH        : $env:PYTHONPATH"

    & $python -c "import sgoda; print('SGODA_IMPORT=PASS')"
    if ($LASTEXITCODE -ne 0) {
        Fail "Project package import prevalidation failed."
    }

    & $python -m py_compile `
        (Join-Path $Root "src\sgoda\integration\spt0237\__init__.py") `
        (Join-Path $Root "src\sgoda\integration\spt0237\models.py") `
        (Join-Path $Root "src\sgoda\integration\spt0237\rules.py") `
        (Join-Path $Root "src\sgoda\integration\spt0237\scanner.py") `
        (Join-Path $Root "src\sgoda\integration\spt0237\auditor.py") `
        (Join-Path $Root "src\sgoda\integration\spt0237\service.py")
    if ($LASTEXITCODE -ne 0) { Fail "Python syntax prevalidation failed." }

    & $python -m pytest -q "tests/integration/test_spt0237_intelligent_audit_layer1.py"
    if ($LASTEXITCODE -ne 0) { Fail "SPT-023.7 Capa 1 targeted tests failed." }
    Write-Host "TARGETED TESTS : 26 PASSED" -ForegroundColor Green

    Write-Step "[6/12] INSTITUTIONAL SUITE + COMPILEALL"
    & $python -m pytest -q
    if ($LASTEXITCODE -ne 0) { Fail "Institutional test suite failed." }

    # Count actual collected tests to avoid inventing a suite total.
    $collect = @(& $python -m pytest --collect-only -q 2>&1)
    if ($LASTEXITCODE -ne 0) { Fail "Unable to collect institutional tests." }
    $suiteCount = 0
    $collectText = ($collect | ForEach-Object { [string]$_ }) -join "`n"
    $countMatches = [regex]::Matches(
        $collectText,
        '(?im)(\d+)\s+(?:tests?|items?)\s+collected'
    )

    if ($countMatches.Count -gt 0) {
        $suiteCount = [int]$countMatches[$countMatches.Count - 1].Groups[1].Value
    }
    else {
        $nodeIds = @(
            $collect |
            Where-Object { ([string]$_) -match '::' }
        )
        $suiteCount = $nodeIds.Count
    }

    if ($suiteCount -lt 1102) {
        Fail "Institutional suite count is below expected continuity floor (1102)."
    }
    Write-Host "FULL SUITE : $suiteCount PASSED" -ForegroundColor Green

    & $python -m compileall -q "src"
    if ($LASTEXITCODE -ne 0) { Fail "COMPILEALL failed." }
    Write-Host "COMPILEALL : PASS" -ForegroundColor Green

    Write-Step "[7/12] SHA-256 PRESERVATION GATE"
    $changedProtected = @()
    foreach ($rel in $freeze.Keys) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) {
            $changedProtected += $rel
        } elseif ((Get-Sha $abs) -ne $freeze[$rel]) {
            $changedProtected += $rel
        }
    }
    Write-Host "PROTECTED FILES CHANGED : $($changedProtected.Count)"
    if ($changedProtected.Count -ne 0) { Fail ("Closed component preservation failed: " + ($changedProtected -join ", ")) }
    Write-Host "SPT-023.1 - SPT-023.6 : PRESERVED" -ForegroundColor Green

    Write-Step "[8/12] EVIDENCE + SGD-002 UPDATE"
    $auditEvidenceRel = "artifacts/development/SPT-023.7-Capa1-v1.0.0/implementation-evidence.json"
    $auditEvidenceAbs = Join-Path $Root ($auditEvidenceRel -replace '/', '\')
    $evidenceObject = [ordered]@{
        component = "SPT-023.7"
        layer = "Capa 1"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        scope = @("SPT-023.1","SPT-023.2","SPT-023.3","SPT-023.4","SPT-023.5","SPT-023.6")
        dimensions = @("integrity","missing_resources","consistency","nomenclature","traceability","quality","institutional_conformity")
        targeted_tests = 26
        institutional_tests = $suiteCount
        compileall = "PASS"
        protected_files = $freeze.Count
        protected_changes = 0
        mutation_of_closed_components = $false
        status = "IMPLEMENTED_AND_VALIDATED"
    }
    Write-Utf8NoBom $auditEvidenceAbs ($evidenceObject | ConvertTo-Json -Depth 8)
    Write-Host "EVIDENCE : CREATED"

    # Locate the authoritative tracked SGD-002 without guessing its exact path.
    $sgdCandidates = @(GitLines @("ls-files") | Where-Object {
        ($_ -match '(^|/)SGD-002([^/]*)(\.md|\.txt|\.json)?$') -or
        ($_ -match 'SGD-002' -and $_ -match '\.(md|txt)$')
    })
    if ($sgdCandidates.Count -eq 0) { Fail "Tracked SGD-002 master document was not found." }
    $sgdRel = $sgdCandidates[0]
    $sgdAbs = Join-Path $Root ($sgdRel -replace '/', '\')
    $sgdText = [IO.File]::ReadAllText($sgdAbs)
    $marker = "SPT-023.7 Capa 1"
    if ($sgdText -notmatch [regex]::Escape($marker)) {
        $append = @"

## SPT-023.7 — Auditoría Inteligente

- Capa 1: IMPLEMENTED AND VALIDATED
- Alcance transversal: SPT-023.1 a SPT-023.6
- Dimensiones: integridad, recursos faltantes, consistencia, nomenclatura, trazabilidad, calidad y conformidad institucional
- Componentes cerrados: PRESERVED
- Estado SPT-023.7: IN PROGRESS
"@
        Write-Utf8NoBom $sgdAbs ($sgdText.TrimEnd() + "`r`n" + $append.TrimStart())
    }
    Write-Host "SGD-002  : UPDATED"

    Write-Step "[9/12] EXACT CONTROLLED STAGING"
    $stage = @($targets + $auditEvidenceRel + $sgdRel + $SelfName) | Sort-Object -Unique
    foreach ($rel in $stage) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root ($rel -replace '/', '\')))) {
            Fail "Required staging path missing: $rel"
        }
        GitLines @("-c","core.safecrlf=false","add","--",$rel) | Out-Null
    }

    $staged = @(GitLines @("diff","--cached","--name-only"))
    $missing = @($stage | Where-Object { $_ -notin $staged })
    $unexpected = @($staged | Where-Object { $_ -notin $stage })
    Write-Host "STAGED     : $($staged.Count)"
    Write-Host "MISSING    : $($missing.Count)"
    Write-Host "UNEXPECTED : $($unexpected.Count)"
    if ($missing.Count -ne 0 -or $unexpected.Count -ne 0) { Fail "Exact controlled staging failed." }
    GitLines @("-c","core.safecrlf=false","diff","--cached","--check") | Out-Null
    Write-Host "DIFF CHECK      : PASS" -ForegroundColor Green
    Write-Host "STAGING QUALITY : PASS" -ForegroundColor Green

    Write-Step "[10/12] FINAL REMOTE GATE"
    GitLines @("fetch","origin") | ForEach-Object { Write-Host $_ }
    $remoteBefore = GitText @("rev-parse","origin/$branch")
    $headBeforeCommit = GitText @("rev-parse","HEAD")
    if ($remoteBefore -ne $headBeforeCommit) { Fail "Remote changed during implementation; refusing commit." }
    Write-Host "  REMOTE GATE : PASS" -ForegroundColor Green

    Write-Step "[11/12] COMMIT + PUSH"
    GitLines @("commit","-m","feat(spt-023.7): implement intelligent transversal audit layer 1") | ForEach-Object { Write-Host $_ }
    $newCommit = GitText @("rev-parse","HEAD")
    Write-Host "NEW COMMIT : $newCommit"
    GitLines @("push","origin",$branch) | ForEach-Object { Write-Host $_ }

    Write-Step "[12/12] AUTHORITATIVE REMOTE VERIFICATION"
    GitLines @("fetch","origin") | ForEach-Object { Write-Host $_ }
    $localFinal = GitText @("rev-parse","HEAD")
    $remoteFinal = GitText @("rev-parse","origin/$branch")
    $aheadBehind = (GitText @("rev-list","--left-right","--count","origin/$branch...HEAD")) -split '\s+'
    $behind = [int]$aheadBehind[0]
    $ahead = [int]$aheadBehind[1]
    $stagedFinal = @(GitLines @("diff","--cached","--name-only")).Count
    $deletedFinal = @(GitLines @("ls-files","--deleted")).Count

    Write-Host "  LOCAL HEAD      : $localFinal"
    Write-Host "  REMOTE HEAD     : $remoteFinal"
    Write-Host "  AHEAD           : $ahead"
    Write-Host "  BEHIND          : $behind"
    Write-Host "  STAGED          : $stagedFinal"
    Write-Host "  DELETED TRACKED : $deletedFinal"

    if ($localFinal -ne $remoteFinal -or $ahead -ne 0 -or $behind -ne 0 -or $stagedFinal -ne 0 -or $deletedFinal -ne 0) {
        Fail "Final authoritative remote verification failed."
    }

    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Green
    Write-Host " SPT-023.7 CAPA 1 : IMPLEMENTED AND VALIDATED" -ForegroundColor Green
    Write-Host " AUDIT SCOPE      : SPT-023.1 - SPT-023.6" -ForegroundColor Green
    Write-Host " DIMENSIONS       : 7 TRANSVERSAL CONTROLS" -ForegroundColor Green
    Write-Host " TARGETED TESTS   : 26 PASSED" -ForegroundColor Green
    Write-Host " FULL SUITE       : $suiteCount PASSED" -ForegroundColor Green
    Write-Host " CLOSED COMPONENTS: PRESERVED" -ForegroundColor Green
    Write-Host " SGD-002          : UPDATED" -ForegroundColor Green
    Write-Host " LOCAL/REMOTE     : IDENTICAL" -ForegroundColor Green
    Write-Host " ERRORS PENDING   : 0" -ForegroundColor Green
    Write-Host " NEXT             : SPT-023.7 CAPA 2" -ForegroundColor Green
    Write-Host ("=" * 70) -ForegroundColor Green
    Write-Host "FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
    exit 0
}
catch {
    Fail $_.Exception.Message
}
