"""SGD-114 v2.0: gobierno institucional del repositorio."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


POLICY_VERSION = "2.0.0"


@dataclass(frozen=True, slots=True)
class ArchivoManifiesto:
    path: str
    sha256: str
    size_bytes: int
    category: str


@dataclass(slots=True)
class ResultadoAuditoriaRepositorio:
    policy_code: str
    policy_version: str
    repository_root: str
    generated_at_utc: str
    passed: bool
    checks: dict[str, bool]
    metrics: dict[str, int]
    missing_directories: list[str]
    missing_files: list[str]
    git: dict[str, Any]
    observations: list[str] = field(default_factory=list)


class ErrorGobiernoRepositorio(ValueError):
    """Error de configuración o auditoría institucional."""


def _read_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(
            f"No se encontró la configuración: {path}"
        )

    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ErrorGobiernoRepositorio(
            f"JSON inválido en {path}: {error}"
        ) from error


def _write_json(path: Path, data: Any) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            data,
            ensure_ascii=False,
            indent=2,
            default=str,
        )
        + "\n",
        encoding="utf-8",
    )

    if not path.is_file() or path.stat().st_size <= 0:
        raise RuntimeError(
            f"No se pudo generar el artefacto: {path}"
        )

    return path


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as stream:
        for chunk in iter(
            lambda: stream.read(1024 * 1024),
            b"",
        ):
            digest.update(chunk)

    return digest.hexdigest()


def _run_git(
    root: Path,
    *args: str,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )


def obtener_estado_git(root: str | Path) -> dict[str, Any]:
    repository_root = Path(root).resolve()

    inside = _run_git(
        repository_root,
        "rev-parse",
        "--is-inside-work-tree",
    )

    if inside.returncode != 0:
        return {
            "available": False,
            "inside_work_tree": False,
            "clean": False,
            "branch": None,
            "head": None,
            "tracked_files": 0,
            "modified_or_untracked": [],
            "error": inside.stderr.strip(),
        }

    status = _run_git(
        repository_root,
        "status",
        "--porcelain",
    )
    branch = _run_git(
        repository_root,
        "branch",
        "--show-current",
    )
    head = _run_git(
        repository_root,
        "rev-parse",
        "HEAD",
    )
    tracked = _run_git(
        repository_root,
        "ls-files",
    )

    changes = [
        line
        for line in status.stdout.splitlines()
        if line.strip()
    ]

    tracked_files = [
        line
        for line in tracked.stdout.splitlines()
        if line.strip()
    ]

    return {
        "available": True,
        "inside_work_tree": True,
        "clean": not changes,
        "branch": branch.stdout.strip() or None,
        "head": (
            head.stdout.strip()
            if head.returncode == 0
            else None
        ),
        "tracked_files": len(tracked_files),
        "modified_or_untracked": changes,
        "error": None,
    }


def _category(relative: str) -> str:
    first = relative.split("/", 1)[0]

    mapping = {
        "src": "source",
        "tests": "tests",
        "docs": "documentation",
        "config": "configuration",
        "scripts": "automation",
        "artifacts": "evidence",
        "dashboard": "dashboard",
        "releases": "release",
    }

    return mapping.get(first, "other")


def _iter_manifest_files(
    root: Path,
    *,
    ignored_directories: set[str],
    extensions: set[str],
    maximum_file_size: int,
) -> Iterable[Path]:
    for path in root.rglob("*"):
        if not path.is_file():
            continue

        relative_parts = path.relative_to(root).parts

        if any(
            part in ignored_directories
            for part in relative_parts
        ):
            continue

        if path.suffix.casefold() not in extensions:
            continue

        if path.stat().st_size > maximum_file_size:
            continue

        yield path


def generar_manifiesto(
    *,
    repository_root: str | Path,
    policy_path: str | Path,
    output_path: str | Path,
) -> Path:
    root = Path(repository_root).resolve()
    policy = _read_json(Path(policy_path))

    ignored = {
        str(value)
        for value in policy.get(
            "ignored_directories",
            [],
        )
    }
    extensions = {
        str(value).casefold()
        for value in policy.get(
            "manifest_extensions",
            [],
        )
    }
    maximum = int(
        policy.get(
            "maximum_manifest_file_size_bytes",
            20 * 1024 * 1024,
        )
    )

    entries: list[ArchivoManifiesto] = []

    for path in _iter_manifest_files(
        root,
        ignored_directories=ignored,
        extensions=extensions,
        maximum_file_size=maximum,
    ):
        relative = path.relative_to(root).as_posix()

        entries.append(
            ArchivoManifiesto(
                path=relative,
                sha256=_sha256(path),
                size_bytes=path.stat().st_size,
                category=_category(relative),
            )
        )

    entries.sort(key=lambda item: item.path)

    totals_by_category: dict[str, int] = {}

    for entry in entries:
        totals_by_category[entry.category] = (
            totals_by_category.get(entry.category, 0)
            + 1
        )

    payload = {
        "policy_code": policy["policy_code"],
        "policy_version": policy["policy_version"],
        "generated_at_utc": datetime.now(
            timezone.utc
        ).isoformat(),
        "repository_root": str(root),
        "total_files": len(entries),
        "totals_by_category": totals_by_category,
        "files": [
            asdict(item)
            for item in entries
        ],
    }

    return _write_json(Path(output_path), payload)


def auditar_repositorio(
    *,
    repository_root: str | Path,
    policy_path: str | Path,
    require_clean_git: bool = False,
) -> ResultadoAuditoriaRepositorio:
    root = Path(repository_root).resolve()

    if not root.is_dir():
        raise NotADirectoryError(
            f"No existe la raíz del repositorio: {root}"
        )

    policy = _read_json(Path(policy_path))

    required_directories = [
        str(value)
        for value in policy["required_directories"]
    ]
    required_files = [
        str(value)
        for value in policy["required_repository_files"]
    ]

    missing_directories = [
        relative
        for relative in required_directories
        if not (root / relative).is_dir()
    ]
    missing_files = [
        relative
        for relative in required_files
        if not (root / relative).is_file()
    ]

    git = obtener_estado_git(root)

    metrics = {
        "source_files": sum(
            1
            for path in (root / "src").rglob("*.py")
            if path.is_file()
        ),
        "test_files": sum(
            1
            for path in (root / "tests").rglob("test_*.py")
            if path.is_file()
        ),
        "documentation_files": sum(
            1
            for path in (root / "docs").rglob("*.md")
            if path.is_file()
        ),
        "configuration_files": sum(
            1
            for path in (root / "config").rglob("*")
            if path.is_file()
        ),
        "evidence_files": sum(
            1
            for path in (root / "artifacts").rglob("*")
            if path.is_file()
        ),
        "dashboard_files": sum(
            1
            for path in (root / "dashboard").rglob("*")
            if path.is_file()
        ),
        "release_files": sum(
            1
            for path in (root / "releases").rglob("*")
            if path.is_file()
        ),
    }

    checks = {
        "required_directories_present": (
            not missing_directories
        ),
        "required_files_present": not missing_files,
        "source_present": metrics["source_files"] > 0,
        "tests_present": metrics["test_files"] > 0,
        "documentation_present": (
            metrics["documentation_files"] > 0
        ),
        "configuration_present": (
            metrics["configuration_files"] > 0
        ),
        "evidence_present": (
            metrics["evidence_files"] > 0
        ),
        "dashboard_present": (
            metrics["dashboard_files"] > 0
        ),
        "release_present": (
            metrics["release_files"] > 0
        ),
        "git_repository_available": bool(
            git["inside_work_tree"]
        ),
        "git_clean_when_required": (
            bool(git["clean"])
            if require_clean_git
            else True
        ),
    }

    observations: list[str] = []

    if not git["clean"]:
        observations.append(
            "El repositorio tiene cambios sin confirmar. "
            "Se registran como evidencia; el cierre de release "
            "debe ejecutarse después del commit."
        )

    if missing_directories:
        observations.append(
            "Faltan directorios: "
            + ", ".join(missing_directories)
        )

    if missing_files:
        observations.append(
            "Faltan archivos: "
            + ", ".join(missing_files)
        )

    return ResultadoAuditoriaRepositorio(
        policy_code=str(policy["policy_code"]),
        policy_version=str(policy["policy_version"]),
        repository_root=str(root),
        generated_at_utc=datetime.now(
            timezone.utc
        ).isoformat(),
        passed=all(checks.values()),
        checks=checks,
        metrics=metrics,
        missing_directories=missing_directories,
        missing_files=missing_files,
        git=git,
        observations=observations,
    )


def publicar_evento(
    *,
    audit: ResultadoAuditoriaRepositorio,
    manifest_path: str | Path,
    output_path: str | Path,
) -> Path:
    manifest = _read_json(Path(manifest_path))

    event = {
        "event_type": "InstitutionalRepositoryAudited",
        "occurred_at_utc": datetime.now(
            timezone.utc
        ).isoformat(),
        "source": "sgoda.governance.repository_governance",
        "policy_code": audit.policy_code,
        "policy_version": audit.policy_version,
        "audit_passed": audit.passed,
        "manifest_total_files": manifest["total_files"],
        "git_clean": audit.git["clean"],
        "git_branch": audit.git["branch"],
        "git_head": audit.git["head"],
        "metrics": audit.metrics,
    }

    return _write_json(Path(output_path), event)


def ejecutar_gobierno_repositorio(
    *,
    repository_root: str | Path,
    policy_path: str | Path,
    audit_output: str | Path,
    manifest_output: str | Path,
    event_output: str | Path,
    require_clean_git: bool = False,
) -> dict[str, Any]:
    audit = auditar_repositorio(
        repository_root=repository_root,
        policy_path=policy_path,
        require_clean_git=require_clean_git,
    )

    audit_path = _write_json(
        Path(audit_output),
        asdict(audit),
    )

    manifest_path = generar_manifiesto(
        repository_root=repository_root,
        policy_path=policy_path,
        output_path=manifest_output,
    )

    event_path = publicar_evento(
        audit=audit,
        manifest_path=manifest_path,
        output_path=event_output,
    )

    return {
        "audit": audit,
        "audit_path": audit_path,
        "manifest_path": manifest_path,
        "event_path": event_path,
    }


def construir_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Audita el repositorio institucional mediante SGD-114 v2."
        )
    )
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--policy",
        default=(
            "config/governance/"
            "sgd-114-v2-repository-policy.json"
        ),
    )
    parser.add_argument(
        "--audit-output",
        default=(
            "artifacts/pmo/SGD-114-v2/"
            "repository-audit.json"
        ),
    )
    parser.add_argument(
        "--manifest-output",
        default=(
            "artifacts/pmo/SGD-114-v2/"
            "repository-manifest.json"
        ),
    )
    parser.add_argument(
        "--event-output",
        default=(
            "artifacts/pmo/SGD-114-v2/"
            "repository-governance-event.json"
        ),
    )
    parser.add_argument(
        "--require-clean-git",
        action="store_true",
    )
    return parser


def main() -> int:
    args = construir_parser().parse_args()

    execution = ejecutar_gobierno_repositorio(
        repository_root=args.root,
        policy_path=args.policy,
        audit_output=args.audit_output,
        manifest_output=args.manifest_output,
        event_output=args.event_output,
        require_clean_git=args.require_clean_git,
    )

    audit = execution["audit"]

    print("SGD-114 v2.0 ejecutado correctamente.")
    print(
        "Auditoría: "
        f"{'APROBADA' if audit.passed else 'NO APROBADA'}"
    )
    print(f"Git limpio: {audit.git['clean']}")
    print(f"Archivos fuente: {audit.metrics['source_files']}")
    print(f"Pruebas: {audit.metrics['test_files']}")
    print(
        "Documentos: "
        f"{audit.metrics['documentation_files']}"
    )
    print(f"Auditoría: {execution['audit_path']}")
    print(f"Manifiesto: {execution['manifest_path']}")

    return 0 if audit.passed else 2


if __name__ == "__main__":
    raise SystemExit(main())