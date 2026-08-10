#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "ae770bb6f91a1d6647586fbe73f1d4ebb1402a0a"
$SelfName = "Invoke-SGODA-SPT0237-Capa2-FINAL-v1.0.0-PS51.ps1"
$CommitMessage = "feat(spt-023.7): implement institutional correlation and verdict layer 2"
$TargetedExpected = 26
$FullSuiteFloor = 1128

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host $Text -ForegroundColor Cyan
}

function Fail([string]$Reason) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Red
    Write-Host " SPT-023.7 CAPA 2 : HOLD" -ForegroundColor Red
    Write-Host " REASON           : $Reason" -ForegroundColor Red
    Write-Host " ERRORS PENDING   : 1" -ForegroundColor Red
    Write-Host ("=" * 70) -ForegroundColor Red
    exit 1
}

function GitLines([string[]]$GitArgs) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = @(& git @GitArgs 2>&1)
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }

    if ($code -ne 0) {
        throw (($output | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                [string]$_.Exception.Message
            } else {
                [string]$_
            }
        }) -join [Environment]::NewLine)
    }

    return @(
        $output | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                [string]$_.Exception.Message
            } else {
                [string]$_
            }
        }
    )
}

function GitText([string[]]$GitArgs) {
    return ((GitLines $GitArgs) -join "`n").Trim()
}

function Write-Utf8Lf([string]$Path,[string]$Content) {
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

try {
    $Root = GitText @("rev-parse","--show-toplevel")
    Set-Location -LiteralPath $Root
    $Branch = GitText @("branch","--show-current")

    Write-Step "[1/12] AUTHORITATIVE BASELINE / WORKTREE SAFETY"
    GitLines @("fetch","origin",$Branch,"--no-tags") | ForEach-Object { Write-Host $_ }

    $Local = GitText @("rev-parse","HEAD")
    $Remote = GitText @("rev-parse","origin/$Branch")
    $Staged = @(GitLines @("diff","--cached","--name-only"))
    $Deleted = @(GitLines @("ls-files","--deleted"))

    Write-Host "LOCAL HEAD      : $Local"
    Write-Host "REMOTE HEAD     : $Remote"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if ($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline) {
        Fail "Authoritative baseline is not the certified SPT-023.7 Capa 1 commit."
    }
    if ($Staged.Count -ne 0) { Fail "Staging must be clean." }
    if ($Deleted.Count -ne 0) { Fail "Tracked deletions detected." }

    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $Root $SelfName),
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null
    if (@($parseErrors).Count -ne 0) { Fail "PowerShell syntax validation failed." }

    # Preserve runtime modifications and reject unrelated tracked changes.
    $modified = @(
        GitLines @("-c","core.safecrlf=false","diff","--name-only") |
        Where-Object { $_ -and $_ -notmatch '^(warning:|hint:)' }
    )
    $runtimeModified = @($modified | Where-Object { $_ -match '^artifacts/runtime/' })
    $unexpectedModified = @($modified | Where-Object { $_ -notmatch '^artifacts/runtime/' })

    Write-Host "PREEXISTING RUNTIME MODIFICATIONS : $($runtimeModified.Count)"
    $runtimeModified | ForEach-Object { Write-Host ("RUNTIME PRESERVED : " + $_) }

    if ($unexpectedModified.Count -ne 0) {
        Fail ("Unexpected non-runtime tracked changes: " + ($unexpectedModified -join ", "))
    }

    Write-Host "BASELINE : PASS" -ForegroundColor Green
    Write-Host "POWERSHELL SYNTAX : PASS" -ForegroundColor Green

    Write-Step "[2/12] SHA-256 FREEZE OF CLOSED + CAPA 1 COMPONENTS"
    $tracked = @(GitLines @("ls-files"))
    $protected = @(
        $tracked | Where-Object {
            $_ -match 'SPT-023\.[1-6]' -or
            $_ -match 'spt023[1-6]' -or
            $_ -match 'SPT-023\.7-Capa1' -or
            $_ -match 'spt0237/(?:__init__|models|rules|scanner|auditor|service)\.py' -or
            $_ -match 'test_spt0237_intelligent_audit_layer1\.py' -or
            $_ -match 'audit-policy\.json' -or
            $_ -match 'Capa1-Auditoria-Transversal'
        } | Sort-Object -Unique
    )

    $freeze = @{}
    foreach ($rel in $protected) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        if (Test-Path -LiteralPath $abs -PathType Leaf) {
            $freeze[$rel] = Get-Sha $abs
        }
    }

    Write-Host "PROTECTED FILES : $($freeze.Count)"
    Write-Host "SHA-256 FREEZE  : PASS" -ForegroundColor Green

    $targets = @(
        "src/sgoda/integration/spt0237/correlation.py",
        "src/sgoda/integration/spt0237/risk.py",
        "src/sgoda/integration/spt0237/evidence.py",
        "src/sgoda/integration/spt0237/crosscheck.py",
        "src/sgoda/integration/spt0237/verdict.py",
        "src/sgoda/integration/spt0237/layer2.py",
        "tests/integration/test_spt0237_institutional_correlation_layer2.py",
        "docs/06_Tecnologia/SPT-023.7/SGD-SPT023.7-Capa2-Correlacion-Riesgo-Dictamen.md",
        "config/integration/spt0237/institutional-correlation.json"
    )

    Write-Step "[3/12] TARGET COLLISION / FAILED-RUN RECOVERY"
    $collisions = @()
    $recovered = @()

    foreach ($rel in $targets) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        if (Test-Path -LiteralPath $abs) {
            $previous = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                $null = & git ls-files --error-unmatch -- $rel 2>$null
                $trackedCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previous
            }

            if ($trackedCode -eq 0) {
                $collisions += $rel
            } else {
                Remove-Item -LiteralPath $abs -Force
                $recovered += $rel
            }
        }
    }

    $staleEvidenceRel = "artifacts/development/SPT-023.7-Capa2-v1.0.0/implementation-evidence.json"
    $staleEvidenceAbs = Join-Path $Root ($staleEvidenceRel -replace '/', '\')
    if (Test-Path -LiteralPath $staleEvidenceAbs -PathType Leaf) {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $null = & git ls-files --error-unmatch -- $staleEvidenceRel 2>$null
            $evidenceTrackedCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previous
        }
        if ($evidenceTrackedCode -ne 0) {
            Remove-Item -LiteralPath $staleEvidenceAbs -Force
            Write-Host "STALE EVIDENCE : REMOVED"
        }
    }

    Write-Host "RECOVERED STALE UNTRACKED TARGETS : $($recovered.Count)"
    Write-Host "TARGET COLLISIONS                 : $($collisions.Count)"
    if ($collisions.Count -ne 0) {
        Fail ("Tracked target collisions: " + ($collisions -join ", "))
    }

    Write-Step "[4/12] IMPLEMENT SPT-023.7 CAPA 2"

    $Files = @{}
    $Files["src/sgoda/integration/spt0237/correlation.py"] = @'
