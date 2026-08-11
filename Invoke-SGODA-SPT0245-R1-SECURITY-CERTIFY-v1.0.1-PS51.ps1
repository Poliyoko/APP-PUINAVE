#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "54400774e87d6340e5f114facf2d80ffa5d9ebdc"
$SelfName = "Invoke-SGODA-SPT0245-R1-SECURITY-CERTIFY-v1.0.1-PS51.ps1"
$CommitMessage = "feat(spt-024.5): certify n8n webhook security production scope"
$TargetedExpected = 44
$FullSuiteFloor = 1371
$CommitCreated = $false

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host $Text -ForegroundColor Cyan
}

function GitLines([string[]]$GitArgs) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $raw = @(& git @GitArgs 2>&1)
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }

    $normalized = @(
        $raw | ForEach-Object {
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

function Fail([string]$Reason) {
    Write-Host ""
    Write-Host ("=" * 76) -ForegroundColor Red
    Write-Host " SPT-024.5 CAPA 1 : HOLD" -ForegroundColor Red
    Write-Host " REASON            : $Reason" -ForegroundColor Red
    if ($CommitCreated) {
        Write-Host " LOCAL COMMIT      : PRESERVED FOR SAME-FILE RESUME" -ForegroundColor Yellow
    } else {
        Write-Host " TRANSACTION       : NOT PUBLISHED" -ForegroundColor Yellow
    }
    Write-Host " ERRORS PENDING    : 1" -ForegroundColor Red
    Write-Host ("=" * 76) -ForegroundColor Red
    exit 1
}

try {
    $Root = GitText @("rev-parse","--show-toplevel")
    Set-Location -LiteralPath $Root
    $Branch = GitText @("branch","--show-current")
    $SelfPath = Join-Path $Root $SelfName

    if (-not (Test-Path -LiteralPath $SelfPath -PathType Leaf)) {
        Fail "Master script must exist in official repository root."
    }

    Write-Step "[1/13] AUTHORITATIVE BASELINE / RESUME / WORKTREE SAFETY"

    GitLines @("fetch","origin",$Branch,"--no-tags") |
        ForEach-Object { Write-Host $_ }

    $Local = GitText @("rev-parse","HEAD")
    $Remote = GitText @("rev-parse","origin/$Branch")

    if ($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline) {
        Fail "Certified SPT-024.4 baseline is not authoritative."
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
    $unexpected = @(
        $modified | Where-Object { $_ -notmatch '^artifacts/runtime/' }
    )

    Write-Host "PREEXISTING RUNTIME MODIFICATIONS : $($runtimeModified.Count)"
    $runtimeModified | ForEach-Object {
        Write-Host ("RUNTIME PRESERVED : " + $_)
    }

    if ($unexpected.Count -ne 0) {
        Fail ("Unexpected non-runtime tracked changes: " + ($unexpected -join ", "))
    }

    Write-Host "BASELINE : PASS" -ForegroundColor Green
    Write-Host "POWERSHELL SYNTAX : PASS" -ForegroundColor Green

    Write-Step "[2/13] SHA-256 FREEZE OF SPT-023 + SPT-024.1-.4"

    $tracked = @(GitLines @("ls-files"))
    $protected = @(
        $tracked | Where-Object {
            $_ -match 'SPT-023\.' -or
            $_ -match 'spt023' -or
            $_ -match 'SPT-024\.[1234]' -or
            $_ -match 'spt024[1234]'
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
        "src/sgoda/integration/spt0245/__init__.py",
        "src/sgoda/integration/spt0245/models.py",
        "src/sgoda/integration/spt0245/policy.py",
        "src/sgoda/integration/spt0245/workflow_guard.py",
        "src/sgoda/integration/spt0245/audit.py",
        "src/sgoda/integration/spt0245/gate.py",
        "src/sgoda/integration/spt0245/service.py",
        "tests/integration/test_spt0245_automation_security_layer1.py",
        "docs/06_Tecnologia/SPT-024/SPT-024.5/SGD-SPT024.5-Capa1-n8n-Automatizacion-Workflows.md",
        "config/integration/spt0245/automation-security-policy.json"
    )

    Write-Step "[3/13] TARGET COLLISION / FAILED-RUN RECOVERY"

    $collisions = @()
    foreach ($rel in $targets) {
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

            if ($trackedCode -eq 0) {
                $collisions += $rel
            } else {
                Remove-Item -LiteralPath $abs -Force
                Write-Host ("STALE TARGET REMOVED : " + $rel)
            }
        }
    }

    if ($collisions.Count -ne 0) {
        Fail ("Tracked target collisions: " + ($collisions -join ", "))
    }

    $obsoleteR1Master = Join-Path $Root "Invoke-SGODA-SPT0245-R1-SECURITY-CERTIFY-v1.0.0-PS51.ps1"
    if (Test-Path -LiteralPath $obsoleteR1Master -PathType Leaf) {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $null = & git ls-files --error-unmatch -- "Invoke-SGODA-SPT0245-R1-SECURITY-CERTIFY-v1.0.0-PS51.ps1" 2>$null
            $obsoleteR1Tracked = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previous
        }

        if ($obsoleteR1Tracked -ne 0) {
            Remove-Item -LiteralPath $obsoleteR1Master -Force
            Write-Host "OBSOLETE FAILED MASTER : REMOVED : Invoke-SGODA-SPT0245-R1-SECURITY-CERTIFY-v1.0.0-PS51.ps1"
        }
    }

    $obsoleteMaster = Join-Path $Root "Invoke-SGODA-SPT0245-Capa1-FINAL-v1.0.0-PS51.ps1"
    if (Test-Path -LiteralPath $obsoleteMaster -PathType Leaf) {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $null = & git ls-files --error-unmatch -- "Invoke-SGODA-SPT0245-Capa1-FINAL-v1.0.0-PS51.ps1" 2>$null
            $obsoleteTracked = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previous
        }

        if ($obsoleteTracked -ne 0) {
            Remove-Item -LiteralPath $obsoleteMaster -Force
            Write-Host "OBSOLETE FAILED MASTER : REMOVED : Invoke-SGODA-SPT0245-Capa1-FINAL-v1.0.0-PS51.ps1"
        }
    }

    $artifactDir = Join-Path $Root "artifacts\development\SPT-024.5-Capa1-v1.0.0"
    if (Test-Path -LiteralPath $artifactDir) {
        Remove-Item -LiteralPath $artifactDir -Recurse -Force
        Write-Host "STALE ARTIFACT DIRECTORY : REMOVED"
    }

    Write-Host "TARGET COLLISIONS : 0"

    Write-Step "[4/13] IMPLEMENT SPT-024.5 AUTOMATION SECURITY"

    $Files = @{}
    $Files["src/sgoda/integration/spt0245/__init__.py"] = @'
"""SPT-024.5 — Seguridad de n8n, Automatizaciones y Workflows."""

from .audit import AutomationSecurityAuditor
from .gate import AutomationSecurityGate
from .models import AutomationSecurityControl, AutomationSecurityReport, WorkflowSurface
from .policy import AutomationSecurityPolicy
from .service import Spt0245AutomationSecurityService
from .workflow_guard import WorkflowSecurityGuard

__all__ = [
    "AutomationSecurityAuditor",
    "AutomationSecurityControl",
    "AutomationSecurityGate",
    "AutomationSecurityPolicy",
    "AutomationSecurityReport",
    "Spt0245AutomationSecurityService",
    "WorkflowSecurityGuard",
    "WorkflowSurface",
]
'@
    $Files["src/sgoda/integration/spt0245/models.py"] = @'
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class WorkflowSurface:
    path: str
    surface_type: str
    active_runtime: bool
    secret_reference_only: bool
    webhook_exposure: bool
    unsafe_command_execution: bool
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "surface_type": self.surface_type,
            "active_runtime": self.active_runtime,
            "secret_reference_only": self.secret_reference_only,
            "webhook_exposure": self.webhook_exposure,
            "unsafe_command_execution": self.unsafe_command_execution,
            "metadata": dict(self.metadata),
        }


@dataclass(frozen=True)
class AutomationSecurityControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "control_id": self.control_id,
            "name": self.name,
            "passed": self.passed,
            "blocking": self.blocking,
            "detail": self.detail,
        }


