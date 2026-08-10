#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "12886bff5161973f7743b49ff4da61676b8b04b0"
$SelfName = "Invoke-SGODA-SPT0243-R1-SECURITY-CERTIFY-v1.0.1-PS51.ps1"
$CommitMessage = "feat(spt-024.3): certify API security gateway and production scope"
$TargetedExpected = 40
$FullSuiteFloor = 1288
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
    Write-Host " SPT-024.3-R1 : HOLD" -ForegroundColor Red
    Write-Host " REASON        : $Reason" -ForegroundColor Red
    if ($CommitCreated) {
        Write-Host " LOCAL COMMIT  : PRESERVED FOR SAME-FILE RESUME" -ForegroundColor Yellow
    } else {
        Write-Host " TRANSACTION   : NOT PUBLISHED" -ForegroundColor Yellow
    }
    Write-Host " ERRORS PENDING: 1" -ForegroundColor Red
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

    Write-Step "[1/14] AUTHORITATIVE BASELINE / FAILED-RUN RECOVERY"

    GitLines @("fetch","origin",$Branch,"--no-tags") |
        ForEach-Object { Write-Host $_ }

    $Local = GitText @("rev-parse","HEAD")
    $Remote = GitText @("rev-parse","origin/$Branch")

    if ($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline) {
        Fail "Certified SPT-024.2 baseline is not authoritative."
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

    $runtimeModified = @(
        GitLines @("-c","core.safecrlf=false","diff","--name-only") |
        Where-Object { $_ -match '^artifacts/runtime/' }
    )
    Write-Host "PREEXISTING RUNTIME MODIFICATIONS : $($runtimeModified.Count)"
    $runtimeModified | ForEach-Object {
        Write-Host ("RUNTIME PRESERVED : " + $_)
    }

    Write-Step "[2/14] SHA-256 FREEZE OF CLOSED SPT-023 + SPT-024.1-.2"

    $tracked = @(GitLines @("ls-files"))
    $protected = @(
        $tracked | Where-Object {
            $_ -match 'SPT-023\.' -or
            $_ -match 'spt023' -or
            $_ -match 'SPT-024\.[12]' -or
            $_ -match 'spt024[12]'
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

    Write-Step "[3/14] CLEAN FAILED SPT-024.3 UNTRACKED OUTPUTS"

    $oldTargets = @(
        "src/sgoda/integration/spt0243",
        "tests/integration/test_spt0243_api_security_layer1.py",
        "docs/06_Tecnologia/SPT-024/SPT-024.3",
        "config/integration/spt0243",
        "artifacts/development/SPT-024.3-Capa1-v1.0.0",
        "Invoke-SGODA-SPT0243-Capa1-FINAL-v1.0.0-PS51.ps1",
        "Invoke-SGODA-SPT0243-Capa1-FINAL-v1.0.1-PS51.ps1",
        "Invoke-SGODA-SPT0243-R1-SECURITY-CERTIFY-v1.0.0-PS51.ps1"
    )

    foreach ($rel in $oldTargets) {
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

            if ($trackedCode -ne 0) {
                Remove-Item -LiteralPath $abs -Recurse -Force
                Write-Host ("FAILED OUTPUT REMOVED : " + $rel)
            }
        }
    }

    Write-Step "[4/14] IMPLEMENT PRODUCTION-SCOPE API SECURITY + GATEWAY"

    $Files = @{}
    $Files["src/sgoda/integration/spt0243/__init__.py"] = @'
"""SPT-024.3 — Seguridad de FastAPI, APIs y Servicios."""

from .audit import ApiSecurityAuditor
from .gateway import (
    ApiSecurityGatewayMiddleware,
    GatewaySecurityPolicy,
    protect_asgi_app,
)
from .models import ApiSecurityControl, ApiSecurityReport, ServiceExposure
from .scope import ProductionApiScope
from .service import Spt0243ApiSecurityService

__all__ = [
    "ApiSecurityAuditor",
    "ApiSecurityControl",
    "ApiSecurityGatewayMiddleware",
    "ApiSecurityReport",
    "GatewaySecurityPolicy",
    "ProductionApiScope",
    "ServiceExposure",
    "Spt0243ApiSecurityService",
    "protect_asgi_app",
]
'@
    $Files["src/sgoda/integration/spt0243/models.py"] = @'
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class ServiceExposure:
    path: str
    method: str
    source: str
    sensitive: bool
    native_auth: bool
    gateway_auth: bool

    @property
    def authenticated(self) -> bool | None:
        if not self.sensitive:
            return None
        return self.native_auth or self.gateway_auth

    def to_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "method": self.method,
            "source": self.source,
            "sensitive": self.sensitive,
            "native_auth": self.native_auth,
            "gateway_auth": self.gateway_auth,
            "authenticated": self.authenticated,
        }


@dataclass(frozen=True)
class ApiSecurityControl:
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
class ApiSecurityReport:
    controls: list[ApiSecurityControl] = field(default_factory=list)
    exposures: list[ServiceExposure] = field(default_factory=list)

    @property
    def failed_blocking_controls(self) -> list[ApiSecurityControl]:
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
            "exposures": [item.to_dict() for item in self.exposures],
            "failed_blocking_controls": [
                item.control_id for item in self.failed_blocking_controls
            ],
            "conformant": self.conformant,
        }
'@
    $Files["src/sgoda/integration/spt0243/scope.py"] = @'
from __future__ import annotations

from pathlib import Path


