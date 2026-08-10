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