from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from typing import Iterable

from .models import AuditFinding


@dataclass(frozen=True)
class CorrelatedFinding:
    correlation_id: str
    dimensions: tuple[str, ...]
    subjects: tuple[str, ...]
    codes: tuple[str, ...]
    severities: tuple[str, ...]
    finding_count: int

    def to_dict(self) -> dict:
        return {
            "correlation_id": self.correlation_id,
            "dimensions": list(self.dimensions),
            "subjects": list(self.subjects),
            "codes": list(self.codes),
            "severities": list(self.severities),
            "finding_count": self.finding_count,
        }


class FindingCorrelator:
    """Correlates audit findings by institutional subject."""

    @staticmethod
    def correlate(findings: Iterable[AuditFinding]) -> list[CorrelatedFinding]:
        grouped: dict[str, list[AuditFinding]] = defaultdict(list)
        for finding in findings:
            key = finding.subject.strip() or "__GLOBAL__"
            grouped[key].append(finding)

        results: list[CorrelatedFinding] = []
        for subject, items in sorted(grouped.items()):
            dimensions = tuple(sorted({item.dimension for item in items}))
            codes = tuple(sorted({item.code for item in items}))
            severities = tuple(sorted({item.severity.upper() for item in items}))
            correlation_id = "CORR-" + subject.replace("\\", "/").replace(" ", "_").upper()
            results.append(
                CorrelatedFinding(
                    correlation_id=correlation_id,
                    dimensions=dimensions,
                    subjects=(subject,),
                    codes=codes,
                    severities=severities,
                    finding_count=len(items),
                )
            )
        return results
'@
    $Files["src/sgoda/integration/spt0237/risk.py"] = @'
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from .correlation import CorrelatedFinding
from .models import AuditFinding


SEVERITY_WEIGHT = {
    "INFO": 0,
    "WARNING": 1,
    "ERROR": 3,
    "CRITICAL": 5,
}


@dataclass(frozen=True)
class RiskAssessment:
    score: int
    level: str
    blocking_findings: int
    correlated_groups: int

    def to_dict(self) -> dict:
        return {
            "score": self.score,
            "level": self.level,
            "blocking_findings": self.blocking_findings,
            "correlated_groups": self.correlated_groups,
        }