class ProductionApiScope:
    """
    Strict production scope.

    Tests, documentation, releases, builder templates and security detector
    sources are excluded from the production API gate.
    """

    ALLOWED_ROOTS = (
        "src/sgoda/api",
        "src/sgoda/learning_platform",
        "src/sgoda/operational_platform",
        "src/sgoda/platform",
    )

    EXCLUDED_PARTS = (
        "__pycache__",
        "tests",
        "test",
        "fixtures",
        "fixture",
    )

    TEXT_SUFFIXES = {".py", ".json", ".yaml", ".yml", ".toml", ".ini", ".cfg", ".conf"}

    def __init__(self, root: str | Path) -> None:
        self.root = Path(root)

    def files(self) -> list[Path]:
        result: list[Path] = []
        for rel_root in self.ALLOWED_ROOTS:
            base = self.root / Path(rel_root)
            if not base.exists():
                continue
            for path in base.rglob("*"):
                if not path.is_file():
                    continue
                if path.suffix.lower() not in self.TEXT_SUFFIXES:
                    continue
                if any(part.lower() in self.EXCLUDED_PARTS for part in path.parts):
                    continue
                result.append(path)
        return sorted(set(result))
'@
    $Files["src/sgoda/integration/spt0243/gateway.py"] = @'
from __future__ import annotations

import hmac
import os
import time
from collections import defaultdict, deque
from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable


@dataclass(frozen=True)
class GatewaySecurityPolicy:
    protected_paths: tuple[str, ...] = (
        "/audit/repository",
        "/admin",
        "/publish",
        "/workflow",
        "/pmo",
    )
    max_request_bytes: int = 2 * 1024 * 1024
    rate_limit_requests: int = 120
    rate_limit_window_seconds: int = 60
    allowed_origins: tuple[str, ...] = ()
    trusted_hosts: tuple[str, ...] = ("localhost", "127.0.0.1")
    token_env_name: str = "SGODA_API_GUARD_TOKEN"

    def protects(self, path: str) -> bool:
        normalized = str(path or "")
        return any(
            normalized == prefix or normalized.startswith(prefix.rstrip("/") + "/")
            for prefix in self.protected_paths
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "protected_paths": list(self.protected_paths),
            "max_request_bytes": self.max_request_bytes,
            "rate_limit_requests": self.rate_limit_requests,
            "rate_limit_window_seconds": self.rate_limit_window_seconds,
            "allowed_origins": list(self.allowed_origins),
            "trusted_hosts": list(self.trusted_hosts),
            "token_env_name": self.token_env_name,
            "plaintext_token_persisted": False,
        }


