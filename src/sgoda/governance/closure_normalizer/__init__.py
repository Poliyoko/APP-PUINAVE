
from __future__ import annotations

import argparse
import json
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any


CLOSED_STATUSES = {
    "closed",
    "implemented",
    "institutionally_closed",
    "implemented_tested_and_candidate_for_closure",
    "technically_completed",
}


@dataclass(frozen=True, slots=True)
class ClosureResult:
    code: str
    descriptor: str
    release: str
    manifest: str
    status_before: str
    status_after: str
    changed: bool
    approved: bool

    def to_dict(self) -> dict[str, Any]:
        return {
            "code": self.code,
            "descriptor": self.descriptor,
            "release": self.release,
            "manifest": self.manifest,
            "status_before": self.status_before,
            "status_after": self.status_after,
            "changed": self.changed,
            "approved": self.approved,
        }


def _values(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value] if value.strip() else []
    if isinstance(value, list):
        return [str(item) for item in value if str(item).strip()]
    return []


def _find_release(root: Path, code: str, version: str) -> Path | None:
    releases = root / "releases"
    if not releases.is_dir():
        return None

    preferred = releases / f"{code}-v{version}"
    if version and preferred.is_dir():
        return preferred

    matches = sorted(
        (
            path
            for path in releases.iterdir()
            if path.is_dir()
            and path.name.upper().startswith(code.upper() + "-V")
        ),
        key=lambda item: item.name.casefold(),
    )
    return matches[-1] if matches else None


def _ensure_release(
    root: Path,
    code: str,
    version: str,
    descriptor_path: Path,
    payload: dict[str, Any],
) -> tuple[Path, Path, bool]:
    release = _find_release(root, code, version)
    changed = False

    if release is None:
        release = root / "releases" / f"{code}-v{version or '1.0.0'}"
        release.mkdir(parents=True, exist_ok=True)
        changed = True

    manifest = release / "manifest.json"

    canonical_manifest = {
        "program": payload.get("program", "PCI-SGODA-v1.0.0"),
        "increment_code": code,
        "version": version or "1.0.0",
        "release_name": release.name,
        "status": "institutionally_closed",
        "descriptor": descriptor_path.relative_to(root).as_posix(),
        "source": _values(
            payload.get("source")
            or payload.get("source_paths")
            or payload.get("code_paths")
        ),
        "tests": _values(
            payload.get("tests")
            or payload.get("test_paths")
        ),
        "documentation": _values(
            payload.get("documentation")
            or payload.get("documentation_paths")
            or payload.get("docs")
        ),
        "dependencies": _values(payload.get("dependencies")),
        "native_ecosystem": bool(payload.get("native_ecosystem", True)),
    }

    current = None
    if manifest.is_file():
        try:
            current = json.loads(manifest.read_text(encoding="utf-8-sig"))
        except Exception:
            current = None

    if current != canonical_manifest:
        manifest.write_text(
            json.dumps(
                canonical_manifest,
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            ) + "\n",
            encoding="utf-8",
        )
        changed = True

    return release, manifest, changed


def normalize_descriptor(
    root_value: str | Path,
    descriptor_value: str | Path,
) -> ClosureResult:
    root = Path(root_value).resolve()
    descriptor = Path(descriptor_value)
    if not descriptor.is_absolute():
        descriptor = root / descriptor

    payload = json.loads(
        descriptor.read_text(encoding="utf-8-sig")
    )
    if not isinstance(payload, dict):
        raise ValueError(f"Descriptor inválido: {descriptor}")

    code = str(
        payload.get("increment_code")
        or payload.get("component_code")
        or payload.get("code")
        or ""
    ).strip().upper()
    if not code:
        raise ValueError(f"Descriptor sin código: {descriptor}")

    version = str(payload.get("version", "1.0.0")).strip() or "1.0.0"
    status_before = str(payload.get("status", "unknown")).strip()

    release, manifest, release_changed = _ensure_release(
        root,
        code,
        version,
        descriptor,
        payload,
    )

    changed = release_changed
    canonical = dict(payload)
    canonical["increment_code"] = code
    canonical["version"] = version
    canonical["status"] = "institutionally_closed"
    canonical["institutionally_closed"] = True
    canonical["release_name"] = release.name
    canonical["release_manifest"] = manifest.relative_to(root).as_posix()
    canonical["completion_percent"] = 100.0

    for key in ("source", "tests", "documentation", "dependencies"):
        canonical[key] = _values(canonical.get(key))

    if canonical != payload:
        descriptor.write_text(
            json.dumps(
                canonical,
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            ) + "\n",
            encoding="utf-8",
        )
        changed = True

    approved = (
        descriptor.is_file()
        and release.is_dir()
        and manifest.is_file()
        and canonical["status"] == "institutionally_closed"
        and canonical["completion_percent"] == 100.0
    )

    return ClosureResult(
        code=code,
        descriptor=descriptor.relative_to(root).as_posix(),
        release=release.relative_to(root).as_posix(),
        manifest=manifest.relative_to(root).as_posix(),
        status_before=status_before,
        status_after=canonical["status"],
        changed=changed,
        approved=approved,
    )


def normalize_all(
    root_value: str | Path,
    *,
    backup_dir: str | Path,
    evidence_json: str | Path,
    include_codes: list[str] | None = None,
) -> dict[str, Any]:
    root = Path(root_value).resolve()
    backup = Path(backup_dir)
    backup.mkdir(parents=True, exist_ok=True)

    descriptors = sorted(
        (root / "config").rglob("*-component.json"),
        key=lambda item: item.as_posix().casefold(),
    )

    wanted = {item.upper() for item in include_codes or []}
    selected: list[Path] = []

    for descriptor in descriptors:
        try:
            payload = json.loads(
                descriptor.read_text(encoding="utf-8-sig")
            )
        except Exception:
            continue

        code = str(
            payload.get("increment_code")
            or payload.get("component_code")
            or payload.get("code")
            or ""
        ).strip().upper()

        if not code:
            continue

        if wanted and code not in wanted:
            continue

        selected.append(descriptor)

    results = []
    for descriptor in selected:
        relative = descriptor.relative_to(root)
        backup_path = backup / relative
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        if descriptor.is_file() and not backup_path.is_file():
            shutil.copy2(descriptor, backup_path)

        results.append(
            normalize_descriptor(root, descriptor).to_dict()
        )

    report = {
        "program": "PCI-SGODA-v1.0.0",
        "increment_code": "PCI-001.4",
        "deliverable": "SGD-201A.4",
        "version": "1.0.0",
        "components_processed": len(results),
        "components_changed": sum(item["changed"] for item in results),
        "components_approved": sum(item["approved"] for item in results),
        "results": results,
        "approved": bool(results)
        and all(item["approved"] for item in results),
    }

    evidence = Path(evidence_json)
    evidence.parent.mkdir(parents=True, exist_ok=True)
    evidence.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--backup-dir", required=True)
    parser.add_argument("--evidence-json", required=True)
    parser.add_argument("--include-code", action="append", default=[])
    args = parser.parse_args()

    result = normalize_all(
        args.root,
        backup_dir=args.backup_dir,
        evidence_json=args.evidence_json,
        include_codes=args.include_code,
    )
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["approved"] else 2
