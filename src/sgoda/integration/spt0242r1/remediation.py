from __future__ import annotations

from pathlib import Path
from typing import Iterable


class GitignoreRemediator:
    REQUIRED_PATTERNS = (
        ".env",
        ".env.*",
        "*.pem",
        "*.key",
        "*.pfx",
        "*.p12",
    )

    def __init__(self, root: str | Path) -> None:
        self.root = Path(root)

    def plan(self) -> dict:
        path = self.root / ".gitignore"
        existing = []
        if path.exists():
            existing = path.read_text(
                encoding="utf-8",
                errors="replace",
            ).splitlines()

        active = {
            line.strip()
            for line in existing
            if line.strip() and not line.lstrip().startswith("#")
        }

        missing = [
            pattern
            for pattern in self.REQUIRED_PATTERNS
            if pattern not in active
        ]

        return {
            "path": ".gitignore",
            "missing_patterns": missing,
            "change_required": bool(missing),
        }

    def apply(self) -> dict:
        plan = self.plan()
        if not plan["change_required"]:
            return {
                **plan,
                "changed": False,
            }

        path = self.root / ".gitignore"
        content = ""
        if path.exists():
            content = path.read_text(
                encoding="utf-8",
                errors="replace",
            ).replace("\r\n", "\n").replace("\r", "\n")
            content = content.rstrip("\n") + "\n"

        block = [
            "",
            "# SPT-024 PISI - institutional secret protection",
            *plan["missing_patterns"],
            "",
        ]

        path.write_text(
            content + "\n".join(block),
            encoding="utf-8",
            newline="\n",
        )

        return {
            **plan,
            "changed": True,
        }


class RemediationPolicy:
    """
    Defines what R1 may change automatically.

    Only low-risk repository hygiene is automatically changed. Credential
    replacement, deletion from history and rotation are deliberately excluded.
    """

    AUTO_REMEDIATION_ACTIONS = (
        "ADD_GITIGNORE_SECRET_PATTERNS",
    )

    MANUAL_ACTIONS = (
        "ROTATE_CREDENTIAL",
        "REPLACE_RUNTIME_REFERENCE",
        "REMOVE_SECRET_FROM_GIT_HISTORY",
        "VALIDATE_SERVICE_DEPENDENCY",
    )

    @classmethod
    def to_dict(cls) -> dict:
        return {
            "automatic": list(cls.AUTO_REMEDIATION_ACTIONS),
            "manual_or_followup": list(cls.MANUAL_ACTIONS),
            "secret_values_must_never_be_logged": True,
        }
