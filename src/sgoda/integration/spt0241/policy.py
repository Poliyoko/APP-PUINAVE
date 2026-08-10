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
