
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Iterable

from .models import MasterDocumentAudit, RepositoryAsset


IGNORED_PARTS = {
    ".git",
    ".venv",
    "__pycache__",
    ".pytest_cache",
    "node_modules",
}

CATEGORY_ROOTS = {
    "source": "src",
    "tests": "tests",
    "documentation": "docs",
    "configuration": "config",
    "evidence": "artifacts",
    "release": "releases",
    "automation": "scripts",
    "dashboard": "dashboard",
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _relative(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def _is_ignored(path: Path) -> bool:
    return any(part in IGNORED_PARTS for part in path.parts)


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8-sig", errors="replace")
    except OSError:
        return ""


class InstitutionalRepositoryManager:
    def __init__(self, root: str | Path) -> None:
        self.root = Path(root).resolve()

    def audit_master_documents(
        self,
        component_code: str = "SGD-117",
    ) -> MasterDocumentAudit:
        index = self.root / "docs" / "00_INDICE_MAESTRO.md"
        registry = (
            self.root
            / "docs"
            / "00_REGISTRO_MAESTRO_COMPONENTES.md"
        )
        normalized = component_code.casefold()

        index_text = _read_text(index).casefold() if index.is_file() else ""
        registry_text = (
            _read_text(registry).casefold()
            if registry.is_file()
            else ""
        )

        config_declares = False
        config_root = self.root / "config"
        if config_root.is_dir():
            for path in config_root.rglob("*.json"):
                if _is_ignored(path):
                    continue
                try:
                    payload = json.loads(
                        path.read_text(encoding="utf-8-sig")
                    )
                except (OSError, UnicodeError, json.JSONDecodeError):
                    continue
                code = str(
                    payload.get("increment_code")
                    or payload.get("component_code")
                    or payload.get("code")
                    or ""
                ).casefold()
                if code == normalized:
                    config_declares = True
                    break

        releases = self.root / "releases"
        release_exists = (
            releases.is_dir()
            and any(
                path.is_dir()
                and path.name.casefold().startswith(
                    normalized + "-v"
                )
                for path in releases.iterdir()
            )
        )

        return MasterDocumentAudit(
            index_exists=index.is_file(),
            registry_exists=registry.is_file(),
            index_mentions_component=normalized in index_text,
            registry_mentions_component=normalized in registry_text,
            config_declares_component=config_declares,
            release_exists=release_exists,
        )

    def inventory(self) -> tuple[RepositoryAsset, ...]:
        assets: list[RepositoryAsset] = []

        for category, root_name in CATEGORY_ROOTS.items():
            base = self.root / root_name
            if not base.exists():
                continue

            for path in sorted(base.rglob("*")):
                if not path.is_file() or _is_ignored(path):
                    continue
                try:
                    size = path.stat().st_size
                    digest = _sha256(path)
                except OSError:
                    continue
                assets.append(
                    RepositoryAsset(
                        path=_relative(path, self.root),
                        category=category,
                        size_bytes=size,
                        sha256=digest,
                    )
                )

        return tuple(assets)

    def validate_structure(self) -> dict[str, Any]:
        required_directories = [
            "src",
            "tests",
            "docs",
            "config",
            "artifacts",
            "releases",
            "scripts",
        ]
        required_files = [
            "pytest.ini",
            "docs/00_INDICE_MAESTRO.md",
            "docs/00_REGISTRO_MAESTRO_COMPONENTES.md",
            "docs/00_ARQUITECTURA_MAESTRA.md",
        ]

        missing_directories = [
            item
            for item in required_directories
            if not (self.root / item).is_dir()
        ]
        missing_files = [
            item
            for item in required_files
            if not (self.root / item).is_file()
        ]

        invalid_json = []
        config_root = self.root / "config"
        if config_root.is_dir():
            for path in sorted(config_root.rglob("*.json")):
                if _is_ignored(path):
                    continue
                try:
                    json.loads(path.read_text(encoding="utf-8-sig"))
                except (OSError, UnicodeError, json.JSONDecodeError):
                    invalid_json.append(_relative(path, self.root))

        approved = not any(
            (missing_directories, missing_files, invalid_json)
        )
        return {
            "approved": approved,
            "exit_code": 0 if approved else 2,
            "missing_directories": missing_directories,
            "missing_files": missing_files,
            "invalid_json": invalid_json,
        }

    def find_untracked_large_assets(
        self,
        threshold_bytes: int = 25 * 1024 * 1024,
    ) -> list[dict[str, Any]]:
        results = []
        for item in self.inventory():
            if item.size_bytes >= threshold_bytes:
                results.append(
                    {
                        "path": item.path,
                        "category": item.category,
                        "size_bytes": item.size_bytes,
                        "sha256": item.sha256,
                    }
                )
        return results

    def build_report(self) -> dict[str, Any]:
        audit = self.audit_master_documents()
        assets = self.inventory()
        validation = self.validate_structure()
        category_counts: dict[str, int] = {}
        total_bytes = 0

        for item in assets:
            category_counts[item.category] = (
                category_counts.get(item.category, 0) + 1
            )
            total_bytes += item.size_bytes

        return {
            "component": "SGD-117",
            "version": "1.0.0",
            "master_document_audit": audit.to_dict(),
            "repository_validation": validation,
            "asset_count": len(assets),
            "total_bytes": total_bytes,
            "category_counts": category_counts,
            "large_assets": self.find_untracked_large_assets(),
            "approved": validation["approved"],
            "exit_code": validation["exit_code"],
        }
