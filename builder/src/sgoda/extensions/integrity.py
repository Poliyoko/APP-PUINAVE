"""Checksums y verificación de integridad para plugins instalados."""

from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
import json
from pathlib import Path
from typing import Any, Iterable


IGNORED_DIRECTORY_NAMES = {
    "__pycache__",
    ".git",
    ".pytest_cache",
}
IGNORED_FILE_SUFFIXES = {
    ".pyc",
    ".pyo",
}
MANIFEST_NAMES = {
    "sgoda.plugin.json",
    "sgoda.template.json",
}


def sha256_file(path: Path) -> str:
    digest = sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def iter_integrity_files(root: Path) -> Iterable[Path]:
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if any(part in IGNORED_DIRECTORY_NAMES for part in relative.parts):
            continue
        if path.suffix.lower() in IGNORED_FILE_SUFFIXES:
            continue
        yield path


def calculate_file_hashes(root: str | Path) -> dict[str, str]:
    base = Path(root).expanduser().resolve()
    return {
        path.relative_to(base).as_posix(): sha256_file(path)
        for path in iter_integrity_files(base)
    }


def calculate_manifest_hash(root: str | Path) -> str:
    base = Path(root).expanduser().resolve()
    manifests = [
        base / name
        for name in sorted(MANIFEST_NAMES)
        if (base / name).is_file()
    ]
    if len(manifests) != 1:
        return ""
    return sha256_file(manifests[0])


def calculate_tree_checksum(file_hashes: dict[str, str]) -> str:
    canonical = json.dumps(
        file_hashes,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return sha256(canonical).hexdigest()


@dataclass(frozen=True, slots=True)
class IntegritySnapshot:
    checksum: str
    manifest_hash: str
    file_hashes: dict[str, str]

    def to_dict(self) -> dict[str, Any]:
        return {
            "checksum": self.checksum,
            "manifest_hash": self.manifest_hash,
            "file_hashes": dict(self.file_hashes),
        }


def create_integrity_snapshot(root: str | Path) -> IntegritySnapshot:
    file_hashes = calculate_file_hashes(root)
    return IntegritySnapshot(
        checksum=calculate_tree_checksum(file_hashes),
        manifest_hash=calculate_manifest_hash(root),
        file_hashes=file_hashes,
    )


@dataclass(frozen=True, slots=True)
class PluginIntegrityResult:
    name: str
    status: str
    tracked: bool
    checksum_expected: str
    checksum_actual: str
    manifest_hash_expected: str
    manifest_hash_actual: str
    modified_files: tuple[str, ...] = ()
    missing_files: tuple[str, ...] = ()
    added_files: tuple[str, ...] = ()

    @property
    def healthy(self) -> bool:
        return self.status == "HEALTHY"

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "status": self.status,
            "tracked": self.tracked,
            "checksum_expected": self.checksum_expected,
            "checksum_actual": self.checksum_actual,
            "manifest_hash_expected": self.manifest_hash_expected,
            "manifest_hash_actual": self.manifest_hash_actual,
            "modified_files": list(self.modified_files),
            "missing_files": list(self.missing_files),
            "added_files": list(self.added_files),
        }


def verify_integrity(
    *,
    name: str,
    root: str | Path,
    expected_checksum: str,
    expected_manifest_hash: str,
    expected_file_hashes: dict[str, str],
) -> PluginIntegrityResult:
    base = Path(root).expanduser().resolve()
    if not base.is_dir():
        return PluginIntegrityResult(
            name=name,
            status="ERROR",
            tracked=bool(expected_file_hashes),
            checksum_expected=expected_checksum,
            checksum_actual="",
            manifest_hash_expected=expected_manifest_hash,
            manifest_hash_actual="",
            missing_files=tuple(sorted(expected_file_hashes)),
        )

    actual = create_integrity_snapshot(base)
    tracked = bool(
        expected_checksum
        and expected_manifest_hash
        and expected_file_hashes
    )
    if not tracked:
        return PluginIntegrityResult(
            name=name,
            status="UNTRACKED",
            tracked=False,
            checksum_expected=expected_checksum,
            checksum_actual=actual.checksum,
            manifest_hash_expected=expected_manifest_hash,
            manifest_hash_actual=actual.manifest_hash,
        )

    expected_names = set(expected_file_hashes)
    actual_names = set(actual.file_hashes)
    missing = sorted(expected_names - actual_names)
    added = sorted(actual_names - expected_names)
    modified = sorted(
        name
        for name in expected_names & actual_names
        if expected_file_hashes[name] != actual.file_hashes[name]
    )
    healthy = (
        not missing
        and not added
        and not modified
        and expected_checksum == actual.checksum
        and expected_manifest_hash == actual.manifest_hash
    )
    return PluginIntegrityResult(
        name=name,
        status="HEALTHY" if healthy else "ERROR",
        tracked=True,
        checksum_expected=expected_checksum,
        checksum_actual=actual.checksum,
        manifest_hash_expected=expected_manifest_hash,
        manifest_hash_actual=actual.manifest_hash,
        modified_files=tuple(modified),
        missing_files=tuple(missing),
        added_files=tuple(added),
    )
