
from __future__ import annotations

import json
import shutil
import tempfile
from pathlib import Path
from typing import Any, Iterable

from .models import ReleaseOperationResult
from .resolver import collapse_duplicate_revision, parse_release_name


_TEXT_SUFFIXES = {
    ".json",
    ".md",
    ".txt",
    ".yaml",
    ".yml",
}


class InstitutionalReleaseManager:
    def __init__(self, root: str | Path) -> None:
        self.root = Path(root).resolve()
        self.releases = self.root / "releases"

    def discover_duplicates(self) -> tuple[tuple[str, str], ...]:
        if not self.releases.exists():
            return ()

        pairs = []

        for path in sorted(self.releases.iterdir()):
            if not path.is_dir():
                continue

            try:
                canonical = collapse_duplicate_revision(path.name)
            except ValueError:
                continue

            if canonical != path.name:
                pairs.append((path.name, canonical))

        return tuple(pairs)

    def migrate_missing_manifests(self) -> tuple[dict[str, Any], ...]:
        self.releases.mkdir(parents=True, exist_ok=True)
        migrated = []

        for release in sorted(self.releases.iterdir()):
            if not release.is_dir():
                continue

            manifest = release / "manifest.json"

            if manifest.exists():
                continue

            try:
                identity = parse_release_name(release.name)
                increment_code = identity.increment_code
                version = identity.version
            except ValueError:
                increment_code = release.name
                version = "legacy"

            files = sorted(
                path.relative_to(release).as_posix()
                for path in release.rglob("*")
                if path.is_file()
            )

            payload = {
                "increment_code": increment_code,
                "version": version,
                "release_name": release.name,
                "status": "legacy_migrated",
                "legacy": True,
                "manifest_generated_by": "SGD-114G-v1.0.1",
                "files": files,
            }

            manifest.write_text(
                json.dumps(
                    payload,
                    indent=2,
                    ensure_ascii=False,
                ) + "\n",
                encoding="utf-8",
            )

            migrated.append(
                {
                    "release": release.name,
                    "manifest": manifest.as_posix(),
                    "legacy": True,
                }
            )

        return tuple(migrated)

    def normalize(
        self,
        source_name: str,
        canonical_name: str | None = None,
    ) -> ReleaseOperationResult:
        self.releases.mkdir(parents=True, exist_ok=True)

        source = self.releases / source_name
        target_name = canonical_name or collapse_duplicate_revision(source_name)
        target = self.releases / target_name

        if not source.exists():
            return ReleaseOperationResult(
                approved=False,
                action="none",
                canonical_release=target_name,
                source_release=source_name,
                backup_path=None,
                references_updated=0,
                findings=(
                    {
                        "code": "SOURCE_NOT_FOUND",
                        "path": str(source),
                    },
                ),
            )

        backup_root = (
            self.root
            / "artifacts"
            / "governance"
            / "SGD-114G"
            / "backups"
        )
        backup_root.mkdir(parents=True, exist_ok=True)

        temp_root = Path(
            tempfile.mkdtemp(
                prefix="sgd114g-",
                dir=str(backup_root),
            )
        )
        backup = temp_root / source.name

        try:
            shutil.copytree(source, backup, dirs_exist_ok=True)
            staging = temp_root / "staging"
            staging.mkdir(parents=True, exist_ok=True)

            if target.exists():
                shutil.copytree(target, staging, dirs_exist_ok=True)

            shutil.copytree(source, staging, dirs_exist_ok=True)
            self._normalize_manifest(staging, target_name)

            if target.exists():
                shutil.rmtree(target)

            shutil.move(str(staging), str(target))

            if source.resolve() != target.resolve() and source.exists():
                shutil.rmtree(source)

            updated = self._update_references(source_name, target_name)

            return ReleaseOperationResult(
                approved=True,
                action="normalized",
                canonical_release=target_name,
                source_release=source_name,
                backup_path=str(backup),
                references_updated=updated,
                findings=(),
            )
        except Exception as error:
            if source.exists():
                shutil.rmtree(source)

            if backup.exists():
                shutil.copytree(backup, source, dirs_exist_ok=True)

            return ReleaseOperationResult(
                approved=False,
                action="rolled_back",
                canonical_release=target_name,
                source_release=source_name,
                backup_path=str(backup),
                references_updated=0,
                findings=(
                    {
                        "code": "NORMALIZATION_FAILED",
                        "message": str(error),
                    },
                ),
            )

    def normalize_all(self) -> tuple[ReleaseOperationResult, ...]:
        return tuple(
            self.normalize(source, target)
            for source, target in self.discover_duplicates()
        )

    def validate(self) -> dict[str, Any]:
        duplicates = self.discover_duplicates()
        findings = []
        validated = []

        if self.releases.exists():
            for release in sorted(self.releases.iterdir()):
                if not release.is_dir():
                    continue

                manifest = release / "manifest.json"

                if not manifest.exists():
                    findings.append(
                        {
                            "code": "MANIFEST_MISSING",
                            "release": release.name,
                        }
                    )
                    continue

                try:
                    payload = json.loads(
                        manifest.read_text(encoding="utf-8-sig")
                    )
                except (
                    OSError,
                    UnicodeError,
                    json.JSONDecodeError,
                ) as error:
                    findings.append(
                        {
                            "code": "MANIFEST_INVALID",
                            "release": release.name,
                            "message": str(error),
                        }
                    )
                    continue

                declared = str(
                    payload.get("release_name") or release.name
                )

                if declared != release.name:
                    findings.append(
                        {
                            "code": "MANIFEST_NAME_MISMATCH",
                            "release": release.name,
                            "declared": declared,
                        }
                    )

                validated.append(release.name)

        approved = len(duplicates) == 0 and len(findings) == 0

        return {
            "approved": approved,
            "exit_code": 0 if approved else 2,
            "duplicates": [
                {"source": source, "canonical": canonical}
                for source, canonical in duplicates
            ],
            "validated_manifests": validated,
            "findings": findings,
        }

    def _normalize_manifest(
        self,
        release_dir: Path,
        release_name: str,
    ) -> None:
        manifest = release_dir / "manifest.json"

        if manifest.exists():
            try:
                payload = json.loads(
                    manifest.read_text(encoding="utf-8-sig")
                )
            except (
                OSError,
                UnicodeError,
                json.JSONDecodeError,
            ):
                payload = {}
        else:
            payload = {}

        if not isinstance(payload, dict):
            payload = {}

        payload["release_name"] = release_name
        payload["normalized_by"] = "SGD-114G-v1.0.1"

        manifest.write_text(
            json.dumps(
                payload,
                indent=2,
                ensure_ascii=False,
            ) + "\n",
            encoding="utf-8",
        )

    def _reference_files(self) -> Iterable[Path]:
        for base_name in (
            "artifacts",
            "config",
            "dashboard",
            "docs",
            "releases",
        ):
            base = self.root / base_name

            if not base.exists():
                continue

            for path in base.rglob("*"):
                if (
                    path.is_file()
                    and path.suffix.casefold() in _TEXT_SUFFIXES
                ):
                    yield path

    def _update_references(self, old: str, new: str) -> int:
        updated = 0

        for path in self._reference_files():
            try:
                content = path.read_text(encoding="utf-8-sig")
            except (OSError, UnicodeError):
                continue

            if not content or old not in content:
                continue

            path.write_text(
                content.replace(old, new),
                encoding="utf-8",
            )
            updated += 1

        return updated
