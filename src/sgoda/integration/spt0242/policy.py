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
