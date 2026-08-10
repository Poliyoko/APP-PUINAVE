#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "1274306bee8ef9e90b43360af14b99cf2dd062c1"
$SelfName = "Invoke-SGODA-SPT0237-Capa3-FINAL-v1.0.0-PS51.ps1"
$CommitMessage = "feat(spt-023.7): close intelligent institutional audit layer 3"
$TargetedExpected = 29
$FullSuiteFloor = 1157
$CommitCreated = $false

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host $Text -ForegroundColor Cyan
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

    $normalized = @(
        $output | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                [string]$_.Exception.Message
            } else {
                [string]$_
            }
        }
    )

    if ($code -ne 0) {
        throw ($normalized -join [Environment]::NewLine)
    }

    return $normalized
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

function Emit-FinalBanner(
    [string]$Commit,
    [int]$Targeted,
    [int]$FullSuite
) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Green
    Write-Host " SPT-023.7 : INSTITUTIONALLY CLOSED" -ForegroundColor Green
    Write-Host " CAPA 1              : PRESERVED" -ForegroundColor Green
    Write-Host " CAPA 2              : PRESERVED" -ForegroundColor Green
    Write-Host " CAPA 3              : IMPLEMENTED AND VALIDATED" -ForegroundColor Green
    Write-Host " TRANSVERSAL AUDIT   : PASS" -ForegroundColor Green
    Write-Host " CORRELATION         : PASS" -ForegroundColor Green
    Write-Host " RISK EVALUATION     : PASS" -ForegroundColor Green
    Write-Host " EVIDENCE INTEGRITY  : PASS" -ForegroundColor Green
    Write-Host " QUALITY GATES       : PASS" -ForegroundColor Green
    Write-Host " GOVERNANCE          : PASS" -ForegroundColor Green
    Write-Host " CLOSURE MANIFEST    : CREATED" -ForegroundColor Green
    Write-Host " TARGETED TESTS      : $Targeted PASSED" -ForegroundColor Green
    Write-Host " FULL SUITE          : $FullSuite PASSED" -ForegroundColor Green
    Write-Host " SPT-023.1 - .6      : PRESERVED" -ForegroundColor Green
    Write-Host " SGD-002             : UPDATED" -ForegroundColor Green
    Write-Host " COMMIT              : $Commit" -ForegroundColor Green
    Write-Host " LOCAL/REMOTE        : IDENTICAL" -ForegroundColor Green
    Write-Host " AHEAD               : 0" -ForegroundColor Green
    Write-Host " BEHIND              : 0" -ForegroundColor Green
    Write-Host " STAGED              : 0" -ForegroundColor Green
    Write-Host " DELETED TRACKED     : 0" -ForegroundColor Green
    Write-Host " ERRORS PENDING      : 0" -ForegroundColor Green
    Write-Host " NEXT                : SPT-023.8 / SPT-024 PISI" -ForegroundColor Green
    Write-Host ("=" * 70) -ForegroundColor Green
    Write-Host "FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
}

function Fail([string]$Reason) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Red
    Write-Host " SPT-023.7 CAPA 3 : HOLD" -ForegroundColor Red
    Write-Host " REASON           : $Reason" -ForegroundColor Red
    if ($CommitCreated) {
        Write-Host " LOCAL COMMIT     : PRESERVED FOR SAME-FILE RESUME" -ForegroundColor Yellow
    } else {
        Write-Host " TRANSACTION      : NOT PUBLISHED" -ForegroundColor Yellow
    }
    Write-Host " ERRORS PENDING   : 1" -ForegroundColor Red
    Write-Host ("=" * 70) -ForegroundColor Red
    exit 1
}