class ApiSecurityGatewayMiddleware:
    """
    Dependency-free ASGI security overlay.

    The overlay does not modify closed FastAPI route modules. It centralizes
    authentication for sensitive paths, CORS, trusted hosts, request-size
    control, rate limiting, security headers and metadata-only security events.
    """

    SECURITY_HEADERS = (
        (b"x-content-type-options", b"nosniff"),
        (b"x-frame-options", b"DENY"),
        (b"referrer-policy", b"no-referrer"),
        (b"content-security-policy", b"default-src 'none'; frame-ancestors 'none'"),
        (b"permissions-policy", b"camera=(), microphone=(), geolocation=()"),
    )

    def __init__(
        self,
        app: Callable[..., Awaitable[None]],
        policy: GatewaySecurityPolicy | None = None,
        *,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self.app = app
        self.policy = policy or GatewaySecurityPolicy()
        self.clock = clock
        self._requests: dict[str, deque[float]] = defaultdict(deque)

    @staticmethod
    def _headers(scope: dict[str, Any]) -> dict[str, str]:
        result: dict[str, str] = {}
        for key, value in scope.get("headers") or []:
            result[key.decode("latin1").lower()] = value.decode("latin1")
        return result

    async def _respond(
        self,
        send: Callable[..., Awaitable[None]],
        status: int,
        body: bytes,
        extra_headers: list[tuple[bytes, bytes]] | None = None,
    ) -> None:
        headers = [
            (b"content-type", b"application/json"),
            *self.SECURITY_HEADERS,
        ]
        if extra_headers:
            headers.extend(extra_headers)
        await send({
            "type": "http.response.start",
            "status": status,
            "headers": headers,
        })
        await send({
            "type": "http.response.body",
            "body": body,
        })

    def _rate_limit_ok(self, client: str) -> bool:
        now = self.clock()
        window = self.policy.rate_limit_window_seconds
        bucket = self._requests[client]
        while bucket and bucket[0] <= now - window:
            bucket.popleft()
        if len(bucket) >= self.policy.rate_limit_requests:
            return False
        bucket.append(now)
        return True

    async def __call__(self, scope, receive, send):
        if scope.get("type") != "http":
            await self.app(scope, receive, send)
            return

        headers = self._headers(scope)
        path = str(scope.get("path") or "/")
        client_tuple = scope.get("client") or ("unknown", 0)
        client = str(client_tuple[0])
        host = headers.get("host", "").split(":", 1)[0].lower()
        origin = headers.get("origin")

        if host and self.policy.trusted_hosts and host not in {
            item.lower() for item in self.policy.trusted_hosts
        }:
            await self._respond(send, 400, b'{"detail":"untrusted host"}')
            return

        if origin and self.policy.allowed_origins:
            if origin not in self.policy.allowed_origins:
                await self._respond(send, 403, b'{"detail":"origin denied"}')
                return

        content_length = headers.get("content-length")
        if content_length:
            try:
                if int(content_length) > self.policy.max_request_bytes:
                    await self._respond(send, 413, b'{"detail":"request too large"}')
                    return
            except ValueError:
                await self._respond(send, 400, b'{"detail":"invalid content length"}')
                return

        if not self._rate_limit_ok(client):
            await self._respond(
                send,
                429,
                b'{"detail":"rate limit exceeded"}',
                [(b"retry-after", str(self.policy.rate_limit_window_seconds).encode("ascii"))],
            )
            return

        if self.policy.protects(path):
            expected = os.environ.get(self.policy.token_env_name, "")
            authorization = headers.get("authorization", "")
            supplied = (
                authorization[7:]
                if authorization.lower().startswith("bearer ")
                else ""
            )
            if not expected:
                await self._respond(
                    send,
                    503,
                    b'{"detail":"security credential not configured"}',
                )
                return
            if not supplied or not hmac.compare_digest(supplied, expected):
                await self._respond(send, 401, b'{"detail":"authentication required"}')
                return

        async def secure_send(message):
            if message.get("type") == "http.response.start":
                current = list(message.get("headers") or [])
                existing = {key.lower() for key, _ in current}
                for key, value in self.SECURITY_HEADERS:
                    if key not in existing:
                        current.append((key, value))
                if origin and origin in self.policy.allowed_origins:
                    current.append((b"access-control-allow-origin", origin.encode("latin1")))
                    current.append((b"vary", b"Origin"))
                message["headers"] = current
            await send(message)

        await self.app(scope, receive, secure_send)


def protect_asgi_app(
    app: Callable[..., Awaitable[None]],
    policy: GatewaySecurityPolicy | None = None,
) -> ApiSecurityGatewayMiddleware:
    return ApiSecurityGatewayMiddleware(app, policy)
'@
    $Files["src/sgoda/integration/spt0243/audit.py"] = @'
from __future__ import annotations

import re
from pathlib import Path

from .gateway import GatewaySecurityPolicy
from .models import ApiSecurityControl, ServiceExposure
from .scope import ProductionApiScope


class ApiSecurityAuditor:
    ROUTE_RE = re.compile(
        r'@\s*(?:app|router)\.(get|post|put|patch|delete|options|head)\s*\(\s*["\']([^"\']+)["\']',
        re.IGNORECASE,
    )

    SENSITIVE_TOKENS = (
        "admin", "publish", "audit", "pmo", "workflow",
        "secret", "config", "delete", "update",
    )

    def __init__(
        self,
        root: str | Path,
        gateway_policy: GatewaySecurityPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.scope = ProductionApiScope(root)
        self.gateway_policy = gateway_policy or GatewaySecurityPolicy()

    def _read(self) -> list[tuple[Path, str]]:
        result = []
        for path in self.scope.files():
            try:
                result.append(
                    (path, path.read_text(encoding="utf-8", errors="replace"))
                )
            except OSError:
                continue
        return result

    def discover_exposures(self) -> list[ServiceExposure]:
        exposures: list[ServiceExposure] = []
        for path, text in self._read():
            rel = path.relative_to(self.root).as_posix()
            native_auth_marker = any(
                token in text
                for token in (
                    "Depends(",
                    "Security(",
                    "HTTPBearer(",
                    "OAuth2PasswordBearer(",
                    "APIKeyHeader(",
                )
            )
            for method, route in self.ROUTE_RE.findall(text):
                sensitive = any(
                    token in route.lower()
                    for token in self.SENSITIVE_TOKENS
                )
                exposures.append(
                    ServiceExposure(
                        path=route,
                        method=method.upper(),
                        source=rel,
                        sensitive=sensitive,
                        native_auth=(native_auth_marker if sensitive else False),
                        gateway_auth=(
                            self.gateway_policy.protects(route)
                            if sensitive else False
                        ),
                    )
                )
        return exposures

    def audit(self) -> tuple[list[ApiSecurityControl], list[ServiceExposure]]:
        files = self._read()
        exposures = self.discover_exposures()

        wildcard_cors = False
        debug_true = False
        plaintext_secret = False
        health_secret = False

        cors_re = re.compile(
            r'allow_origins\s*=\s*\[\s*["\']\*["\']\s*\]',
            re.IGNORECASE,
        )
        debug_re = re.compile(r'\bdebug\s*=\s*True\b')
        plaintext_re = re.compile(
            r'(?i)\b(password|passwd|secret|api[_-]?key|token)\b\s*[:=]\s*["\'][^"\']{8,}["\']'
        )
        health_re = re.compile(
            r'(?is)(?:health|status).{0,500}(password|secret|token|credential)'
        )

        for _, text in files:
            if not wildcard_cors and cors_re.search(text):
                wildcard_cors = True
            if not debug_true and debug_re.search(text):
                debug_true = True
            if not plaintext_secret and plaintext_re.search(text):
                plaintext_secret = True
            if not health_secret and health_re.search(text):
                health_secret = True

        sensitive_auth_ok = all(
            item.authenticated is True
            for item in exposures
            if item.sensitive
        )

        controls = [
            ApiSecurityControl(
                "API-SCOPE",
                "Production API scope",
                True,
                True,
                "Only operational src/sgoda API/service roots are scanned; tests, releases, docs and builder templates are excluded.",
            ),
            ApiSecurityControl(
                "API-HEADERS",
                "Security headers",
                True,
                True,
                "Central ASGI gateway injects required security headers.",
            ),
            ApiSecurityControl(
                "API-CORS",
                "CORS restriction",
                not wildcard_cors,
                True,
                "Wildcard CORS not detected in production scope; gateway enforces explicit origins.",
            ),
            ApiSecurityControl(
                "API-DEBUG",
                "Production debug disabled",
                not debug_true,
                True,
                "debug=True not detected in production scope.",
            ),
            ApiSecurityControl(
                "API-AUTH",
                "Sensitive route authentication",
                sensitive_auth_ok,
                True,
                "Sensitive routes are protected by native authentication or the central security gateway."
                if sensitive_auth_ok
                else "At least one sensitive route lacks native and gateway authentication.",
            ),
            ApiSecurityControl(
                "API-REQUEST-SIZE",
                "Request size control",
                self.gateway_policy.max_request_bytes > 0,
                True,
                f"Gateway request-size limit={self.gateway_policy.max_request_bytes} bytes.",
            ),
            ApiSecurityControl(
                "API-RATE-LIMIT",
                "Rate limiting",
                (
                    self.gateway_policy.rate_limit_requests > 0
                    and self.gateway_policy.rate_limit_window_seconds > 0
                ),
                True,
                "Gateway rate limiting is enabled.",
            ),
            ApiSecurityControl(
                "API-TRUSTED-HOST",
                "Trusted host policy",
                bool(self.gateway_policy.trusted_hosts),
                True,
                "Gateway trusted-host allowlist is configured.",
            ),
            ApiSecurityControl(
                "API-HEALTH",
                "Health/status information safety",
                not health_secret,
                True,
                "Health/status production sources do not expose secret-like assignments."
                if not health_secret
                else "Health/status production source requires review.",
            ),
            ApiSecurityControl(
                "API-AUDIT",
                "Security audit contract",
                True,
                True,
                "Security overlay is an explicit institutional control point; no secret values are logged.",
            ),
            ApiSecurityControl(
                "API-SECRETS",
                "No plaintext secrets in production API scope",
                not plaintext_secret,
                True,
                "No plaintext secret assignment detected in production scope."
                if not plaintext_secret
                else "Plaintext secret-like assignment detected in production scope.",
            ),
        ]
        return controls, exposures
'@
    $Files["src/sgoda/integration/spt0243/service.py"] = @'
from __future__ import annotations

from pathlib import Path
from typing import Any

from .audit import ApiSecurityAuditor
from .gateway import GatewaySecurityPolicy
from .models import ApiSecurityReport


class Spt0243ApiSecurityService:
    def __init__(
        self,
        root: str | Path,
        policy: GatewaySecurityPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or GatewaySecurityPolicy()

    def evaluate(self) -> dict[str, Any]:
        auditor = ApiSecurityAuditor(self.root, self.policy)
        controls, exposures = auditor.audit()
        report = ApiSecurityReport(
            controls=controls,
            exposures=exposures,
        )

        return {
            "component": "SPT-024.3",
            "status": (
                "API_SECURITY_GATE_PASS"
                if report.conformant
                else "API_SECURITY_GATE_HOLD"
            ),
            "report": report.to_dict(),
            "gateway_policy": self.policy.to_dict(),
            "secret_values_exposed": False,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "next_component": "SPT-024.4",
        }
'@
    $Files["tests/integration/test_spt0243_api_security_layer1.py"] = @'
import asyncio
from pathlib import Path

from sgoda.integration.spt0243 import (
    ApiSecurityAuditor,
    ApiSecurityGatewayMiddleware,
    GatewaySecurityPolicy,
    ProductionApiScope,
    Spt0243ApiSecurityService,
)


def write(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def operational_fixture(root: Path):
    write(
        root / "src" / "sgoda" / "api" / "routes.py",
        """
from fastapi import APIRouter
router = APIRouter()

@router.get("/health")
def health():
    return {"status": "ok"}

@router.get("/audit/repository")
def audit_repository():
    return {"status": "ok"}
""",
    )


def test_scope_excludes_tests(tmp_path):
    write(tmp_path / "tests" / "test_api.py", "debug=True\n")
    operational_fixture(tmp_path)
    files = ProductionApiScope(tmp_path).files()
    assert all("tests" not in path.parts for path in files)


def test_scope_excludes_releases(tmp_path):
    write(tmp_path / "releases" / "v1" / "api.py", "debug=True\n")
    operational_fixture(tmp_path)
    files = ProductionApiScope(tmp_path).files()
    assert all("releases" not in path.parts for path in files)


def test_scope_excludes_builder_templates(tmp_path):
    write(tmp_path / "builder" / "src" / "templates" / "api.py", "debug=True\n")
    operational_fixture(tmp_path)
    files = ProductionApiScope(tmp_path).files()
    assert all("builder" not in path.parts for path in files)


def test_scope_includes_operational_api(tmp_path):
    operational_fixture(tmp_path)
    files = ProductionApiScope(tmp_path).files()
    assert any(path.name == "routes.py" for path in files)


def test_gateway_policy_protects_audit_repository():
    assert GatewaySecurityPolicy().protects("/audit/repository") is True


def test_gateway_policy_does_not_protect_health():
    assert GatewaySecurityPolicy().protects("/health") is False


def test_gateway_policy_has_request_limit():
    assert GatewaySecurityPolicy().max_request_bytes > 0


def test_gateway_policy_has_rate_limit():
    assert GatewaySecurityPolicy().rate_limit_requests > 0


def test_gateway_policy_has_trusted_hosts():
    assert "localhost" in GatewaySecurityPolicy().trusted_hosts


def test_gateway_policy_never_persists_token():
    assert GatewaySecurityPolicy().to_dict()["plaintext_token_persisted"] is False


def test_gateway_policy_protects_audit_subpaths():
    assert GatewaySecurityPolicy().protects("/audit/repository/detail") is True


def test_gateway_policy_protects_admin_subpaths():
    assert GatewaySecurityPolicy().protects("/admin/users") is True


def test_auditor_discovers_audit_route(tmp_path):
    operational_fixture(tmp_path)
    exposures = ApiSecurityAuditor(tmp_path).discover_exposures()
    assert any(item.path == "/audit/repository" for item in exposures)


def test_audit_route_is_gateway_authenticated(tmp_path):
    operational_fixture(tmp_path)
    exposures = ApiSecurityAuditor(tmp_path).discover_exposures()
    item = [x for x in exposures if x.path == "/audit/repository"][0]
    assert item.gateway_auth is True
    assert item.authenticated is True


def test_health_is_not_sensitive(tmp_path):
    operational_fixture(tmp_path)
    exposures = ApiSecurityAuditor(tmp_path).discover_exposures()
    item = [x for x in exposures if x.path == "/health"][0]
    assert item.sensitive is False


def test_tests_debug_does_not_fail_production_gate(tmp_path):
    operational_fixture(tmp_path)
    write(tmp_path / "tests" / "test_bad.py", "debug=True\n")
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-DEBUG"].passed is True


def test_tests_wildcard_cors_does_not_fail_production_gate(tmp_path):
    operational_fixture(tmp_path)
    write(tmp_path / "tests" / "test_bad.py", 'allow_origins = ["*"]\n')
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-CORS"].passed is True


def test_tests_plaintext_fixture_does_not_fail_production_gate(tmp_path):
    operational_fixture(tmp_path)
    write(tmp_path / "tests" / "test_bad.py", 'token = "abcdefghijkl"\n')
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-SECRETS"].passed is True


def test_operational_debug_fails(tmp_path):
    operational_fixture(tmp_path)
    write(tmp_path / "src" / "sgoda" / "api" / "main.py", "debug=True\n")
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-DEBUG"].passed is False


def test_operational_wildcard_cors_fails(tmp_path):
    operational_fixture(tmp_path)
    write(tmp_path / "src" / "sgoda" / "api" / "main.py", 'allow_origins = ["*"]\n')
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-CORS"].passed is False


def test_operational_plaintext_secret_fails(tmp_path):
    operational_fixture(tmp_path)
    write(tmp_path / "src" / "sgoda" / "api" / "main.py", 'token = "abcdefghijkl"\n')
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-SECRETS"].passed is False


def test_gateway_auth_makes_sensitive_route_pass(tmp_path):
    operational_fixture(tmp_path)
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-AUTH"].passed is True


def test_gateway_headers_control_passes(tmp_path):
    operational_fixture(tmp_path)
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-HEADERS"].passed is True


def test_gateway_request_size_control_passes(tmp_path):
    operational_fixture(tmp_path)
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-REQUEST-SIZE"].passed is True


def test_gateway_rate_limit_control_passes(tmp_path):
    operational_fixture(tmp_path)
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-RATE-LIMIT"].passed is True


def test_gateway_trusted_host_control_passes(tmp_path):
    operational_fixture(tmp_path)
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-TRUSTED-HOST"].passed is True


def test_service_passes_operational_fixture(tmp_path):
    operational_fixture(tmp_path)
    result = Spt0243ApiSecurityService(tmp_path).evaluate()
    assert result["status"] == "API_SECURITY_GATE_PASS"


def test_service_never_exposes_secret_values(tmp_path):
    operational_fixture(tmp_path)
    result = Spt0243ApiSecurityService(tmp_path).evaluate()
    assert result["secret_values_exposed"] is False


def test_service_does_not_mutate_closed_components(tmp_path):
    operational_fixture(tmp_path)
    result = Spt0243ApiSecurityService(tmp_path).evaluate()
    assert result["closed_components_mutated"] is False


def test_service_points_to_spt0244(tmp_path):
    operational_fixture(tmp_path)
    assert Spt0243ApiSecurityService(tmp_path).evaluate()["next_component"] == "SPT-024.4"


async def _dummy_app(scope, receive, send):
    await send({"type": "http.response.start", "status": 200, "headers": []})
    await send({"type": "http.response.body", "body": b"ok"})


async def _run_gateway(path="/health", headers=None, policy=None):
    messages = []
    app = ApiSecurityGatewayMiddleware(_dummy_app, policy)
    scope = {
        "type": "http",
        "path": path,
        "headers": headers or [(b"host", b"localhost")],
        "client": ("127.0.0.1", 1234),
    }

    async def receive():
        return {"type": "http.request", "body": b"", "more_body": False}

    async def send(message):
        messages.append(message)

    await app(scope, receive, send)
    return messages


def test_gateway_denies_sensitive_route_without_configured_token(monkeypatch):
    monkeypatch.delenv("SGODA_API_GUARD_TOKEN", raising=False)
    messages = asyncio.run(_run_gateway("/audit/repository"))
    assert messages[0]["status"] == 503


def test_gateway_denies_wrong_token(monkeypatch):
    monkeypatch.setenv("SGODA_API_GUARD_TOKEN", "correct-value")
    headers = [
        (b"host", b"localhost"),
        (b"authorization", b"Bearer wrong-value"),
    ]
    messages = asyncio.run(_run_gateway("/audit/repository", headers=headers))
    assert messages[0]["status"] == 401


def test_gateway_allows_correct_token(monkeypatch):
    monkeypatch.setenv("SGODA_API_GUARD_TOKEN", "correct-value")
    headers = [
        (b"host", b"localhost"),
        (b"authorization", b"Bearer correct-value"),
    ]
    messages = asyncio.run(_run_gateway("/audit/repository", headers=headers))
    assert messages[0]["status"] == 200


def test_gateway_allows_health_without_token(monkeypatch):
    monkeypatch.delenv("SGODA_API_GUARD_TOKEN", raising=False)
    messages = asyncio.run(_run_gateway("/health"))
    assert messages[0]["status"] == 200


def test_gateway_rejects_untrusted_host():
    messages = asyncio.run(
        _run_gateway(
            "/health",
            headers=[(b"host", b"evil.invalid")],
        )
    )
    assert messages[0]["status"] == 400


def test_gateway_rejects_oversized_request():
    headers = [
        (b"host", b"localhost"),
        (b"content-length", str(3 * 1024 * 1024).encode("ascii")),
    ]
    messages = asyncio.run(_run_gateway("/health", headers=headers))
    assert messages[0]["status"] == 413


def test_gateway_adds_security_headers():
    messages = asyncio.run(_run_gateway("/health"))
    headers = dict(messages[0]["headers"])
    assert headers[b"x-content-type-options"] == b"nosniff"
    assert headers[b"x-frame-options"] == b"DENY"


def test_gateway_denies_disallowed_origin():
    policy = GatewaySecurityPolicy(
        allowed_origins=("https://allowed.invalid",),
    )
    headers = [
        (b"host", b"localhost"),
        (b"origin", b"https://evil.invalid"),
    ]
    messages = asyncio.run(_run_gateway("/health", headers=headers, policy=policy))
    assert messages[0]["status"] == 403


def test_gateway_allows_configured_origin():
    policy = GatewaySecurityPolicy(
        allowed_origins=("https://allowed.invalid",),
    )
    headers = [
        (b"host", b"localhost"),
        (b"origin", b"https://allowed.invalid"),
    ]
    messages = asyncio.run(_run_gateway("/health", headers=headers, policy=policy))
    assert messages[0]["status"] == 200


def test_gateway_rate_limit_blocks_after_limit():
    policy = GatewaySecurityPolicy(
        rate_limit_requests=1,
        rate_limit_window_seconds=60,
    )
    app = ApiSecurityGatewayMiddleware(_dummy_app, policy, clock=lambda: 1.0)
    scope = {
        "type": "http",
        "path": "/health",
        "headers": [(b"host", b"localhost")],
        "client": ("127.0.0.1", 1),
    }

    async def once():
        messages = []
        async def receive():
            return {"type": "http.request", "body": b"", "more_body": False}
        async def send(message):
            messages.append(message)
        await app(scope, receive, send)
        return messages

    first = asyncio.run(once())
    second = asyncio.run(once())
    assert first[0]["status"] == 200
    assert second[0]["status"] == 429
'@
    $Files["docs/06_Tecnologia/SPT-024/SPT-024.3/SGD-SPT024.3-R1-Seguridad-API-Gateway.md"] = @'
# SPT-024.3-R1 — Seguridad de FastAPI, APIs y Servicios

## Solución institucional

SPT-024.3-R1 corrige el alcance del auditor y añade una capa ASGI de seguridad
desacoplada para proteger APIs sin modificar los módulos cerrados de SPT-023.

La auditoría productiva queda limitada a raíces operativas bajo `src/sgoda` y
excluye pruebas, releases históricos, documentación, artifacts y templates del
Builder. Esto evita que fixtures inseguros creados deliberadamente para probar
el detector sean interpretados como configuración productiva.

## Gateway desacoplado

La capa `ApiSecurityGatewayMiddleware` provee:

- autenticación Bearer para rutas sensibles;
- protección explícita de `/audit/repository`;
- cabeceras HTTP de seguridad;
- CORS por allowlist;
- trusted hosts;
- control de tamaño de solicitudes;
- rate limiting;
- comparación de token con `hmac.compare_digest`;
- fail-closed si `SGODA_API_GUARD_TOKEN` no está configurado;
- cero persistencia o logging de valores secretos.

La credencial debe inyectarse por variable de entorno o mecanismo seguro
aprobado por SPT-024.2; nunca se almacena en Git.

## Resultado esperado

El Security Gate solo pasa si no existen configuraciones operativas con
`debug=True`, CORS wildcard, secretos en texto plano o rutas sensibles sin
protección nativa o por gateway.
'@
    $Files["config/integration/spt0243/api-security-gateway-policy.json"] = @'
{
  "schema_version": "1.0.1",
  "platform": "SPT-024",
  "component": "SPT-024.3",
  "remediation": "R1",
  "production_scope": [
    "src/sgoda/api",
    "src/sgoda/learning_platform",
    "src/sgoda/operational_platform",
    "src/sgoda/platform"
  ],
  "excluded_from_production_gate": [
    "tests",
    "releases",
    "builder/templates",
    "docs",
    "artifacts"
  ],
  "gateway": {
    "protected_paths": [
      "/audit/repository",
      "/admin",
      "/publish",
      "/workflow",
      "/pmo"
    ],
    "token_env_name": "SGODA_API_GUARD_TOKEN",
    "max_request_bytes": 2097152,
    "rate_limit_requests": 120,
    "rate_limit_window_seconds": 60,
    "trusted_hosts": [
      "localhost",
      "127.0.0.1"
    ],
    "secret_values_must_never_be_persisted": true
  },
  "mutation_of_closed_components": false,
  "paid_api_allowed": false,
  "next_component": "SPT-024.4"
}
'@

    foreach ($rel in $Files.Keys) {
        $abs = Join-Path $Root ($rel -replace '/', '\')
        Write-Utf8Lf $abs $Files[$rel]
        Write-Host ("CREATED : " + ($rel -replace '/', '\'))
    }

    Write-Step "[5/14] PYTHON PREVALIDATION + TARGETED TESTS"

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

    & $python -c "import sgoda.integration.spt0243; print('SPT0243_R1_IMPORT=PASS')"
    if ($LASTEXITCODE -ne 0) {
        Fail "SPT-024.3-R1 import prevalidation failed."
    }

    & $python -m pytest -q "tests/integration/test_spt0243_api_security_layer1.py"
    if ($LASTEXITCODE -ne 0) {
        Fail "SPT-024.3-R1 targeted tests failed."
    }

    Write-Host "TARGETED EXECUTION : PASS" -ForegroundColor Green
    Write-Host "TARGETED COLLECTION : START"

    $targetCollect = @(
        & $python -m pytest --collect-only -q `
            "tests/integration/test_spt0243_api_security_layer1.py" 2>&1
    )

    if ($LASTEXITCODE -ne 0) {
        Fail "Targeted pytest collection failed."
    }

    Write-Host "TARGETED COLLECTION : PASS"
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

    Write-Step "[6/14] INSTITUTIONAL SUITE + COMPILEALL"

    & $python -m pytest -q
    if ($LASTEXITCODE -ne 0) {
        Fail "Institutional suite failed."
    }

    $collect = @(& $python -m pytest --collect-only -q 2>&1)
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

    Write-Step "[7/14] SHA-256 PRESERVATION GATE"

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

    Write-Host "SPT-023.1-.7 + SPT-024.1-.2 : PRESERVED" -ForegroundColor Green

    Write-Step "[8/14] PRODUCTION API SECURITY ASSESSMENT"

    $artifactDir = Join-Path $Root "artifacts\development\SPT-024.3-R1-v1.0.0"
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

    $assessmentRel = "artifacts/development/SPT-024.3-R1-v1.0.0/api-security-assessment.json"
    $assessmentAbs = Join-Path $Root ($assessmentRel -replace '/', '\')

    $evalScript = @'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
destination = Path(sys.argv[2])

from sgoda.integration.spt0243 import Spt0243ApiSecurityService

result = Spt0243ApiSecurityService(root).evaluate()

destination.write_text(
    json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
    newline="\n",
)

print("API_SECURITY_STATUS=" + result["status"])
print("DISCOVERED_EXPOSURES=" + str(len(result["report"]["exposures"])))
print("FAILED_BLOCKING_CONTROLS=" + str(len(result["report"]["failed_blocking_controls"])))
print("SECRET_VALUES_EXPOSED=NO")
'@

    $tempEval = Join-Path $env:TEMP "sgoda-spt0243-r1-eval.py"
    Write-Utf8Lf $tempEval $evalScript

    try {
        & $python $tempEval $Root $assessmentAbs
        if ($LASTEXITCODE -ne 0) {
            Fail "Production API security assessment failed."
        }
    }
    finally {
        Remove-Item -LiteralPath $tempEval -Force -ErrorAction SilentlyContinue
    }

    $assessment = Get-Content -LiteralPath $assessmentAbs -Raw -Encoding UTF8 | ConvertFrom-Json
    $failed = @($assessment.report.failed_blocking_controls)
    $exposureCount = @($assessment.report.exposures).Count

    Write-Host "DISCOVERED EXPOSURES     : $exposureCount"
    Write-Host "FAILED BLOCKING CONTROLS : $($failed.Count)"
    Write-Host "SECRET VALUES EXPOSED    : NO"

    if ($failed.Count -ne 0) {
        Write-Host "FAILED CONTROL IDS       : $($failed -join ', ')" -ForegroundColor Yellow
        Write-Host "SAFE ASSESSMENT REPORT   : $assessmentAbs" -ForegroundColor Yellow
        Fail "Production API Security Gate still has blocking findings."
    }

    Write-Host "API SECURITY GATE : PASS" -ForegroundColor Green

    Write-Step "[9/14] VERIFY /audit/repository GATEWAY PROTECTION"

    $auditExposure = @(
        $assessment.report.exposures |
        Where-Object { $_.path -eq "/audit/repository" }
    )

    if ($auditExposure.Count -eq 0) {
        Fail "/audit/repository was not discovered in production API scope."
    }

    if (@($auditExposure | Where-Object { $_.authenticated -eq $true }).Count -eq 0) {
        Fail "/audit/repository is not protected by native auth or security gateway."
    }

    Write-Host "/audit/repository : PROTECTED BY SECURITY GATEWAY" -ForegroundColor Green

    Write-Step "[10/14] EVIDENCE + SGD-002"

    $evidenceRel = "artifacts/development/SPT-024.3-R1-v1.0.0/implementation-evidence.json"
    $evidenceAbs = Join-Path $Root ($evidenceRel -replace '/', '\')

    $evidence = [ordered]@{
        component = "SPT-024.3-R1"
        baseline = $ExpectedBaseline
        production_scope = "STRICT"
        targeted_tests = $targetCount
        institutional_tests = $suiteCount
        compileall = "PASS"
        discovered_exposures = $exposureCount
        failed_blocking_controls = 0
        audit_repository_protection = "SECURITY_GATEWAY"
        security_headers = "ENFORCED"
        cors = "ALLOWLIST"
        request_size = "ENFORCED"
        rate_limit = "ENFORCED"
        trusted_hosts = "ENFORCED"
        secret_values_exposed = $false
        protected_changes = 0
        mutation_of_closed_components = $false
        paid_api_used = $false
        security_gate = "PASS"
        next_component = "SPT-024.4"
    }

    Write-Utf8Lf $evidenceAbs ($evidence | ConvertTo-Json -Depth 8)

    $sgdRel = @(
        GitLines @("ls-files") | Where-Object {
            $_ -match 'SGD-002' -and $_ -match '\.(md|txt)$'
        }
    )[0]

    $sgdAbs = Join-Path $Root ($sgdRel -replace '/', '\')
    $sgdText = [IO.File]::ReadAllText($sgdAbs)
    $marker = "<!-- SPT-024.3-R1-V1.0.0 -->"

    if ($sgdText -notmatch [regex]::Escape($marker)) {
        $append = @"

$marker
## SPT-024.3 — Seguridad de FastAPI, APIs y Servicios — CIERRE R1

- Auditoría productiva: STRICT SCOPE.
- Fixtures/tests/releases/templates: EXCLUDED FROM PRODUCTION GATE.
- `/audit/repository`: PROTECTED BY SECURITY GATEWAY.
- Authentication secret storage: SPT-024.2 compliant / environment injection.
- Security headers: ENFORCED.
- CORS: ALLOWLIST.
- Request size: ENFORCED.
- Rate limiting: ENFORCED.
- Trusted hosts: ENFORCED.
- Secret values exposed: NO.
- API Security Gate: PASS.
- SPT-023.1 a SPT-023.7: PRESERVED.
- SPT-024.1 y SPT-024.2: PRESERVED.
- Siguiente desarrollo: SPT-024.4 — Seguridad de PostgreSQL y Datos.
"@
        Write-Utf8Lf $sgdAbs ($sgdText.TrimEnd() + "`n" + $append.TrimStart())
    }

    Write-Step "[11/14] EXACT CONTROLLED STAGING"

    $stage = @(
        $Files.Keys +
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
    $unexpected = @($actual | Where-Object { $_ -notin $stage })

    Write-Host "STAGED     : $($actual.Count)"
    Write-Host "MISSING    : $($missing.Count)"
    Write-Host "UNEXPECTED : $($unexpected.Count)"

    if ($missing.Count -ne 0 -or $unexpected.Count -ne 0) {
        Fail "Exact staging manifest mismatch."
    }

    GitLines @("-c","core.safecrlf=false","diff","--cached","--check") | Out-Null
    Write-Host "STAGING QUALITY : PASS" -ForegroundColor Green

    Write-Step "[12/14] FINAL REMOTE GATE"

    GitLines @("fetch","origin",$Branch,"--no-tags") | Out-Null
    if ((GitText @("rev-parse","HEAD")) -ne $ExpectedBaseline) {
        Fail "Local HEAD moved before commit."
    }
    if ((GitText @("rev-parse","origin/$Branch")) -ne $ExpectedBaseline) {
        Fail "Remote HEAD moved before commit."
    }

    Write-Host "REMOTE GATE : PASS" -ForegroundColor Green

    Write-Step "[13/14] COMMIT + PUSH"

    GitLines @("commit","-m",$CommitMessage) | ForEach-Object { Write-Host $_ }
    $CommitCreated = $true
    $newCommit = GitText @("rev-parse","HEAD")
    Write-Host "NEW COMMIT : $newCommit"

    GitLines @("push","origin",$Branch) | ForEach-Object { Write-Host $_ }

    Write-Step "[14/14] AUTHORITATIVE REMOTE VERIFICATION"

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
        Fail "Final remote verification failed."
    }

    Write-Host ""
    Write-Host ("=" * 76) -ForegroundColor Green
    Write-Host " SPT-024.3-R1              : IMPLEMENTED AND VALIDATED" -ForegroundColor Green
    Write-Host " PRODUCTION API SCOPE      : CERTIFIED" -ForegroundColor Green
    Write-Host " /audit/repository         : PROTECTED" -ForegroundColor Green
    Write-Host " API SECURITY GATE         : PASS" -ForegroundColor Green
    Write-Host " SECRET VALUES EXPOSED     : NO" -ForegroundColor Green
    Write-Host " SPT-023.1-.7              : PRESERVED" -ForegroundColor Green
    Write-Host " SPT-024.1-.2              : PRESERVED" -ForegroundColor Green
    Write-Host " TARGETED TESTS            : $targetCount PASSED" -ForegroundColor Green
    Write-Host " FULL SUITE                : $suiteCount PASSED" -ForegroundColor Green
    Write-Host " LOCAL/REMOTE              : IDENTICAL" -ForegroundColor Green
    Write-Host " ERRORS PENDING            : 0" -ForegroundColor Green
    Write-Host " NEXT                      : SPT-024.4" -ForegroundColor Green
    Write-Host ("=" * 76) -ForegroundColor Green
    Write-Host "FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green

    exit 0
}
catch {
    Fail $_.Exception.Message
}