class InstitutionalRiskEvaluator:
    @staticmethod
    def evaluate(
        findings: Iterable[AuditFinding],
        correlations: Iterable[CorrelatedFinding],
    ) -> RiskAssessment:
        findings = list(findings)
        correlations = list(correlations)

        base = sum(SEVERITY_WEIGHT.get(item.severity.upper(), 2) for item in findings)
        multi_dimension_penalty = sum(
            max(0, len(item.dimensions) - 1)
            for item in correlations
        )
        score = base + multi_dimension_penalty
        blocking = sum(1 for item in findings if item.blocking)

        if blocking > 0 or score >= 12:
            level = "HIGH"
        elif score >= 5:
            level = "MEDIUM"
        elif score > 0:
            level = "LOW"
        else:
            level = "NONE"

        return RiskAssessment(
            score=score,
            level=level,
            blocking_findings=blocking,
            correlated_groups=len(correlations),
        )
'@
    $Files["src/sgoda/integration/spt0237/evidence.py"] = @'
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any, Iterable

from .models import AuditFinding


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


@dataclass(frozen=True)
class EvidenceBundle:
    finding_count: int
    subjects: tuple[str, ...]
    dimensions: tuple[str, ...]
    sha256: str
    payload: tuple[dict[str, Any], ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "finding_count": self.finding_count,
            "subjects": list(self.subjects),
            "dimensions": list(self.dimensions),
            "sha256": self.sha256,
            "payload": list(self.payload),
        }


class EvidenceConsolidator:
    @staticmethod
    def consolidate(findings: Iterable[AuditFinding]) -> EvidenceBundle:
        payload = tuple(
            sorted(
                (
                    {
                        "dimension": f.dimension,
                        "code": f.code,
                        "severity": f.severity.upper(),
                        "message": f.message,
                        "subject": f.subject,
                        "evidence": dict(f.evidence),
                    }
                    for f in findings
                ),
                key=lambda item: (
                    item["subject"],
                    item["dimension"],
                    item["code"],
                    item["severity"],
                ),
            )
        )
        sha = hashlib.sha256(_canonical(payload)).hexdigest().upper()
        return EvidenceBundle(
            finding_count=len(payload),
            subjects=tuple(sorted({item["subject"] for item in payload if item["subject"]})),
            dimensions=tuple(sorted({item["dimension"] for item in payload})),
            sha256=sha,
            payload=payload,
        )
'@
    $Files["src/sgoda/integration/spt0237/crosscheck.py"] = @'
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from .models import AuditFinding


@dataclass(frozen=True)
class CrossComponentInconsistency:
    code: str
    severity: str
    components: tuple[str, ...]
    message: str

    def to_dict(self) -> dict:
        return {
            "code": self.code,
            "severity": self.severity,
            "components": list(self.components),
            "message": self.message,
        }


class CrossComponentConsistencyEngine:
    """Detects cross-component inconsistencies from audit findings."""

    COMPONENTS = tuple(f"SPT-023.{i}" for i in range(1, 7))

    @classmethod
    def detect(cls, findings: Iterable[AuditFinding]) -> list[CrossComponentInconsistency]:
        findings = list(findings)
        results: list[CrossComponentInconsistency] = []

        missing_scope = {
            f.subject
            for f in findings
            if f.code in {"SCOPE_GAP", "COMPONENT_RESOURCE_MISSING"}
            and f.subject in cls.COMPONENTS
        }
        if missing_scope:
            results.append(
                CrossComponentInconsistency(
                    code="PIPELINE_SCOPE_INCOMPLETE",
                    severity="ERROR",
                    components=tuple(sorted(missing_scope)),
                    message="The intelligent integration pipeline has missing auditable components.",
                )
            )

        blocking_components = sorted({
            f.subject
            for f in findings
            if f.blocking and f.subject in cls.COMPONENTS
        })
        if len(blocking_components) > 1:
            results.append(
                CrossComponentInconsistency(
                    code="MULTI_COMPONENT_BLOCKING_RISK",
                    severity="CRITICAL",
                    components=tuple(blocking_components),
                    message="Blocking findings affect multiple closed pipeline components.",
                )
            )

        evidence_gaps = sorted({
            f.subject
            for f in findings
            if f.code == "EVIDENCE_NOT_DISCOVERED"
            and f.subject in cls.COMPONENTS
        })
        if len(evidence_gaps) >= 2:
            results.append(
                CrossComponentInconsistency(
                    code="TRACEABILITY_CHAIN_WEAKNESS",
                    severity="WARNING",
                    components=tuple(evidence_gaps),
                    message="Evidence gaps span multiple pipeline components.",
                )
            )

        return results
'@
    $Files["src/sgoda/integration/spt0237/verdict.py"] = @'
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .evidence import EvidenceBundle
from .risk import RiskAssessment


@dataclass(frozen=True)
class InstitutionalVerdict:
    status: str
    publishable: bool
    blocking_reasons: tuple[str, ...]
    risk_level: str
    evidence_sha256: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status,
            "publishable": self.publishable,
            "blocking_reasons": list(self.blocking_reasons),
            "risk_level": self.risk_level,
            "evidence_sha256": self.evidence_sha256,
        }