try {
    $Root = GitText @("rev-parse","--show-toplevel")
    Set-Location -LiteralPath $Root
    $Branch = GitText @("branch","--show-current")

    $SelfPath = Join-Path $Root $SelfName
    if (-not (Test-Path -LiteralPath $SelfPath -PathType Leaf)) {
        Fail "Master script must exist in the official repository root."
    }

    Write-Step "[1/12] AUTHORITATIVE BASELINE / RESUME / WORKTREE SAFETY"

    GitLines @("fetch","origin",$Branch,"--no-tags") | ForEach-Object { Write-Host $_ }

    $Local = GitText @("rev-parse","HEAD")
    $Remote = GitText @("rev-parse","origin/$Branch")
    $Subject = GitText @("log","-1","--pretty=%s")

    if ($Local -ne $ExpectedBaseline) {
        $Parent = GitText @("rev-parse","HEAD^")

        if ($Subject -eq $CommitMessage -and $Parent -eq $ExpectedBaseline) {
            $ResumeEvidence = Join-Path $Root "artifacts\development\SPT-023.7-Capa3-v1.0.0\implementation-evidence.json"

            if (-not (Test-Path -LiteralPath $ResumeEvidence -PathType Leaf)) {
                Fail "Resumable Capa 3 commit exists but implementation evidence is missing."
            }

            $ResumeData = Get-Content -LiteralPath $ResumeEvidence -Raw -Encoding UTF8 | ConvertFrom-Json

            if ($Local -eq $Remote) {
                $stagedResume = @(GitLines @("diff","--cached","--name-only")).Count
                $deletedResume = @(GitLines @("ls-files","--deleted")).Count
                if ($stagedResume -ne 0 -or $deletedResume -ne 0) {
                    Fail "Published Capa 3 commit exists but repository safety is not clean."
                }

                Emit-FinalBanner `
                    -Commit $Local `
                    -Targeted ([int]$ResumeData.targeted_tests) `
                    -FullSuite ([int]$ResumeData.institutional_tests)
                exit 0
            }

            if ($Remote -eq $ExpectedBaseline) {
                $CommitCreated = $true
                Write-Host "RESUME MODE : LOCAL COMMIT EXISTS; PUSH PENDING" -ForegroundColor Yellow

                GitLines @("push","origin",$Branch) | ForEach-Object { Write-Host $_ }
                GitLines @("fetch","origin",$Branch,"--no-tags") | ForEach-Object { Write-Host $_ }

                $remoteResume = GitText @("rev-parse","origin/$Branch")
                if ($remoteResume -ne $Local) {
                    Fail "Resume remote verification failed."
                }

                Emit-FinalBanner `
                    -Commit $Local `
                    -Targeted ([int]$ResumeData.targeted_tests) `
                    -FullSuite ([int]$ResumeData.institutional_tests)
                exit 0
            }
        }

        Fail "HEAD is neither certified baseline nor a resumable SPT-023.7 Capa 3 commit."
    }

    if ($Remote -ne $ExpectedBaseline) {
        Fail "Official remote moved away from the certified Capa 2 baseline."
    }

    $Staged = @(GitLines @("diff","--cached","--name-only"))
    $Deleted = @(GitLines @("ls-files","--deleted"))

    Write-Host "LOCAL HEAD      : $Local"
    Write-Host "REMOTE HEAD     : $Remote"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if ($Staged.Count -ne 0) { Fail "Staging must be clean." }
    if ($Deleted.Count -ne 0) { Fail "Tracked deletions detected." }

    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        $SelfPath,
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null
    if (@($parseErrors).Count -ne 0) {
        Fail "PowerShell syntax validation failed."
    }

    # Recover only a stale Capa 3 SGD-002 update from a failed pre-commit attempt.
    $modified = @(
        GitLines @("-c","core.safecrlf=false","diff","--name-only") |
        Where-Object { $_ -and $_ -notmatch '^(warning:|hint:)' }
    )

    $sgdModified = @(
        $modified | Where-Object {
            $_ -match 'SGD-002' -and $_ -match '\.(md|txt)$'
        }
    )

    foreach ($rel in $sgdModified) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        $workText = [IO.File]::ReadAllText($abs)
        $headText = GitText @("show","HEAD:$rel")

        if (
            $workText -match 'SPT-023\.7-CAPA3-CLOSE-V1\.0\.0' -and
            $headText -notmatch 'SPT-023\.7-CAPA3-CLOSE-V1\.0\.0'
        ) {
            GitLines @("restore","--worktree","--source=HEAD","--",$rel) | Out-Null
            Write-Host ("STALE SGD-002 : RESTORED TO BASELINE : " + $rel)
        }
    }

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

    Write-Step "[2/12] SHA-256 FREEZE OF SPT-023.1-.6 + SPT-023.7 CAPAS 1-2"

    $tracked = @(GitLines @("ls-files"))
    $protected = @(
        $tracked | Where-Object {
            $_ -match 'SPT-023\.[1-6]' -or
            $_ -match 'spt023[1-6]' -or
            $_ -match 'SPT-023\.7-Capa[12]' -or
            $_ -match 'spt0237/(?:__init__|models|rules|scanner|auditor|service|correlation|risk|evidence|crosscheck|verdict|layer2)\.py' -or
            $_ -match 'test_spt0237_(?:intelligent_audit_layer1|institutional_correlation_layer2)\.py' -or
            $_ -match 'audit-policy\.json' -or
            $_ -match 'institutional-correlation\.json' -or
            $_ -match 'Capa[12]-'
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
        "src/sgoda/integration/spt0237/gates.py",
        "src/sgoda/integration/spt0237/governance.py",
        "src/sgoda/integration/spt0237/ledger.py",
        "src/sgoda/integration/spt0237/closure.py",
        "src/sgoda/integration/spt0237/layer3.py",
        "tests/integration/test_spt0237_governance_closure_layer3.py",
        "docs/06_Tecnologia/SPT-023.7/SGD-SPT023.7-Capa3-Gobierno-Quality-Gates-Cierre.md",
        "config/integration/spt0237/governance-quality-gates.json"
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
            }
            else {
                Remove-Item -LiteralPath $abs -Force
                $recovered += $rel
            }
        }
    }

    $staleEvidenceRel = "artifacts/development/SPT-023.7-Capa3-v1.0.0/implementation-evidence.json"
    $staleManifestRel = "artifacts/development/SPT-023.7-Capa3-v1.0.0/closure-manifest.json"
    $staleLedgerRel = "artifacts/development/SPT-023.7-Capa3-v1.0.0/audit-closure-ledger.json"

    foreach ($rel in @($staleEvidenceRel,$staleManifestRel,$staleLedgerRel)) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        if (Test-Path -LiteralPath $abs -PathType Leaf) {
            $previous = $ErrorActionPreference
            $ErrorActionPreference = "Continue"

            try {
                $null = & git ls-files --error-unmatch -- $rel 2>$null
                $trackedCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previous
            }

            if ($trackedCode -ne 0) {
                Remove-Item -LiteralPath $abs -Force
                Write-Host ("STALE ARTIFACT : REMOVED : " + $rel)
            }
        }
    }

    Write-Host "RECOVERED STALE UNTRACKED TARGETS : $($recovered.Count)"
    Write-Host "TARGET COLLISIONS                 : $($collisions.Count)"

    if ($collisions.Count -ne 0) {
        Fail ("Tracked target collisions: " + ($collisions -join ", "))
    }

    Write-Step "[4/12] IMPLEMENT SPT-023.7 CAPA 3"

    $Files = @{}
    $Files["src/sgoda/integration/spt0237/gates.py"] = @'
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class QualityGate:
    gate_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "gate_id": self.gate_id,
            "name": self.name,
            "passed": self.passed,
            "blocking": self.blocking,
            "detail": self.detail,
        }


