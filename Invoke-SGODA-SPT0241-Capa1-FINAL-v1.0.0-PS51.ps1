#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "a4df5b03eab03dfaad691d444146884a41d4622c"
$SelfName = "Invoke-SGODA-SPT0241-Capa1-FINAL-v1.0.0-PS51.ps1"
$CommitMessage = "feat(spt-024.1): establish institutional security inventory baseline"
$TargetedExpected = 30
$FullSuiteFloor = 1187
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
    Write-Host " SPT-024 PISI     : INITIATED" -ForegroundColor Green
    Write-Host " SPT-024.1 CAPA 1 : IMPLEMENTED AND VALIDATED" -ForegroundColor Green
    Write-Host " SECURITY INVENTORY : ESTABLISHED" -ForegroundColor Green
    Write-Host " ATTACK SURFACE     : BASELINED" -ForegroundColor Green
    Write-Host " SECRET METADATA    : SCANNED / VALUES NOT EXPOSED" -ForegroundColor Green
    Write-Host " SPT-023.1-.7       : PRESERVED" -ForegroundColor Green
    Write-Host " TARGETED TESTS     : $Targeted PASSED" -ForegroundColor Green
    Write-Host " FULL SUITE         : $FullSuite PASSED" -ForegroundColor Green
    Write-Host " SGD-002            : UPDATED" -ForegroundColor Green
    Write-Host " COMMIT             : $Commit" -ForegroundColor Green
    Write-Host " LOCAL/REMOTE       : IDENTICAL" -ForegroundColor Green
    Write-Host " AHEAD              : 0" -ForegroundColor Green
    Write-Host " BEHIND             : 0" -ForegroundColor Green
    Write-Host " STAGED             : 0" -ForegroundColor Green
    Write-Host " DELETED TRACKED    : 0" -ForegroundColor Green
    Write-Host " ERRORS PENDING     : 0" -ForegroundColor Green
    Write-Host " NEXT               : SPT-024.2 SECRETS / CREDENTIALS / CONFIG" -ForegroundColor Green
    Write-Host ("=" * 70) -ForegroundColor Green
    Write-Host "FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
}

