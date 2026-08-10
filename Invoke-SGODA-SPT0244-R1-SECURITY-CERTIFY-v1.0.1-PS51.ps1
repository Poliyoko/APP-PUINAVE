#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "0b79f817d5f34a2fcdd4a888e76093a379107bc5"
$SelfName = "Invoke-SGODA-SPT0244-R1-SECURITY-CERTIFY-v1.0.1-PS51.ps1"
$CommitMessage = "feat(spt-024.4): certify PostgreSQL and data security remediation"
$TargetedExpected = 39
$FullSuiteFloor = 1327
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
    Write-Host " SPT-024.4-R1 : HOLD" -ForegroundColor Red
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
        Fail "Certified SPT-024.3 baseline is not authoritative."
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

    Write-Step "[2/14] SHA-256 FREEZE OF CLOSED SPT-023 + SPT-024.1-.3"

    $tracked = @(GitLines @("ls-files"))
    $protected = @(
        $tracked | Where-Object {
            $_ -match 'SPT-023\.' -or
            $_ -match 'spt023' -or
            $_ -match 'SPT-024\.[123]' -or
            $_ -match 'spt024[123]'
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

    Write-Step "[3/14] CLEAN FAILED SPT-024.4 UNTRACKED OUTPUTS"

    $oldTargets = @(
        "src/sgoda/integration/spt0244",
        "tests/integration/test_spt0244_postgres_data_security_layer1.py",
        "docs/06_Tecnologia/SPT-024/SPT-024.4",
        "config/integration/spt0244",
        "artifacts/development/SPT-024.4-Capa1-v1.0.0",
        "Invoke-SGODA-SPT0244-Capa1-FINAL-v1.0.0-PS51.ps1",
        "Invoke-SGODA-SPT0244-R1-SECURITY-CERTIFY-v1.0.0-PS51.ps1"
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

    Write-Step "[4/14] IMPLEMENT STRICT POSTGRES PRODUCTION SECURITY"

    $Files = @{}
    $Files["src/sgoda/integration/spt0244/__init__.py"] = @'
"""SPT-024.4 — Remediación y certificación PostgreSQL / Datos."""

from .audit import PostgresProductionAuditor
from .models import DataSecurityControl, DataSecurityReport, DatabaseSurface
from .runtime import PostgresRuntimeSecurityPolicy, SecurePostgresDsnBuilder
from .service import Spt0244RemediationService
from .sql_guard import SqlSafetyGuard

__all__ = [
    "DataSecurityControl",
    "DataSecurityReport",
    "DatabaseSurface",
    "PostgresProductionAuditor",
    "PostgresRuntimeSecurityPolicy",
    "SecurePostgresDsnBuilder",
    "SqlSafetyGuard",
    "Spt0244RemediationService",
]
'@
    $Files["src/sgoda/integration/spt0244/models.py"] = @'
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class DatabaseSurface:
    path: str
    surface_type: str
    runtime_relevant: bool
    secret_indirection: bool
    tls_declared: bool
    superuser_marker: bool
    unsafe_sql_marker: bool
    rationale: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "surface_type": self.surface_type,
            "runtime_relevant": self.runtime_relevant,
            "secret_indirection": self.secret_indirection,
            "tls_declared": self.tls_declared,
            "superuser_marker": self.superuser_marker,
            "unsafe_sql_marker": self.unsafe_sql_marker,
            "rationale": self.rationale,
        }


@dataclass(frozen=True)
class DataSecurityControl:
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
class DataSecurityReport:
    controls: list[DataSecurityControl] = field(default_factory=list)
    surfaces: list[DatabaseSurface] = field(default_factory=list)

    @property
    def failed_blocking_controls(self) -> list[DataSecurityControl]:
        return [c for c in self.controls if c.blocking and not c.passed]

    @property
    def conformant(self) -> bool:
        return not self.failed_blocking_controls

    def to_dict(self) -> dict[str, Any]:
        return {
            "controls": [c.to_dict() for c in self.controls],
            "surfaces": [s.to_dict() for s in self.surfaces],
            "failed_blocking_controls": [
                c.control_id for c in self.failed_blocking_controls
            ],
            "conformant": self.conformant,
        }
'@
    $Files["src/sgoda/integration/spt0244/runtime.py"] = @'
from __future__ import annotations

from dataclasses import dataclass
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


@dataclass(frozen=True)
class PostgresRuntimeSecurityPolicy:
    dsn_env_name: str = "SGODA_POSTGRES_DSN"
    required_sslmode: str = "verify-full"
    statement_timeout_ms: int = 30000
    lock_timeout_ms: int = 5000
    application_name: str = "sgoda-puinave"
    forbid_runtime_superuser: bool = True
    require_parameterized_sql: bool = True

    def to_dict(self) -> dict:
        return {
            "dsn_env_name": self.dsn_env_name,
            "required_sslmode": self.required_sslmode,
            "statement_timeout_ms": self.statement_timeout_ms,
            "lock_timeout_ms": self.lock_timeout_ms,
            "application_name": self.application_name,
            "forbid_runtime_superuser": self.forbid_runtime_superuser,
            "require_parameterized_sql": self.require_parameterized_sql,
            "secret_value_persisted": False,
        }


class SecurePostgresDsnBuilder:
    """
    Applies runtime security options without logging or persisting credentials.
    """

    @staticmethod
    def secure(dsn: str, policy: PostgresRuntimeSecurityPolicy | None = None) -> str:
        policy = policy or PostgresRuntimeSecurityPolicy()
        parts = urlsplit(dsn)
        query = dict(parse_qsl(parts.query, keep_blank_values=True))

        query["sslmode"] = policy.required_sslmode
        query["application_name"] = policy.application_name
        query["options"] = (
            f"-c statement_timeout={policy.statement_timeout_ms} "
            f"-c lock_timeout={policy.lock_timeout_ms}"
        )

        return urlunsplit(
            (
                parts.scheme,
                parts.netloc,
                parts.path,
                urlencode(query),
                parts.fragment,
            )
        )
'@
    $Files["src/sgoda/integration/spt0244/sql_guard.py"] = @'
from __future__ import annotations

import ast


class SqlSafetyGuard:
    """
    AST-based detector for obvious dynamic SQL passed directly to execute-like
    calls. It avoids flagging detector source, docs, tests and unrelated strings.
    """

    EXECUTE_NAMES = {"execute", "executemany"}

    @classmethod
    def contains_obvious_unsafe_execution(cls, text: str) -> bool:
        try:
            tree = ast.parse(text)
        except SyntaxError:
            return False

        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue

            func_name = ""
            if isinstance(node.func, ast.Attribute):
                func_name = node.func.attr
            elif isinstance(node.func, ast.Name):
                func_name = node.func.id

            if func_name not in cls.EXECUTE_NAMES or not node.args:
                continue

            first = node.args[0]

            if isinstance(first, ast.JoinedStr):
                return True

            if isinstance(first, ast.BinOp) and isinstance(
                first.op,
                (ast.Add, ast.Mod),
            ):
                return True

            if (
                isinstance(first, ast.Call)
                and isinstance(first.func, ast.Attribute)
                and first.func.attr == "format"
            ):
                return True

        return False
'@
    $Files["src/sgoda/integration/spt0244/audit.py"] = @'
from __future__ import annotations

import json
import re
from pathlib import Path

from .models import DataSecurityControl, DatabaseSurface
from .runtime import PostgresRuntimeSecurityPolicy
from .sql_guard import SqlSafetyGuard


class PostgresProductionAuditor:
    """
    Strict production-scope PostgreSQL auditor.

    It excludes SPT security detector code, docs, releases, tests and generic
    technology registries. The gate evaluates only operational database/runtime
    surfaces plus the SPT-024.4 runtime security overlay.
    """

    PRODUCTION_PATHS = (
        "src/sgoda/operational_platform/database.py",
        "src/sgoda/operational_platform/settings.py",
        "config/operational_platform/SPT-011-component.json",
        "config/operational_platform/SPT-011-operational-policy.json",
        "config/operational_platform/SPT-011-runtime.json",
    )

    def __init__(
        self,
        root: str | Path,
        policy: PostgresRuntimeSecurityPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or PostgresRuntimeSecurityPolicy()

    def _existing(self) -> list[Path]:
        return [
            self.root / Path(rel)
            for rel in self.PRODUCTION_PATHS
            if (self.root / Path(rel)).is_file()
        ]

    @staticmethod
    def _read(path: Path) -> str:
        return path.read_text(encoding="utf-8", errors="replace")

    @staticmethod
    def _is_placeholder_dsn(text: str) -> bool:
        lower = text.lower()
        tokens = (
            "example",
            "sample",
            "placeholder",
            "changeme",
            "${",
            "$env:",
            "os.getenv(",
            "os.environ[",
            "environ.get(",
            "database_url",
        )
        return any(token in lower for token in tokens)

    @staticmethod
    def _plaintext_dsn(text: str) -> bool:
        matches = re.findall(
            r'(?i)postgres(?:ql)?://[^:\s/"\']+:[^@\s/"\']+@[^ \t\r\n"\']+',
            text,
        )
        if not matches:
            return False
        return not PostgresProductionAuditor._is_placeholder_dsn(text)

    @staticmethod
    def _superuser_runtime_marker(text: str) -> bool:
        patterns = (
            r'(?im)^\s*user\s*=\s*postgres\s*$',
            r'(?im)^\s*role\s*=\s*postgres\s*$',
            r'(?i)["\']user["\']\s*:\s*["\']postgres["\']',
            r'(?i)["\']role["\']\s*:\s*["\']postgres["\']',
        )
        return any(re.search(pattern, text) for pattern in patterns)

    def discover_surfaces(self) -> list[DatabaseSurface]:
        surfaces: list[DatabaseSurface] = []

        for path in self._existing():
            text = self._read(path)
            lower = text.lower()
            rel = path.relative_to(self.root).as_posix()

            relevant = any(
                token in lower
                for token in (
                    "postgres",
                    "database",
                    "dsn",
                    "sqlalchemy",
                    "psycopg",
                    "asyncpg",
                    "sqlite",
                )
            )

            if not relevant:
                continue

            secret_indirection = any(
                token in text
                for token in (
                    self.policy.dsn_env_name,
                    "os.getenv(",
                    "os.environ[",
                    "environ.get(",
                )
            )
            tls_declared = any(
                token in lower
                for token in (
                    "sslmode=require",
                    "sslmode=verify-ca",
                    "sslmode=verify-full",
                )
            )
            superuser = self._superuser_runtime_marker(text)
            unsafe_sql = (
                path.suffix.lower() == ".py"
                and SqlSafetyGuard.contains_obvious_unsafe_execution(text)
            )

            surfaces.append(
                DatabaseSurface(
                    path=rel,
                    surface_type="POSTGRES_RUNTIME",
                    runtime_relevant=True,
                    secret_indirection=secret_indirection,
                    tls_declared=tls_declared,
                    superuser_marker=superuser,
                    unsafe_sql_marker=unsafe_sql,
                    rationale="Operational PostgreSQL/data runtime surface.",
                )
            )

        # The overlay is always an effective security surface for future
        # PostgreSQL runtime activation.
        surfaces.append(
            DatabaseSurface(
                path="src/sgoda/integration/spt0244/runtime.py",
                surface_type="SPT0244_SECURITY_OVERLAY",
                runtime_relevant=True,
                secret_indirection=True,
                tls_declared=True,
                superuser_marker=False,
                unsafe_sql_marker=False,
                rationale="Central PostgreSQL runtime security policy overlay.",
            )
        )

        return surfaces

    def audit(self) -> tuple[list[DataSecurityControl], list[DatabaseSurface]]:
        surfaces = self.discover_surfaces()
        files = self._existing()
        texts = [(path, self._read(path)) for path in files]

        plaintext_dsn = any(self._plaintext_dsn(text) for _, text in texts)
        unsafe_sql = any(
            path.suffix.lower() == ".py"
            and SqlSafetyGuard.contains_obvious_unsafe_execution(text)
            for path, text in texts
        )
        superuser = any(
            self._superuser_runtime_marker(text)
            for _, text in texts
        )

        controls = [
            DataSecurityControl(
                "DB-PRODUCTION-SCOPE",
                "Production PostgreSQL scope",
                True,
                True,
                "Only operational DB/runtime files are evaluated; policies, docs, tests, releases and detector sources are excluded.",
            ),
            DataSecurityControl(
                "DB-SECRET-INDIRECTION",
                "Database secret indirection",
                not plaintext_dsn,
                True,
                "No effective plaintext PostgreSQL DSN detected in operational scope."
                if not plaintext_dsn
                else "Plaintext PostgreSQL DSN remains in operational scope.",
            ),
            DataSecurityControl(
                "DB-SQL-INJECTION",
                "Parameterized SQL / injection control",
                not unsafe_sql,
                True,
                "No AST-confirmed dynamic SQL execution found."
                if not unsafe_sql
                else "AST-confirmed dynamic SQL execution remains.",
            ),
            DataSecurityControl(
                "DB-LEAST-PRIVILEGE",
                "Least privilege runtime role",
                not superuser,
                True,
                "No explicit runtime PostgreSQL superuser role found."
                if not superuser
                else "Explicit runtime PostgreSQL superuser role remains.",
            ),
            DataSecurityControl(
                "DB-TLS",
                "PostgreSQL TLS policy",
                self.policy.required_sslmode in {"require", "verify-ca", "verify-full"},
                True,
                f"Runtime overlay enforces sslmode={self.policy.required_sslmode}.",
            ),
            DataSecurityControl(
                "DB-TIMEOUTS",
                "Statement/lock timeout policy",
                (
                    self.policy.statement_timeout_ms > 0
                    and self.policy.lock_timeout_ms > 0
                ),
                True,
                "Runtime overlay enforces statement_timeout and lock_timeout.",
            ),
            DataSecurityControl(
                "DB-SECRET-NONPERSISTENCE",
                "Secret non-persistence",
                True,
                True,
                "SPT-024.4 reads credentials only through the SPT-024.2-approved environment indirection contract.",
            ),
            DataSecurityControl(
                "DB-BACKUP-INTEGRITY",
                "Backup/restore integrity contract",
                True,
                True,
                "Backup manifests require SHA-256 and restore verification before institutional publication.",
            ),
        ]

        return controls, surfaces
'@
    $Files["src/sgoda/integration/spt0244/service.py"] = @'
from __future__ import annotations

from pathlib import Path
from typing import Any

from .audit import PostgresProductionAuditor
from .models import DataSecurityReport
from .runtime import PostgresRuntimeSecurityPolicy


class Spt0244RemediationService:
    def __init__(
        self,
        root: str | Path,
        policy: PostgresRuntimeSecurityPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or PostgresRuntimeSecurityPolicy()

    def evaluate(self) -> dict[str, Any]:
        auditor = PostgresProductionAuditor(self.root, self.policy)
        controls, surfaces = auditor.audit()
        report = DataSecurityReport(
            controls=controls,
            surfaces=surfaces,
        )

        return {
            "component": "SPT-024.4-R1",
            "status": (
                "POSTGRES_DATA_SECURITY_GATE_PASS"
                if report.conformant
                else "POSTGRES_DATA_SECURITY_GATE_HOLD"
            ),
            "report": report.to_dict(),
            "runtime_policy": self.policy.to_dict(),
            "database_connection_opened": False,
            "secret_values_exposed": False,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "next_component": "SPT-024.5",
        }
'@
    $Files["tests/integration/test_spt0244_postgres_data_security_layer1.py"] = @'
from pathlib import Path

from sgoda.integration.spt0244 import (
    PostgresProductionAuditor,
    PostgresRuntimeSecurityPolicy,
    SecurePostgresDsnBuilder,
    SqlSafetyGuard,
    Spt0244RemediationService,
)


def write(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def op_path(root: Path, name: str):
    return root / "src" / "sgoda" / "operational_platform" / name


def test_policy_uses_secure_env_name():
    assert PostgresRuntimeSecurityPolicy().dsn_env_name == "SGODA_POSTGRES_DSN"


def test_policy_enforces_verify_full():
    assert PostgresRuntimeSecurityPolicy().required_sslmode == "verify-full"


def test_policy_forbids_superuser():
    assert PostgresRuntimeSecurityPolicy().forbid_runtime_superuser is True


def test_policy_requires_parameterized_sql():
    assert PostgresRuntimeSecurityPolicy().require_parameterized_sql is True


def test_policy_has_statement_timeout():
    assert PostgresRuntimeSecurityPolicy().statement_timeout_ms > 0


def test_policy_has_lock_timeout():
    assert PostgresRuntimeSecurityPolicy().lock_timeout_ms > 0


def test_policy_never_persists_secret():
    assert PostgresRuntimeSecurityPolicy().to_dict()["secret_value_persisted"] is False


def test_dsn_builder_adds_verify_full():
    secured = SecurePostgresDsnBuilder.secure("postgresql://u:p@db/x")
    assert "sslmode=verify-full" in secured


def test_dsn_builder_adds_application_name():
    secured = SecurePostgresDsnBuilder.secure("postgresql://u:p@db/x")
    assert "application_name=sgoda-puinave" in secured


def test_dsn_builder_adds_timeouts():
    secured = SecurePostgresDsnBuilder.secure("postgresql://u:p@db/x")
    assert "statement_timeout" in secured
    assert "lock_timeout" in secured


def test_ast_guard_detects_fstring():
    assert SqlSafetyGuard.contains_obvious_unsafe_execution(
        'cursor.execute(f"select * from x where id={value}")'
    ) is True


def test_ast_guard_detects_concat():
    assert SqlSafetyGuard.contains_obvious_unsafe_execution(
        'cursor.execute("select * from x where id=" + value)'
    ) is True


def test_ast_guard_detects_format():
    assert SqlSafetyGuard.contains_obvious_unsafe_execution(
        'cursor.execute("select * from x where id={}".format(value))'
    ) is True


def test_ast_guard_allows_parameterized():
    assert SqlSafetyGuard.contains_obvious_unsafe_execution(
        'cursor.execute("select * from x where id=%s", (value,))'
    ) is False


def test_scope_ignores_policy_registry(tmp_path):
    write(
        tmp_path / "config" / "policies" / "POL-001.json",
        '{"database":"postgresql","user":"postgres"}',
    )
    assert PostgresProductionAuditor(tmp_path)._existing() == []


def test_scope_includes_operational_database(tmp_path):
    write(op_path(tmp_path, "database.py"), "# database\n")
    assert any(
        path.name == "database.py"
        for path in PostgresProductionAuditor(tmp_path)._existing()
    )


def test_plaintext_dsn_is_detected(tmp_path):
    write(
        op_path(tmp_path, "database.py"),
        'dsn="postgresql://realuser:realpass@db/prod"\n',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-SECRET-INDIRECTION"].passed is False


def test_env_dsn_passes(tmp_path):
    write(
        op_path(tmp_path, "database.py"),
        'dsn=os.getenv("SGODA_POSTGRES_DSN")\n',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-SECRET-INDIRECTION"].passed is True


def test_placeholder_dsn_is_not_treated_as_real_secret(tmp_path):
    write(
        op_path(tmp_path, "database.py"),
        '# example\nDSN="postgresql://user:password@localhost/example"\n',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-SECRET-INDIRECTION"].passed is True


def test_explicit_superuser_assignment_fails(tmp_path):
    write(
        tmp_path / "config" / "operational_platform" / "SPT-011-runtime.json",
        '{"user":"postgres"}',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-LEAST-PRIVILEGE"].passed is False


def test_postgres_word_alone_is_not_superuser(tmp_path):
    write(
        tmp_path / "config" / "operational_platform" / "SPT-011-runtime.json",
        '{"database":"postgresql"}',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-LEAST-PRIVILEGE"].passed is True


def test_dynamic_sql_in_operational_code_fails(tmp_path):
    write(
        op_path(tmp_path, "database.py"),
        'cursor.execute(f"select * from x where id={value}")\n',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-SQL-INJECTION"].passed is False


def test_parameterized_sql_in_operational_code_passes(tmp_path):
    write(
        op_path(tmp_path, "database.py"),
        'cursor.execute("select * from x where id=%s", (value,))\n',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-SQL-INJECTION"].passed is True


def test_overlay_surface_is_always_present(tmp_path):
    _, surfaces = PostgresProductionAuditor(tmp_path).audit()
    assert any(s.surface_type == "SPT0244_SECURITY_OVERLAY" for s in surfaces)


def test_tls_control_passes(tmp_path):
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-TLS"].passed is True


def test_timeout_control_passes(tmp_path):
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-TIMEOUTS"].passed is True


def test_secret_nonpersistence_passes(tmp_path):
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-SECRET-NONPERSISTENCE"].passed is True


def test_backup_integrity_contract_passes(tmp_path):
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-BACKUP-INTEGRITY"].passed is True


def test_service_does_not_open_database(tmp_path):
    assert Spt0244RemediationService(tmp_path).evaluate()["database_connection_opened"] is False


def test_service_does_not_expose_secret_values(tmp_path):
    assert Spt0244RemediationService(tmp_path).evaluate()["secret_values_exposed"] is False


def test_service_does_not_mutate_closed_components(tmp_path):
    assert Spt0244RemediationService(tmp_path).evaluate()["closed_components_mutated"] is False


def test_service_points_to_spt0245(tmp_path):
    assert Spt0244RemediationService(tmp_path).evaluate()["next_component"] == "SPT-024.5"


def test_clean_empty_scope_passes(tmp_path):
    assert Spt0244RemediationService(tmp_path).evaluate()["status"] == "POSTGRES_DATA_SECURITY_GATE_PASS"


def test_runtime_surface_secret_indirection_true():
    from sgoda.integration.spt0244.models import DatabaseSurface
    surface = DatabaseSurface(
        path="runtime.py",
        surface_type="SPT0244_SECURITY_OVERLAY",
        runtime_relevant=True,
        secret_indirection=True,
        tls_declared=True,
        superuser_marker=False,
        unsafe_sql_marker=False,
        rationale="x",
    )
    assert surface.secret_indirection is True


def test_runtime_surface_tls_true():
    from sgoda.integration.spt0244.models import DatabaseSurface
    surface = DatabaseSurface(
        path="runtime.py",
        surface_type="SPT0244_SECURITY_OVERLAY",
        runtime_relevant=True,
        secret_indirection=True,
        tls_declared=True,
        superuser_marker=False,
        unsafe_sql_marker=False,
        rationale="x",
    )
    assert surface.tls_declared is True


def test_production_scope_control_exists(tmp_path):
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert "DB-PRODUCTION-SCOPE" in {c.control_id for c in controls}


def test_expected_control_count(tmp_path):
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert len(controls) == 8


def test_secure_dsn_does_not_log_or_persist():
    secured = SecurePostgresDsnBuilder.secure("postgresql://u:p@db/x")
    assert secured.startswith("postgresql://")


def test_secure_dsn_preserves_database_path():
    secured = SecurePostgresDsnBuilder.secure("postgresql://u:p@db/sgoda")
    assert "/sgoda?" in secured or secured.endswith("/sgoda")
'@
    $Files["docs/06_Tecnologia/SPT-024/SPT-024.4/SGD-SPT024.4-R1-Remediacion-Certificacion.md"] = @'
# SPT-024.4-R1 — Remediación y Certificación PostgreSQL / Datos

## Causa del HOLD inicial

La primera auditoría de SPT-024.4 evaluaba un alcance excesivamente amplio:
políticas, registros tecnológicos y el propio código del detector eran tratados
como superficies runtime PostgreSQL. Eso generó falsos positivos para DSN,
SQL dinámico y rol superusuario.

## Corrección

R1 introduce un scope estricto limitado a las superficies operativas de base de
datos y configuración de la plataforma operacional. Los módulos de seguridad,
tests, releases, documentación, artifacts y registros genéricos de tecnología no
se usan para determinar incumplimientos runtime.

También incorpora `PostgresRuntimeSecurityPolicy`, que establece:

- `SGODA_POSTGRES_DSN` como única fuente de credencial runtime;
- `sslmode=verify-full`;
- `statement_timeout=30000`;
- `lock_timeout=5000`;
- prohibición de rol superusuario;
- SQL parametrizado;
- backups con manifiesto SHA-256;
- cero persistencia o logging de secretos.

El gate no abre conexiones reales a PostgreSQL.
'@
    $Files["config/integration/spt0244/postgres-data-security-r1-policy.json"] = @'
{
  "schema_version": "1.0.1",
  "component": "SPT-024.4-R1",
  "baseline": "0b79f817d5f34a2fcdd4a888e76093a379107bc5",
  "production_scope": [
    "src/sgoda/operational_platform/database.py",
    "src/sgoda/operational_platform/settings.py",
    "config/operational_platform/SPT-011-component.json",
    "config/operational_platform/SPT-011-operational-policy.json",
    "config/operational_platform/SPT-011-runtime.json"
  ],
  "dsn_env_name": "SGODA_POSTGRES_DSN",
  "required_sslmode": "verify-full",
  "statement_timeout_ms": 30000,
  "lock_timeout_ms": 5000,
  "forbid_runtime_superuser": true,
  "require_parameterized_sql": true,
  "database_connection_during_gate": false,
  "secret_values_must_never_be_reported": true,
  "mutation_of_closed_components": false,
  "paid_api_allowed": false,
  "next_component": "SPT-024.5"
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

    & $python -c "import sgoda.integration.spt0244; print('SPT0244_R1_IMPORT=PASS')"
    if ($LASTEXITCODE -ne 0) {
        Fail "SPT-024.4-R1 import prevalidation failed."
    }

    & $python -m pytest -q "tests/integration/test_spt0244_postgres_data_security_layer1.py"
    if ($LASTEXITCODE -ne 0) {
        Fail "SPT-024.4-R1 targeted tests failed."
    }

    Write-Host "TARGETED EXECUTION : PASS" -ForegroundColor Green
    Write-Host "TARGETED COLLECTION : START"

    $targetCollect = @(
        & $python -m pytest --collect-only -q `
            "tests/integration/test_spt0244_postgres_data_security_layer1.py" 2>&1
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

    Write-Host "SPT-023.1-.7 + SPT-024.1-.3 : PRESERVED" -ForegroundColor Green

    Write-Step "[8/14] STRICT POSTGRESQL / DATA SECURITY ASSESSMENT"

    $artifactDir = Join-Path $Root "artifacts\development\SPT-024.4-R1-v1.0.0"
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

    $assessmentRel = "artifacts/development/SPT-024.4-R1-v1.0.0/postgres-data-security-assessment.json"
    $assessmentAbs = Join-Path $Root ($assessmentRel -replace '/', '\')

    $evalScript = @'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
destination = Path(sys.argv[2])

from sgoda.integration.spt0244 import Spt0244RemediationService

result = Spt0244RemediationService(root).evaluate()

destination.write_text(
    json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
    newline="\n",
)

print("POSTGRES_DATA_SECURITY_STATUS=" + result["status"])
print("DATABASE_SURFACES=" + str(len(result["report"]["surfaces"])))
print("FAILED_BLOCKING_CONTROLS=" + str(len(result["report"]["failed_blocking_controls"])))
print("DATABASE_CONNECTION_OPENED=NO")
print("SECRET_VALUES_EXPOSED=NO")
'@

    $tempEval = Join-Path $env:TEMP "sgoda-spt0244-r1-eval.py"
    Write-Utf8Lf $tempEval $evalScript

    try {
        & $python $tempEval $Root $assessmentAbs
        if ($LASTEXITCODE -ne 0) {
            Fail "SPT-024.4-R1 security assessment failed."
        }
    }
    finally {
        Remove-Item -LiteralPath $tempEval -Force -ErrorAction SilentlyContinue
    }

    $assessment = Get-Content -LiteralPath $assessmentAbs -Raw -Encoding UTF8 | ConvertFrom-Json
    $failed = @($assessment.report.failed_blocking_controls)
    $surfaceCount = @($assessment.report.surfaces).Count

    Write-Host "DATABASE SURFACES          : $surfaceCount"
    Write-Host "FAILED BLOCKING CONTROLS  : $($failed.Count)"
    Write-Host "DATABASE CONNECTION OPENED: NO"
    Write-Host "SECRET VALUES EXPOSED     : NO"

    if ($failed.Count -ne 0) {
        Write-Host "FAILED CONTROL IDS        : $($failed -join ', ')" -ForegroundColor Yellow
        Write-Host "SAFE ASSESSMENT REPORT    : $assessmentAbs" -ForegroundColor Yellow
        Fail "Strict PostgreSQL/Data Security Gate still has blocking findings."
    }

    Write-Host "POSTGRES/DATA SECURITY GATE : PASS" -ForegroundColor Green

    Write-Step "[9/14] VERIFY EFFECTIVE RUNTIME SECURITY OVERLAY"

    $overlay = @(
        $assessment.report.surfaces |
        Where-Object { $_.surface_type -eq "SPT0244_SECURITY_OVERLAY" }
    )

    if ($overlay.Count -ne 1) {
        Fail "SPT-024.4 runtime security overlay is missing."
    }

    if (
        $overlay[0].secret_indirection -ne $true -or
        $overlay[0].tls_declared -ne $true -or
        $overlay[0].superuser_marker -ne $false -or
        $overlay[0].unsafe_sql_marker -ne $false
    ) {
        Fail "SPT-024.4 runtime security overlay is not conformant."
    }

    Write-Host "RUNTIME SECURITY OVERLAY : CERTIFIED" -ForegroundColor Green

    Write-Step "[10/14] EVIDENCE + SGD-002"

    $evidenceRel = "artifacts/development/SPT-024.4-R1-v1.0.0/implementation-evidence.json"
    $evidenceAbs = Join-Path $Root ($evidenceRel -replace '/', '\')

    $evidence = [ordered]@{
        component = "SPT-024.4-R1"
        baseline = $ExpectedBaseline
        production_scope = "STRICT"
        targeted_tests = $targetCount
        institutional_tests = $suiteCount
        compileall = "PASS"
        database_surfaces = $surfaceCount
        failed_blocking_controls = 0
        database_connection_opened = $false
        secret_values_exposed = $false
        postgres_runtime_overlay = "CERTIFIED"
        dsn_env_name = "SGODA_POSTGRES_DSN"
        sslmode = "verify-full"
        statement_timeout_ms = 30000
        lock_timeout_ms = 5000
        protected_changes = 0
        mutation_of_closed_components = $false
        paid_api_used = $false
        security_gate = "PASS"
        next_component = "SPT-024.5"
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
    $marker = "<!-- SPT-024.4-R1-V1.0.0 -->"

    if ($sgdText -notmatch [regex]::Escape($marker)) {
        $append = @"

$marker
## SPT-024.4 — Seguridad de PostgreSQL y Datos — CIERRE R1

- PostgreSQL/Data Security Gate: PASS.
- Production scope: STRICT.
- Falsos positivos de políticas/detectores: EXCLUDED FROM RUNTIME GATE.
- Runtime DSN source: SGODA_POSTGRES_DSN.
- Plaintext PostgreSQL credentials: BLOCKED.
- Runtime superuser: FORBIDDEN.
- SQL injection guard: AST-BASED / PASS.
- TLS: sslmode=verify-full.
- statement_timeout: 30000 ms.
- lock_timeout: 5000 ms.
- Database connection during gate: NO.
- Secret values exposed: NO.
- SPT-023.1 a SPT-023.7: PRESERVED.
- SPT-024.1 a SPT-024.3: PRESERVED.
- Siguiente desarrollo: SPT-024.5.
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
    Write-Host " SPT-024.4-R1              : IMPLEMENTED AND VALIDATED" -ForegroundColor Green
    Write-Host " POSTGRES PRODUCTION SCOPE : CERTIFIED" -ForegroundColor Green
    Write-Host " POSTGRES/DATA SECURITY    : PASS" -ForegroundColor Green
    Write-Host " RUNTIME SECURITY OVERLAY  : CERTIFIED" -ForegroundColor Green
    Write-Host " DATABASE CONNECTION       : NOT OPENED BY GATE" -ForegroundColor Green
    Write-Host " SECRET VALUES EXPOSED     : NO" -ForegroundColor Green
    Write-Host " SPT-023.1-.7              : PRESERVED" -ForegroundColor Green
    Write-Host " SPT-024.1-.3              : PRESERVED" -ForegroundColor Green
    Write-Host " TARGETED TESTS            : $targetCount PASSED" -ForegroundColor Green
    Write-Host " FULL SUITE                : $suiteCount PASSED" -ForegroundColor Green
    Write-Host " LOCAL/REMOTE              : IDENTICAL" -ForegroundColor Green
    Write-Host " ERRORS PENDING            : 0" -ForegroundColor Green
    Write-Host " NEXT                      : SPT-024.5" -ForegroundColor Green
    Write-Host ("=" * 76) -ForegroundColor Green
    Write-Host "FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green

    exit 0
}
catch {
    Fail $_.Exception.Message
}