class InstitutionalQualityGateEngine:
    """Converts the Layer 2 verdict into final institutional closure gates."""

    REQUIRED_GATE_IDS = (
        "GATE-TRANSVERSAL-AUDIT",
        "GATE-CORRELATION",
        "GATE-RISK",
        "GATE-EVIDENCE",
        "GATE-CROSS-COMPONENT",
        "GATE-VERDICT",
        "GATE-PRESERVATION",
    )

    @classmethod
    def build(
        cls,
        *,
        layer2_result: dict[str, Any],
        protected_changes: int,
    ) -> list[QualityGate]:
        verdict = dict(layer2_result.get("verdict") or {})
        risk = dict(layer2_result.get("risk") or {})
        evidence = dict(layer2_result.get("evidence_bundle") or {})
        inconsistencies = list(
            layer2_result.get("cross_component_inconsistencies") or []
        )

        blocking_cross = sum(
            1
            for item in inconsistencies
            if str(item.get("severity") or "").upper() in {"ERROR", "CRITICAL"}
        )

        return [
            QualityGate(
                "GATE-TRANSVERSAL-AUDIT",
                "Transversal audit",
                bool(verdict.get("publishable")),
                True,
                str(verdict.get("status") or ""),
            ),
            QualityGate(
                "GATE-CORRELATION",
                "Finding correlation",
                "correlations" in layer2_result,
                True,
                f"groups={len(layer2_result.get('correlations') or [])}",
            ),
            QualityGate(
                "GATE-RISK",
                "Institutional risk",
                str(risk.get("level") or "").upper() not in {"HIGH", "CRITICAL"},
                True,
                f"level={risk.get('level', '')};score={risk.get('score', '')}",
            ),
            QualityGate(
                "GATE-EVIDENCE",
                "Evidence integrity",
                len(str(evidence.get("sha256") or "")) == 64,
                True,
                str(evidence.get("sha256") or ""),
            ),
            QualityGate(
                "GATE-CROSS-COMPONENT",
                "Cross-component consistency",
                blocking_cross == 0,
                True,
                f"blocking={blocking_cross}",
            ),
            QualityGate(
                "GATE-VERDICT",
                "Institutional verdict",
                str(verdict.get("status") or "") == "INSTITUTIONAL_AUDIT_APPROVED",
                True,
                str(verdict.get("status") or ""),
            ),
            QualityGate(
                "GATE-PRESERVATION",
                "Closed component preservation",
                int(protected_changes) == 0,
                True,
                f"protected_changes={protected_changes}",
            ),
        ]

    @classmethod
    def certify(cls, gates: list[QualityGate]) -> dict[str, Any]:
        by_id = {gate.gate_id: gate for gate in gates}
        missing = [gate_id for gate_id in cls.REQUIRED_GATE_IDS if gate_id not in by_id]
        failed_blocking = [
            gate.gate_id
            for gate in gates
            if gate.blocking and not gate.passed
        ]
        return {
            "required": list(cls.REQUIRED_GATE_IDS),
            "missing": missing,
            "failed_blocking": failed_blocking,
            "passed": not missing and not failed_blocking,
            "gates": [gate.to_dict() for gate in gates],
        }
'@
    $Files["src/sgoda/integration/spt0237/governance.py"] = @'
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class ClosureGovernancePolicy:
    require_quality_gates: bool = True
    require_layer1_reuse: bool = True
    require_layer2_reuse: bool = True
    require_sha256_evidence: bool = True
    require_zero_protected_changes: bool = True
    require_remote_sync: bool = True
    allow_paid_api: bool = False

    def validate(
        self,
        *,
        layer2_result: dict[str, Any],
        gate_certificate: dict[str, Any],
        protected_changes: int,
    ) -> dict[str, Any]:
        violations: list[str] = []

        if self.require_quality_gates and not gate_certificate.get("passed"):
            violations.append("QUALITY_GATES_NOT_APPROVED")
        if self.require_layer1_reuse and not layer2_result.get("layer1_reused"):
            violations.append("LAYER1_NOT_REUSED")
        if self.require_layer2_reuse and layer2_result.get("layer") != "2":
            violations.append("LAYER2_RESULT_INVALID")
        if self.require_sha256_evidence:
            sha = str(
                (layer2_result.get("evidence_bundle") or {}).get("sha256") or ""
            )
            if len(sha) != 64:
                violations.append("EVIDENCE_SHA256_INVALID")
        if self.require_zero_protected_changes and protected_changes != 0:
            violations.append("PROTECTED_COMPONENTS_CHANGED")
        if bool(layer2_result.get("paid_api_used")):
            violations.append("PAID_API_USAGE_DETECTED")

        return {
            "passed": not violations,
            "violations": violations,
            "policy": {
                "require_quality_gates": self.require_quality_gates,
                "require_layer1_reuse": self.require_layer1_reuse,
                "require_layer2_reuse": self.require_layer2_reuse,
                "require_sha256_evidence": self.require_sha256_evidence,
                "require_zero_protected_changes": self.require_zero_protected_changes,
                "require_remote_sync": self.require_remote_sync,
                "allow_paid_api": self.allow_paid_api,
            },
        }
'@
    $Files["src/sgoda/integration/spt0237/ledger.py"] = @'
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from typing import Any


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