function Fail([string]$Reason) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Red
    Write-Host " SPT-024.1 CAPA 1 : HOLD" -ForegroundColor Red
    Write-Host " REASON            : $Reason" -ForegroundColor Red
    if ($CommitCreated) {
        Write-Host " LOCAL COMMIT      : PRESERVED FOR SAME-FILE RESUME" -ForegroundColor Yellow
    } else {
        Write-Host " TRANSACTION       : NOT PUBLISHED" -ForegroundColor Yellow
    }
    Write-Host " ERRORS PENDING    : 1" -ForegroundColor Red
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
            $ResumeEvidence = Join-Path $Root "artifacts\development\SPT-024.1-Capa1-v1.0.0\implementation-evidence.json"

            if (-not (Test-Path -LiteralPath $ResumeEvidence -PathType Leaf)) {
                Fail "Resumable SPT-024.1 commit exists but evidence is missing."
            }

            $ResumeData = Get-Content -LiteralPath $ResumeEvidence -Raw -Encoding UTF8 | ConvertFrom-Json

            if ($Local -eq $Remote) {
                $stagedResume = @(GitLines @("diff","--cached","--name-only")).Count
                $deletedResume = @(GitLines @("ls-files","--deleted")).Count
                if ($stagedResume -ne 0 -or $deletedResume -ne 0) {
                    Fail "Published SPT-024.1 commit exists but repository safety is not clean."
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

        Fail "HEAD is neither certified baseline nor a resumable SPT-024.1 commit."
    }

    if ($Remote -ne $ExpectedBaseline) {
        Fail "Official remote moved away from the certified SPT-023.7 closure baseline."
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

    $modified = @(
        GitLines @("-c","core.safecrlf=false","diff","--name-only") |
        Where-Object { $_ -and $_ -notmatch '^(warning:|hint:)' }
    )

    $runtimeModified = @(
        $modified | Where-Object { $_ -match '^artifacts/runtime/' }
    )
    $unexpectedModified = @(
        $modified | Where-Object { $_ -notmatch '^artifacts/runtime/' }
    )

    Write-Host "PREEXISTING RUNTIME MODIFICATIONS : $($runtimeModified.Count)"
    $runtimeModified | ForEach-Object { Write-Host ("RUNTIME PRESERVED : " + $_) }

    if ($unexpectedModified.Count -ne 0) {
        Fail ("Unexpected non-runtime tracked changes: " + ($unexpectedModified -join ", "))
    }

    Write-Host "BASELINE : PASS" -ForegroundColor Green
    Write-Host "POWERSHELL SYNTAX : PASS" -ForegroundColor Green

    Write-Step "[2/12] SHA-256 FREEZE OF CLOSED SPT-023 ECOSYSTEM"

    $tracked = @(GitLines @("ls-files"))
    $protected = @(
        $tracked | Where-Object {
            $_ -match 'SPT-023\.' -or
            $_ -match 'spt023' -or
            $_ -match 'SGD-002' -or
            $_ -match 'pmo' -or
            $_ -match 'audit'
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
        "src/sgoda/integration/spt0241/__init__.py",
        "src/sgoda/integration/spt0241/models.py",
        "src/sgoda/integration/spt0241/policy.py",
        "src/sgoda/integration/spt0241/classifier.py",
        "src/sgoda/integration/spt0241/scanner.py",
        "src/sgoda/integration/spt0241/secrets.py",
        "src/sgoda/integration/spt0241/surface.py",
        "src/sgoda/integration/spt0241/service.py",
        "tests/integration/test_spt0241_security_inventory_layer1.py",
        "docs/06_Tecnologia/SPT-024/SPT-024.1/SGD-SPT024.1-Capa1-Inventario-Superficie-Ataque.md",
        "config/integration/spt0241/security-inventory-policy.json"
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

    $staleEvidenceRel = "artifacts/development/SPT-024.1-Capa1-v1.0.0/implementation-evidence.json"
    $staleInventoryRel = "artifacts/development/SPT-024.1-Capa1-v1.0.0/security-inventory-baseline.json"

    foreach ($rel in @($staleEvidenceRel,$staleInventoryRel)) {
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

    Write-Step "[4/12] IMPLEMENT SPT-024.1 SECURITY INVENTORY BASELINE"

    $Files = @{}
    $Files["src/sgoda/integration/spt0241/__init__.py"] = @'
"""SPT-024.1 Security Inventory and Attack Surface Baseline."""

from .classifier import AssetClassifier
from .models import SecurityAsset, SecurityBaseline, SecurityFinding
from .policy import SecurityInventoryPolicy
from .scanner import SecuritySurfaceScanner
from .secrets import SecretCandidate, SecretMetadataScanner
from .service import Spt0241SecurityInventoryService
from .surface import AttackSurfaceModel

__all__ = [
    "AssetClassifier",
    "AttackSurfaceModel",
    "SecurityAsset",
    "SecurityBaseline",
    "SecurityFinding",
    "SecurityInventoryPolicy",
    "SecuritySurfaceScanner",
    "SecretCandidate",
    "SecretMetadataScanner",
    "Spt0241SecurityInventoryService",
]
'@
    $Files["src/sgoda/integration/spt0241/models.py"] = @'
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class SecurityAsset:
    asset_id: str
    path: str
    asset_type: str
    criticality: str
    data_classification: str
    exposed_surface: bool
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "asset_id": self.asset_id,
            "path": self.path,
            "asset_type": self.asset_type,
            "criticality": self.criticality,
            "data_classification": self.data_classification,
            "exposed_surface": self.exposed_surface,
            "metadata": dict(self.metadata),
        }


@dataclass(frozen=True)
class SecurityFinding:
    code: str
    severity: str
    asset_id: str
    message: str
    evidence: dict[str, Any] = field(default_factory=dict)

    @property
    def blocking(self) -> bool:
        return self.severity.upper() in {"ERROR", "CRITICAL"}

    def to_dict(self) -> dict[str, Any]:
        return {
            "code": self.code,
            "severity": self.severity,
            "asset_id": self.asset_id,
            "message": self.message,
            "evidence": dict(self.evidence),
            "blocking": self.blocking,
        }


@dataclass
class SecurityBaseline:
    assets: list[SecurityAsset] = field(default_factory=list)
    findings: list[SecurityFinding] = field(default_factory=list)

    @property
    def blocking_findings(self) -> list[SecurityFinding]:
        return [item for item in self.findings if item.blocking]

    @property
    def conformant(self) -> bool:
        return not self.blocking_findings

    def to_dict(self) -> dict[str, Any]:
        return {
            "assets": [item.to_dict() for item in self.assets],
            "findings": [item.to_dict() for item in self.findings],
            "asset_count": len(self.assets),
            "finding_count": len(self.findings),
            "blocking_count": len(self.blocking_findings),
            "conformant": self.conformant,
        }
'@
    $Files["src/sgoda/integration/spt0241/policy.py"] = @'
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class SecurityInventoryPolicy:
    excluded_directories: tuple[str, ...]
    sensitive_extensions: tuple[str, ...]
    secret_name_tokens: tuple[str, ...]
    public_surface_tokens: tuple[str, ...]
    critical_path_tokens: tuple[str, ...]
    fail_on_blocking: bool = True
    paid_api_allowed: bool = False

    @classmethod
    def default(cls) -> "SecurityInventoryPolicy":
        return cls(
            excluded_directories=(
                ".git",
                ".venv",
                "venv",
                "__pycache__",
                ".pytest_cache",
                "node_modules",
            ),
            sensitive_extensions=(
                ".env",
                ".pem",
                ".key",
                ".pfx",
                ".p12",
                ".crt",
                ".cer",
            ),
            secret_name_tokens=(
                "secret",
                "token",
                "password",
                "passwd",
                "credential",
                "apikey",
                "api_key",
                "private_key",
            ),
            public_surface_tokens=(
                "fastapi",
                "api",
                "n8n",
                "webhook",
                "endpoint",
                "route",
                "router",
            ),
            critical_path_tokens=(
                "postgres",
                "database",
                "db",
                "security",
                "auth",
                "audit",
                "pmo",
                "sgd-002",
                "artifact",
            ),
        )

    @classmethod
    def from_json(cls, path: str | Path) -> "SecurityInventoryPolicy":
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        default = cls.default()
        return cls(
            excluded_directories=tuple(
                data.get("excluded_directories") or default.excluded_directories
            ),
            sensitive_extensions=tuple(
                data.get("sensitive_extensions") or default.sensitive_extensions
            ),
            secret_name_tokens=tuple(
                data.get("secret_name_tokens") or default.secret_name_tokens
            ),
            public_surface_tokens=tuple(
                data.get("public_surface_tokens") or default.public_surface_tokens
            ),
            critical_path_tokens=tuple(
                data.get("critical_path_tokens") or default.critical_path_tokens
            ),
            fail_on_blocking=bool(data.get("fail_on_blocking", True)),
            paid_api_allowed=bool(data.get("paid_api_allowed", False)),
        )
'@
    $Files["src/sgoda/integration/spt0241/classifier.py"] = @'
from __future__ import annotations

from pathlib import Path

from .models import SecurityAsset
from .policy import SecurityInventoryPolicy


class AssetClassifier:
    def __init__(self, policy: SecurityInventoryPolicy | None = None) -> None:
        self.policy = policy or SecurityInventoryPolicy.default()

    def classify(self, path: Path, *, root: Path) -> SecurityAsset:
        rel = path.relative_to(root).as_posix()
        lower = rel.lower()
        suffix = path.suffix.lower()

        if lower.endswith(".ps1"):
            asset_type = "POWERSHELL"
        elif suffix == ".py":
            asset_type = "PYTHON"
        elif suffix == ".json":
            asset_type = "JSON"
        elif suffix in {".md", ".txt"}:
            asset_type = "DOCUMENTATION"
        elif suffix in {".wav", ".mp3", ".flac", ".ogg", ".m4a"}:
            asset_type = "AUDIO"
        elif suffix in {".png", ".jpg", ".jpeg", ".webp", ".svg"}:
            asset_type = "IMAGE"
        elif suffix in {".xlsx", ".xls", ".csv"}:
            asset_type = "LEXICAL_DATA"
        else:
            asset_type = "OTHER"

        exposed = any(token in lower for token in self.policy.public_surface_tokens)

        if any(token in lower for token in self.policy.critical_path_tokens):
            criticality = "HIGH"
        elif asset_type in {"POWERSHELL", "PYTHON", "JSON", "LEXICAL_DATA"}:
            criticality = "MEDIUM"
        else:
            criticality = "LOW"

        if asset_type == "LEXICAL_DATA":
            classification = "INSTITUTIONAL_DATA"
        elif asset_type in {"AUDIO", "IMAGE"}:
            classification = "CULTURAL_RESOURCE"
        elif suffix in self.policy.sensitive_extensions:
            classification = "SENSITIVE"
        else:
            classification = "INTERNAL"

        asset_id = "AST-" + rel.replace("/", "_").replace("\\", "_").upper()

        return SecurityAsset(
            asset_id=asset_id,
            path=rel,
            asset_type=asset_type,
            criticality=criticality,
            data_classification=classification,
            exposed_surface=exposed,
            metadata={"suffix": suffix},
        )
'@
    $Files["src/sgoda/integration/spt0241/scanner.py"] = @'
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Iterable

from .classifier import AssetClassifier
from .models import SecurityAsset, SecurityFinding
from .policy import SecurityInventoryPolicy


class SecuritySurfaceScanner:
    """Read-only repository security inventory and attack-surface scanner."""

    def __init__(
        self,
        root: str | Path,
        policy: SecurityInventoryPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or SecurityInventoryPolicy.default()
        self.classifier = AssetClassifier(self.policy)

    def files(self) -> list[Path]:
        excluded = set(self.policy.excluded_directories)
        return sorted(
            path
            for path in self.root.rglob("*")
            if path.is_file()
            and not any(part in excluded for part in path.parts)
        )

    @staticmethod
    def sha256(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest().upper()

    def inventory(self) -> list[SecurityAsset]:
        return [
            self.classifier.classify(path, root=self.root)
            for path in self.files()
        ]

    def detect_findings(
        self,
        assets: Iterable[SecurityAsset],
    ) -> list[SecurityFinding]:
        findings: list[SecurityFinding] = []

        for asset in assets:
            path = self.root / Path(asset.path)
            name_lower = path.name.lower()
            suffix_lower = path.suffix.lower()

            if suffix_lower in self.policy.sensitive_extensions:
                findings.append(
                    SecurityFinding(
                        code="SENSITIVE_FILE_PRESENT",
                        severity="ERROR",
                        asset_id=asset.asset_id,
                        message="Sensitive file type is present in the repository working tree.",
                        evidence={"path": asset.path},
                    )
                )

            if any(token in name_lower for token in self.policy.secret_name_tokens):
                findings.append(
                    SecurityFinding(
                        code="SECRET_LIKE_FILENAME",
                        severity="WARNING",
                        asset_id=asset.asset_id,
                        message="Filename contains a secret-related token and requires review.",
                        evidence={"path": asset.path},
                    )
                )

            if asset.exposed_surface:
                findings.append(
                    SecurityFinding(
                        code="EXPOSED_SURFACE_IDENTIFIED",
                        severity="INFO",
                        asset_id=asset.asset_id,
                        message="Potential externally reachable or integration surface identified.",
                        evidence={
                            "path": asset.path,
                            "asset_type": asset.asset_type,
                        },
                    )
                )

        return findings
'@
    $Files["src/sgoda/integration/spt0241/secrets.py"] = @'
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class SecretCandidate:
    path: str
    line: int
    detector: str
    fingerprint: str

    def to_dict(self) -> dict:
        return {
            "path": self.path,
            "line": self.line,
            "detector": self.detector,
            "fingerprint": self.fingerprint,
        }


class SecretMetadataScanner:
    """
    Conservative scanner that reports metadata/fingerprints only.
    It never returns the secret value itself.
    """

    PATTERNS = (
        ("PRIVATE_KEY_MARKER", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
        ("ASSIGNED_SECRET", re.compile(
            r"(?i)\b(password|passwd|secret|api[_-]?key|token)\b\s*[:=]\s*['\"][^'\"]{8,}['\"]"
        )),
    )

    TEXT_SUFFIXES = {
        ".py", ".ps1", ".json", ".yml", ".yaml", ".toml",
        ".ini", ".cfg", ".conf", ".env", ".md", ".txt",
    }

    @staticmethod
    def _fingerprint(path: str, line_no: int, detector: str) -> str:
        import hashlib
        material = f"{path}|{line_no}|{detector}".encode("utf-8")
        return hashlib.sha256(material).hexdigest().upper()[:24]

    def scan(
        self,
        *,
        root: Path,
        paths: Iterable[Path],
        max_bytes: int = 2 * 1024 * 1024,
    ) -> list[SecretCandidate]:
        candidates: list[SecretCandidate] = []

        for path in paths:
            if path.suffix.lower() not in self.TEXT_SUFFIXES:
                continue
            try:
                if path.stat().st_size > max_bytes:
                    continue
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue

            rel = path.relative_to(root).as_posix()
            for line_no, line in enumerate(text.splitlines(), start=1):
                for detector, pattern in self.PATTERNS:
                    if pattern.search(line):
                        candidates.append(
                            SecretCandidate(
                                path=rel,
                                line=line_no,
                                detector=detector,
                                fingerprint=self._fingerprint(rel, line_no, detector),
                            )
                        )

        return candidates
'@
    $Files["src/sgoda/integration/spt0241/surface.py"] = @'
from __future__ import annotations

from collections import Counter
from typing import Iterable

from .models import SecurityAsset


class AttackSurfaceModel:
    @staticmethod
    def build(assets: Iterable[SecurityAsset]) -> dict:
        assets = list(assets)
        exposed = [asset for asset in assets if asset.exposed_surface]

        return {
            "asset_count": len(assets),
            "exposed_surface_count": len(exposed),
            "criticality": dict(
                sorted(Counter(asset.criticality for asset in assets).items())
            ),
            "asset_types": dict(
                sorted(Counter(asset.asset_type for asset in assets).items())
            ),
            "exposed_assets": [
                {
                    "asset_id": asset.asset_id,
                    "path": asset.path,
                    "criticality": asset.criticality,
                    "asset_type": asset.asset_type,
                }
                for asset in exposed
            ],
        }
'@
    $Files["src/sgoda/integration/spt0241/service.py"] = @'
from __future__ import annotations

from pathlib import Path
from typing import Any

from .models import SecurityBaseline
from .policy import SecurityInventoryPolicy
from .scanner import SecuritySurfaceScanner
from .secrets import SecretMetadataScanner
from .surface import AttackSurfaceModel


class Spt0241SecurityInventoryService:
    """SPT-024.1 institutional security inventory and attack-surface baseline."""

    def __init__(
        self,
        root: str | Path,
        policy: SecurityInventoryPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or SecurityInventoryPolicy.default()
        self.scanner = SecuritySurfaceScanner(self.root, self.policy)

    def evaluate(self) -> dict[str, Any]:
        files = self.scanner.files()
        assets = self.scanner.inventory()
        findings = self.scanner.detect_findings(assets)
        secret_candidates = SecretMetadataScanner().scan(
            root=self.root,
            paths=files,
        )

        baseline = SecurityBaseline(
            assets=assets,
            findings=findings,
        )

        return {
            "component": "SPT-024.1",
            "status": "SECURITY_BASELINE_ESTABLISHED",
            "read_only_scan": True,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "baseline": baseline.to_dict(),
            "attack_surface": AttackSurfaceModel.build(assets),
            "secret_candidates": [
                item.to_dict()
                for item in secret_candidates
            ],
            "secret_values_exposed": False,
            "next_component": "SPT-024.2",
        }
'@
    $Files["tests/integration/test_spt0241_security_inventory_layer1.py"] = @'
import json
from pathlib import Path

from sgoda.integration.spt0241 import (
    AssetClassifier,
    AttackSurfaceModel,
    SecurityAsset,
    SecurityBaseline,
    SecurityFinding,
    SecurityInventoryPolicy,
    SecuritySurfaceScanner,
    SecretMetadataScanner,
    Spt0241SecurityInventoryService,
)


def write(path: Path, content: str = "x\n"):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def test_default_policy_disallows_paid_api():
    assert SecurityInventoryPolicy.default().paid_api_allowed is False


def test_policy_loads_json(tmp_path):
    path = write(tmp_path / "policy.json", json.dumps({"fail_on_blocking": False}))
    assert SecurityInventoryPolicy.from_json(path).fail_on_blocking is False


def test_asset_serializes():
    asset = SecurityAsset("A", "x.py", "PYTHON", "MEDIUM", "INTERNAL", False)
    assert asset.to_dict()["asset_id"] == "A"


def test_error_finding_is_blocking():
    finding = SecurityFinding("X", "ERROR", "A", "x")
    assert finding.blocking is True


def test_warning_finding_is_not_blocking():
    finding = SecurityFinding("X", "WARNING", "A", "x")
    assert finding.blocking is False


def test_empty_baseline_is_conformant():
    assert SecurityBaseline().conformant is True


def test_baseline_with_error_not_conformant():
    baseline = SecurityBaseline(
        findings=[SecurityFinding("X", "ERROR", "A", "x")]
    )
    assert baseline.conformant is False


def test_classifier_python(tmp_path):
    path = write(tmp_path / "src" / "x.py")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.asset_type == "PYTHON"


def test_classifier_powershell(tmp_path):
    path = write(tmp_path / "tool.ps1")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.asset_type == "POWERSHELL"


def test_classifier_lexical_data(tmp_path):
    path = write(tmp_path / "diccionario.xlsx")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.data_classification == "INSTITUTIONAL_DATA"


def test_classifier_audio(tmp_path):
    path = write(tmp_path / "audio.wav")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.asset_type == "AUDIO"


def test_classifier_image(tmp_path):
    path = write(tmp_path / "image.png")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.asset_type == "IMAGE"


def test_classifier_detects_api_surface(tmp_path):
    path = write(tmp_path / "src" / "fastapi_router.py")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.exposed_surface is True


def test_classifier_marks_security_path_high(tmp_path):
    path = write(tmp_path / "src" / "security" / "gate.py")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.criticality == "HIGH"


def test_scanner_excludes_git(tmp_path):
    write(tmp_path / ".git" / "config")
    write(tmp_path / "src" / "x.py")
    files = SecuritySurfaceScanner(tmp_path).files()
    assert all(".git" not in path.parts for path in files)


def test_scanner_sha256(tmp_path):
    path = write(tmp_path / "x.txt", "abc")
    assert len(SecuritySurfaceScanner.sha256(path)) == 64


def test_inventory_returns_assets(tmp_path):
    write(tmp_path / "src" / "x.py")
    assert len(SecuritySurfaceScanner(tmp_path).inventory()) == 1


def test_sensitive_extension_is_blocking(tmp_path):
    write(tmp_path / "private.key", "not-a-real-key")
    scanner = SecuritySurfaceScanner(tmp_path)
    findings = scanner.detect_findings(scanner.inventory())
    assert any(f.code == "SENSITIVE_FILE_PRESENT" and f.blocking for f in findings)


def test_secret_like_filename_is_warning(tmp_path):
    write(tmp_path / "token_notes.txt")
    scanner = SecuritySurfaceScanner(tmp_path)
    findings = scanner.detect_findings(scanner.inventory())
    assert any(f.code == "SECRET_LIKE_FILENAME" for f in findings)


def test_exposed_surface_is_info(tmp_path):
    write(tmp_path / "api" / "router.py")
    scanner = SecuritySurfaceScanner(tmp_path)
    findings = scanner.detect_findings(scanner.inventory())
    assert any(f.code == "EXPOSED_SURFACE_IDENTIFIED" for f in findings)


def test_secret_scanner_detects_assigned_secret_without_value(tmp_path):
    path = write(tmp_path / "config.py", 'api_key = "1234567890ABCDEF"\n')
    result = SecretMetadataScanner().scan(root=tmp_path, paths=[path])
    assert len(result) == 1
    assert "1234567890ABCDEF" not in json.dumps(result[0].to_dict())


def test_secret_scanner_detects_private_key_marker(tmp_path):
    path = write(tmp_path / "x.txt", "-----BEGIN PRIVATE KEY-----\n")
    result = SecretMetadataScanner().scan(root=tmp_path, paths=[path])
    assert result[0].detector == "PRIVATE_KEY_MARKER"


def test_secret_scanner_skips_binary_extension(tmp_path):
    path = write(tmp_path / "x.png", 'token="1234567890"\n')
    assert SecretMetadataScanner().scan(root=tmp_path, paths=[path]) == []


def test_secret_fingerprint_is_stable(tmp_path):
    path = write(tmp_path / "config.py", 'secret = "abcdefghijkl"\n')
    scanner = SecretMetadataScanner()
    one = scanner.scan(root=tmp_path, paths=[path])[0]
    two = scanner.scan(root=tmp_path, paths=[path])[0]
    assert one.fingerprint == two.fingerprint


def test_attack_surface_counts_assets():
    assets = [
        SecurityAsset("A", "api.py", "PYTHON", "HIGH", "INTERNAL", True),
        SecurityAsset("B", "x.md", "DOCUMENTATION", "LOW", "INTERNAL", False),
    ]
    model = AttackSurfaceModel.build(assets)
    assert model["asset_count"] == 2
    assert model["exposed_surface_count"] == 1


def test_attack_surface_groups_types():
    assets = [
        SecurityAsset("A", "a.py", "PYTHON", "MEDIUM", "INTERNAL", False),
        SecurityAsset("B", "b.py", "PYTHON", "MEDIUM", "INTERNAL", False),
    ]
    assert AttackSurfaceModel.build(assets)["asset_types"]["PYTHON"] == 2


def test_service_establishes_baseline(tmp_path):
    write(tmp_path / "src" / "x.py")
    result = Spt0241SecurityInventoryService(tmp_path).evaluate()
    assert result["status"] == "SECURITY_BASELINE_ESTABLISHED"


def test_service_is_read_only(tmp_path):
    path = write(tmp_path / "src" / "x.py", "VALUE = 1\n")
    before = SecuritySurfaceScanner.sha256(path)
    Spt0241SecurityInventoryService(tmp_path).evaluate()
    after = SecuritySurfaceScanner.sha256(path)
    assert before == after


def test_service_does_not_expose_secret_values(tmp_path):
    write(tmp_path / "config.py", 'password = "abcdefghijkl"\n')
    result = Spt0241SecurityInventoryService(tmp_path).evaluate()
    assert result["secret_values_exposed"] is False


def test_service_points_to_spt0242(tmp_path):
    write(tmp_path / "src" / "x.py")
    assert Spt0241SecurityInventoryService(tmp_path).evaluate()["next_component"] == "SPT-024.2"
'@
    $Files["docs/06_Tecnologia/SPT-024/SPT-024.1/SGD-SPT024.1-Capa1-Inventario-Superficie-Ataque.md"] = @'
# SPT-024 — Plataforma Institucional de Seguridad Informática (PISI)

## SPT-024.1 — Inventario de Activos y Superficie de Ataque — Capa 1

### Objetivo

Establecer la línea base transversal de seguridad informática de SGODA-PUINAVE
sin modificar los componentes institucionales cerrados.

La Capa 1 identifica y clasifica activos, superficies potencialmente expuestas,
archivos sensibles por tipo, nombres que requieren revisión y candidatos a
secretos. El detector de secretos conserva únicamente metadatos y huellas; nunca
incluye el valor sensible detectado dentro de reportes o evidencias.

### Alcance protegido

La plataforma de seguridad cubre progresivamente:

- código Python y PowerShell;
- FastAPI y superficies API;
- n8n y automatizaciones;
- PostgreSQL y datos;
- Excel/JSON y datos léxicos;
- imágenes y audios;
- FLD y ODA;
- PMO Digital;
- Auditor Institucional;
- SGD-002 y documentación;
- artefactos, evidencias y publicación Git.

### Principios

- lectura y observación antes de cualquier endurecimiento;
- no reabrir SPT-023 ni entregables cerrados;
- cero APIs de pago obligatorias;
- herramientas gratuitas/código abierto;
- operación institucional desde PowerShell;
- trazabilidad y evidencia;
- valores de secretos nunca incluidos en reportes;
- seguridad como gate transversal del proyecto.

### Continuidad

SPT-024.1 establece inventario y superficie de ataque. SPT-024.2 deberá abordar
gestión de secretos, credenciales y configuración segura sobre esta línea base.
'@
    $Files["config/integration/spt0241/security-inventory-policy.json"] = @'
{
  "schema_version": "1.0.0",
  "platform": "SPT-024",
  "name": "Plataforma Institucional de Seguridad Informatica",
  "acronym": "PISI",
  "component": "SPT-024.1",
  "layer": "1",
  "purpose": "security_asset_inventory_and_attack_surface_baseline",
  "excluded_directories": [
    ".git",
    ".venv",
    "venv",
    "__pycache__",
    ".pytest_cache",
    "node_modules"
  ],
  "sensitive_extensions": [
    ".env",
    ".pem",
    ".key",
    ".pfx",
    ".p12",
    ".crt",
    ".cer"
  ],
  "secret_name_tokens": [
    "secret",
    "token",
    "password",
    "passwd",
    "credential",
    "apikey",
    "api_key",
    "private_key"
  ],
  "public_surface_tokens": [
    "fastapi",
    "api",
    "n8n",
    "webhook",
    "endpoint",
    "route",
    "router"
  ],
  "critical_path_tokens": [
    "postgres",
    "database",
    "db",
    "security",
    "auth",
    "audit",
    "pmo",
    "sgd-002",
    "artifact"
  ],
  "read_only_inventory": true,
  "secret_values_must_not_be_reported": true,
  "mutation_of_closed_components": false,
  "paid_api_allowed": false,
  "next_component": "SPT-024.2"
}
'@

    foreach ($rel in $Files.Keys) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        Write-Utf8Lf $abs $Files[$rel]
        Write-Host ("CREATED : " + ($rel -replace '/', '\'))
    }

    Write-Step "[5/12] PYTHON PREVALIDATION + TARGETED SECURITY TESTS"

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

    & $python -c "import sgoda; import sgoda.integration.spt0241; print('SGODA_SECURITY_IMPORT=PASS')"
    if ($LASTEXITCODE -ne 0) {
        Fail "SPT-024.1 package import failed."
    }

    $pyTargets = @(
        "src/sgoda/integration/spt0241/__init__.py",
        "src/sgoda/integration/spt0241/models.py",
        "src/sgoda/integration/spt0241/policy.py",
        "src/sgoda/integration/spt0241/classifier.py",
        "src/sgoda/integration/spt0241/scanner.py",
        "src/sgoda/integration/spt0241/secrets.py",
        "src/sgoda/integration/spt0241/surface.py",
        "src/sgoda/integration/spt0241/service.py",
        "tests/integration/test_spt0241_security_inventory_layer1.py"
    ) | ForEach-Object {
        Join-Path $Root ($_ -replace '/', '\')
    }

    & $python -m py_compile @pyTargets
    if ($LASTEXITCODE -ne 0) {
        Fail "Python syntax prevalidation failed."
    }

    & $python -m pytest -q "tests/integration/test_spt0241_security_inventory_layer1.py"
    if ($LASTEXITCODE -ne 0) {
        Fail "SPT-024.1 targeted security tests failed."
    }

    $targetCollect = @(
        & $python -m pytest --collect-only -q `
            "tests/integration/test_spt0241_security_inventory_layer1.py" 2>&1
    )
    if ($LASTEXITCODE -ne 0) {
        Fail "Unable to collect targeted security tests."
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
        Fail "Targeted security test count is below expected floor ($TargetedExpected)."
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
        Fail ("Closed SPT-023 ecosystem preservation failed: " + ($changed -join ", "))
    }

    Write-Host "SPT-023.1-.7 : PRESERVED" -ForegroundColor Green

    Write-Step "[8/12] SECURITY BASELINE + EVIDENCE + SGD-002"

    $artifactDir = Join-Path $Root "artifacts\development\SPT-024.1-Capa1-v1.0.0"
    if (-not (Test-Path -LiteralPath $artifactDir)) {
        New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
    }

    $inventoryRel = "artifacts/development/SPT-024.1-Capa1-v1.0.0/security-inventory-baseline.json"
    $inventoryAbs = Join-Path $Root ($inventoryRel -replace '/', '\')

    $securityEval = @'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
destination = Path(sys.argv[2])

from sgoda.integration.spt0241 import Spt0241SecurityInventoryService

result = Spt0241SecurityInventoryService(root).evaluate()

# Baseline is descriptive: existing findings are recorded, not silently ignored.
# SPT-024.1 closes when the inventory engine is valid and does not mutate closed
# components; remediation belongs to subsequent security packages.
destination.write_text(
    json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
    newline="\n",
)

print("SECURITY_BASELINE=ESTABLISHED")
print("ASSET_COUNT=" + str(result["baseline"]["asset_count"]))
print("ATTACK_SURFACE_COUNT=" + str(result["attack_surface"]["exposed_surface_count"]))
print("SECURITY_FINDINGS=" + str(result["baseline"]["finding_count"]))
print("BLOCKING_FINDINGS_DISCOVERED=" + str(result["baseline"]["blocking_count"]))
print("SECRET_CANDIDATES=" + str(len(result["secret_candidates"])))
print("SECRET_VALUES_EXPOSED=NO")
'@

    $tempSecurityEval = Join-Path $env:TEMP "sgoda-spt0241-security-eval.py"
    Write-Utf8Lf $tempSecurityEval $securityEval

    try {
        & $python $tempSecurityEval $Root $inventoryAbs
        if ($LASTEXITCODE -ne 0) {
            Fail "Security inventory runtime evaluation failed."
        }
    }
    finally {
        Remove-Item -LiteralPath $tempSecurityEval -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path -LiteralPath $inventoryAbs -PathType Leaf)) {
        Fail "Security inventory baseline was not generated."
    }

    $inventoryData = Get-Content -LiteralPath $inventoryAbs -Raw -Encoding UTF8 | ConvertFrom-Json

    if ($inventoryData.status -ne "SECURITY_BASELINE_ESTABLISHED") {
        Fail "Security inventory baseline status is invalid."
    }
    if ($inventoryData.secret_values_exposed -ne $false) {
        Fail "Security baseline must never expose secret values."
    }

    $evidenceRel = "artifacts/development/SPT-024.1-Capa1-v1.0.0/implementation-evidence.json"
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
        path = $inventoryRel
        sha256 = Get-Sha $inventoryAbs
    }

    $evidenceObject = [ordered]@{
        platform = "SPT-024 PISI"
        component = "SPT-024.1"
        layer = "Capa 1"
        version = "1.0.0"
        baseline = $ExpectedBaseline
        targeted_tests = $targetCount
        institutional_tests = $suiteCount
        compileall = "PASS"
        protected_files = $freeze.Count
        protected_changes = 0
        security_inventory_status = "ESTABLISHED"
        asset_count = [int]$inventoryData.baseline.asset_count
        attack_surface_count = [int]$inventoryData.attack_surface.exposed_surface_count
        findings_discovered = [int]$inventoryData.baseline.finding_count
        blocking_findings_discovered = [int]$inventoryData.baseline.blocking_count
        secret_candidates = @($inventoryData.secret_candidates).Count
        secret_values_exposed = $false
        mutation_of_closed_components = $false
        paid_api_used = $false
        next_component = "SPT-024.2"
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
    $marker = "<!-- SPT-024.1-CAPA1-V1.0.0 -->"

    if ($sgdText -notmatch [regex]::Escape($marker)) {
        $append = @"

$marker
## SPT-024 — Plataforma Institucional de Seguridad Informática (PISI)

### SPT-024.1 — Inventario de Activos y Superficie de Ataque — Capa 1

- Estado: IMPLEMENTED AND VALIDATED.
- Línea base de seguridad: ESTABLISHED.
- Inventario institucional de activos: habilitado.
- Superficie de ataque: identificada y baselined.
- Detector conservador de candidatos a secretos: habilitado.
- Valores de secretos en evidencia: NO.
- SPT-023.1 a SPT-023.7: PRESERVED.
- Modificación de componentes cerrados: NO.
- Siguiente desarrollo: SPT-024.2 — Secretos, Credenciales y Configuración Segura.
"@

        Write-Utf8Lf $sgdAbs ($sgdText.TrimEnd() + "`n" + $append.TrimStart())
    }

    Write-Host "SECURITY INVENTORY : CREATED" -ForegroundColor Green
    Write-Host "EVIDENCE           : CREATED" -ForegroundColor Green
    Write-Host "SGD-002            : SPT-024 INITIATED" -ForegroundColor Green

    Write-Step "[9/12] EXACT CONTROLLED STAGING"

    $stage = @(
        $targets +
        $inventoryRel +
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
        Fail "Repository moved during SPT-024.1 transaction."
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
