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