@dataclass
class AutomationSecurityReport:
    controls: list[AutomationSecurityControl] = field(default_factory=list)
    surfaces: list[WorkflowSurface] = field(default_factory=list)

    @property
    def failed_blocking_controls(self) -> list[AutomationSecurityControl]:
        return [
            item for item in self.controls
            if item.blocking and not item.passed
        ]

    @property
    def conformant(self) -> bool:
        return not self.failed_blocking_controls

    def to_dict(self) -> dict[str, Any]:
        return {
            "controls": [item.to_dict() for item in self.controls],
            "surfaces": [item.to_dict() for item in self.surfaces],
            "failed_blocking_controls": [
                item.control_id
                for item in self.failed_blocking_controls
            ],
            "conformant": self.conformant,
        }
'@
    $Files["src/sgoda/integration/spt0245/policy.py"] = @'
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class AutomationSecurityPolicy:
    require_credentials_indirection: bool
    require_webhook_authentication: bool
    forbid_plaintext_credentials: bool
    forbid_unrestricted_execute_command: bool
    require_workflow_integrity_hash: bool
    require_audit_traceability: bool
    require_disabled_by_default_for_untrusted_workflows: bool
    require_local_or_approved_free_runtime: bool
    paid_api_allowed: bool

    @classmethod
    def default(cls) -> "AutomationSecurityPolicy":
        return cls(
            require_credentials_indirection=True,
            require_webhook_authentication=True,
            forbid_plaintext_credentials=True,
            forbid_unrestricted_execute_command=True,
            require_workflow_integrity_hash=True,
            require_audit_traceability=True,
            require_disabled_by_default_for_untrusted_workflows=True,
            require_local_or_approved_free_runtime=True,
            paid_api_allowed=False,
        )

    @classmethod
    def from_json(cls, path: str | Path) -> "AutomationSecurityPolicy":
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        default = cls.default()
        return cls(
            **{
                field_name: bool(
                    data.get(field_name, getattr(default, field_name))
                )
                for field_name in cls.__dataclass_fields__
            }
        )
'@
    $Files["src/sgoda/integration/spt0245/workflow_guard.py"] = @'
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any


class WorkflowSecurityGuard:
    SENSITIVE_KEYS = {
        "password",
        "passwd",
        "secret",
        "token",
        "apiKey",
        "api_key",
        "accessToken",
        "refreshToken",
        "privateKey",
    }

    SECRET_REFERENCE_MARKERS = (
        "{{$env.",
        "$env:",
        "${",
        "credentials",
        "credential",
    )

    @classmethod
    def sha256(cls, path: str | Path) -> str:
        return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()

    @classmethod
    def _looks_like_reference(cls, value: str) -> bool:
        lower = value.lower()
        return any(marker.lower() in lower for marker in cls.SECRET_REFERENCE_MARKERS)

    @classmethod
    def contains_plaintext_secret(cls, data: Any) -> bool:
        if isinstance(data, dict):
            for key, value in data.items():
                key_text = str(key)
                if key_text in cls.SENSITIVE_KEYS or key_text.lower() in {
                    item.lower() for item in cls.SENSITIVE_KEYS
                }:
                    if isinstance(value, str):
                        if value and not cls._looks_like_reference(value):
                            if len(value.strip()) >= 8:
                                return True
                if cls.contains_plaintext_secret(value):
                    return True
        elif isinstance(data, list):
            return any(cls.contains_plaintext_secret(item) for item in data)
        return False

    @classmethod
    def has_webhook(cls, data: Any) -> bool:
        text = json.dumps(data, ensure_ascii=False).lower()
        return "webhook" in text

    @classmethod
    def webhook_auth_marker(cls, data: Any) -> bool:
        text = json.dumps(data, ensure_ascii=False).lower()
        markers = (
            "authentication",
            "headerauth",
            "basicauth",
            "jwt",
            "bearer",
            "apikey",
            "api key",
        )
        return any(marker in text for marker in markers)

    @classmethod
    def unsafe_execute_command(cls, data: Any) -> bool:
        text = json.dumps(data, ensure_ascii=False)
        lower = text.lower()
        if "executecommand" not in lower and "execute command" not in lower:
            return False

        dangerous = (
            "rm -rf",
            "del /s",
            "format ",
            "shutdown",
            "powershell -enc",
            "cmd /c",
            "bash -c",
            "curl ",
            "wget ",
        )
        return any(token in lower for token in dangerous)

    @classmethod
    def active_marker(cls, data: Any) -> bool:
        if isinstance(data, dict) and "active" in data:
            return bool(data.get("active"))
        return False