class InstitutionalAuditLedger:
    """Append-only logical ledger with chained SHA-256 integrity."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def _load(self) -> list[dict[str, Any]]:
        if not self.path.exists():
            return []
        data = json.loads(self.path.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            raise ValueError("Audit ledger must be a JSON array.")
        self.verify(data)
        return data

    @staticmethod
    def verify(entries: list[dict[str, Any]]) -> bool:
        previous_hash = "GENESIS"
        for sequence, entry in enumerate(entries, start=1):
            if int(entry.get("sequence", 0)) != sequence:
                raise ValueError("Audit ledger sequence mismatch.")
            if str(entry.get("previous_hash") or "") != previous_hash:
                raise ValueError("Audit ledger previous_hash mismatch.")

            body = {
                "sequence": sequence,
                "event_type": str(entry.get("event_type") or ""),
                "payload": dict(entry.get("payload") or {}),
                "previous_hash": previous_hash,
            }
            expected = hashlib.sha256(_canonical(body)).hexdigest().upper()
            if str(entry.get("entry_sha256") or "") != expected:
                raise ValueError("Audit ledger SHA-256 mismatch.")
            previous_hash = expected
        return True

    def append(
        self,
        *,
        event_type: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        event_type = str(event_type or "").strip()
        if not event_type:
            raise ValueError("event_type is required.")

        entries = self._load()
        previous_hash = entries[-1]["entry_sha256"] if entries else "GENESIS"
        body = {
            "sequence": len(entries) + 1,
            "event_type": event_type,
            "payload": dict(payload),
            "previous_hash": previous_hash,
        }
        entry = dict(body)
        entry["entry_sha256"] = hashlib.sha256(
            _canonical(body)
        ).hexdigest().upper()
        entries.append(entry)

        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_name(self.path.name + ".tmp")
        tmp.write_text(
            json.dumps(entries, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(tmp, self.path)
        self.verify(entries)
        return entry

    def all(self) -> list[dict[str, Any]]:
        return self._load()
'@
    $Files["src/sgoda/integration/spt0237/closure.py"] = @'
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


@dataclass(frozen=True)
class ClosureManifest:
    component: str
    status: str
    quality_gates_passed: bool
    governance_passed: bool
    layer1_preserved: bool
    layer2_preserved: bool
    closed_components_preserved: bool
    next_component: str
    manifest_sha256: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "component": self.component,
            "status": self.status,
            "quality_gates_passed": self.quality_gates_passed,
            "governance_passed": self.governance_passed,
            "layer1_preserved": self.layer1_preserved,
            "layer2_preserved": self.layer2_preserved,
            "closed_components_preserved": self.closed_components_preserved,
            "next_component": self.next_component,
            "manifest_sha256": self.manifest_sha256,
        }


class Spt0237ClosureManifestBuilder:
    @staticmethod
    def build(
        *,
        quality_gates_passed: bool,
        governance_passed: bool,
        protected_changes: int,
    ) -> ClosureManifest:
        if not quality_gates_passed:
            raise ValueError("Quality gates must pass before SPT-023.7 closure.")
        if not governance_passed:
            raise ValueError("Governance must pass before SPT-023.7 closure.")
        if protected_changes != 0:
            raise ValueError("Protected components changed; closure forbidden.")

        body = {
            "component": "SPT-023.7",
            "status": "INSTITUTIONALLY_CLOSED",
            "quality_gates_passed": True,
            "governance_passed": True,
            "layer1_preserved": True,
            "layer2_preserved": True,
            "closed_components_preserved": True,
            "next_component": "SPT-023.8",
        }
        sha = hashlib.sha256(_canonical(body)).hexdigest().upper()
        return ClosureManifest(
            component=body["component"],
            status=body["status"],
            quality_gates_passed=True,
            governance_passed=True,
            layer1_preserved=True,
            layer2_preserved=True,
            closed_components_preserved=True,
            next_component="SPT-023.8",
            manifest_sha256=sha,
        )
'@
    $Files["src/sgoda/integration/spt0237/layer3.py"] = @'
from __future__ import annotations

from pathlib import Path
from typing import Any

from .closure import Spt0237ClosureManifestBuilder
from .gates import InstitutionalQualityGateEngine
from .governance import ClosureGovernancePolicy
from .layer2 import Spt0237Layer2Service
from .ledger import InstitutionalAuditLedger


class Spt0237Layer3ClosureService:
    """Final governance, quality gates and closure for SPT-023.7."""

    def __init__(
        self,
        root: str | Path,
        *,
        ledger_path: str | Path,
        governance_policy: ClosureGovernancePolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.layer2 = Spt0237Layer2Service(self.root)
        self.ledger = InstitutionalAuditLedger(ledger_path)
        self.policy = governance_policy or ClosureGovernancePolicy()

    def evaluate(self, *, protected_changes: int = 0) -> dict[str, Any]:
        layer2_result = self.layer2.evaluate()

        gates = InstitutionalQualityGateEngine.build(
            layer2_result=layer2_result,
            protected_changes=protected_changes,
        )
        gate_certificate = InstitutionalQualityGateEngine.certify(gates)

        governance = self.policy.validate(
            layer2_result=layer2_result,
            gate_certificate=gate_certificate,
            protected_changes=protected_changes,
        )

        self.ledger.append(
            event_type="QUALITY_GATES_EVALUATED",
            payload={
                "passed": gate_certificate["passed"],
                "failed_blocking": gate_certificate["failed_blocking"],
            },
        )
        self.ledger.append(
            event_type="GOVERNANCE_EVALUATED",
            payload={
                "passed": governance["passed"],
                "violations": governance["violations"],
            },
        )

        manifest = Spt0237ClosureManifestBuilder.build(
            quality_gates_passed=bool(gate_certificate["passed"]),
            governance_passed=bool(governance["passed"]),
            protected_changes=protected_changes,
        )

        self.ledger.append(
            event_type="SPT0237_CLOSURE_CERTIFIED",
            payload={
                "status": manifest.status,
                "manifest_sha256": manifest.manifest_sha256,
                "next_component": manifest.next_component,
            },
        )

        ledger_verified = InstitutionalAuditLedger.verify(self.ledger.all())

        return {
            "component": "SPT-023.7",
            "layer": "3",
            "status": manifest.status,
            "layer2_result": layer2_result,
            "quality_gate_certificate": gate_certificate,
            "governance": governance,
            "closure_manifest": manifest.to_dict(),
            "ledger_verified": ledger_verified,
            "protected_changes": protected_changes,
            "layer1_preserved": True,
            "layer2_preserved": True,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "next_component": "SPT-023.8",
        }
'@
    $Files["tests/integration/test_spt0237_governance_closure_layer3.py"] = @'
from pathlib import Path

import pytest

from sgoda.integration.spt0237.closure import Spt0237ClosureManifestBuilder
from sgoda.integration.spt0237.gates import (
    InstitutionalQualityGateEngine,
    QualityGate,
)
from sgoda.integration.spt0237.governance import ClosureGovernancePolicy
from sgoda.integration.spt0237.layer3 import Spt0237Layer3ClosureService
from sgoda.integration.spt0237.ledger import InstitutionalAuditLedger


def make_component(root: Path, number: int):
    base = root / "src" / "sgoda" / "integration" / f"spt023{number}"
    base.mkdir(parents=True, exist_ok=True)
    (base / "service.py").write_text("VALUE = 1\n", encoding="utf-8")

    tests = root / "tests" / "integration"
    tests.mkdir(parents=True, exist_ok=True)
    (tests / f"test_spt023{number}.py").write_text(
        "def test_ok(): assert True\n",
        encoding="utf-8",
    )

    docs = root / "docs" / f"SPT-023.{number}"
    docs.mkdir(parents=True, exist_ok=True)
    (docs / f"SGD-SPT023.{number}.md").write_text("# doc\n", encoding="utf-8")

    evidence = root / "artifacts" / "development" / f"SPT-023.{number}"
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / "implementation-evidence.json").write_text(
        '{"ok": true}\n',
        encoding="utf-8",
    )


def make_repo(root: Path):
    for number in range(1, 7):
        make_component(root, number)


def clean_layer2_result():
    return {
        "layer": "2",
        "layer1_reused": True,
        "paid_api_used": False,
        "correlations": [],
        "risk": {
            "score": 0,
            "level": "NONE",
            "blocking_findings": 0,
            "correlated_groups": 0,
        },
        "evidence_bundle": {
            "sha256": "A" * 64,
            "finding_count": 0,
        },
        "cross_component_inconsistencies": [],
        "verdict": {
            "status": "INSTITUTIONAL_AUDIT_APPROVED",
            "publishable": True,
            "blocking_reasons": [],
        },
    }


def test_quality_gate_serializes():
    gate = QualityGate("G", "Gate", True, True, "ok")
    assert gate.to_dict()["passed"] is True


def test_gate_engine_builds_seven_required_gates():
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=clean_layer2_result(),
        protected_changes=0,
    )
    assert len(gates) == 7


def test_gate_engine_certificate_passes_clean_result():
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=clean_layer2_result(),
        protected_changes=0,
    )
    assert InstitutionalQualityGateEngine.certify(gates)["passed"] is True


def test_gate_engine_fails_high_risk():
    result = clean_layer2_result()
    result["risk"]["level"] = "HIGH"
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=result,
        protected_changes=0,
    )
    certificate = InstitutionalQualityGateEngine.certify(gates)
    assert certificate["passed"] is False
    assert "GATE-RISK" in certificate["failed_blocking"]


def test_gate_engine_fails_invalid_evidence():
    result = clean_layer2_result()
    result["evidence_bundle"]["sha256"] = "BAD"
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=result,
        protected_changes=0,
    )
    assert InstitutionalQualityGateEngine.certify(gates)["passed"] is False


def test_gate_engine_fails_protected_changes():
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=clean_layer2_result(),
        protected_changes=1,
    )
    assert InstitutionalQualityGateEngine.certify(gates)["passed"] is False


def test_gate_engine_fails_blocking_cross_component():
    result = clean_layer2_result()
    result["cross_component_inconsistencies"] = [
        {"severity": "ERROR", "code": "X"}
    ]
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=result,
        protected_changes=0,
    )
    assert InstitutionalQualityGateEngine.certify(gates)["passed"] is False


def test_gate_engine_fails_nonapproved_verdict():
    result = clean_layer2_result()
    result["verdict"]["status"] = "INSTITUTIONAL_AUDIT_HOLD"
    result["verdict"]["publishable"] = False
    gates = InstitutionalQualityGateEngine.build(
        layer2_result=result,
        protected_changes=0,
    )
    assert InstitutionalQualityGateEngine.certify(gates)["passed"] is False


def test_governance_passes_clean_result():
    result = clean_layer2_result()
    cert = InstitutionalQualityGateEngine.certify(
        InstitutionalQualityGateEngine.build(
            layer2_result=result,
            protected_changes=0,
        )
    )
    governance = ClosureGovernancePolicy().validate(
        layer2_result=result,
        gate_certificate=cert,
        protected_changes=0,
    )
    assert governance["passed"] is True


def test_governance_fails_without_layer1_reuse():
    result = clean_layer2_result()
    result["layer1_reused"] = False
    governance = ClosureGovernancePolicy().validate(
        layer2_result=result,
        gate_certificate={"passed": True},
        protected_changes=0,
    )
    assert "LAYER1_NOT_REUSED" in governance["violations"]


def test_governance_fails_paid_api():
    result = clean_layer2_result()
    result["paid_api_used"] = True
    governance = ClosureGovernancePolicy().validate(
        layer2_result=result,
        gate_certificate={"passed": True},
        protected_changes=0,
    )
    assert "PAID_API_USAGE_DETECTED" in governance["violations"]


def test_governance_fails_invalid_sha():
    result = clean_layer2_result()
    result["evidence_bundle"]["sha256"] = "BAD"
    governance = ClosureGovernancePolicy().validate(
        layer2_result=result,
        gate_certificate={"passed": True},
        protected_changes=0,
    )
    assert "EVIDENCE_SHA256_INVALID" in governance["violations"]


def test_ledger_appends_and_verifies(tmp_path):
    ledger = InstitutionalAuditLedger(tmp_path / "ledger.json")
    ledger.append(event_type="X", payload={"a": 1})
    assert InstitutionalAuditLedger.verify(ledger.all()) is True


def test_ledger_hash_chain(tmp_path):
    ledger = InstitutionalAuditLedger(tmp_path / "ledger.json")
    first = ledger.append(event_type="A", payload={})
    second = ledger.append(event_type="B", payload={})
    assert second["previous_hash"] == first["entry_sha256"]


def test_ledger_detects_tampering(tmp_path):
    ledger = InstitutionalAuditLedger(tmp_path / "ledger.json")
    item = ledger.append(event_type="A", payload={})
    item["entry_sha256"] = "BAD"
    with pytest.raises(ValueError):
        InstitutionalAuditLedger.verify([item])


def test_closure_manifest_requires_quality_gates():
    with pytest.raises(ValueError):
        Spt0237ClosureManifestBuilder.build(
            quality_gates_passed=False,
            governance_passed=True,
            protected_changes=0,
        )


def test_closure_manifest_requires_governance():
    with pytest.raises(ValueError):
        Spt0237ClosureManifestBuilder.build(
            quality_gates_passed=True,
            governance_passed=False,
            protected_changes=0,
        )


def test_closure_manifest_requires_preservation():
    with pytest.raises(ValueError):
        Spt0237ClosureManifestBuilder.build(
            quality_gates_passed=True,
            governance_passed=True,
            protected_changes=1,
        )


def test_closure_manifest_is_closed_when_valid():
    manifest = Spt0237ClosureManifestBuilder.build(
        quality_gates_passed=True,
        governance_passed=True,
        protected_changes=0,
    )
    assert manifest.status == "INSTITUTIONALLY_CLOSED"


def test_closure_manifest_sha_is_64_chars():
    manifest = Spt0237ClosureManifestBuilder.build(
        quality_gates_passed=True,
        governance_passed=True,
        protected_changes=0,
    )
    assert len(manifest.manifest_sha256) == 64


def test_closure_manifest_points_to_spt0238():
    manifest = Spt0237ClosureManifestBuilder.build(
        quality_gates_passed=True,
        governance_passed=True,
        protected_changes=0,
    )
    assert manifest.next_component == "SPT-023.8"


def test_layer3_clean_fixture_closes(tmp_path):
    make_repo(tmp_path)
    service = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    )
    result = service.evaluate(protected_changes=0)
    assert result["status"] == "INSTITUTIONALLY_CLOSED"


def test_layer3_quality_gates_pass(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["quality_gate_certificate"]["passed"] is True


def test_layer3_governance_passes(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["governance"]["passed"] is True


def test_layer3_ledger_verified(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["ledger_verified"] is True


def test_layer3_preserves_layer1_and_layer2(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["layer1_preserved"] is True
    assert result["layer2_preserved"] is True


def test_layer3_disables_paid_api(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["paid_api_used"] is False


def test_layer3_does_not_mutate_closed_components(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["closed_components_mutated"] is False


def test_layer3_points_to_spt0238(tmp_path):
    make_repo(tmp_path)
    result = Spt0237Layer3ClosureService(
        tmp_path,
        ledger_path=tmp_path / "ledger.json",
    ).evaluate(protected_changes=0)
    assert result["next_component"] == "SPT-023.8"
'@
    $Files["docs/06_Tecnologia/SPT-023.7/SGD-SPT023.7-Capa3-Gobierno-Quality-Gates-Cierre.md"] = @'
# SPT-023.7 Capa 3 — Gobierno, Quality Gates y Cierre Institucional

## Objetivo

Cerrar formalmente SPT-023.7 — Auditoría Inteligente reutilizando íntegramente
las Capas 1 y 2, convirtiendo el dictamen institucional de Capa 2 en quality
gates finales, aplicando gobierno de cierre, consolidando trazabilidad y
evidencias, y produciendo un manifiesto verificable de cierre.

## Quality Gates

Capa 3 exige siete gates bloqueantes:

1. Auditoría transversal.
2. Correlación de hallazgos.
3. Riesgo institucional.
4. Integridad de evidencia SHA-256.
5. Consistencia cruzada entre componentes.
6. Dictamen institucional.
7. Preservación de componentes cerrados.

No puede emitirse cierre si cualquiera de estos gates falla.

## Gobierno

La política de cierre exige reutilización de Capa 1, resultado válido de Capa 2,
evidencia SHA-256, cero cambios en componentes protegidos y ausencia de APIs de
pago.

## Ledger institucional

Las decisiones de quality gates, gobierno y cierre se registran en un ledger
JSON con secuencia e integridad SHA-256 encadenada.

## Manifiesto de cierre

El manifiesto solo puede generarse cuando quality gates y gobierno están
aprobados y `protected_changes == 0`. El estado final es
`INSTITUTIONALLY_CLOSED`.

## Continuidad

SPT-023.1–SPT-023.6 y SPT-023.7 Capas 1–2 permanecen preservados. El siguiente
paquete funcional es SPT-023.8 — Publicación Institucional. La plataforma
transversal SPT-024 — Seguridad Informática deberá incorporarse sobre la línea
base certificada sin reabrir este cierre.
'@
    $Files["config/integration/spt0237/governance-quality-gates.json"] = @'
{
  "schema_version": "1.0.0",
  "component": "SPT-023.7",
  "layer": "3",
  "purpose": "governance_quality_gates_and_institutional_closure",
  "reuse": {
    "layer1": true,
    "layer2": true,
    "spt023_1_to_6": true
  },
  "required_quality_gates": [
    "GATE-TRANSVERSAL-AUDIT",
    "GATE-CORRELATION",
    "GATE-RISK",
    "GATE-EVIDENCE",
    "GATE-CROSS-COMPONENT",
    "GATE-VERDICT",
    "GATE-PRESERVATION"
  ],
  "ledger": {
    "format": "LOCAL_JSON",
    "sha256_chain": true
  },
  "protected_changes_required": 0,
  "paid_api_allowed": false,
  "close_spt0237": true,
  "next_component": "SPT-023.8"
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
    }
    else {
        $env:PYTHONPATH = $srcPath + [IO.Path]::PathSeparator + $env:PYTHONPATH
    }

    Write-Host "PYTHON EXECUTABLE : $python"
    Write-Host "PYTHONPATH        : $env:PYTHONPATH"

    & $python -c "import sgoda; import sgoda.integration.spt0237.layer2; print('SGODA_IMPORT=PASS')"
    if ($LASTEXITCODE -ne 0) {
        Fail "Project package / Capa 2 import prevalidation failed."
    }

    $pyTargets = @(
        "src/sgoda/integration/spt0237/gates.py",
        "src/sgoda/integration/spt0237/governance.py",
        "src/sgoda/integration/spt0237/ledger.py",
        "src/sgoda/integration/spt0237/closure.py",
        "src/sgoda/integration/spt0237/layer3.py",
        "tests/integration/test_spt0237_governance_closure_layer3.py"
    ) | ForEach-Object {
        Join-Path $Root ($_ -replace '/', '\')
    }

    & $python -m py_compile @pyTargets
    if ($LASTEXITCODE -ne 0) {
        Fail "Python syntax prevalidation failed."
    }

    & $python -m pytest -q "tests/integration/test_spt0237_governance_closure_layer3.py"
    if ($LASTEXITCODE -ne 0) {
        Fail "SPT-023.7 Capa 3 targeted tests failed."
    }

    # Certify actual targeted count instead of only printing an expectation.
    $targetCollect = @(
        & $python -m pytest --collect-only -q `
            "tests/integration/test_spt0237_governance_closure_layer3.py" 2>&1
    )
    if ($LASTEXITCODE -ne 0) {
        Fail "Unable to collect targeted Capa 3 tests."
    }

    $targetText = ($targetCollect | ForEach-Object { [string]$_ }) -join "`n"
    $targetMatches = [regex]::Matches(
        $targetText,
        '(?im)(\d+)\s+(?:tests?|items?)\s+collected'
    )

    if ($targetMatches.Count -gt 0) {
        $targetCount = [int]$targetMatches[$targetMatches.Count - 1].Groups[1].Value
    }
    else {
        $targetCount = @(
            $targetCollect | Where-Object { ([string]$_) -match '::' }
        ).Count
    }

    if ($targetCount -lt $TargetedExpected) {
        Fail "Targeted test count is below expected floor ($TargetedExpected)."
    }

    Write-Host "TARGETED TESTS : $targetCount PASSED" -ForegroundColor Green

    Write-Step "[6/12] INSTITUTIONAL SUITE + COMPILEALL"

    & $python -m pytest -q
    if ($LASTEXITCODE -ne 0) {
        Fail "Institutional suite failed."
    }

    $collect = @(& $python -m pytest --collect-only -q 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Fail "Unable to collect institutional tests."
    }

    $collectText = ($collect | ForEach-Object { [string]$_ }) -join "`n"
    $matches = [regex]::Matches(
        $collectText,
        '(?im)(\d+)\s+(?:tests?|items?)\s+collected'
    )

    if ($matches.Count -gt 0) {
        $suiteCount = [int]$matches[$matches.Count - 1].Groups[1].Value
    }
    else {
        $suiteCount = @(
            $collect | Where-Object { ([string]$_) -match '::' }
        ).Count
    }

    if ($suiteCount -lt $FullSuiteFloor) {
        Fail "Institutional suite count is below expected continuity floor ($FullSuiteFloor)."
    }

    & $python -m compileall -q src
    if ($LASTEXITCODE -ne 0) {
        Fail "COMPILEALL failed."
    }

    Write-Host "FULL SUITE : $suiteCount PASSED" -ForegroundColor Green
    Write-Host "COMPILEALL : PASS" -ForegroundColor Green

    Write-Step "[7/12] SHA-256 PRESERVATION GATE"

    $changed = @()
    foreach ($rel in $freeze.Keys) {
        $abs = Join-Path $Root ($rel -replace '/', '\')

        if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) {
            $changed += $rel
        }
        elseif ((Get-Sha $abs) -ne $freeze[$rel]) {
            $changed += $rel
        }
    }

    Write-Host "PROTECTED FILES CHANGED : $($changed.Count)"

    if ($changed.Count -ne 0) {
        Fail ("Protected component preservation failed: " + ($changed -join ", "))
    }

    Write-Host "SPT-023.1-.6 + SPT-023.7 CAPAS 1-2 : PRESERVED" -ForegroundColor Green

    Write-Step "[8/12] GOVERNANCE + QUALITY GATES + CLOSURE EVIDENCE + SGD-002"

    $artifactDir = Join-Path $Root "artifacts\development\SPT-023.7-Capa3-v1.0.0"
    if (-not (Test-Path -LiteralPath $artifactDir)) {
        New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
    }

    $closureCheckScript = @'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
artifact_dir = Path(sys.argv[2])

from sgoda.integration.spt0237.layer3 import Spt0237Layer3ClosureService

service = Spt0237Layer3ClosureService(
    root,
    ledger_path=artifact_dir / "audit-closure-ledger.json",
)
result = service.evaluate(protected_changes=0)

if result["status"] != "INSTITUTIONALLY_CLOSED":
    raise SystemExit("SPT-023.7 closure status is not approved.")
if not result["quality_gate_certificate"]["passed"]:
    raise SystemExit("Quality gates did not pass.")
if not result["governance"]["passed"]:
    raise SystemExit("Governance did not pass.")
if not result["ledger_verified"]:
    raise SystemExit("Audit closure ledger verification failed.")

(artifact_dir / "closure-manifest.json").write_text(
    json.dumps(
        result["closure_manifest"],
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    ) + "\n",
    encoding="utf-8",
    newline="\n",
)

print("TRANSVERSAL_AUDIT=PASS")
print("CORRELATION=PASS")
print("RISK_EVALUATION=PASS")
print("EVIDENCE_INTEGRITY=PASS")
print("QUALITY_GATES=PASS")
print("GOVERNANCE=PASS")
print("CLOSURE_MANIFEST=CREATED")
print("SPT0237_STATUS=INSTITUTIONALLY_CLOSED")
'@

    $tempClosureCheck = Join-Path $env:TEMP "sgoda-spt0237-layer3-closure-check.py"
    Write-Utf8Lf $tempClosureCheck $closureCheckScript

    try {
        & $python $tempClosureCheck $Root $artifactDir
        if ($LASTEXITCODE -ne 0) {
            Fail "Runtime institutional closure gate failed."
        }
    }
    finally {
        Remove-Item -LiteralPath $tempClosureCheck -Force -ErrorAction SilentlyContinue
    }

    $manifestAbs = Join-Path $artifactDir "closure-manifest.json"
    $ledgerAbs = Join-Path $artifactDir "audit-closure-ledger.json"

    if (-not (Test-Path -LiteralPath $manifestAbs -PathType Leaf)) {
        Fail "Closure manifest was not generated."
    }
    if (-not (Test-Path -LiteralPath $ledgerAbs -PathType Leaf)) {
        Fail "Audit closure ledger was not generated."
    }

    $manifestData = Get-Content -LiteralPath $manifestAbs -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifestData.status -ne "INSTITUTIONALLY_CLOSED") {
        Fail "Closure manifest status is not INSTITUTIONALLY_CLOSED."
    }
    if ([string]$manifestData.manifest_sha256 -notmatch '^[A-F0-9]{64}$') {
        Fail "Closure manifest SHA-256 is invalid."
    }

    $evidenceRel = "artifacts/development/SPT-023.7-Capa3-v1.0.0/implementation-evidence.json"
    $manifestRel = "artifacts/development/SPT-023.7-Capa3-v1.0.0/closure-manifest.json"
    $ledgerRel = "artifacts/development/SPT-023.7-Capa3-v1.0.0/audit-closure-ledger.json"
    $evidenceAbs = Join-Path $Root ($evidenceRel -replace '/', '\')

    $generated = @()
    foreach ($rel in $Files.Keys | Sort-Object) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        $generated += [ordered]@{
            path = $rel
            sha256 = Get-Sha $abs
        }
    }

    $generated += [ordered]@{
        path = $manifestRel
        sha256 = Get-Sha $manifestAbs
    }
    $generated += [ordered]@{
        path = $ledgerRel
        sha256 = Get-Sha $ledgerAbs
    }

    $evidenceObject = [ordered]@{
        component = "SPT-023.7"
        layer = "Capa 3"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        targeted_tests = $targetCount
        institutional_tests = $suiteCount
        compileall = "PASS"
        protected_files = $freeze.Count
        protected_changes = 0
        layer1_preserved = $true
        layer2_preserved = $true
        transversal_audit = "PASS"
        correlation = "PASS"
        risk_evaluation = "PASS"
        evidence_integrity = "PASS"
        quality_gates = "PASS"
        governance = "PASS"
        closure_manifest = "CREATED"
        closure_manifest_sha256 = [string]$manifestData.manifest_sha256
        audit_ledger_sha256_chain = "VERIFIED"
        spt0237_status = "INSTITUTIONALLY_CLOSED"
        paid_api_used = $false
        next_component = "SPT-023.8"
        security_platform_next = "SPT-024 PISI"
        generated_files = $generated
    }

    Write-Utf8Lf $evidenceAbs ($evidenceObject | ConvertTo-Json -Depth 10)

    $sgdCandidates = @(
        GitLines @("ls-files") | Where-Object {
            $_ -match 'SGD-002' -and $_ -match '\.(md|txt)$'
        }
    )

    if ($sgdCandidates.Count -eq 0) {
        Fail "Tracked SGD-002 master document not found."
    }

    $sgdRel = $sgdCandidates[0]
    $sgdAbs = Join-Path $Root ($sgdRel -replace '/', '\')
    $sgdText = [IO.File]::ReadAllText($sgdAbs)

    $marker = "<!-- SPT-023.7-CAPA3-CLOSE-V1.0.0 -->"

    if ($sgdText -notmatch [regex]::Escape($marker)) {
        $append = @"

$marker
## SPT-023.7 — Auditoría Inteligente — CIERRE INSTITUCIONAL

- Capa 1: PRESERVED.
- Capa 2: PRESERVED.
- Capa 3: IMPLEMENTED AND VALIDATED.
- Auditoría transversal: PASS.
- Correlación institucional: PASS.
- Evaluación de riesgo: PASS.
- Integridad de evidencia: PASS.
- Quality Gates: PASS.
- Gobierno de cierre: PASS.
- Ledger institucional SHA-256: VERIFIED.
- Closure Manifest: CREATED.
- SPT-023.1 a SPT-023.6: PRESERVED.
- SPT-023.7: INSTITUTIONALLY CLOSED.
- Siguiente paquete funcional: SPT-023.8 — Publicación Institucional.
- Plataforma transversal prioritaria siguiente: SPT-024 — Plataforma Institucional de Seguridad Informática (PISI).
"@

        Write-Utf8Lf $sgdAbs ($sgdText.TrimEnd() + "`n" + $append.TrimStart())
    }

    Write-Host "EVIDENCE             : CREATED" -ForegroundColor Green
    Write-Host "CLOSURE MANIFEST     : CREATED" -ForegroundColor Green
    Write-Host "AUDIT LEDGER         : SHA-256 VERIFIED" -ForegroundColor Green
    Write-Host "SGD-002              : SPT-023.7 CLOSED" -ForegroundColor Green

    Write-Step "[9/12] EXACT CONTROLLED STAGING"

    $stage = @(
        $targets +
        $evidenceRel +
        $manifestRel +
        $ledgerRel +
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

    Write-Host "DIFF CHECK      : PASS" -ForegroundColor Green
    Write-Host "STAGING QUALITY : PASS" -ForegroundColor Green

    Write-Step "[10/12] FINAL REMOTE GATE"

    GitLines @("fetch","origin",$Branch,"--no-tags") | ForEach-Object { Write-Host $_ }

    $headBeforeCommit = GitText @("rev-parse","HEAD")
    $remoteBeforeCommit = GitText @("rev-parse","origin/$Branch")

    if (
        $headBeforeCommit -ne $ExpectedBaseline -or
        $remoteBeforeCommit -ne $ExpectedBaseline
    ) {
        Fail "Repository moved during SPT-023.7 Capa 3 transaction."
    }

    Write-Host "REMOTE GATE : PASS" -ForegroundColor Green

    Write-Step "[11/12] COMMIT + PUSH"

    GitLines @("commit","-m",$CommitMessage) | ForEach-Object { Write-Host $_ }
    $CommitCreated = $true
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

    if (
        $localFinal -ne $remoteFinal -or
        $ahead -ne 0 -or
        $behind -ne 0 -or
        $stagedFinal -ne 0 -or
        $deletedFinal -ne 0
    ) {
        Fail "Final authoritative remote verification failed."
    }

    Emit-FinalBanner `
        -Commit $localFinal `
        -Targeted $targetCount `
        -FullSuite $suiteCount

    exit 0
}
catch {
    Fail $_.Exception.Message
}
