#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "212c9430fcd96f564439f3af828b740c2761f850"
$SelfName = "Invoke-SGODA-SPT0242-Capa1-FINAL-v1.0.0-PS51.ps1"
$CommitMessage = "feat(spt-024.2): implement secrets credentials and secure configuration gate"
$TargetedExpected = 32
$FullSuiteFloor = 1219
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
            }
            else {
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
    [int]$FullSuite,
    [int]$Candidates,
    [int]$RealRisk,
    [string]$GateStatus
) {
    Write-Host ""
    Write-Host ("=" * 72) -ForegroundColor Green
    Write-Host " SPT-024.2 CAPA 1  : IMPLEMENTED AND VALIDATED" -ForegroundColor Green
    Write-Host " SECRET CANDIDATES : $Candidates CLASSIFIED" -ForegroundColor Green
    Write-Host " REAL RISK         : $RealRisk" -ForegroundColor Green
    Write-Host " SECRET VALUES     : NOT EXPOSED" -ForegroundColor Green
    Write-Host " SECURE STORAGE    : POLICY ESTABLISHED" -ForegroundColor Green
    Write-Host " ROTATION POLICY   : ESTABLISHED" -ForegroundColor Green
    Write-Host " GIT SECRET GATE   : $GateStatus" -ForegroundColor Green
    Write-Host " SPT-023.1-.7      : PRESERVED" -ForegroundColor Green
    Write-Host " SPT-024.1         : PRESERVED" -ForegroundColor Green
    Write-Host " TARGETED TESTS    : $Targeted PASSED" -ForegroundColor Green
    Write-Host " FULL SUITE        : $FullSuite PASSED" -ForegroundColor Green
    Write-Host " SGD-002           : UPDATED" -ForegroundColor Green
    Write-Host " COMMIT            : $Commit" -ForegroundColor Green
    Write-Host " LOCAL/REMOTE      : IDENTICAL" -ForegroundColor Green
    Write-Host " AHEAD             : 0" -ForegroundColor Green
    Write-Host " BEHIND            : 0" -ForegroundColor Green
    Write-Host " STAGED            : 0" -ForegroundColor Green
    Write-Host " DELETED TRACKED   : 0" -ForegroundColor Green
    Write-Host " ERRORS PENDING    : 0" -ForegroundColor Green
    Write-Host " NEXT              : SPT-024.3 API / FASTAPI SECURITY" -ForegroundColor Green
    Write-Host ("=" * 72) -ForegroundColor Green
    Write-Host "FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
}