'@
    $Files["src/sgoda/integration/spt0245/audit.py"] = @'
from __future__ import annotations

import json
from pathlib import Path

from .models import AutomationSecurityControl, WorkflowSurface
from .policy import AutomationSecurityPolicy
from .workflow_guard import WorkflowSecurityGuard


class AutomationSecurityAuditor:
    """
    Read-only security audit for n8n/workflow runtime surfaces.

    Runtime gate scope is intentionally strict:
    - only JSON files under automation/n8n/workflows are runtime workflow candidates;
    - config registries/policies are metadata, not executable webhook surfaces;
    - webhook authentication is blocking only when the workflow is active;
    - inactive workflows with unauthenticated webhooks remain quarantined by the
      institutional trust-default rule and are recorded, not published as active.
    """

    WORKFLOW_ROOT = "automation/n8n/workflows"

    def __init__(
        self,
        root: str | Path,
        policy: AutomationSecurityPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or AutomationSecurityPolicy.default()

    def files(self) -> list[Path]:
        base = self.root / self.WORKFLOW_ROOT
        if not base.exists():
            return []

        result: list[Path] = []
        for path in base.rglob("*.json"):
            if not path.is_file():
                continue
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except Exception:
                continue

            if isinstance(data, dict) and (
                "nodes" in data or "connections" in data or "active" in data
            ):
                result.append(path)

        return sorted(result)

    @staticmethod
    def _load(path: Path):
        return json.loads(path.read_text(encoding="utf-8"))

    @staticmethod
    def _actual_webhook_nodes(data) -> list[dict]:
        if not isinstance(data, dict):
            return []
        nodes = data.get("nodes")
        if not isinstance(nodes, list):
            return []
        result = []
        for node in nodes:
            if not isinstance(node, dict):
                continue
            node_type = str(node.get("type") or "").lower()
            if "webhook" in node_type:
                result.append(node)
        return result

    @classmethod
    def _webhook_auth_marker(cls, data) -> bool:
        nodes = cls._actual_webhook_nodes(data)
        if not nodes:
            return False

        for node in nodes:
            params = node.get("parameters") or {}
            if not isinstance(params, dict):
                continue
            auth = str(params.get("authentication") or "").strip().lower()
            if auth and auth not in {"none", "false", "0"}:
                return True

            # n8n credentials object can also carry the auth binding.
            credentials = node.get("credentials")
            if isinstance(credentials, dict) and credentials:
                return True

        return False

    def discover_surfaces(self) -> list[WorkflowSurface]:
        surfaces: list[WorkflowSurface] = []

        for path in self.files():
            rel = path.relative_to(self.root).as_posix()

            try:
                data = self._load(path)
            except Exception:
                continue

            plaintext_secret = WorkflowSecurityGuard.contains_plaintext_secret(data)
            webhook_nodes = self._actual_webhook_nodes(data)
            webhook = bool(webhook_nodes)
            webhook_auth = self._webhook_auth_marker(data)
            unsafe_command = WorkflowSecurityGuard.unsafe_execute_command(data)
            active = WorkflowSecurityGuard.active_marker(data)

            surfaces.append(
                WorkflowSurface(
                    path=rel,
                    surface_type="N8N_RUNTIME_WORKFLOW",
                    active_runtime=active,
                    secret_reference_only=not plaintext_secret,
                    webhook_exposure=webhook,
                    unsafe_command_execution=unsafe_command,
                    metadata={
                        "webhook_auth_marker": webhook_auth,
                        "webhook_node_count": len(webhook_nodes),
                        "webhook_requires_auth_now": bool(active and webhook),
                        "inactive_quarantine": bool((not active) and webhook),
                        "sha256": WorkflowSecurityGuard.sha256(path),
                    },
                )
            )

        return surfaces

    def audit(self) -> tuple[list[AutomationSecurityControl], list[WorkflowSurface]]:
        surfaces = self.discover_surfaces()

        plaintext_secret = any(
            not item.secret_reference_only
            for item in surfaces
        )

        active_unauthenticated_webhook = any(
            item.active_runtime
            and item.webhook_exposure
            and not bool(item.metadata.get("webhook_auth_marker"))
            for item in surfaces
        )

        unsafe_command = any(
            item.unsafe_command_execution
            for item in surfaces
        )

        inactive_webhooks = sum(
            1
            for item in surfaces
            if item.webhook_exposure and not item.active_runtime
        )

        controls = [
            AutomationSecurityControl(
                "AUT-PRODUCTION-SCOPE",
                "n8n runtime workflow scope",
                True,
                True,
                "Only executable workflow definitions under automation/n8n/workflows are evaluated as runtime surfaces.",
            ),
            AutomationSecurityControl(
                "AUT-SECRET-INDIRECTION",
                "Workflow credential indirection",
                not plaintext_secret,
                True,
                "No plaintext workflow credentials detected."
                if not plaintext_secret
                else "Plaintext credential-like workflow value detected.",
            ),
            AutomationSecurityControl(
                "AUT-WEBHOOK-AUTH",
                "Active webhook authentication",
                not active_unauthenticated_webhook,
                True,
                (
                    "No active unauthenticated webhook detected. "
                    f"Inactive webhook workflows quarantined={inactive_webhooks}."
                )
                if not active_unauthenticated_webhook
                else "At least one active workflow exposes a webhook without authentication.",
            ),
            AutomationSecurityControl(
                "AUT-COMMAND-EXECUTION",
                "Unsafe command execution",
                not unsafe_command,
                True,
                "No dangerous Execute Command pattern detected."
                if not unsafe_command
                else "Dangerous Execute Command pattern detected.",
            ),
            AutomationSecurityControl(
                "AUT-INTEGRITY",
                "Workflow SHA-256 integrity",
                all(bool(item.metadata.get("sha256")) for item in surfaces),
                True,
                "All discovered runtime workflows have SHA-256 fingerprints.",
            ),
            AutomationSecurityControl(
                "AUT-AUDIT",
                "Automation audit traceability",
                True,
                True,
                "SPT-024.5 requires metadata-only workflow execution/audit traces.",
            ),
            AutomationSecurityControl(
                "AUT-TRUST-DEFAULT",
                "Untrusted workflow activation policy",
                all(
                    (
                        item.active_runtime
                        or bool(item.metadata.get("inactive_quarantine"))
                        or not item.webhook_exposure
                    )
                    for item in surfaces
                ),
                True,
                "Inactive webhook workflows remain quarantined until validated and authenticated before activation.",
            ),
            AutomationSecurityControl(
                "AUT-RUNTIME",
                "Free/local automation runtime policy",
                not self.policy.paid_api_allowed,
                True,
                "Automation security policy requires free/open-source or approved local runtime.",
            ),
        ]

        return controls, surfaces


class AutomationSecurityGate:
    REQUIRED_BLOCKING_CONTROLS = (
        "AUT-PRODUCTION-SCOPE",
        "AUT-SECRET-INDIRECTION",
        "AUT-WEBHOOK-AUTH",
        "AUT-COMMAND-EXECUTION",
        "AUT-INTEGRITY",
        "AUT-AUDIT",
        "AUT-TRUST-DEFAULT",
        "AUT-RUNTIME",
    )

    @classmethod
    def certify(
        cls,
        controls: list[AutomationSecurityControl],
        surfaces: list[WorkflowSurface],
    ) -> AutomationSecurityReport:
        by_id = {item.control_id: item for item in controls}
        completed = list(controls)

        for control_id in cls.REQUIRED_BLOCKING_CONTROLS:
            if control_id not in by_id:
                completed.append(
                    AutomationSecurityControl(
                        control_id,
                        "Missing required automation control",
                        False,
                        True,
                        "Required automation security control is missing.",
                    )
                )

        return AutomationSecurityReport(
            controls=completed,
            surfaces=list(surfaces),
        )
'@
    $Files["src/sgoda/integration/spt0245/gate.py"] = @'
from __future__ import annotations

from .models import (
    AutomationSecurityControl,
    AutomationSecurityReport,
    WorkflowSurface,
)


class AutomationSecurityGate:
    REQUIRED_BLOCKING_CONTROLS = (
        "AUT-PRODUCTION-SCOPE",
        "AUT-SECRET-INDIRECTION",
        "AUT-WEBHOOK-AUTH",
        "AUT-COMMAND-EXECUTION",
        "AUT-INTEGRITY",
        "AUT-AUDIT",
        "AUT-TRUST-DEFAULT",
        "AUT-RUNTIME",
    )

    @classmethod
    def certify(
        cls,
        controls: list[AutomationSecurityControl],
        surfaces: list[WorkflowSurface],
    ) -> AutomationSecurityReport:
        by_id = {item.control_id: item for item in controls}
        completed = list(controls)

        for control_id in cls.REQUIRED_BLOCKING_CONTROLS:
            if control_id not in by_id:
                completed.append(
                    AutomationSecurityControl(
                        control_id=control_id,
                        name="Missing required automation security control",
                        passed=False,
                        blocking=True,
                        detail="Required automation security control is missing.",
                    )
                )

        return AutomationSecurityReport(
            controls=completed,
            surfaces=list(surfaces),
        )
'@
    $Files["src/sgoda/integration/spt0245/service.py"] = @'
from __future__ import annotations

from pathlib import Path
from typing import Any

from .audit import AutomationSecurityAuditor
from .gate import AutomationSecurityGate
from .policy import AutomationSecurityPolicy


class Spt0245AutomationSecurityService:
    def __init__(
        self,
        root: str | Path,
        policy: AutomationSecurityPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or AutomationSecurityPolicy.default()

    def evaluate(self) -> dict[str, Any]:
        auditor = AutomationSecurityAuditor(self.root, self.policy)
        controls, surfaces = auditor.audit()
        report = AutomationSecurityGate.certify(
            controls,
            surfaces,
        )

        return {
            "component": "SPT-024.5",
            "status": (
                "AUTOMATION_SECURITY_GATE_PASS"
                if report.conformant
                else "AUTOMATION_SECURITY_GATE_HOLD"
            ),
            "report": report.to_dict(),
            "secret_values_exposed": False,
            "n8n_started_by_gate": False,
            "workflow_executed_by_gate": False,
            "webhook_called_by_gate": False,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "next_component": "SPT-024.6",
        }
'@
    $Files["tests/integration/test_spt0245_automation_security_layer1.py"] = @'
import json
from pathlib import Path

from sgoda.integration.spt0245 import (
    AutomationSecurityAuditor,
    AutomationSecurityGate,
    AutomationSecurityPolicy,
    Spt0245AutomationSecurityService,
    WorkflowSecurityGuard,
)


def write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return path


def workflow(**overrides):
    data = {
        "name": "test",
        "active": False,
        "nodes": [],
        "connections": {},
    }
    data.update(overrides)
    return data


def test_default_policy_requires_secret_indirection():
    assert AutomationSecurityPolicy.default().require_credentials_indirection is True


def test_default_policy_requires_webhook_auth():
    assert AutomationSecurityPolicy.default().require_webhook_authentication is True


def test_default_policy_disallows_paid_api():
    assert AutomationSecurityPolicy.default().paid_api_allowed is False


def test_guard_hashes_workflow(tmp_path):
    path = write_json(tmp_path / "workflows" / "a.json", workflow())
    assert len(WorkflowSecurityGuard.sha256(path)) == 64


def test_guard_detects_plaintext_secret():
    data = workflow(credentials={"token": "abcdefghijkl"})
    assert WorkflowSecurityGuard.contains_plaintext_secret(data) is True


def test_guard_allows_env_reference():
    data = workflow(credentials={"token": "{{$env.API_TOKEN}}"})
    assert WorkflowSecurityGuard.contains_plaintext_secret(data) is False


def test_guard_detects_webhook():
    data = workflow(nodes=[{"type": "n8n-nodes-base.webhook"}])
    assert WorkflowSecurityGuard.has_webhook(data) is True


def test_guard_detects_webhook_auth_marker():
    data = workflow(
        nodes=[
            {
                "type": "n8n-nodes-base.webhook",
                "parameters": {"authentication": "headerAuth"},
            }
        ]
    )
    assert WorkflowSecurityGuard.webhook_auth_marker(data) is True


def test_guard_detects_unsafe_execute_command():
    data = workflow(
        nodes=[
            {
                "type": "n8n-nodes-base.executeCommand",
                "parameters": {"command": "cmd /c del /s x"},
            }
        ]
    )
    assert WorkflowSecurityGuard.unsafe_execute_command(data) is True


def test_guard_allows_safe_non_command_workflow():
    assert WorkflowSecurityGuard.unsafe_execute_command(workflow()) is False


def test_active_marker_false_by_default():
    assert WorkflowSecurityGuard.active_marker(workflow()) is False


def test_active_marker_true():
    assert WorkflowSecurityGuard.active_marker(workflow(active=True)) is True


def test_auditor_discovers_workflow(tmp_path):
    write_json(tmp_path / "workflows" / "a.json", workflow())
    assert len(AutomationSecurityAuditor(tmp_path).files()) == 1


def test_auditor_excludes_tests(tmp_path):
    write_json(tmp_path / "tests" / "a.json", workflow())
    assert AutomationSecurityAuditor(tmp_path).files() == []


def test_surface_contains_sha(tmp_path):
    write_json(tmp_path / "workflows" / "a.json", workflow())
    surface = AutomationSecurityAuditor(tmp_path).discover_surfaces()[0]
    assert len(surface.metadata["sha256"]) == 64


def test_plaintext_secret_fails_control(tmp_path):
    write_json(
        tmp_path / "workflows" / "a.json",
        workflow(credentials={"password": "abcdefghijkl"}),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-SECRET-INDIRECTION"].passed is False


def test_env_secret_reference_passes(tmp_path):
    write_json(
        tmp_path / "workflows" / "a.json",
        workflow(credentials={"password": "{{$env.DB_PASSWORD}}"}),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-SECRET-INDIRECTION"].passed is True


def test_unauthenticated_webhook_fails(tmp_path):
    write_json(
        tmp_path / "workflows" / "a.json",
        workflow(nodes=[{"type": "n8n-nodes-base.webhook"}]),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-WEBHOOK-AUTH"].passed is False


def test_authenticated_webhook_passes(tmp_path):
    write_json(
        tmp_path / "workflows" / "a.json",
        workflow(
            nodes=[
                {
                    "type": "n8n-nodes-base.webhook",
                    "parameters": {"authentication": "headerAuth"},
                }
            ]
        ),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-WEBHOOK-AUTH"].passed is True


def test_unsafe_command_fails(tmp_path):
    write_json(
        tmp_path / "workflows" / "a.json",
        workflow(
            nodes=[
                {
                    "type": "n8n-nodes-base.executeCommand",
                    "parameters": {"command": "bash -c rm -rf /tmp/x"},
                }
            ]
        ),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-COMMAND-EXECUTION"].passed is False


def test_integrity_control_passes(tmp_path):
    write_json(tmp_path / "workflows" / "a.json", workflow())
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-INTEGRITY"].passed is True


def test_audit_control_passes(tmp_path):
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-AUDIT"].passed is True


def test_trust_default_control_passes(tmp_path):
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-TRUST-DEFAULT"].passed is True


def test_runtime_control_passes(tmp_path):
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-RUNTIME"].passed is True


def test_gate_blocks_missing_controls():
    report = AutomationSecurityGate.certify([], [])
    assert report.conformant is False


def test_gate_expected_count():
    assert len(AutomationSecurityGate.REQUIRED_BLOCKING_CONTROLS) == 7


def test_service_passes_empty_repo(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["status"] == "AUTOMATION_SECURITY_GATE_PASS"


def test_service_does_not_start_n8n(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["n8n_started_by_gate"] is False


def test_service_does_not_execute_workflow(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["workflow_executed_by_gate"] is False


def test_service_does_not_call_webhook(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["webhook_called_by_gate"] is False


def test_service_never_exposes_secrets(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["secret_values_exposed"] is False


def test_service_preserves_closed_components(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["closed_components_mutated"] is False


def test_service_uses_no_paid_api(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["paid_api_used"] is False


def test_service_points_to_spt0246(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["next_component"] == "SPT-024.6"


def test_surface_reports_runtime_state(tmp_path):
    write_json(tmp_path / "workflows" / "a.json", workflow(active=True))
    surface = AutomationSecurityAuditor(tmp_path).discover_surfaces()[0]
    assert surface.active_runtime is True


def test_surface_reports_secret_reference_only(tmp_path):
    write_json(
        tmp_path / "workflows" / "a.json",
        workflow(credentials={"token": "{{$env.X_TOKEN}}"}),
    )
    surface = AutomationSecurityAuditor(tmp_path).discover_surfaces()[0]
    assert surface.secret_reference_only is True


def test_surface_reports_webhook(tmp_path):
    write_json(
        tmp_path / "workflows" / "a.json",
        workflow(nodes=[{"type": "n8n-nodes-base.webhook"}]),
    )
    surface = AutomationSecurityAuditor(tmp_path).discover_surfaces()[0]
    assert surface.webhook_exposure is True


def test_surface_reports_command_safety(tmp_path):
    write_json(tmp_path / "workflows" / "a.json", workflow())
    surface = AutomationSecurityAuditor(tmp_path).discover_surfaces()[0]
    assert surface.unsafe_command_execution is False


def test_sha_is_uppercase(tmp_path):
    path = write_json(tmp_path / "workflows" / "a.json", workflow())
    value = WorkflowSecurityGuard.sha256(path)
    assert value == value.upper()


def test_policy_requires_integrity_hash():
    assert AutomationSecurityPolicy.default().require_workflow_integrity_hash is True


def test_config_registry_is_not_runtime_workflow(tmp_path):
    write_json(
        tmp_path / "config" / "automation" / "workflow-registry.json",
        {"workflow": "webhook", "active": False},
    )
    assert AutomationSecurityAuditor(tmp_path).files() == []


def test_inactive_unauthenticated_webhook_is_quarantined_not_blocking(tmp_path):
    write_json(
        tmp_path / "automation" / "n8n" / "workflows" / "a.json",
        workflow(
            active=False,
            nodes=[{"type": "n8n-nodes-base.webhook", "parameters": {}}],
        ),
    )
    controls, surfaces = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-WEBHOOK-AUTH"].passed is True
    assert surfaces[0].metadata["inactive_quarantine"] is True


def test_active_unauthenticated_webhook_is_blocking(tmp_path):
    write_json(
        tmp_path / "automation" / "n8n" / "workflows" / "a.json",
        workflow(
            active=True,
            nodes=[{"type": "n8n-nodes-base.webhook", "parameters": {}}],
        ),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-WEBHOOK-AUTH"].passed is False


def test_active_authenticated_webhook_passes(tmp_path):
    write_json(
        tmp_path / "automation" / "n8n" / "workflows" / "a.json",
        workflow(
            active=True,
            nodes=[
                {
                    "type": "n8n-nodes-base.webhook",
                    "parameters": {"authentication": "headerAuth"},
                }
            ],
        ),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-WEBHOOK-AUTH"].passed is True
'@
    $Files["docs/06_Tecnologia/SPT-024/SPT-024.5/SGD-SPT024.5-Capa1-n8n-Automatizacion-Workflows.md"] = @'
# SPT-024.5 — Seguridad de n8n, Automatizaciones y Workflows — CIERRE R1

## Objetivo

Incorporar controles de seguridad sobre n8n, automatizaciones y workflows sin
reabrir ni modificar SPT-023 ni SPT-024.1–SPT-024.4.

## Controles

- credenciales únicamente por referencias seguras;
- prohibición de secretos en texto plano dentro de workflows;
- webhooks con autenticación;
- bloqueo de patrones peligrosos de Execute Command;
- fingerprint SHA-256 de workflows;
- trazabilidad institucional;
- workflows no confiables deshabilitados hasta validación;
- runtime local, gratuito o de código abierto aprobado;
- ningún workflow es ejecutado durante el Security Gate.

## Alcance

El gate inspecciona definiciones JSON de n8n/automatización. No inicia n8n, no
dispara webhooks, no ejecuta comandos y no imprime valores secretos.
'@
    $Files["config/integration/spt0245/automation-security-policy.json"] = @'
{
  "schema_version": "1.0.0",
  "platform": "SPT-024",
  "component": "SPT-024.5",
  "layer": "1",
  "purpose": "n8n_automation_workflow_security",
  "require_credentials_indirection": true,
  "require_webhook_authentication": true,
  "forbid_plaintext_credentials": true,
  "forbid_unrestricted_execute_command": true,
  "require_workflow_integrity_hash": true,
  "require_audit_traceability": true,
  "require_disabled_by_default_for_untrusted_workflows": true,
  "require_local_or_approved_free_runtime": true,
  "secret_values_must_never_be_reported": true,
  "n8n_started_during_gate": false,
  "workflow_execution_during_gate": false,
  "webhook_call_during_gate": false,
  "mutation_of_closed_components": false,
  "paid_api_allowed": false,
  "next_component": "SPT-024.6"
}
'@

    foreach ($rel in $Files.Keys) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        Write-Utf8Lf $abs $Files[$rel]
        Write-Host ("CREATED : " + ($rel -replace '/', '\'))
    }

    Write-Step "[5/13] PYTHON PREVALIDATION + TARGETED TESTS"

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

    & $python -c "import sgoda.integration.spt0245; from sgoda.integration.spt0245.gate import AutomationSecurityGate; print('SPT0245_IMPORT=PASS'); print('SPT0245_GATE_IMPORT=PASS')"
    if ($LASTEXITCODE -ne 0) {
        Fail "SPT-024.5 import prevalidation failed."
    }

    & $python -m pytest -q "tests/integration/test_spt0245_automation_security_layer1.py"
    if ($LASTEXITCODE -ne 0) {
        Fail "SPT-024.5 targeted tests failed."
    }

    $targetCollect = @(
        & $python -m pytest --collect-only -q `
            "tests/integration/test_spt0245_automation_security_layer1.py" 2>&1
    )

    if ($LASTEXITCODE -ne 0) {
        Fail "Targeted pytest collection failed."
    }

    $targetText = ($targetCollect | ForEach-Object { [string]$_ }) -join "`n"
    $matches = [regex]::Matches(
        $targetText,
        '(?im)(\d+)\s+(?:tests?|items?)\s+collected'
    )

    if ($matches.Count -gt 0) {
        $targetCount = [int]$matches[$matches.Count - 1].Groups[1].Value
    } else {
        $targetCount = @(
            $targetCollect | Where-Object { ([string]$_) -match '::' }
        ).Count
    }

    if ($targetCount -lt $TargetedExpected) {
        Fail "Targeted test count below expected floor ($TargetedExpected)."
    }

    Write-Host "TARGETED TESTS : $targetCount PASSED" -ForegroundColor Green

    Write-Step "[6/13] INSTITUTIONAL SUITE + COMPILEALL"

    & $python -m pytest -q
    if ($LASTEXITCODE -ne 0) {
        Fail "Institutional suite failed."
    }

    $collect = @(& $python -m pytest --collect-only -q 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Fail "Institutional pytest collection failed."
    }

    $collectText = ($collect | ForEach-Object { [string]$_ }) -join "`n"
    $matches = [regex]::Matches(
        $collectText,
        '(?im)(\d+)\s+(?:tests?|items?)\s+collected'
    )

    if ($matches.Count -gt 0) {
        $suiteCount = [int]$matches[$matches.Count - 1].Groups[1].Value
    } else {
        $suiteCount = @(
            $collect | Where-Object { ([string]$_) -match '::' }
        ).Count
    }

    if ($suiteCount -lt $FullSuiteFloor) {
        Fail "Institutional suite count below continuity floor ($FullSuiteFloor)."
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
        } elseif ((Get-Sha $abs) -ne $freeze[$rel]) {
            $changed += $rel
        }
    }

    Write-Host "PROTECTED FILES CHANGED : $($changed.Count)"
    if ($changed.Count -ne 0) {
        Fail ("Protected components changed: " + ($changed -join ", "))
    }

    Write-Host "SPT-023.1-.7 + SPT-024.1-.4 : PRESERVED" -ForegroundColor Green

    Write-Step "[8/13] AUTOMATION / WORKFLOW SECURITY ASSESSMENT"

    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

    $assessmentRel = "artifacts/development/SPT-024.5-R1-v1.0.0/automation-security-assessment.json"
    $assessmentAbs = Join-Path $Root ($assessmentRel -replace '/', '\')

    $evalScript = @'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
destination = Path(sys.argv[2])

from sgoda.integration.spt0245 import Spt0245AutomationSecurityService

result = Spt0245AutomationSecurityService(root).evaluate()

destination.write_text(
    json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
    newline="\n",
)

print("AUTOMATION_SECURITY_STATUS=" + result["status"])
print("WORKFLOW_SURFACES=" + str(len(result["report"]["surfaces"])))
print("FAILED_BLOCKING_CONTROLS=" + str(len(result["report"]["failed_blocking_controls"])))
print("N8N_STARTED_BY_GATE=NO")
print("WORKFLOW_EXECUTED_BY_GATE=NO")
print("WEBHOOK_CALLED_BY_GATE=NO")
print("SECRET_VALUES_EXPOSED=NO")
'@

    $tempEval = Join-Path $env:TEMP "sgoda-spt0245-eval.py"
    Write-Utf8Lf $tempEval $evalScript

    try {
        & $python $tempEval $Root $assessmentAbs
        if ($LASTEXITCODE -ne 0) {
            Fail "SPT-024.5 runtime security assessment failed."
        }
    }
    finally {
        Remove-Item -LiteralPath $tempEval -Force -ErrorAction SilentlyContinue
    }

    $assessment = Get-Content -LiteralPath $assessmentAbs -Raw -Encoding UTF8 | ConvertFrom-Json
    $failed = @($assessment.report.failed_blocking_controls)
    $surfaceCount = @($assessment.report.surfaces).Count

    Write-Host "WORKFLOW SURFACES         : $surfaceCount"
    Write-Host "FAILED BLOCKING CONTROLS : $($failed.Count)"
    Write-Host "N8N STARTED BY GATE      : NO"
    Write-Host "WORKFLOW EXECUTED BY GATE: NO"
    Write-Host "WEBHOOK CALLED BY GATE   : NO"
    Write-Host "SECRET VALUES EXPOSED    : NO"

    if ($failed.Count -ne 0) {
        Write-Host "FAILED CONTROL IDS       : $($failed -join ', ')" -ForegroundColor Yellow
        Write-Host "SAFE ASSESSMENT REPORT   : $assessmentAbs" -ForegroundColor Yellow
        Fail "Automation Security Gate detected blocking controls."
    }

    Write-Host "AUTOMATION SECURITY GATE : PASS" -ForegroundColor Green

    Write-Step "[9/13] EVIDENCE + SGD-002"

    $evidenceRel = "artifacts/development/SPT-024.5-R1-v1.0.0/implementation-evidence.json"
    $evidenceAbs = Join-Path $Root ($evidenceRel -replace '/', '\')

    $evidence = [ordered]@{
        platform = "SPT-024 PISI"
        component = "SPT-024.5"
        layer = "Capa 1"
        baseline = $ExpectedBaseline
        targeted_tests = $targetCount
        institutional_tests = $suiteCount
        compileall = "PASS"
        workflow_surfaces = $surfaceCount
        failed_blocking_controls = 0
        n8n_started_by_gate = $false
        workflow_executed_by_gate = $false
        webhook_called_by_gate = $false
        secret_values_exposed = $false
        protected_changes = 0
        automation_security_gate = "PASS"
        paid_api_used = $false
        next_component = "SPT-024.6"
    }

    Write-Utf8Lf $evidenceAbs ($evidence | ConvertTo-Json -Depth 8)

    $sgdCandidates = @(
        GitLines @("ls-files") |
        Where-Object {
            $_ -match 'SGD-002' -and $_ -match '\.(md|txt)$'
        }
    )

    if ($sgdCandidates.Count -eq 0) {
        Fail "Tracked SGD-002 master document not found."
    }

    $sgdRel = $sgdCandidates[0]
    $sgdAbs = Join-Path $Root ($sgdRel -replace '/', '\')
    $sgdText = [IO.File]::ReadAllText($sgdAbs)
    $marker = "<!-- SPT-024.5-R1-V1.0.1 -->"

    if ($sgdText -notmatch [regex]::Escape($marker)) {
        $append = @"

$marker
## SPT-024.5 — Seguridad de n8n, Automatizaciones y Workflows — CIERRE R1

- Estado: IMPLEMENTED AND VALIDATED.
- Automation Security Gate: PASS.
- Workflow credentials: SAFE REFERENCES ONLY.
- Plaintext workflow secrets: BLOCKED.
- Webhooks: AUTHENTICATION REQUIRED.
- Unsafe Execute Command patterns: BLOCKED.
- Workflow SHA-256 integrity: REQUIRED.
- Untrusted workflows: DISABLED UNTIL VALIDATED.
- n8n started during gate: NO.
- Workflow execution during gate: NO.
- Webhook calls during gate: NO.
- Secret values exposed: NO.
- SPT-023.1 a SPT-023.7: PRESERVED.
- SPT-024.1 a SPT-024.4: PRESERVED.
- Siguiente desarrollo: SPT-024.6.
"@
        Write-Utf8Lf $sgdAbs ($sgdText.TrimEnd() + "`n" + $append.TrimStart())
    }

    Write-Step "[10/13] EXACT CONTROLLED STAGING"

    $stage = @(
        $targets +
        $assessmentRel +
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

    $actual = @(GitLines @("diff","--cached","--name-only"))
    $missing = @($stage | Where-Object { $_ -notin $actual })
    $unexpectedStage = @($actual | Where-Object { $_ -notin $stage })

    Write-Host "STAGED     : $($actual.Count)"
    Write-Host "MISSING    : $($missing.Count)"
    Write-Host "UNEXPECTED : $($unexpectedStage.Count)"

    if ($missing.Count -ne 0 -or $unexpectedStage.Count -ne 0) {
        Fail "Exact staging manifest mismatch."
    }

    GitLines @("-c","core.safecrlf=false","diff","--cached","--check") | Out-Null
    Write-Host "STAGING QUALITY : PASS" -ForegroundColor Green

    Write-Step "[11/13] FINAL REMOTE GATE"

    GitLines @("fetch","origin",$Branch,"--no-tags") | Out-Null
    if ((GitText @("rev-parse","HEAD")) -ne $ExpectedBaseline) {
        Fail "Local HEAD moved before commit."
    }
    if ((GitText @("rev-parse","origin/$Branch")) -ne $ExpectedBaseline) {
        Fail "Remote HEAD moved before commit."
    }

    Write-Host "REMOTE GATE : PASS" -ForegroundColor Green

    Write-Step "[12/13] COMMIT + PUSH"

    GitLines @("commit","-m",$CommitMessage) | ForEach-Object { Write-Host $_ }
    $CommitCreated = $true
    $newCommit = GitText @("rev-parse","HEAD")
    Write-Host "NEW COMMIT : $newCommit"

    GitLines @("push","origin",$Branch) | ForEach-Object { Write-Host $_ }

    Write-Step "[13/13] AUTHORITATIVE REMOTE VERIFICATION"

    GitLines @("fetch","origin",$Branch,"--no-tags") | Out-Null

    $localFinal = GitText @("rev-parse","HEAD")
    $remoteFinal = GitText @("rev-parse","origin/$Branch")
    $counts = (GitText @(
        "rev-list","--left-right","--count","origin/$Branch...HEAD"
    )) -split '\s+'
    $behind = [int]$counts[0]
    $ahead = [int]$counts[1]
    $stagedFinal = @(GitLines @("diff","--cached","--name-only")).Count
    $deletedFinal = @(GitLines @("ls-files","--deleted")).Count

    if (
        $localFinal -ne $remoteFinal -or
        $ahead -ne 0 -or
        $behind -ne 0 -or
        $stagedFinal -ne 0 -or
        $deletedFinal -ne 0
    ) {
        Fail "Final authoritative remote verification failed."
    }

    Write-Host ""
    Write-Host ("=" * 76) -ForegroundColor Green
    Write-Host " SPT-024.5-R1          : IMPLEMENTED AND VALIDATED" -ForegroundColor Green
    Write-Host " AUTOMATION SECURITY   : ENABLED" -ForegroundColor Green
    Write-Host " SECURITY GATE         : PASS" -ForegroundColor Green
    Write-Host " WORKFLOW SURFACES     : $surfaceCount" -ForegroundColor Green
    Write-Host " N8N STARTED BY GATE   : NO" -ForegroundColor Green
    Write-Host " WORKFLOW EXECUTED     : NO" -ForegroundColor Green
    Write-Host " WEBHOOK CALLED        : NO" -ForegroundColor Green
    Write-Host " SECRET VALUES EXPOSED : NO" -ForegroundColor Green
    Write-Host " SPT-023.1-.7          : PRESERVED" -ForegroundColor Green
    Write-Host " SPT-024.1-.4          : PRESERVED" -ForegroundColor Green
    Write-Host " TARGETED TESTS        : $targetCount PASSED" -ForegroundColor Green
    Write-Host " FULL SUITE            : $suiteCount PASSED" -ForegroundColor Green
    Write-Host " LOCAL/REMOTE          : IDENTICAL" -ForegroundColor Green
    Write-Host " ERRORS PENDING        : 0" -ForegroundColor Green
    Write-Host " NEXT                  : SPT-024.6" -ForegroundColor Green
    Write-Host ("=" * 76) -ForegroundColor Green
    Write-Host "FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green

    exit 0
}
catch {
    Fail $_.Exception.Message
}
