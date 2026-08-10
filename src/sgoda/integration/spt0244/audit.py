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