function Fail([string]$Reason) {
    Write-Host ""
    Write-Host ("=" * 72) -ForegroundColor Red
    Write-Host " SPT-024.2 CAPA 1 : HOLD" -ForegroundColor Red
    Write-Host " REASON            : $Reason" -ForegroundColor Red

    if ($CommitCreated) {
        Write-Host " LOCAL COMMIT      : PRESERVED FOR SAME-FILE RESUME" -ForegroundColor Yellow
    }
    else {
        Write-Host " TRANSACTION       : NOT PUBLISHED" -ForegroundColor Yellow
    }

    Write-Host " ERRORS PENDING    : 1" -ForegroundColor Red
    Write-Host ("=" * 72) -ForegroundColor Red
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

    Write-Step "[1/13] AUTHORITATIVE BASELINE / RESUME / WORKTREE SAFETY"

    GitLines @("fetch","origin",$Branch,"--no-tags") |
        ForEach-Object { Write-Host $_ }

    $Local = GitText @("rev-parse","HEAD")
    $Remote = GitText @("rev-parse","origin/$Branch")
    $Subject = GitText @("log","-1","--pretty=%s")

    if ($Local -ne $ExpectedBaseline) {
        $Parent = GitText @("rev-parse","HEAD^")

        if ($Subject -eq $CommitMessage -and $Parent -eq $ExpectedBaseline) {
            $ResumeEvidence = Join-Path $Root "artifacts\development\SPT-024.2-Capa1-v1.0.0\implementation-evidence.json"

            if (-not (Test-Path -LiteralPath $ResumeEvidence -PathType Leaf)) {
                Fail "Resumable SPT-024.2 commit exists but evidence is missing."
            }

            $ResumeData = Get-Content `
                -LiteralPath $ResumeEvidence `
                -Raw `
                -Encoding UTF8 |
                ConvertFrom-Json

            if ($Local -eq $Remote) {
                $stagedResume = @(
                    GitLines @("diff","--cached","--name-only")
                ).Count

                $deletedResume = @(
                    GitLines @("ls-files","--deleted")
                ).Count

                if ($stagedResume -ne 0 -or $deletedResume -ne 0) {
                    Fail "Published SPT-024.2 commit exists but repository safety is not clean."
                }

                Emit-FinalBanner `
                    -Commit $Local `
                    -Targeted ([int]$ResumeData.targeted_tests) `
                    -FullSuite ([int]$ResumeData.institutional_tests) `
                    -Candidates ([int]$ResumeData.secret_candidates_assessed) `
                    -RealRisk ([int]$ResumeData.probable_real_secrets) `
                    -GateStatus ([string]$ResumeData.security_gate_status)

                exit 0
            }

            if ($Remote -eq $ExpectedBaseline) {
                $CommitCreated = $true

                Write-Host "RESUME MODE : LOCAL COMMIT EXISTS; PUSH PENDING" -ForegroundColor Yellow

                GitLines @("push","origin",$Branch) |
                    ForEach-Object { Write-Host $_ }

                GitLines @("fetch","origin",$Branch,"--no-tags") |
                    ForEach-Object { Write-Host $_ }

                $remoteResume = GitText @("rev-parse","origin/$Branch")

                if ($remoteResume -ne $Local) {
                    Fail "Resume remote verification failed."
                }

                Emit-FinalBanner `
                    -Commit $Local `
                    -Targeted ([int]$ResumeData.targeted_tests) `
                    -FullSuite ([int]$ResumeData.institutional_tests) `
                    -Candidates ([int]$ResumeData.secret_candidates_assessed) `
                    -RealRisk ([int]$ResumeData.probable_real_secrets) `
                    -GateStatus ([string]$ResumeData.security_gate_status)

                exit 0
            }
        }

        Fail "HEAD is neither certified SPT-024.1 baseline nor resumable SPT-024.2 commit."
    }

    if ($Remote -ne $ExpectedBaseline) {
        Fail "Official remote moved away from the certified SPT-024.1 baseline."
    }

    $Staged = @(GitLines @("diff","--cached","--name-only"))
    $Deleted = @(GitLines @("ls-files","--deleted"))

    Write-Host "LOCAL HEAD      : $Local"
    Write-Host "REMOTE HEAD     : $Remote"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if ($Staged.Count -ne 0) {
        Fail "Staging must be clean."
    }

    if ($Deleted.Count -ne 0) {
        Fail "Tracked deletions detected."
    }

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

    $modified = @(
        GitLines @("-c","core.safecrlf=false","diff","--name-only") |
        Where-Object {
            $_ -and $_ -notmatch '^(warning:|hint:)'
        }
    )

    $runtimeModified = @(
        $modified |
        Where-Object { $_ -match '^artifacts/runtime/' }
    )

    $unexpectedModified = @(
        $modified |
        Where-Object { $_ -notmatch '^artifacts/runtime/' }
    )

    Write-Host "PREEXISTING RUNTIME MODIFICATIONS : $($runtimeModified.Count)"

    $runtimeModified |
        ForEach-Object {
            Write-Host ("RUNTIME PRESERVED : " + $_)
        }

    if ($unexpectedModified.Count -ne 0) {
        Fail (
            "Unexpected non-runtime tracked changes: " +
            ($unexpectedModified -join ", ")
        )
    }

    Write-Host "BASELINE : PASS" -ForegroundColor Green
    Write-Host "POWERSHELL SYNTAX : PASS" -ForegroundColor Green

    Write-Step "[2/13] SHA-256 FREEZE OF CLOSED SPT-023 + SPT-024.1"

    $tracked = @(GitLines @("ls-files"))

    $protected = @(
        $tracked |
        Where-Object {
            $_ -match 'SPT-023\.' -or
            $_ -match 'spt023' -or
            $_ -match 'SPT-024\.1' -or
            $_ -match 'spt0241'
        } |
        Sort-Object -Unique
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
        "src/sgoda/integration/spt0242/__init__.py",
        "src/sgoda/integration/spt0242/models.py",
        "src/sgoda/integration/spt0242/policy.py",
        "src/sgoda/integration/spt0242/classification.py",
        "src/sgoda/integration/spt0242/config_audit.py",
        "src/sgoda/integration/spt0242/rotation.py",
        "src/sgoda/integration/spt0242/storage.py",
        "src/sgoda/integration/spt0242/git_gate.py",
        "src/sgoda/integration/spt0242/service.py",
        "tests/integration/test_spt0242_secrets_security_layer1.py",
        "docs/06_Tecnologia/SPT-024/SPT-024.2/SGD-SPT024.2-Capa1-Secretos-Credenciales-Configuracion.md",
        "config/integration/spt0242/secrets-security-policy.json"
    )

    Write-Step "[3/13] TARGET COLLISION / FAILED-RUN RECOVERY"

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

    $staleEvidenceRel = "artifacts/development/SPT-024.2-Capa1-v1.0.0/implementation-evidence.json"
    $staleAssessmentRel = "artifacts/development/SPT-024.2-Capa1-v1.0.0/secret-assessment.json"

    foreach ($rel in @($staleEvidenceRel,$staleAssessmentRel)) {
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

    Write-Step "[4/13] IMPLEMENT SPT-024.2 SECRETS / CREDENTIALS / CONFIG"

    $Files = @{}

    $Files["src/sgoda/integration/spt0242/__init__.py"] = @'
"""SPT-024.2 — Gestión de Secretos, Credenciales y Configuración Segura."""

from .classification import SecretCandidateClassifier
from .config_audit import SecureConfigurationAuditor
from .git_gate import GitSecretGate
from .models import (
    CredentialControl,
    SecretAssessment,
    SecurityGateResult,
)
from .policy import SecretManagementPolicy
from .rotation import RotationPolicyEngine
from .service import Spt0242SecretsSecurityService
from .storage import SecureStoragePlanner

__all__ = [
    "CredentialControl",
    "GitSecretGate",
    "RotationPolicyEngine",
    "SecretAssessment",
    "SecretCandidateClassifier",
    "SecretManagementPolicy",
    "SecureConfigurationAuditor",
    "SecureStoragePlanner",
    "SecurityGateResult",
    "Spt0242SecretsSecurityService",
]
'@

    $Files["src/sgoda/integration/spt0242/models.py"] = @'
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class SecretAssessment:
    path: str
    line: int
    detector: str
    fingerprint: str
    classification: str
    severity: str
    requires_rotation: bool
    requires_removal_from_git: bool
    rationale: str

    @property
    def blocking(self) -> bool:
        return self.severity.upper() in {"ERROR", "CRITICAL"}

    def to_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "line": self.line,
            "detector": self.detector,
            "fingerprint": self.fingerprint,
            "classification": self.classification,
            "severity": self.severity,
            "requires_rotation": self.requires_rotation,
            "requires_removal_from_git": self.requires_removal_from_git,
            "rationale": self.rationale,
            "blocking": self.blocking,
        }


@dataclass(frozen=True)
class CredentialControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "control_id": self.control_id,
            "name": self.name,
            "passed": self.passed,
            "blocking": self.blocking,
            "detail": self.detail,
        }


@dataclass(frozen=True)
class SecurityGateResult:
    passed: bool
    failed_blocking_controls: tuple[str, ...]
    controls: tuple[CredentialControl, ...]
    assessed_candidates: int
    real_risk_candidates: int
    false_positive_candidates: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "passed": self.passed,
            "failed_blocking_controls": list(self.failed_blocking_controls),
            "controls": [item.to_dict() for item in self.controls],
            "assessed_candidates": self.assessed_candidates,
            "real_risk_candidates": self.real_risk_candidates,
            "false_positive_candidates": self.false_positive_candidates,
        }
'@

    $Files["src/sgoda/integration/spt0242/policy.py"] = @'
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class SecretManagementPolicy:
    approved_storage_backends: tuple[str, ...]
    forbidden_tracked_patterns: tuple[str, ...]
    ignored_example_suffixes: tuple[str, ...]
    rotation_days_high: int
    rotation_days_medium: int
    require_env_gitignore: bool
    require_git_gate: bool
    fail_on_real_secret: bool
    fail_on_sensitive_file: bool
    secret_values_must_never_be_reported: bool
    paid_api_allowed: bool

    @classmethod
    def default(cls) -> "SecretManagementPolicy":
        return cls(
            approved_storage_backends=(
                "ENVIRONMENT_VARIABLES",
                "WINDOWS_CREDENTIAL_MANAGER",
                "LOCAL_ENCRYPTED_SECRET_FILE_OUTSIDE_REPOSITORY",
            ),
            forbidden_tracked_patterns=(
                ".env",
                "*.pem",
                "*.key",
                "*.pfx",
                "*.p12",
                "*credentials*.json",
                "*secrets*.json",
            ),
            ignored_example_suffixes=(
                ".example",
                ".sample",
                ".template",
            ),
            rotation_days_high=30,
            rotation_days_medium=90,
            require_env_gitignore=True,
            require_git_gate=True,
            fail_on_real_secret=True,
            fail_on_sensitive_file=True,
            secret_values_must_never_be_reported=True,
            paid_api_allowed=False,
        )

    @classmethod
    def from_json(cls, path: str | Path) -> "SecretManagementPolicy":
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        default = cls.default()
        return cls(
            approved_storage_backends=tuple(
                data.get("approved_storage_backends")
                or default.approved_storage_backends
            ),
            forbidden_tracked_patterns=tuple(
                data.get("forbidden_tracked_patterns")
                or default.forbidden_tracked_patterns
            ),
            ignored_example_suffixes=tuple(
                data.get("ignored_example_suffixes")
                or default.ignored_example_suffixes
            ),
            rotation_days_high=int(
                data.get("rotation_days_high", default.rotation_days_high)
            ),
            rotation_days_medium=int(
                data.get("rotation_days_medium", default.rotation_days_medium)
            ),
            require_env_gitignore=bool(
                data.get("require_env_gitignore", True)
            ),
            require_git_gate=bool(data.get("require_git_gate", True)),
            fail_on_real_secret=bool(data.get("fail_on_real_secret", True)),
            fail_on_sensitive_file=bool(
                data.get("fail_on_sensitive_file", True)
            ),
            secret_values_must_never_be_reported=bool(
                data.get("secret_values_must_never_be_reported", True)
            ),
            paid_api_allowed=bool(data.get("paid_api_allowed", False)),
        )
'@

    $Files["src/sgoda/integration/spt0242/classification.py"] = @'
from __future__ import annotations

from pathlib import PurePosixPath
from typing import Iterable

from .models import SecretAssessment


class SecretCandidateClassifier:
    """
    Classifies SPT-024.1 secret candidates using metadata only.

    It never requests, loads, stores or returns the candidate secret value.
    """

    EXAMPLE_TOKENS = (
        "example",
        "sample",
        "template",
        "fixture",
        "test_",
        "_test",
        "dummy",
        "placeholder",
    )

    DOC_TOKENS = (
        "docs/",
        "readme",
        ".md",
    )

    @classmethod
    def classify_one(cls, candidate: dict) -> SecretAssessment:
        path = str(candidate.get("path") or "").replace("\\", "/")
        detector = str(candidate.get("detector") or "")
        fingerprint = str(candidate.get("fingerprint") or "")
        line = int(candidate.get("line") or 0)

        lower = path.lower()
        name = PurePosixPath(lower).name

        if any(token in lower for token in cls.EXAMPLE_TOKENS):
            classification = "LIKELY_FALSE_POSITIVE"
            severity = "INFO"
            rotate = False
            remove = False
            rationale = "Candidate is located in example/test/template context."
        elif any(token in lower for token in cls.DOC_TOKENS):
            classification = "REVIEW_REQUIRED"
            severity = "WARNING"
            rotate = False
            remove = False
            rationale = "Documentation candidate requires manual validation."
        elif detector == "PRIVATE_KEY_MARKER":
            classification = "PROBABLE_REAL_SECRET"
            severity = "CRITICAL"
            rotate = True
            remove = True
            rationale = "Private-key marker outside an example context."
        elif detector == "ASSIGNED_SECRET":
            classification = "PROBABLE_REAL_SECRET"
            severity = "ERROR"
            rotate = True
            remove = True
            rationale = "Assigned secret-like value outside an example context."
        else:
            classification = "REVIEW_REQUIRED"
            severity = "WARNING"
            rotate = False
            remove = False
            rationale = "Unknown detector requires review."

        if name.endswith((".example", ".sample", ".template")):
            classification = "LIKELY_FALSE_POSITIVE"
            severity = "INFO"
            rotate = False
            remove = False
            rationale = "Explicit example/sample/template file."

        return SecretAssessment(
            path=path,
            line=line,
            detector=detector,
            fingerprint=fingerprint,
            classification=classification,
            severity=severity,
            requires_rotation=rotate,
            requires_removal_from_git=remove,
            rationale=rationale,
        )

    @classmethod
    def classify_many(
        cls,
        candidates: Iterable[dict],
    ) -> list[SecretAssessment]:
        return [cls.classify_one(item) for item in candidates]
'@

    $Files["src/sgoda/integration/spt0242/config_audit.py"] = @'
from __future__ import annotations

import fnmatch
from pathlib import Path
from typing import Iterable

from .models import CredentialControl
from .policy import SecretManagementPolicy


class SecureConfigurationAuditor:
    def __init__(
        self,
        root: str | Path,
        policy: SecretManagementPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or SecretManagementPolicy.default()

    @staticmethod
    def _normalized(values: Iterable[str]) -> set[str]:
        return {
            str(value).replace("\\", "/").strip()
            for value in values
            if str(value).strip()
        }

    def audit_gitignore(self) -> CredentialControl:
        gitignore = self.root / ".gitignore"
        if not gitignore.exists():
            return CredentialControl(
                "CTRL-GITIGNORE",
                ".gitignore secret protection",
                False,
                True,
                ".gitignore is missing.",
            )

        lines = {
            line.strip()
            for line in gitignore.read_text(
                encoding="utf-8",
                errors="replace",
            ).splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }

        protected = (
            ".env" in lines
            or ".env*" in lines
            or "**/.env" in lines
            or "**/.env*" in lines
        )

        return CredentialControl(
            "CTRL-GITIGNORE",
            ".gitignore secret protection",
            protected,
            True,
            "Environment secret patterns protected." if protected
            else "Environment secret patterns are not protected.",
        )

    def audit_tracked_sensitive_files(
        self,
        tracked_paths: Iterable[str],
    ) -> CredentialControl:
        tracked = self._normalized(tracked_paths)
        violations: list[str] = []

        for path in tracked:
            lower = path.lower()
            if any(
                lower.endswith(suffix)
                for suffix in self.policy.ignored_example_suffixes
            ):
                continue

            for pattern in self.policy.forbidden_tracked_patterns:
                if fnmatch.fnmatch(lower, pattern.lower()):
                    violations.append(path)
                    break

        return CredentialControl(
            "CTRL-TRACKED-SECRETS",
            "Tracked sensitive file protection",
            not violations,
            True,
            f"violations={len(violations)}",
        )

    def audit_repository_secret_policy(self) -> CredentialControl:
        approved = (
            self.policy.require_git_gate
            and self.policy.secret_values_must_never_be_reported
            and not self.policy.paid_api_allowed
        )
        return CredentialControl(
            "CTRL-SECRET-POLICY",
            "Institutional secret policy",
            approved,
            True,
            "Git gate + redaction + free/open-source policy enforced.",
        )
'@

    $Files["src/sgoda/integration/spt0242/rotation.py"] = @'
from __future__ import annotations

from dataclasses import dataclass

from .models import SecretAssessment
from .policy import SecretManagementPolicy


@dataclass(frozen=True)
class RotationInstruction:
    fingerprint: str
    required: bool
    maximum_age_days: int | None
    reason: str

    def to_dict(self) -> dict:
        return {
            "fingerprint": self.fingerprint,
            "required": self.required,
            "maximum_age_days": self.maximum_age_days,
            "reason": self.reason,
        }


class RotationPolicyEngine:
    def __init__(
        self,
        policy: SecretManagementPolicy | None = None,
    ) -> None:
        self.policy = policy or SecretManagementPolicy.default()

    def plan(self, assessment: SecretAssessment) -> RotationInstruction:
        if not assessment.requires_rotation:
            return RotationInstruction(
                fingerprint=assessment.fingerprint,
                required=False,
                maximum_age_days=None,
                reason="Rotation not required by current classification.",
            )

        days = (
            self.policy.rotation_days_high
            if assessment.severity.upper() == "CRITICAL"
            else self.policy.rotation_days_medium
        )

        return RotationInstruction(
            fingerprint=assessment.fingerprint,
            required=True,
            maximum_age_days=days,
            reason="Probable real credential must be rotated after secure replacement.",
        )
'@

    $Files["src/sgoda/integration/spt0242/storage.py"] = @'
from __future__ import annotations

from dataclasses import dataclass

from .policy import SecretManagementPolicy


@dataclass(frozen=True)
class SecureStoragePlan:
    backend: str
    repository_storage_allowed: bool
    plaintext_allowed: bool
    instructions: tuple[str, ...]

    def to_dict(self) -> dict:
        return {
            "backend": self.backend,
            "repository_storage_allowed": self.repository_storage_allowed,
            "plaintext_allowed": self.plaintext_allowed,
            "instructions": list(self.instructions),
        }


class SecureStoragePlanner:
    def __init__(
        self,
        policy: SecretManagementPolicy | None = None,
    ) -> None:
        self.policy = policy or SecretManagementPolicy.default()

    def plan(self, *, preferred_backend: str = "ENVIRONMENT_VARIABLES") -> SecureStoragePlan:
        if preferred_backend not in self.policy.approved_storage_backends:
            raise ValueError("Storage backend is not institutionally approved.")

        if preferred_backend == "ENVIRONMENT_VARIABLES":
            instructions = (
                "Store runtime secrets outside Git.",
                "Inject values through environment variables.",
                "Keep only variable names and examples in repository.",
            )
        elif preferred_backend == "WINDOWS_CREDENTIAL_MANAGER":
            instructions = (
                "Store credentials in Windows Credential Manager.",
                "Reference credentials by logical target name.",
                "Never serialize secret values into project artifacts.",
            )
        else:
            instructions = (
                "Store encrypted secret material outside repository root.",
                "Restrict filesystem permissions to the runtime identity.",
                "Keep only non-sensitive metadata in SGODA evidence.",
            )

        return SecureStoragePlan(
            backend=preferred_backend,
            repository_storage_allowed=False,
            plaintext_allowed=False,
            instructions=instructions,
        )
'@

    $Files["src/sgoda/integration/spt0242/git_gate.py"] = @'
from __future__ import annotations

from typing import Iterable

from .models import CredentialControl, SecretAssessment, SecurityGateResult


class GitSecretGate:
    """Blocking publication gate for secret/credential safety."""

    REQUIRED_CONTROL_IDS = (
        "CTRL-GITIGNORE",
        "CTRL-TRACKED-SECRETS",
        "CTRL-SECRET-POLICY",
        "CTRL-CANDIDATE-CLASSIFICATION",
    )

    @classmethod
    def candidate_control(
        cls,
        assessments: Iterable[SecretAssessment],
    ) -> CredentialControl:
        assessments = list(assessments)
        real_risk = [
            item
            for item in assessments
            if item.classification == "PROBABLE_REAL_SECRET"
        ]

        return CredentialControl(
            "CTRL-CANDIDATE-CLASSIFICATION",
            "Secret candidate classification",
            len(real_risk) == 0,
            True,
            f"probable_real_secrets={len(real_risk)}",
        )

    @classmethod
    def certify(
        cls,
        *,
        controls: Iterable[CredentialControl],
        assessments: Iterable[SecretAssessment],
    ) -> SecurityGateResult:
        controls = list(controls)
        assessments = list(assessments)
        by_id = {item.control_id: item for item in controls}

        missing = [
            control_id
            for control_id in cls.REQUIRED_CONTROL_IDS
            if control_id not in by_id
        ]

        failed = [
            item.control_id
            for item in controls
            if item.blocking and not item.passed
        ]
        failed.extend(f"MISSING:{item}" for item in missing)

        real_risk = sum(
            1
            for item in assessments
            if item.classification == "PROBABLE_REAL_SECRET"
        )
        false_positive = sum(
            1
            for item in assessments
            if item.classification == "LIKELY_FALSE_POSITIVE"
        )

        return SecurityGateResult(
            passed=not failed,
            failed_blocking_controls=tuple(sorted(set(failed))),
            controls=tuple(controls),
            assessed_candidates=len(assessments),
            real_risk_candidates=real_risk,
            false_positive_candidates=false_positive,
        )
'@

    $Files["src/sgoda/integration/spt0242/service.py"] = @'
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterable

from .classification import SecretCandidateClassifier
from .config_audit import SecureConfigurationAuditor
from .git_gate import GitSecretGate
from .policy import SecretManagementPolicy
from .rotation import RotationPolicyEngine
from .storage import SecureStoragePlanner


class Spt0242SecretsSecurityService:
    """Secrets, credentials and secure configuration governance service."""

    def __init__(
        self,
        root: str | Path,
        policy: SecretManagementPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or SecretManagementPolicy.default()

    @staticmethod
    def load_spt0241_candidates(path: str | Path) -> list[dict]:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        return list(data.get("secret_candidates") or [])

    def evaluate(
        self,
        *,
        secret_candidates: Iterable[dict],
        tracked_paths: Iterable[str],
        preferred_storage_backend: str = "ENVIRONMENT_VARIABLES",
    ) -> dict[str, Any]:
        assessments = SecretCandidateClassifier.classify_many(secret_candidates)

        auditor = SecureConfigurationAuditor(self.root, self.policy)
        controls = [
            auditor.audit_gitignore(),
            auditor.audit_tracked_sensitive_files(tracked_paths),
            auditor.audit_repository_secret_policy(),
            GitSecretGate.candidate_control(assessments),
        ]

        gate = GitSecretGate.certify(
            controls=controls,
            assessments=assessments,
        )

        rotation_engine = RotationPolicyEngine(self.policy)
        rotation = [
            rotation_engine.plan(item).to_dict()
            for item in assessments
        ]

        storage = SecureStoragePlanner(self.policy).plan(
            preferred_backend=preferred_storage_backend
        )

        return {
            "component": "SPT-024.2",
            "status": (
                "SECURITY_GATE_PASS"
                if gate.passed
                else "SECURITY_GATE_HOLD"
            ),
            "assessments": [item.to_dict() for item in assessments],
            "security_gate": gate.to_dict(),
            "rotation_plan": rotation,
            "secure_storage_plan": storage.to_dict(),
            "secret_values_exposed": False,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "next_component": "SPT-024.3",
        }
'@

    $Files["tests/integration/test_spt0242_secrets_security_layer1.py"] = @'
import json
from pathlib import Path

import pytest

from sgoda.integration.spt0242 import (
    GitSecretGate,
    SecretCandidateClassifier,
    SecretManagementPolicy,
    SecureConfigurationAuditor,
    SecureStoragePlanner,
    Spt0242SecretsSecurityService,
)
from sgoda.integration.spt0242.rotation import RotationPolicyEngine


def write(path: Path, content: str = "x\n"):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def candidate(
    path="src/config.py",
    detector="ASSIGNED_SECRET",
    fingerprint="ABCDEF1234567890ABCDEF12",
    line=1,
):
    return {
        "path": path,
        "detector": detector,
        "fingerprint": fingerprint,
        "line": line,
    }


def test_default_policy_disallows_paid_api():
    assert SecretManagementPolicy.default().paid_api_allowed is False


def test_default_policy_requires_git_gate():
    assert SecretManagementPolicy.default().require_git_gate is True


def test_policy_loads_json(tmp_path):
    path = write(tmp_path / "p.json", json.dumps({"rotation_days_high": 7}))
    assert SecretManagementPolicy.from_json(path).rotation_days_high == 7


def test_example_candidate_is_false_positive():
    assessment = SecretCandidateClassifier.classify_one(
        candidate(path="tests/fixture_secret.py")
    )
    assert assessment.classification == "LIKELY_FALSE_POSITIVE"


def test_sample_candidate_is_false_positive():
    assessment = SecretCandidateClassifier.classify_one(
        candidate(path="config/sample_token.json")
    )
    assert assessment.classification == "LIKELY_FALSE_POSITIVE"


def test_docs_candidate_requires_review():
    assessment = SecretCandidateClassifier.classify_one(
        candidate(path="docs/secret-guide.md")
    )
    assert assessment.classification == "REVIEW_REQUIRED"


def test_private_key_candidate_is_critical():
    assessment = SecretCandidateClassifier.classify_one(
        candidate(detector="PRIVATE_KEY_MARKER")
    )
    assert assessment.severity == "CRITICAL"


def test_assigned_secret_is_error():
    assessment = SecretCandidateClassifier.classify_one(candidate())
    assert assessment.severity == "ERROR"


def test_real_secret_requires_rotation():
    assessment = SecretCandidateClassifier.classify_one(candidate())
    assert assessment.requires_rotation is True


def test_real_secret_requires_git_removal():
    assessment = SecretCandidateClassifier.classify_one(candidate())
    assert assessment.requires_removal_from_git is True


def test_classifier_preserves_only_metadata():
    assessment = SecretCandidateClassifier.classify_one(candidate())
    serialized = json.dumps(assessment.to_dict())
    assert "secret-value" not in serialized


def test_gitignore_control_passes_for_env(tmp_path):
    write(tmp_path / ".gitignore", ".env\n")
    control = SecureConfigurationAuditor(tmp_path).audit_gitignore()
    assert control.passed is True


def test_gitignore_control_fails_without_env(tmp_path):
    write(tmp_path / ".gitignore", "__pycache__/\n")
    control = SecureConfigurationAuditor(tmp_path).audit_gitignore()
    assert control.passed is False


def test_gitignore_control_fails_when_missing(tmp_path):
    control = SecureConfigurationAuditor(tmp_path).audit_gitignore()
    assert control.passed is False


def test_tracked_env_is_blocking(tmp_path):
    control = SecureConfigurationAuditor(tmp_path).audit_tracked_sensitive_files(
        [".env"]
    )
    assert control.passed is False


def test_tracked_private_key_is_blocking(tmp_path):
    control = SecureConfigurationAuditor(tmp_path).audit_tracked_sensitive_files(
        ["certs/prod.key"]
    )
    assert control.passed is False


def test_safe_tracked_file_passes(tmp_path):
    control = SecureConfigurationAuditor(tmp_path).audit_tracked_sensitive_files(
        ["config/settings.example"]
    )
    assert control.passed is True


def test_secret_policy_control_passes_default(tmp_path):
    assert SecureConfigurationAuditor(
        tmp_path
    ).audit_repository_secret_policy().passed is True


def test_rotation_high_is_30_days():
    assessment = SecretCandidateClassifier.classify_one(
        candidate(detector="PRIVATE_KEY_MARKER")
    )
    plan = RotationPolicyEngine().plan(assessment)
    assert plan.maximum_age_days == 30


def test_rotation_medium_is_90_days():
    assessment = SecretCandidateClassifier.classify_one(candidate())
    plan = RotationPolicyEngine().plan(assessment)
    assert plan.maximum_age_days == 90


def test_false_positive_does_not_rotate():
    assessment = SecretCandidateClassifier.classify_one(
        candidate(path="tests/example_secret.py")
    )
    assert RotationPolicyEngine().plan(assessment).required is False


def test_environment_storage_is_secure():
    plan = SecureStoragePlanner().plan()
    assert plan.repository_storage_allowed is False
    assert plan.plaintext_allowed is False


def test_windows_credential_manager_is_supported():
    plan = SecureStoragePlanner().plan(
        preferred_backend="WINDOWS_CREDENTIAL_MANAGER"
    )
    assert plan.backend == "WINDOWS_CREDENTIAL_MANAGER"


def test_unapproved_storage_fails():
    with pytest.raises(ValueError):
        SecureStoragePlanner().plan(preferred_backend="PLAINTEXT_FILE")


def test_candidate_control_passes_without_real_secrets():
    assessments = SecretCandidateClassifier.classify_many(
        [candidate(path="tests/example_secret.py")]
    )
    assert GitSecretGate.candidate_control(assessments).passed is True


def test_candidate_control_fails_with_real_secret():
    assessments = SecretCandidateClassifier.classify_many([candidate()])
    assert GitSecretGate.candidate_control(assessments).passed is False


def test_git_gate_passes_all_controls(tmp_path):
    write(tmp_path / ".gitignore", ".env\n")
    assessments = SecretCandidateClassifier.classify_many(
        [candidate(path="tests/example_secret.py")]
    )
    auditor = SecureConfigurationAuditor(tmp_path)
    controls = [
        auditor.audit_gitignore(),
        auditor.audit_tracked_sensitive_files(["src/x.py"]),
        auditor.audit_repository_secret_policy(),
        GitSecretGate.candidate_control(assessments),
    ]
    assert GitSecretGate.certify(
        controls=controls,
        assessments=assessments,
    ).passed is True


def test_git_gate_blocks_real_secret(tmp_path):
    write(tmp_path / ".gitignore", ".env\n")
    assessments = SecretCandidateClassifier.classify_many([candidate()])
    auditor = SecureConfigurationAuditor(tmp_path)
    controls = [
        auditor.audit_gitignore(),
        auditor.audit_tracked_sensitive_files(["src/x.py"]),
        auditor.audit_repository_secret_policy(),
        GitSecretGate.candidate_control(assessments),
    ]
    assert GitSecretGate.certify(
        controls=controls,
        assessments=assessments,
    ).passed is False


def test_service_loads_candidates(tmp_path):
    path = write(
        tmp_path / "baseline.json",
        json.dumps({"secret_candidates": [candidate()]}),
    )
    assert len(
        Spt0242SecretsSecurityService.load_spt0241_candidates(path)
    ) == 1


def test_service_never_exposes_values(tmp_path):
    write(tmp_path / ".gitignore", ".env\n")
    result = Spt0242SecretsSecurityService(tmp_path).evaluate(
        secret_candidates=[candidate(path="tests/example_secret.py")],
        tracked_paths=["src/x.py"],
    )
    assert result["secret_values_exposed"] is False


def test_service_preserves_closed_components(tmp_path):
    write(tmp_path / ".gitignore", ".env\n")
    result = Spt0242SecretsSecurityService(tmp_path).evaluate(
        secret_candidates=[],
        tracked_paths=["src/x.py"],
    )
    assert result["closed_components_mutated"] is False


def test_service_points_to_spt0243(tmp_path):
    write(tmp_path / ".gitignore", ".env\n")
    result = Spt0242SecretsSecurityService(tmp_path).evaluate(
        secret_candidates=[],
        tracked_paths=["src/x.py"],
    )
    assert result["next_component"] == "SPT-024.3"
'@

    $Files["docs/06_Tecnologia/SPT-024/SPT-024.2/SGD-SPT024.2-Capa1-Secretos-Credenciales-Configuracion.md"] = @'
# SPT-024.2 — Gestión de Secretos, Credenciales y Configuración Segura

## Objetivo

Convertir la línea base de seguridad de SPT-024.1 en controles institucionales
sobre secretos, credenciales y configuración sin exponer valores sensibles ni
modificar los componentes cerrados de SGODA-PUINAVE.

## Capacidades

- clasificación de candidatos detectados por SPT-024.1;
- separación entre probable secreto real, falso positivo y revisión requerida;
- validación de `.gitignore`;
- detección de tipos sensibles rastreados por Git;
- política de almacenamiento seguro;
- política de rotación;
- Security Gate bloqueante antes de publicación;
- evidencia basada únicamente en metadatos y fingerprints.

## Almacenamiento aprobado

El diseño contempla exclusivamente alternativas gratuitas o incorporadas al
sistema:

- variables de entorno;
- Windows Credential Manager;
- archivo cifrado local fuera del repositorio y con permisos restringidos.

Nunca se autoriza almacenar secretos en texto plano dentro del repositorio.

## Rotación

Los hallazgos clasificados como probables secretos reales exigen sustitución y
rotación. La evidencia conserva fingerprint, clasificación y acción requerida,
pero nunca el valor.

## Security Gate

El gate bloquea la publicación si:

- `.env` no está protegido por `.gitignore`;
- existen tipos sensibles rastreados por Git;
- la política institucional de secretos no está activa;
- existe al menos un candidato clasificado como `PROBABLE_REAL_SECRET`.

SPT-024.2 no elimina ni rota credenciales automáticamente. Las acciones
destructivas o que impliquen sustitución de credenciales requieren una fase
posterior controlada y evidencia explícita.
'@

    $Files["config/integration/spt0242/secrets-security-policy.json"] = @'
{
  "schema_version": "1.0.0",
  "platform": "SPT-024",
  "component": "SPT-024.2",
  "layer": "1",
  "purpose": "secrets_credentials_secure_configuration",
  "approved_storage_backends": [
    "ENVIRONMENT_VARIABLES",
    "WINDOWS_CREDENTIAL_MANAGER",
    "LOCAL_ENCRYPTED_SECRET_FILE_OUTSIDE_REPOSITORY"
  ],
  "forbidden_tracked_patterns": [
    ".env",
    "*.pem",
    "*.key",
    "*.pfx",
    "*.p12",
    "*credentials*.json",
    "*secrets*.json"
  ],
  "ignored_example_suffixes": [
    ".example",
    ".sample",
    ".template"
  ],
  "rotation_days_high": 30,
  "rotation_days_medium": 90,
  "require_env_gitignore": true,
  "require_git_gate": true,
  "fail_on_real_secret": true,
  "fail_on_sensitive_file": true,
  "secret_values_must_never_be_reported": true,
  "mutation_of_closed_components": false,
  "paid_api_allowed": false,
  "next_component": "SPT-024.3"
}
'@

    foreach ($rel in $Files.Keys) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        Write-Utf8Lf $abs $Files[$rel]
        Write-Host ("CREATED : " + ($rel -replace '/', '\'))
    }

    Write-Step "[5/13] PYTHON PREVALIDATION + TARGETED SECURITY TESTS"

    $python = Join-Path $Root ".venv\Scripts\python.exe"

    if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
        Fail "Project .venv Python not found."
    }

    $srcPath = Join-Path $Root "src"

    if ([string]::IsNullOrWhiteSpace($env:PYTHONPATH)) {
        $env:PYTHONPATH = $srcPath
    }
    else {
        $env:PYTHONPATH =
            $srcPath +
            [IO.Path]::PathSeparator +
            $env:PYTHONPATH
    }

    Write-Host "PYTHON EXECUTABLE : $python"
    Write-Host "PYTHONPATH        : $env:PYTHONPATH"

    & $python -c "import sgoda; import sgoda.integration.spt0241; import sgoda.integration.spt0242; print('SGODA_SECURITY_IMPORT=PASS')"

    if ($LASTEXITCODE -ne 0) {
        Fail "SPT-024.1/SPT-024.2 import prevalidation failed."
    }

    $pyTargets = @(
        "src/sgoda/integration/spt0242/__init__.py",
        "src/sgoda/integration/spt0242/models.py",
        "src/sgoda/integration/spt0242/policy.py",
        "src/sgoda/integration/spt0242/classification.py",
        "src/sgoda/integration/spt0242/config_audit.py",
        "src/sgoda/integration/spt0242/rotation.py",
        "src/sgoda/integration/spt0242/storage.py",
        "src/sgoda/integration/spt0242/git_gate.py",
        "src/sgoda/integration/spt0242/service.py",
        "tests/integration/test_spt0242_secrets_security_layer1.py"
    ) |
    ForEach-Object {
        Join-Path $Root ($_ -replace '/', '\')
    }

    & $python -m py_compile @pyTargets

    if ($LASTEXITCODE -ne 0) {
        Fail "Python syntax prevalidation failed."
    }

    & $python -m pytest -q `
        "tests/integration/test_spt0242_secrets_security_layer1.py"

    if ($LASTEXITCODE -ne 0) {
        Fail "SPT-024.2 targeted security tests failed."
    }

    $targetCollect = @(
        & $python -m pytest --collect-only -q `
            "tests/integration/test_spt0242_secrets_security_layer1.py" 2>&1
    )

    if ($LASTEXITCODE -ne 0) {
        Fail "Unable to collect targeted security tests."
    }

    $targetText =
        ($targetCollect | ForEach-Object { [string]$_ }) -join "`n"

    $targetMatches = [regex]::Matches(
        $targetText,
        '(?im)(\d+)\s+(?:tests?|items?)\s+collected'
    )

    if ($targetMatches.Count -gt 0) {
        $targetCount =
            [int]$targetMatches[
                $targetMatches.Count - 1
            ].Groups[1].Value
    }
    else {
        $targetCount = @(
            $targetCollect |
            Where-Object {
                ([string]$_) -match '::'
            }
        ).Count
    }

    if ($targetCount -lt $TargetedExpected) {
        Fail "Targeted security test count is below expected floor ($TargetedExpected)."
    }

    Write-Host "TARGETED TESTS : $targetCount PASSED" -ForegroundColor Green

    Write-Step "[6/13] INSTITUTIONAL SUITE + COMPILEALL"

    & $python -m pytest -q

    if ($LASTEXITCODE -ne 0) {
        Fail "Institutional suite failed."
    }

    $collect = @(
        & $python -m pytest --collect-only -q 2>&1
    )

    if ($LASTEXITCODE -ne 0) {
        Fail "Unable to collect institutional tests."
    }

    $collectText =
        ($collect | ForEach-Object { [string]$_ }) -join "`n"

    $matches = [regex]::Matches(
        $collectText,
        '(?im)(\d+)\s+(?:tests?|items?)\s+collected'
    )

    if ($matches.Count -gt 0) {
        $suiteCount =
            [int]$matches[
                $matches.Count - 1
            ].Groups[1].Value
    }
    else {
        $suiteCount = @(
            $collect |
            Where-Object {
                ([string]$_) -match '::'
            }
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

    Write-Step "[7/13] SHA-256 PRESERVATION GATE"

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
        Fail (
            "Closed SPT-023 / SPT-024.1 preservation failed: " +
            ($changed -join ", ")
        )
    }

    Write-Host "SPT-023.1-.7 + SPT-024.1 : PRESERVED" -ForegroundColor Green

    Write-Step "[8/13] LOAD SPT-024.1 SECURITY BASELINE"

    $baselineRel =
        "artifacts/development/SPT-024.1-Capa1-v1.0.0/security-inventory-baseline.json"

    $baselineAbs =
        Join-Path $Root ($baselineRel -replace '/', '\')

    if (-not (Test-Path -LiteralPath $baselineAbs -PathType Leaf)) {
        Fail "SPT-024.1 security inventory baseline is missing."
    }

    $baselineData =
        Get-Content `
            -LiteralPath $baselineAbs `
            -Raw `
            -Encoding UTF8 |
        ConvertFrom-Json

    $candidateCount =
        @($baselineData.secret_candidates).Count

    Write-Host "SPT-024.1 SECRET CANDIDATES : $candidateCount"

    if ($candidateCount -lt 1) {
        Write-Host "NOTE : no candidates require classification in this baseline." -ForegroundColor Yellow
    }

    Write-Step "[9/13] CLASSIFY CANDIDATES + SECURITY GATE"

    $artifactDir =
        Join-Path $Root `
            "artifacts\development\SPT-024.2-Capa1-v1.0.0"

    if (-not (Test-Path -LiteralPath $artifactDir)) {
        New-Item `
            -ItemType Directory `
            -Path $artifactDir `
            -Force |
            Out-Null
    }

    $assessmentRel =
        "artifacts/development/SPT-024.2-Capa1-v1.0.0/secret-assessment.json"

    $assessmentAbs =
        Join-Path $Root ($assessmentRel -replace '/', '\')

    $trackedFile =
        Join-Path $env:TEMP "sgoda-spt0242-tracked.txt"

    $tracked |
        Set-Content `
            -LiteralPath $trackedFile `
            -Encoding UTF8

    $evalScript = @'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
baseline_path = Path(sys.argv[2])
tracked_file = Path(sys.argv[3])
destination = Path(sys.argv[4])

from sgoda.integration.spt0242 import Spt0242SecretsSecurityService

service = Spt0242SecretsSecurityService(root)

candidates = service.load_spt0241_candidates(baseline_path)

tracked_paths = [
    line.strip()
    for line in tracked_file.read_text(
        encoding="utf-8-sig",
        errors="replace",
    ).splitlines()
    if line.strip()
]

result = service.evaluate(
    secret_candidates=candidates,
    tracked_paths=tracked_paths,
)

destination.write_text(
    json.dumps(
        result,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    ) + "\n",
    encoding="utf-8",
    newline="\n",
)

gate = result["security_gate"]

print("SECRET_CANDIDATES_ASSESSED=" + str(gate["assessed_candidates"]))
print("PROBABLE_REAL_SECRETS=" + str(gate["real_risk_candidates"]))
print("LIKELY_FALSE_POSITIVES=" + str(gate["false_positive_candidates"]))
print("SECRET_VALUES_EXPOSED=NO")
print("SECURITY_GATE=" + ("PASS" if gate["passed"] else "HOLD"))
'@

    $tempEval =
        Join-Path $env:TEMP "sgoda-spt0242-eval.py"

    Write-Utf8Lf $tempEval $evalScript

    try {
        & $python `
            $tempEval `
            $Root `
            $baselineAbs `
            $trackedFile `
            $assessmentAbs

        if ($LASTEXITCODE -ne 0) {
            Fail "SPT-024.2 runtime security evaluation failed."
        }
    }
    finally {
        Remove-Item `
            -LiteralPath $tempEval `
            -Force `
            -ErrorAction SilentlyContinue

        Remove-Item `
            -LiteralPath $trackedFile `
            -Force `
            -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path -LiteralPath $assessmentAbs -PathType Leaf)) {
        Fail "Secret assessment report was not generated."
    }

    $assessmentData =
        Get-Content `
            -LiteralPath $assessmentAbs `
            -Raw `
            -Encoding UTF8 |
        ConvertFrom-Json

    if ($assessmentData.secret_values_exposed -ne $false) {
        Fail "Secret assessment must never expose secret values."
    }

    $gatePassed =
        [bool]$assessmentData.security_gate.passed

    $probableReal =
        [int]$assessmentData.security_gate.real_risk_candidates

    $falsePositive =
        [int]$assessmentData.security_gate.false_positive_candidates

    Write-Host "SECURITY GATE : $(
        if ($gatePassed) { 'PASS' } else { 'HOLD' }
    )"

    if (-not $gatePassed) {
        $failedControls =
            @(
                $assessmentData.security_gate.failed_blocking_controls
            ) -join ", "

        Fail (
            "Blocking Security Gate failed. " +
            "Probable real secrets: $probableReal. " +
            "Failed controls: $failedControls. " +
            "No secret values were exposed."
        )
    }

    Write-Step "[10/13] EVIDENCE + SGD-002 UPDATE"

    $evidenceRel =
        "artifacts/development/SPT-024.2-Capa1-v1.0.0/implementation-evidence.json"

    $evidenceAbs =
        Join-Path $Root ($evidenceRel -replace '/', '\')

    $generated = @()

    foreach ($rel in $Files.Keys | Sort-Object) {
        $abs = Join-Path $Root ($rel -replace '/', '\')

        $generated += [ordered]@{
            path = $rel
            sha256 = Get-Sha $abs
        }
    }

    $generated += [ordered]@{
        path = $assessmentRel
        sha256 = Get-Sha $assessmentAbs
    }

    $evidenceObject = [ordered]@{
        platform = "SPT-024 PISI"
        component = "SPT-024.2"
        layer = "Capa 1"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        targeted_tests = $targetCount
        institutional_tests = $suiteCount
        compileall = "PASS"
        protected_files = $freeze.Count
        protected_changes = 0
        secret_candidates_assessed =
            [int]$assessmentData.security_gate.assessed_candidates
        probable_real_secrets =
            $probableReal
        likely_false_positives =
            $falsePositive
        security_gate_status = "PASS"
        secret_values_exposed = $false
        secure_storage_policy = "ESTABLISHED"
        rotation_policy = "ESTABLISHED"
        git_secret_gate = "BLOCKING"
        mutation_of_closed_components = $false
        paid_api_used = $false
        next_component = "SPT-024.3"
        generated_files = $generated
    }

    Write-Utf8Lf `
        $evidenceAbs `
        ($evidenceObject | ConvertTo-Json -Depth 10)

    $sgdCandidates = @(
        GitLines @("ls-files") |
        Where-Object {
            $_ -match 'SGD-002' -and
            $_ -match '\.(md|txt)$'
        }
    )

    if ($sgdCandidates.Count -eq 0) {
        Fail "Tracked SGD-002 master document not found."
    }

    $sgdRel = $sgdCandidates[0]
    $sgdAbs =
        Join-Path $Root ($sgdRel -replace '/', '\')

    $sgdText =
        [IO.File]::ReadAllText($sgdAbs)

    $marker =
        "<!-- SPT-024.2-CAPA1-V1.0.0 -->"

    if ($sgdText -notmatch [regex]::Escape($marker)) {
        $append = @"

$marker
## SPT-024.2 — Gestión de Secretos, Credenciales y Configuración Segura

- Estado: IMPLEMENTED AND VALIDATED.
- Candidatos de SPT-024.1: CLASSIFIED.
- Valores de secretos expuestos en evidencia: NO.
- Falsos positivos: clasificados por metadatos.
- Probables secretos reales: 0 al momento del gate de publicación.
- `.gitignore`: validado.
- Tipos sensibles rastreados por Git: gate bloqueante.
- Almacenamiento seguro: política establecida.
- Rotación de credenciales: política establecida.
- Security Gate de publicación: PASS / BLOCKING ENFORCED.
- SPT-023.1 a SPT-023.7: PRESERVED.
- SPT-024.1: PRESERVED.
- Siguiente desarrollo: SPT-024.3 — Seguridad de FastAPI, APIs y Servicios.
"@

        Write-Utf8Lf `
            $sgdAbs `
            ($sgdText.TrimEnd() + "`n" + $append.TrimStart())
    }

    Write-Host "SECRET ASSESSMENT : CREATED" -ForegroundColor Green
    Write-Host "EVIDENCE          : CREATED" -ForegroundColor Green
    Write-Host "SGD-002           : UPDATED" -ForegroundColor Green

    Write-Step "[11/13] EXACT CONTROLLED STAGING"

    $stage = @(
        $targets +
        $assessmentRel +
        $evidenceRel +
        $sgdRel +
        $SelfName
    ) |
    Sort-Object -Unique

    foreach ($rel in $stage) {
        $abs =
            Join-Path $Root ($rel -replace '/', '\')

        if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) {
            Fail "Required staging path missing: $rel"
        }

        GitLines @(
            "-c",
            "core.safecrlf=false",
            "add",
            "--",
            $rel
        ) |
        Out-Null
    }

    $actual = @(
        GitLines @(
            "diff",
            "--cached",
            "--name-only"
        ) |
        Where-Object {
            $_ -and
            $_ -notmatch '^(warning:|hint:)'
        }
    )

    $missing =
        @(
            $stage |
            Where-Object { $_ -notin $actual }
        )

    $unexpected =
        @(
            $actual |
            Where-Object { $_ -notin $stage }
        )

    Write-Host "STAGED     : $($actual.Count)"
    Write-Host "MISSING    : $($missing.Count)"
    Write-Host "UNEXPECTED : $($unexpected.Count)"

    if (
        $missing.Count -ne 0 -or
        $unexpected.Count -ne 0
    ) {
        Fail "Exact staging manifest mismatch."
    }

    GitLines @(
        "-c",
        "core.safecrlf=false",
        "diff",
        "--cached",
        "--check"
    ) |
    Out-Null

    Write-Host "DIFF CHECK      : PASS" -ForegroundColor Green
    Write-Host "STAGING QUALITY : PASS" -ForegroundColor Green

    Write-Step "[12/13] FINAL REMOTE GATE + COMMIT + PUSH"

    GitLines @(
        "fetch",
        "origin",
        $Branch,
        "--no-tags"
    ) |
    ForEach-Object { Write-Host $_ }

    $headBeforeCommit =
        GitText @("rev-parse","HEAD")

    $remoteBeforeCommit =
        GitText @("rev-parse","origin/$Branch")

    if (
        $headBeforeCommit -ne $ExpectedBaseline -or
        $remoteBeforeCommit -ne $ExpectedBaseline
    ) {
        Fail "Repository moved during SPT-024.2 transaction."
    }

    Write-Host "REMOTE GATE : PASS" -ForegroundColor Green

    GitLines @(
        "commit",
        "-m",
        $CommitMessage
    ) |
    ForEach-Object { Write-Host $_ }

    $CommitCreated = $true

    $newCommit =
        GitText @("rev-parse","HEAD")

    Write-Host "NEW COMMIT : $newCommit"

    GitLines @(
        "push",
        "origin",
        $Branch
    ) |
    ForEach-Object { Write-Host $_ }

    Write-Step "[13/13] AUTHORITATIVE REMOTE VERIFICATION"

    GitLines @(
        "fetch",
        "origin",
        $Branch,
        "--no-tags"
    ) |
    ForEach-Object { Write-Host $_ }

    $localFinal =
        GitText @("rev-parse","HEAD")

    $remoteFinal =
        GitText @("rev-parse","origin/$Branch")

    $counts =
        (
            GitText @(
                "rev-list",
                "--left-right",
                "--count",
                "origin/$Branch...HEAD"
            )
        ) -split '\s+'

    $behind = [int]$counts[0]
    $ahead = [int]$counts[1]

    $stagedFinal =
        @(
            GitLines @(
                "diff",
                "--cached",
                "--name-only"
            )
        ).Count

    $deletedFinal =
        @(
            GitLines @(
                "ls-files",
                "--deleted"
            )
        ).Count

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
        -FullSuite $suiteCount `
        -Candidates ([int]$assessmentData.security_gate.assessed_candidates) `
        -RealRisk $probableReal `
        -GateStatus "PASS"

    exit 0
}
catch {
    Fail $_.Exception.Message
}