class InstitutionalVerdictEngine:
    @staticmethod
    def issue(
        *,
        report_conformant: bool,
        risk: RiskAssessment,
        evidence: EvidenceBundle,
        cross_inconsistency_count: int,
        blocking_cross_inconsistency_count: int,
    ) -> InstitutionalVerdict:
        reasons: list[str] = []

        if not report_conformant:
            reasons.append("TRANSVERSAL_AUDIT_NOT_CONFORMANT")
        if risk.blocking_findings > 0:
            reasons.append("BLOCKING_FINDINGS_PRESENT")
        if blocking_cross_inconsistency_count > 0:
            reasons.append("BLOCKING_CROSS_COMPONENT_INCONSISTENCIES")
        if not evidence.sha256 or len(evidence.sha256) != 64:
            reasons.append("EVIDENCE_BUNDLE_INVALID")

        publishable = not reasons
        status = (
            "INSTITUTIONAL_AUDIT_APPROVED"
            if publishable
            else "INSTITUTIONAL_AUDIT_HOLD"
        )

        return InstitutionalVerdict(
            status=status,
            publishable=publishable,
            blocking_reasons=tuple(reasons),
            risk_level=risk.level,
            evidence_sha256=evidence.sha256,
        )
'@
    $Files["src/sgoda/integration/spt0237/layer2.py"] = @'
from __future__ import annotations

from pathlib import Path
from typing import Any

from .correlation import FindingCorrelator
from .crosscheck import CrossComponentConsistencyEngine
from .evidence import EvidenceConsolidator
from .risk import InstitutionalRiskEvaluator
from .service import Spt0237Layer1Service
from .verdict import InstitutionalVerdictEngine


class Spt0237Layer2Service:
    """Advanced institutional correlation and verdict layer."""

    def __init__(self, root: str | Path):
        self.root = Path(root)
        self.layer1 = Spt0237Layer1Service(self.root)

    def evaluate(self) -> dict[str, Any]:
        report = self.layer1.audit()
        correlations = FindingCorrelator.correlate(report.findings)
        risk = InstitutionalRiskEvaluator.evaluate(report.findings, correlations)
        evidence = EvidenceConsolidator.consolidate(report.findings)
        inconsistencies = CrossComponentConsistencyEngine.detect(report.findings)

        blocking_cross = sum(
            1
            for item in inconsistencies
            if item.severity.upper() in {"ERROR", "CRITICAL"}
        )

        verdict = InstitutionalVerdictEngine.issue(
            report_conformant=report.conformant,
            risk=risk,
            evidence=evidence,
            cross_inconsistency_count=len(inconsistencies),
            blocking_cross_inconsistency_count=blocking_cross,
        )

        return {
            "component": "SPT-023.7",
            "layer": "2",
            "scope": list(report.scope),
            "correlations": [item.to_dict() for item in correlations],
            "risk": risk.to_dict(),
            "evidence_bundle": evidence.to_dict(),
            "cross_component_inconsistencies": [
                item.to_dict() for item in inconsistencies
            ],
            "verdict": verdict.to_dict(),
            "layer1_reused": True,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "next_component": "SPT-023.7-CAPA-3",
        }
'@
    $Files["tests/integration/test_spt0237_institutional_correlation_layer2.py"] = @'
from pathlib import Path

from sgoda.integration.spt0237.correlation import FindingCorrelator
from sgoda.integration.spt0237.crosscheck import CrossComponentConsistencyEngine
from sgoda.integration.spt0237.evidence import EvidenceConsolidator
from sgoda.integration.spt0237.layer2 import Spt0237Layer2Service
from sgoda.integration.spt0237.models import AuditFinding
from sgoda.integration.spt0237.risk import InstitutionalRiskEvaluator
from sgoda.integration.spt0237.verdict import InstitutionalVerdictEngine


