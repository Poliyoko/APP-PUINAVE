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
