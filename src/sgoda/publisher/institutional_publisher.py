"""SPB-007: publicación institucional automatizada del repositorio."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Sequence


VERSION = "1.0.0"


@dataclass(frozen=True, slots=True)
class ResultadoComandoGit:
    command: list[str]
    returncode: int
    stdout: str
    stderr: str


@dataclass(slots=True)
class ResultadoPublicacion:
    branch: str
    remote: str
    upstream_before: str | None
    upstream_after: str | None
    staged_files: int
    commit_created: bool
    commit_sha: str | None
    tag_created: bool
    pushed: bool
    clean_after_publish: bool
    commands: list[ResultadoComandoGit]


class ErrorPublicacionRepositorio(RuntimeError):
    """Error controlado del publicador institucional."""


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
    return path


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def ejecutar(
    root: Path,
    arguments: Sequence[str],
    *,
    check: bool = True,
) -> ResultadoComandoGit:
    process = subprocess.run(
        ["git", *arguments],
        cwd=root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )

    result = ResultadoComandoGit(
        command=["git", *arguments],
        returncode=process.returncode,
        stdout=process.stdout.strip(),
        stderr=process.stderr.strip(),
    )

    if check and result.returncode != 0:
        raise ErrorPublicacionRepositorio(
            "Falló el comando: "
            + " ".join(result.command)
            + "\n"
            + (result.stderr or result.stdout)
        )

    return result


def validar_repositorio(root: str | Path) -> Path:
    repository_root = Path(root).resolve()

    if not repository_root.is_dir():
        raise NotADirectoryError(
            f"No existe el repositorio: {repository_root}"
        )

    result = ejecutar(
        repository_root,
        ["rev-parse", "--show-toplevel"],
    )

    detected = Path(result.stdout).resolve()

    if detected != repository_root:
        raise ErrorPublicacionRepositorio(
            f"La raíz Git detectada es {detected}, no {repository_root}."
        )

    return repository_root


def rama_actual(root: Path) -> str:
    result = ejecutar(root, ["branch", "--show-current"])
    branch = result.stdout.strip()

    if not branch:
        raise ErrorPublicacionRepositorio(
            "No se puede publicar desde detached HEAD."
        )

    return branch


def upstream_actual(root: Path) -> str | None:
    result = ejecutar(
        root,
        [
            "rev-parse",
            "--abbrev-ref",
            "--symbolic-full-name",
            "@{upstream}",
        ],
        check=False,
    )

    return result.stdout.strip() if result.returncode == 0 else None


def estado_porcelain(root: Path) -> list[str]:
    result = ejecutar(root, ["status", "--porcelain"])
    return [
        line
        for line in result.stdout.splitlines()
        if line.strip()
    ]


def archivos_staged(root: Path) -> list[str]:
    result = ejecutar(
        root,
        ["diff", "--cached", "--name-only"],
    )
    return [
        line
        for line in result.stdout.splitlines()
        if line.strip()
    ]


def preparar_staging(root: Path) -> list[ResultadoComandoGit]:
    """Normaliza el índice sin modificar la configuración global."""

    commands: list[ResultadoComandoGit] = []

    commands.append(
        ejecutar(
            root,
            [
                "-c",
                "core.safecrlf=false",
                "add",
                "--renormalize",
                ".",
            ],
        )
    )

    commands.append(
        ejecutar(
            root,
            [
                "-c",
                "core.safecrlf=false",
                "add",
                "--all",
            ],
        )
    )

    return commands


def crear_commit(
    root: Path,
    message: str,
) -> tuple[bool, str | None, ResultadoComandoGit | None]:
    staged = archivos_staged(root)

    if not staged:
        return False, None, None

    commit = ejecutar(root, ["commit", "-m", message])
    head = ejecutar(root, ["rev-parse", "HEAD"])

    return True, head.stdout.strip(), commit


def asegurar_upstream(
    root: Path,
    *,
    remote: str,
    branch: str,
) -> tuple[str, ResultadoComandoGit | None]:
    upstream = upstream_actual(root)

    if upstream:
        return upstream, None

    command = ejecutar(
        root,
        [
            "push",
            "--set-upstream",
            remote,
            branch,
        ],
    )

    return f"{remote}/{branch}", command


def push_branch(
    root: Path,
    *,
    remote: str,
    branch: str,
    upstream_was_created: bool,
) -> ResultadoComandoGit | None:
    if upstream_was_created:
        return None

    return ejecutar(root, ["push", remote, branch])


def crear_y_publicar_tag(
    root: Path,
    *,
    remote: str,
    tag_name: str,
) -> list[ResultadoComandoGit]:
    if not tag_name:
        return []

    existing = ejecutar(
        root,
        ["tag", "--list", tag_name],
    )

    if existing.stdout.strip():
        raise ErrorPublicacionRepositorio(
            f"El tag ya existe: {tag_name}"
        )

    return [
        ejecutar(
            root,
            [
                "tag",
                "-a",
                tag_name,
                "-m",
                f"Publicación institucional {tag_name}",
            ],
        ),
        ejecutar(root, ["push", remote, tag_name]),
    ]


def generar_evidencia(
    *,
    root: Path,
    result: ResultadoPublicacion,
    output_path: str | Path,
) -> Path:
    payload = {
        "increment": "SPB-007",
        "version": VERSION,
        "generated_at_utc": datetime.now(
            timezone.utc
        ).isoformat(),
        "repository_root": str(root),
        "result": asdict(result),
    }

    return _write_json(Path(output_path), payload)


def publicar(
    *,
    repository_root: str | Path,
    commit_message: str,
    remote: str = "origin",
    tag_name: str = "",
    evidence_output: str | Path = (
        "artifacts/pmo/SPB-007/publication-result.json"
    ),
) -> ResultadoPublicacion:
    root = validar_repositorio(repository_root)
    branch = rama_actual(root)
    upstream_before = upstream_actual(root)
    commands: list[ResultadoComandoGit] = []

    commands.extend(preparar_staging(root))
    staged = archivos_staged(root)

    commit_created, commit_sha, commit_command = crear_commit(
        root,
        commit_message,
    )

    if commit_command is not None:
        commands.append(commit_command)

    upstream_after, upstream_command = asegurar_upstream(
        root,
        remote=remote,
        branch=branch,
    )

    if upstream_command is not None:
        commands.append(upstream_command)

    push_command = push_branch(
        root,
        remote=remote,
        branch=branch,
        upstream_was_created=upstream_command is not None,
    )

    if push_command is not None:
        commands.append(push_command)

    tag_commands = crear_y_publicar_tag(
        root,
        remote=remote,
        tag_name=tag_name,
    )
    commands.extend(tag_commands)

    clean = not estado_porcelain(root)

    result = ResultadoPublicacion(
        branch=branch,
        remote=remote,
        upstream_before=upstream_before,
        upstream_after=upstream_after,
        staged_files=len(staged),
        commit_created=commit_created,
        commit_sha=commit_sha,
        tag_created=bool(tag_commands),
        pushed=True,
        clean_after_publish=clean,
        commands=commands,
    )

    generar_evidencia(
        root=root,
        result=result,
        output_path=evidence_output,
    )

    if not clean:
        raise ErrorPublicacionRepositorio(
            "La publicación terminó, pero el worktree no quedó limpio."
        )

    return result


def auditar_sin_publicar(
    *,
    repository_root: str | Path,
    output_path: str | Path,
) -> Path:
    root = validar_repositorio(repository_root)
    branch = rama_actual(root)
    upstream = upstream_actual(root)
    status = estado_porcelain(root)

    payload = {
        "increment": "SPB-007",
        "version": VERSION,
        "generated_at_utc": datetime.now(
            timezone.utc
        ).isoformat(),
        "repository_root": str(root),
        "branch": branch,
        "upstream": upstream,
        "clean": not status,
        "changes": status,
        "gitattributes_present": (
            root / ".gitattributes"
        ).is_file(),
        "gitignore_present": (
            root / ".gitignore"
        ).is_file(),
    }

    return _write_json(Path(output_path), payload)


def construir_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Publica institucionalmente el repositorio SGODA-PUINAVE."
        )
    )
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--commit-message",
        default=(
            "feat(repository): institutional publication "
            "through SPB-007"
        ),
    )
    parser.add_argument("--remote", default="origin")
    parser.add_argument("--tag", default="")
    parser.add_argument(
        "--evidence-output",
        default=(
            "artifacts/pmo/SPB-007/"
            "publication-result.json"
        ),
    )
    parser.add_argument(
        "--audit-output",
        default=(
            "artifacts/pmo/SPB-007/"
            "prepublication-audit.json"
        ),
    )
    parser.add_argument(
        "--publish",
        action="store_true",
    )
    return parser


def main() -> int:
    args = construir_parser().parse_args()

    if not args.publish:
        path = auditar_sin_publicar(
            repository_root=args.root,
            output_path=args.audit_output,
        )
        print("SPB-007 auditoría previa completada.")
        print(f"Evidencia: {path}")
        return 0

    result = publicar(
        repository_root=args.root,
        commit_message=args.commit_message,
        remote=args.remote,
        tag_name=args.tag,
        evidence_output=args.evidence_output,
    )

    print("SPB-007 publicación completada.")
    print(f"Rama: {result.branch}")
    print(f"Upstream: {result.upstream_after}")
    print(f"Commit: {result.commit_sha}")
    print(f"Git limpio: {result.clean_after_publish}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())