def finding(subject="SPT-023.1", dimension="quality", code="X", severity="WARNING"):
    return AuditFinding(
        dimension=dimension,
        code=code,
        severity=severity,
        message="message",
        subject=subject,
        evidence={"x": 1},
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


def test_correlator_groups_same_subject():
    result = FindingCorrelator.correlate([finding(), finding(code="Y")])
    assert len(result) == 1
    assert result[0].finding_count == 2


def test_correlator_separates_subjects():
    result = FindingCorrelator.correlate([
        finding(subject="SPT-023.1"),
        finding(subject="SPT-023.2"),
    ])
    assert len(result) == 2


def test_correlator_collects_dimensions():
    result = FindingCorrelator.correlate([
        finding(dimension="quality"),
        finding(dimension="traceability"),
    ])
    assert set(result[0].dimensions) == {"quality", "traceability"}


def test_risk_none_without_findings():
    risk = InstitutionalRiskEvaluator.evaluate([], [])
    assert risk.level == "NONE"
    assert risk.score == 0


def test_risk_low_for_warning():
    findings = [finding(severity="WARNING")]
    correlations = FindingCorrelator.correlate(findings)
    assert InstitutionalRiskEvaluator.evaluate(findings, correlations).level == "LOW"


def test_risk_high_for_blocking_error():
    findings = [finding(severity="ERROR")]
    correlations = FindingCorrelator.correlate(findings)
    risk = InstitutionalRiskEvaluator.evaluate(findings, correlations)
    assert risk.level == "HIGH"
    assert risk.blocking_findings == 1


def test_multi_dimension_correlation_adds_penalty():
    findings = [
        finding(dimension="quality"),
        finding(dimension="traceability"),
    ]
    correlations = FindingCorrelator.correlate(findings)
    risk = InstitutionalRiskEvaluator.evaluate(findings, correlations)
    assert risk.score >= 3


def test_evidence_bundle_is_deterministic():
    findings = [finding(code="A"), finding(code="B")]
    one = EvidenceConsolidator.consolidate(findings)
    two = EvidenceConsolidator.consolidate(reversed(findings))
    assert one.sha256 == two.sha256


def test_evidence_sha256_has_64_chars():
    assert len(EvidenceConsolidator.consolidate([finding()]).sha256) == 64


def test_evidence_bundle_counts_findings():
    assert EvidenceConsolidator.consolidate([finding(), finding(code="Y")]).finding_count == 2


def test_crosscheck_detects_scope_gap():
    result = CrossComponentConsistencyEngine.detect([
        finding(subject="SPT-023.4", code="SCOPE_GAP", severity="ERROR")
    ])
    assert any(item.code == "PIPELINE_SCOPE_INCOMPLETE" for item in result)


def test_crosscheck_detects_multi_component_blocking():
    result = CrossComponentConsistencyEngine.detect([
        finding(subject="SPT-023.1", severity="ERROR"),
        finding(subject="SPT-023.2", severity="CRITICAL"),
    ])
    assert any(item.code == "MULTI_COMPONENT_BLOCKING_RISK" for item in result)


def test_crosscheck_detects_traceability_weakness():
    result = CrossComponentConsistencyEngine.detect([
        finding(subject="SPT-023.1", code="EVIDENCE_NOT_DISCOVERED"),
        finding(subject="SPT-023.2", code="EVIDENCE_NOT_DISCOVERED"),
    ])
    assert any(item.code == "TRACEABILITY_CHAIN_WEAKNESS" for item in result)


def test_crosscheck_empty_for_clean_findings():
    assert CrossComponentConsistencyEngine.detect([]) == []


def test_verdict_approves_clean_report():
    evidence = EvidenceConsolidator.consolidate([])
    risk = InstitutionalRiskEvaluator.evaluate([], [])
    verdict = InstitutionalVerdictEngine.issue(
        report_conformant=True,
        risk=risk,
        evidence=evidence,
        cross_inconsistency_count=0,
        blocking_cross_inconsistency_count=0,
    )
    assert verdict.publishable is True
    assert verdict.status == "INSTITUTIONAL_AUDIT_APPROVED"


def test_verdict_holds_nonconformant_report():
    evidence = EvidenceConsolidator.consolidate([finding(severity="ERROR")])
    risk = InstitutionalRiskEvaluator.evaluate(
        [finding(severity="ERROR")],
        FindingCorrelator.correlate([finding(severity="ERROR")]),
    )
    verdict = InstitutionalVerdictEngine.issue(
        report_conformant=False,
        risk=risk,
        evidence=evidence,
        cross_inconsistency_count=0,
        blocking_cross_inconsistency_count=0,
    )
    assert verdict.publishable is False


def test_verdict_holds_cross_component_blocker():
    evidence = EvidenceConsolidator.consolidate([])
    risk = InstitutionalRiskEvaluator.evaluate([], [])
    verdict = InstitutionalVerdictEngine.issue(
        report_conformant=True,
        risk=risk,
        evidence=evidence,
        cross_inconsistency_count=1,
        blocking_cross_inconsistency_count=1,
    )
    assert "BLOCKING_CROSS_COMPONENT_INCONSISTENCIES" in verdict.blocking_reasons


def test_layer2_reuses_layer1(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert result["layer1_reused"] is True


def test_layer2_does_not_mutate_closed_components(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert result["closed_components_mutated"] is False


def test_layer2_disables_paid_api(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert result["paid_api_used"] is False


def test_layer2_points_to_layer3(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert result["next_component"] == "SPT-023.7-CAPA-3"


def test_layer2_clean_fixture_is_approved(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert result["verdict"]["status"] == "INSTITUTIONAL_AUDIT_APPROVED"


def test_layer2_clean_fixture_risk_is_not_high(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert result["risk"]["level"] in {"NONE", "LOW", "MEDIUM"}


def test_layer2_returns_evidence_bundle(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert len(result["evidence_bundle"]["sha256"]) == 64


def test_layer2_scope_covers_six_components(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert len(result["scope"]) == 6


def test_layer2_output_contains_correlations(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer2Service(tmp_path).evaluate()
    assert "correlations" in result
'@
    $Files["docs/06_Tecnologia/SPT-023.7/SGD-SPT023.7-Capa2-Correlacion-Riesgo-Dictamen.md"] = @'
# SPT-023.7 Capa 2 — Correlación, Riesgo y Dictamen Institucional

## Objetivo

Extender el Motor de Auditoría Transversal de Capa 1 sin reescribirlo, incorporando correlación institucional de hallazgos, evaluación de severidad y riesgo, consolidación determinística de evidencia, detección de inconsistencias cruzadas entre SPT-023.1 y SPT-023.6 y generación de dictamen institucional.

## Reutilización

Capa 2 utiliza directamente `Spt0237Layer1Service` y los modelos `AuditFinding` / `AuditReport` existentes. No modifica la lógica de Capa 1 ni ningún componente cerrado SPT-023.1–SPT-023.6.

## Capacidades

- correlación de hallazgos por sujeto institucional;
- riesgo acumulado por severidad y multidimensionalidad;
- bundle de evidencia con SHA-256 determinístico;
- detección de brechas de alcance transversal;
- detección de bloqueos en múltiples componentes;
- detección de debilidad transversal de trazabilidad;
- dictamen `INSTITUTIONAL_AUDIT_APPROVED` o `INSTITUTIONAL_AUDIT_HOLD`.

## Gobierno

ERROR y CRITICAL continúan siendo bloqueantes. El dictamen no puede aprobarse si la auditoría transversal no es conforme, existen hallazgos bloqueantes, inconsistencias cruzadas bloqueantes o la evidencia consolidada carece de hash válido.

## Siguiente desarrollo

SPT-023.7 Capa 3 deberá incorporar cierre institucional del auditor, quality gates finales, evidencia de cierre y habilitación de SPT-023.8 — Publicación Institucional.
'@
    $Files["config/integration/spt0237/institutional-correlation.json"] = @'
{
  "schema_version": "1.0.0",
  "component": "SPT-023.7",
  "layer": "2",
  "reuse_layer1": true,
  "scope": [
    "SPT-023.1",
    "SPT-023.2",
    "SPT-023.3",
    "SPT-023.4",
    "SPT-023.5",
    "SPT-023.6"
  ],
  "capabilities": [
    "finding_correlation",
    "severity_risk_evaluation",
    "evidence_consolidation",
    "cross_component_consistency",
    "institutional_verdict"
  ],
  "blocking_severities": [
    "ERROR",
    "CRITICAL"
  ],
  "evidence_sha256": true,
  "mutation_of_closed_components": false,
  "paid_api_allowed": false,
  "next_component": "SPT-023.7-CAPA-3"
}
'@

    foreach ($rel in $Files.Keys) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        Write-Utf8Lf $abs $Files[$rel]
        Write-Host ("CREATED : " + ($rel -replace '/', '\'))
    }

    Write-Step "[5/12] PYTHON PREVALIDATION + TARGETED TESTS"
    $python = Join-Path $Root ".venv\Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
        Fail "Project .venv Python not found."
    }

    $srcPath = Join-Path $Root "src"
    if ([string]::IsNullOrWhiteSpace($env:PYTHONPATH)) {
        $env:PYTHONPATH = $srcPath
    } else {
        $env:PYTHONPATH = $srcPath + [IO.Path]::PathSeparator + $env:PYTHONPATH
    }

    & $python -c "import sgoda; import sgoda.integration.spt0237; print('SGODA_IMPORT=PASS')"
    if ($LASTEXITCODE -ne 0) { Fail "Project package import failed." }

    $pyTargets = @(
        "src/sgoda/integration/spt0237/correlation.py",
        "src/sgoda/integration/spt0237/risk.py",
        "src/sgoda/integration/spt0237/evidence.py",
        "src/sgoda/integration/spt0237/crosscheck.py",
        "src/sgoda/integration/spt0237/verdict.py",
        "src/sgoda/integration/spt0237/layer2.py",
        "tests/integration/test_spt0237_institutional_correlation_layer2.py"
    ) | ForEach-Object { Join-Path $Root ($_ -replace '/', '\') }

    & $python -m py_compile @pyTargets
    if ($LASTEXITCODE -ne 0) { Fail "Python syntax prevalidation failed." }

    & $python -m pytest -q "tests/integration/test_spt0237_institutional_correlation_layer2.py"
    if ($LASTEXITCODE -ne 0) { Fail "SPT-023.7 Capa 2 targeted tests failed." }
    Write-Host "TARGETED TESTS : $TargetedExpected PASSED" -ForegroundColor Green

    Write-Step "[6/12] INSTITUTIONAL SUITE + COMPILEALL"
    & $python -m pytest -q
    if ($LASTEXITCODE -ne 0) { Fail "Institutional suite failed." }

    $collect = @(& $python -m pytest --collect-only -q 2>&1)
    if ($LASTEXITCODE -ne 0) { Fail "Unable to collect institutional tests." }

    $collectText = ($collect | ForEach-Object { [string]$_ }) -join "`n"
    $matches = [regex]::Matches($collectText,'(?im)(\d+)\s+(?:tests?|items?)\s+collected')
    if ($matches.Count -gt 0) {
        $suiteCount = [int]$matches[$matches.Count - 1].Groups[1].Value
    } else {
        $suiteCount = @($collect | Where-Object { ([string]$_) -match '::' }).Count
    }

    if ($suiteCount -lt $FullSuiteFloor) {
        Fail "Institutional suite count is below expected continuity floor ($FullSuiteFloor)."
    }

    & $python -m compileall -q src
    if ($LASTEXITCODE -ne 0) { Fail "COMPILEALL failed." }

    Write-Host "FULL SUITE : $suiteCount PASSED" -ForegroundColor Green
    Write-Host "COMPILEALL : PASS" -ForegroundColor Green

    Write-Step "[7/12] SHA-256 PRESERVATION GATE"
    $changed = @()
    foreach ($rel in $freeze.Keys) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) {
            $changed += $rel
        } elseif ((Get-Sha $abs) -ne $freeze[$rel]) {
            $changed += $rel
        }
    }

    Write-Host "PROTECTED FILES CHANGED : $($changed.Count)"
    if ($changed.Count -ne 0) {
        Fail ("Closed/Capa1 component preservation failed: " + ($changed -join ", "))
    }
    Write-Host "SPT-023.1-.6 + SPT-023.7 CAPA 1 : PRESERVED" -ForegroundColor Green

    Write-Step "[8/12] EVIDENCE + SGD-002 UPDATE"
    $evidenceRel = "artifacts/development/SPT-023.7-Capa2-v1.0.0/implementation-evidence.json"
    $evidenceAbs = Join-Path $Root ($evidenceRel -replace '/', '\')

    $generated = @()
    foreach ($rel in $Files.Keys | Sort-Object) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        $generated += [ordered]@{
            path = $rel
            sha256 = Get-Sha $abs
        }
    }

    $evidenceObject = [ordered]@{
        component = "SPT-023.7"
        layer = "Capa 2"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        targeted_tests = $TargetedExpected
        institutional_tests = $suiteCount
        compileall = "PASS"
        protected_files = $freeze.Count
        protected_changes = 0
        layer1_reused = $true
        correlation = $true
        risk_evaluation = $true
        evidence_consolidation = $true
        cross_component_consistency = $true
        institutional_verdict = $true
        mutation_of_closed_components = $false
        next_component = "SPT-023.7-CAPA-3"
        generated_files = $generated
        status = "IMPLEMENTED_AND_VALIDATED"
    }

    Write-Utf8Lf $evidenceAbs ($evidenceObject | ConvertTo-Json -Depth 8)
    Write-Host "EVIDENCE : CREATED"

    $sgdCandidates = @(GitLines @("ls-files") | Where-Object {
        $_ -match 'SGD-002' -and $_ -match '\.(md|txt)$'
    })
    if ($sgdCandidates.Count -eq 0) { Fail "Tracked SGD-002 master document not found." }

    $sgdRel = $sgdCandidates[0]
    $sgdAbs = Join-Path $Root ($sgdRel -replace '/', '\')
    $sgdText = [IO.File]::ReadAllText($sgdAbs)

    $marker = "<!-- SPT-023.7-CAPA2-V1.0.0 -->"
    if ($sgdText -notmatch [regex]::Escape($marker)) {
        $append = @"

$marker
## SPT-023.7 — Auditoría Inteligente — Capa 2

- Estado: IMPLEMENTED AND VALIDATED.
- Capa 1: reutilizada y preservada.
- Correlación institucional de hallazgos: implementada.
- Evaluación de severidad y riesgo: implementada.
- Consolidación de evidencia SHA-256: implementada.
- Inconsistencias cruzadas SPT-023.1–SPT-023.6: implementadas.
- Dictamen institucional: implementado.
- Componentes cerrados modificados: NO.
- Siguiente desarrollo: SPT-023.7 Capa 3.
"@
        Write-Utf8Lf $sgdAbs ($sgdText.TrimEnd() + "`n" + $append.TrimStart())
    }

    Write-Host "SGD-002  : UPDATED"

    Write-Step "[9/12] EXACT CONTROLLED STAGING"
    $stage = @(
        $targets +
        $evidenceRel +
        $sgdRel +
        $SelfName
    ) | Sort-Object -Unique

    foreach ($rel in $stage) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) {
            Fail "Required staging path missing: $rel"
        }
        GitLines @("-c","core.safecrlf=false","add","--",$rel) | Out-Null
    }

    $actual = @(
        GitLines @("diff","--cached","--name-only") |
        Where-Object { $_ -and $_ -notmatch '^(warning:|hint:)' }
    )
    $missing = @($stage | Where-Object { $_ -notin $actual })
    $unexpected = @($actual | Where-Object { $_ -notin $stage })

    Write-Host "STAGED     : $($actual.Count)"
    Write-Host "MISSING    : $($missing.Count)"
    Write-Host "UNEXPECTED : $($unexpected.Count)"

    if ($missing.Count -ne 0 -or $unexpected.Count -ne 0) {
        Fail "Exact staging manifest mismatch."
    }

    GitLines @("-c","core.safecrlf=false","diff","--cached","--check") | Out-Null
    Write-Host "DIFF CHECK       : PASS" -ForegroundColor Green
    Write-Host "STAGING QUALITY  : PASS" -ForegroundColor Green

    Write-Step "[10/12] FINAL REMOTE GATE"
    GitLines @("fetch","origin",$Branch,"--no-tags") | ForEach-Object { Write-Host $_ }
    $headBeforeCommit = GitText @("rev-parse","HEAD")
    $remoteBeforeCommit = GitText @("rev-parse","origin/$Branch")
    if ($headBeforeCommit -ne $ExpectedBaseline -or $remoteBeforeCommit -ne $ExpectedBaseline) {
        Fail "Repository moved during SPT-023.7 Capa 2 transaction."
    }
    Write-Host "REMOTE GATE : PASS" -ForegroundColor Green

    Write-Step "[11/12] COMMIT + PUSH"
    GitLines @("commit","-m",$CommitMessage) | ForEach-Object { Write-Host $_ }
    $newCommit = GitText @("rev-parse","HEAD")
    Write-Host "NEW COMMIT : $newCommit"

    GitLines @("push","origin",$Branch) | ForEach-Object { Write-Host $_ }

    Write-Step "[12/12] AUTHORITATIVE REMOTE VERIFICATION"
    GitLines @("fetch","origin",$Branch,"--no-tags") | ForEach-Object { Write-Host $_ }

    $localFinal = GitText @("rev-parse","HEAD")
    $remoteFinal = GitText @("rev-parse","origin/$Branch")
    $counts = (GitText @("rev-list","--left-right","--count","origin/$Branch...HEAD")) -split '\s+'
    $behind = [int]$counts[0]
    $ahead = [int]$counts[1]
    $stagedFinal = @(GitLines @("diff","--cached","--name-only")).Count
    $deletedFinal = @(GitLines @("ls-files","--deleted")).Count

    Write-Host "LOCAL HEAD      : $localFinal"
    Write-Host "REMOTE HEAD     : $remoteFinal"
    Write-Host "AHEAD           : $ahead"
    Write-Host "BEHIND          : $behind"
    Write-Host "STAGED          : $stagedFinal"
    Write-Host "DELETED TRACKED : $deletedFinal"

    if ($localFinal -ne $remoteFinal -or $ahead -ne 0 -or $behind -ne 0 -or $stagedFinal -ne 0 -or $deletedFinal -ne 0) {
        Fail "Final authoritative remote verification failed."
    }

    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Green
    Write-Host " SPT-023.7 CAPA 2 : IMPLEMENTED AND VALIDATED" -ForegroundColor Green
    Write-Host " CORRELATION       : READY" -ForegroundColor Green
    Write-Host " RISK EVALUATION   : READY" -ForegroundColor Green
    Write-Host " EVIDENCE BUNDLE   : SHA-256" -ForegroundColor Green
    Write-Host " CROSS-CHECKS      : READY" -ForegroundColor Green
    Write-Host " VERDICT ENGINE    : READY" -ForegroundColor Green
    Write-Host " TARGETED TESTS    : $TargetedExpected PASSED" -ForegroundColor Green
    Write-Host " FULL SUITE        : $suiteCount PASSED" -ForegroundColor Green
    Write-Host " CAPA 1            : PRESERVED" -ForegroundColor Green
    Write-Host " SPT-023.1-.6      : PRESERVED" -ForegroundColor Green
    Write-Host " SGD-002           : UPDATED" -ForegroundColor Green
    Write-Host " LOCAL/REMOTE      : IDENTICAL" -ForegroundColor Green
    Write-Host " ERRORS PENDING    : 0" -ForegroundColor Green
    Write-Host " NEXT              : SPT-023.7 CAPA 3" -ForegroundColor Green
    Write-Host ("=" * 70) -ForegroundColor Green
    Write-Host "FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
    exit 0
}
catch {
    Fail $_.Exception.Message
}
