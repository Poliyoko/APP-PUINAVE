<#
.SYNOPSIS
    Implementa SPB-007 — Publicación Institucional Automatizada del
    Repositorio SGODA-PUINAVE.

.DESCRIPTION
    Instala y valida, desde un solo archivo:
      - política de publicación institucional;
      - normalización controlada CRLF/LF;
      - .gitattributes y .gitignore institucionales;
      - auditor de prepublicación;
      - staging seguro;
      - commit, tag, upstream y push opcionales;
      - manifiesto SHA-256;
      - evento PMO;
      - dashboard;
      - pruebas automatizadas en repositorios temporales;
      - suite completa;
      - quality gate SGD-114.

    Por seguridad, el instalador NO publica automáticamente al remoto.
    Para ejecutar la publicación real después de instalar y revisar:

      .\scripts\Invoke-SPB007-InstitutionalPublish.ps1 -Publish

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER SkipFullSuite
    Omite la suite completa. Las pruebas específicas siempre se ejecutan.

.PARAMETER PublishNow
    Después de instalar, probar y auditar, ejecuta staging, commit, tag
    y push real. Debe usarse únicamente después de revisar git status.

.PARAMETER CommitMessage
    Mensaje del commit institucional.

.PARAMETER TagName
    Tag institucional. Si está vacío, no crea tag.

.EXAMPLE
    .\Install-SPB007-Institutional-Repository-Publisher.ps1

.EXAMPLE
    .\Install-SPB007-Institutional-Repository-Publisher.ps1 `
        -PublishNow `
        -CommitMessage "feat(repository): institutional publication" `
        -TagName "sgoda-baseline-2026.08"
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite,
    [switch]$PublishNow,
    [string]$CommitMessage = "feat(repository): institutional publication through SPB-007",
    [string]$TagName = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Path {
    param([string]$Path, [string]$Description)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontró $Description en: $Path"
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)

    $Parent = Split-Path -Parent $Path

    if ($Parent -and -not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo crear: $Path"
    }

    $Info = Get-Item -LiteralPath $Path

    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-JsonUtf8 {
    param([string]$Path, [object]$Data)

    $Parent = Split-Path -Parent $Path

    if ($Parent -and -not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Data | ConvertTo-Json -Depth 50

    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$SrcRoot = Join-Path $ProjectRoot "src"
$env:PYTHONPATH = $SrcRoot

$PublisherDir = Join-Path $SrcRoot "sgoda\publisher"
$TestsDir = Join-Path $ProjectRoot "tests\publisher"
$ConfigDir = Join-Path $ProjectRoot "config\repository"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPB-007"
$GovDocsDir = Join-Path $ProjectRoot "docs\01_Gobierno"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\pmo\SPB-007"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPB-007-v1.0.0"

$ModulePath = Join-Path $PublisherDir "institutional_publisher.py"
$InitPath = Join-Path $PublisherDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_SPB_007_institutional_publisher.py"
$PolicyPath = Join-Path $ConfigDir "SPB-007-publication-policy.json"
$ComponentPath = Join-Path $ConfigDir "SPB-007-component.json"
$DocPath = Join-Path $DocsDir "SPB-007-Publicacion-Institucional.md"
$GovDocPath = Join-Path $GovDocsDir "SPB-007-Politica-Publicacion-Repositorio.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPB007-InstitutionalPublish.ps1"
$TracePath = Join-Path $ArtifactsDir "traceability-SPB-007.json"
$EvidencePath = Join-Path $ArtifactsDir "implementation-evidence.json"
$GatePath = Join-Path $ArtifactsDir "SPB-007-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "SPB-007-dashboard.json"
$AttributesPath = Join-Path $ProjectRoot ".gitattributes"
$GitIgnorePath = Join-Path $ProjectRoot ".gitignore"

Write-Step "Validando línea base institucional"

foreach ($Required in @(
    (Join-Path $ProjectRoot ".git"),
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot "src\sgoda\governance\repository_governance.py"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-v2-repository-policy.json")
)) {
    Assert-Path -Path $Required -Description $Required
}

& python --version
if ($LASTEXITCODE -ne 0) {
    throw "Python no está disponible."
}

& git --version
if ($LASTEXITCODE -ne 0) {
    throw "Git no está disponible."
}

$AttributesContent = @'
# SPB-007 — Política institucional de finales de línea
* text=auto

*.py      text eol=lf
*.ps1     text eol=crlf
*.psm1    text eol=crlf
*.psd1    text eol=crlf
*.md      text eol=lf
*.json    text eol=lf
*.jsonl   text eol=lf
*.yaml    text eol=lf
*.yml     text eol=lf
*.toml    text eol=lf
*.ini     text eol=lf
*.sql     text eol=lf
*.sh      text eol=lf

*.png     binary
*.jpg     binary
*.jpeg    binary
*.gif     binary
*.webp    binary
*.pdf     binary
*.xlsx    binary
*.zip     binary
*.sqlite3 binary
*.db      binary
*.wav     binary
*.mp3     binary
*.mp4     binary
'@

$GitIgnoreContent = @'
# Python
__pycache__/
*.py[cod]
.pytest_cache/
.coverage
htmlcov/

# Entornos virtuales
.venv/
venv/
env/

# IDE y sistema operativo
.vscode/
.idea/
.DS_Store
Thumbs.db

# Archivos temporales
*.tmp
*.temp
*.bak
*.before-compatibility-fix
~$*

# SQLite temporales
*.sqlite3-wal
*.sqlite3-shm

# Logs locales no gobernados
*.log
'@

$PolicyContent = @'
{
  "increment_code": "SPB-007",
  "version": "1.0.0",
  "policy_name": "Publicación Institucional Automatizada del Repositorio",
  "default_remote": "origin",
  "require_tests": true,
  "require_repository_audit": true,
  "require_manifest": true,
  "require_clean_after_push": true,
  "create_upstream_when_missing": true,
  "line_endings": {
    "default": "auto",
    "python": "lf",
    "powershell": "crlf",
    "documentation": "lf",
    "json": "lf"
  },
  "excluded_from_staging": [
    ".venv",
    "venv",
    "__pycache__",
    ".pytest_cache",
    "node_modules"
  ],
  "publish_steps": [
    "validate_repository",
    "ensure_attributes",
    "renormalize_index",
    "stage_changes",
    "validate_staged_changes",
    "commit",
    "configure_upstream",
    "push_branch",
    "create_tag_optional",
    "push_tag_optional",
    "strict_repository_audit",
    "verify_clean_worktree",
    "generate_evidence"
  ],
  "governed_by": "SGD-114-v2.0.1"
}
'@

$ComponentContent = @'
{
  "increment_code": "SPB-007",
  "component_type": "institutional_repository_publisher",
  "version": "1.0.0",
  "status": "technically_completed",
  "entrypoint": "sgoda.publisher.institutional_publisher",
  "source": [
    "src/sgoda/publisher/institutional_publisher.py"
  ],
  "tests": [
    "tests/publisher/test_SPB_007_institutional_publisher.py"
  ],
  "governed_by": "SGD-114-v2.0.1"
}
'@

$ModuleContent = @'
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
'@

$InitContent = @'
"""Publicación institucional automatizada SGODA-PUINAVE."""

from .institutional_publisher import (
    ErrorPublicacionRepositorio,
    ResultadoPublicacion,
    auditar_sin_publicar,
    preparar_staging,
    publicar,
    validar_repositorio,
)

__all__ = [
    "ErrorPublicacionRepositorio",
    "ResultadoPublicacion",
    "auditar_sin_publicar",
    "preparar_staging",
    "publicar",
    "validar_repositorio",
]
'@

$TestContent = @'
"""Pruebas SPB-007 del publicador institucional."""

import json
import subprocess
from pathlib import Path

from sgoda.publisher.institutional_publisher import (
    archivos_staged,
    auditar_sin_publicar,
    preparar_staging,
    rama_actual,
    upstream_actual,
    validar_repositorio,
)


def _git(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=root,
        capture_output=True,
        text=True,
        check=True,
    )


def _repo(tmp_path: Path) -> Path:
    _git(tmp_path, "init")
    _git(tmp_path, "config", "user.name", "SPB-007 Test")
    _git(tmp_path, "config", "user.email", "spb007@example.invalid")

    (tmp_path / ".gitattributes").write_text(
        "* text=auto\n*.py text eol=lf\n",
        encoding="utf-8",
    )
    (tmp_path / ".gitignore").write_text(
        ".venv/\n__pycache__/\n",
        encoding="utf-8",
    )
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "module.py").write_text(
        "VALUE = 1\n",
        encoding="utf-8",
    )

    _git(tmp_path, "add", ".")
    _git(tmp_path, "commit", "-m", "initial")
    return tmp_path


def test_SPB_007_valida_raiz_git(tmp_path: Path) -> None:
    root = _repo(tmp_path)
    assert validar_repositorio(root) == root.resolve()


def test_SPB_007_detecta_rama_actual(tmp_path: Path) -> None:
    root = _repo(tmp_path)
    branch = rama_actual(root)
    assert branch in {"master", "main"}


def test_SPB_007_upstream_ausente_es_valido(
    tmp_path: Path,
) -> None:
    root = _repo(tmp_path)
    assert upstream_actual(root) is None


def test_SPB_007_staging_supera_safecrlf(
    tmp_path: Path,
) -> None:
    root = _repo(tmp_path)

    _git(root, "config", "core.safecrlf", "true")

    requirements = root / "requirements.txt"
    requirements.write_bytes(b"pytest==8.4.2\r\n")

    preparar_staging(root)
    staged = archivos_staged(root)

    assert "requirements.txt" in staged


def test_SPB_007_auditoria_previa_genera_evidencia(
    tmp_path: Path,
) -> None:
    root = _repo(tmp_path)
    output = tmp_path / "audit.json"

    result = auditar_sin_publicar(
        repository_root=root,
        output_path=output,
    )

    assert result.is_file()
    payload = json.loads(
        result.read_text(encoding="utf-8")
    )
    assert payload["increment"] == "SPB-007"
    assert payload["gitattributes_present"] is True
    assert payload["gitignore_present"] is True


def test_SPB_007_no_publica_durante_pruebas(
    tmp_path: Path,
) -> None:
    root = _repo(tmp_path)
    before = _git(root, "rev-parse", "HEAD").stdout.strip()

    auditar_sin_publicar(
        repository_root=root,
        output_path=tmp_path / "audit.json",
    )

    after = _git(root, "rev-parse", "HEAD").stdout.strip()

    assert before == after
    assert upstream_actual(root) is None
'@

$DocContent = @'
# SPB-007 — Publicación Institucional Automatizada del Repositorio

## Objetivo

Resolver de forma reproducible los problemas de finales de línea,
staging, commit, upstream, push, tag y verificación final del repositorio.

## Seguridad operativa

Las pruebas nunca hacen push ni requieren acceso remoto. Utilizan
repositorios temporales locales.

El instalador no publica automáticamente salvo que se utilice
`-PublishNow`. La operación recomendada es:

1. Instalar y ejecutar las pruebas.
2. Revisar `git status -sb`.
3. Ejecutar el publicador con `-Publish`.
4. Ejecutar la auditoría estricta SGD-114 v2.

## Solución al error CRLF/LF

SPB-007 crea `.gitattributes` y usa comandos Git con configuración
temporal y local al comando:

```text
git -c core.safecrlf=false add --renormalize .
git -c core.safecrlf=false add --all
```

No modifica la configuración global de Git.

## Upstream

Cuando la rama no tiene upstream, el publicador ejecuta:

```text
git push --set-upstream origin <rama>
```

Cuando ya existe upstream, ejecuta el push normal.

## Evidencias

- auditoría previa;
- resultado de publicación;
- manifiesto SGD-114 v2;
- evento PMO;
- dashboard;
- quality gate.
'@

$GovDocContent = @'
# SPB-007 — Política Institucional de Publicación del Repositorio

Toda publicación institucional debe:

- respetar `.gitattributes`;
- excluir archivos temporales mediante `.gitignore`;
- ejecutar pruebas;
- generar staging verificable;
- usar un mensaje de commit institucional;
- configurar upstream si no existe;
- publicar únicamente en el remoto autorizado;
- generar tag cuando corresponda;
- comprobar worktree limpio;
- ejecutar auditoría estricta;
- conservar evidencias en el repositorio.

La publicación remota no se ejecuta dentro de pruebas automatizadas.
'@

$InvokeContent = @'
[CmdletBinding()]
param(
    [switch]$Publish,
    [string]$CommitMessage = "feat(repository): institutional publication through SPB-007",
    [string]$TagName = "",
    [string]$Remote = "origin"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Arguments = @(
    "-m",
    "sgoda.publisher.institutional_publisher",
    "--root",
    $Root,
    "--commit-message",
    $CommitMessage,
    "--remote",
    $Remote,
    "--tag",
    $TagName,
    "--audit-output",
    "artifacts/pmo/SPB-007/prepublication-audit.json",
    "--evidence-output",
    "artifacts/pmo/SPB-007/publication-result.json"
)

if ($Publish) {
    $Arguments += "--publish"
}

& python @Arguments

if ($LASTEXITCODE -ne 0) {
    throw "SPB-007 terminó con errores."
}

if ($Publish) {
    & "$Root\scripts\Invoke-SGD114-v2-RepositoryAudit.ps1" -RequireCleanGit

    if ($LASTEXITCODE -ne 0) {
        throw "La auditoría estricta posterior a la publicación falló."
    }
}
'@

Write-Step "Instalando política de finales de línea"

Write-Utf8NoBom -Path $AttributesPath -Content $AttributesContent
Write-Utf8NoBom -Path $GitIgnorePath -Content $GitIgnoreContent

Write-Step "Instalando SPB-007"

Write-Utf8NoBom -Path $ModulePath -Content $ModuleContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent
Write-Utf8NoBom -Path $PolicyPath -Content $PolicyContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentContent
Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $GovDocPath -Content $GovDocContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando evidencia y trazabilidad"

$Timestamp = [DateTime]::UtcNow.ToString("o")

$Evidence = [ordered]@{
    increment_code = "SPB-007"
    version = "1.0.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    components = @(
        ".gitattributes",
        ".gitignore",
        "src/sgoda/publisher/institutional_publisher.py",
        "src/sgoda/publisher/__init__.py",
        "tests/publisher/test_SPB_007_institutional_publisher.py",
        "config/repository/SPB-007-publication-policy.json",
        "config/repository/SPB-007-component.json",
        "docs/05_Fase_Tecnologica/SPB-007/SPB-007-Publicacion-Institucional.md",
        "docs/01_Gobierno/SPB-007-Politica-Publicacion-Repositorio.md",
        "scripts/Invoke-SPB007-InstitutionalPublish.ps1"
    )
}
Write-JsonUtf8 -Path $EvidencePath -Data $Evidence

$Trace = [ordered]@{
    increment_code = "SPB-007"
    generated_at_utc = $Timestamp
    source = @(
        "src/sgoda/publisher/institutional_publisher.py",
        "config/repository/SPB-007-publication-policy.json",
        "config/repository/SPB-007-component.json"
    )
    tests = @(
        "tests/publisher/test_SPB_007_institutional_publisher.py"
    )
    documentation = @(
        "docs/05_Fase_Tecnologica/SPB-007/SPB-007-Publicacion-Institucional.md",
        "docs/01_Gobierno/SPB-007-Politica-Publicacion-Repositorio.md"
    )
    evidence = @(
        "artifacts/pmo/SPB-007/implementation-evidence.json"
    )
}
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Validando importación"

& python -c "from sgoda.publisher import validar_repositorio, preparar_staging; print(validar_repositorio.__name__, preparar_staging.__name__)"

if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de SPB-007."
}

Write-Step "Ejecutando pruebas específicas SPB-007"

& python -m pytest `
    "tests/publisher/test_SPB_007_institutional_publisher.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SPB-007 fallaron."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest

    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

Write-Step "Ejecutando auditoría previa sin publicar"

& python -m sgoda.publisher.institutional_publisher `
    --root "$ProjectRoot" `
    --audit-output "artifacts/pmo/SPB-007/prepublication-audit.json"

if ($LASTEXITCODE -ne 0) {
    throw "La auditoría previa SPB-007 falló."
}

Write-Step "Publicando release técnico SPB-007"

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

foreach ($Artifact in @(
    $PolicyPath,
    $ComponentPath,
    $DocPath,
    $GovDocPath,
    $EvidencePath,
    $TracePath,
    (Join-Path $ArtifactsDir "prepublication-audit.json")
)) {
    Copy-Item `
        -LiteralPath $Artifact `
        -Destination (Join-Path $ReleaseDir (Split-Path $Artifact -Leaf)) `
        -Force
}

$Trace.evidence = @(
    "artifacts/pmo/SPB-007/implementation-evidence.json",
    "artifacts/pmo/SPB-007/prepublication-audit.json",
    "releases/SPB-007-v1.0.0/"
)
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPB-007" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    $Failure = Get-Content -LiteralPath $GatePath -Raw |
        ConvertFrom-Json
    $Missing = $Failure.missing_categories -join ", "
    throw "Quality gate SPB-007 no aprobado. Faltan: $Missing"
}

$Gate = Get-Content -LiteralPath $GatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "SPB-007 no tiene passed=true."
}

$PreAudit = Get-Content `
    -LiteralPath (Join-Path $ArtifactsDir "prepublication-audit.json") `
    -Raw |
    ConvertFrom-Json

$Dashboard = [ordered]@{
    increment_code = "SPB-007"
    version = "1.0.0"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    branch = $PreAudit.branch
    upstream = $PreAudit.upstream
    git_clean_before_publication = $PreAudit.clean
    pending_changes = @($PreAudit.changes).Count
    gitattributes = $PreAudit.gitattributes_present
    gitignore = $PreAudit.gitignore_present
    tests = "approved"
    quality_gate = "approved"
    release = "SPB-007-v1.0.0"
    remote_publication = if ($PublishNow) {
        "requested"
    }
    else {
        "pending_explicit_execution"
    }
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

if ($PublishNow) {
    Write-Step "Ejecutando publicación real solicitada"

    $Arguments = @(
        "-m",
        "sgoda.publisher.institutional_publisher",
        "--root",
        $ProjectRoot,
        "--commit-message",
        $CommitMessage,
        "--remote",
        "origin",
        "--tag",
        $TagName,
        "--publish",
        "--evidence-output",
        "artifacts/pmo/SPB-007/publication-result.json"
    )

    & python @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "La publicación real SPB-007 terminó con errores."
    }

    Write-Step "Ejecutando auditoría estricta posterior"

    & "$ProjectRoot\scripts\Invoke-SGD114-v2-RepositoryAudit.ps1" `
        -RequireCleanGit

    if ($LASTEXITCODE -ne 0) {
        throw "La auditoría estricta posterior falló."
    }
}

Write-Step "Resultado final"

Write-Host "SPB-007 implementado y validado." -ForegroundColor Green
Write-Host "Pruebas específicas esperadas: 6 aprobadas." -ForegroundColor Cyan
Write-Host "Suite total esperada desde 97: 103 pruebas." -ForegroundColor Cyan
Write-Host "Política CRLF/LF: INSTALADA." -ForegroundColor Green
Write-Host "Auditoría previa: APROBADA." -ForegroundColor Green
Write-Host "Quality gate SGD-114: APROBADO." -ForegroundColor Green
Write-Host "Rama: $($PreAudit.branch)" -ForegroundColor Cyan
Write-Host "Upstream actual: $($PreAudit.upstream)" -ForegroundColor Cyan
Write-Host "Cambios pendientes: $(@($PreAudit.changes).Count)" -ForegroundColor Yellow

if ($PublishNow) {
    Write-Host "Publicación remota: EJECUTADA." -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Publicación remota: PENDIENTE DE EJECUCIÓN EXPLÍCITA." -ForegroundColor Yellow
    Write-Host "Revise git status -sb y luego ejecute:" -ForegroundColor Yellow
    Write-Host ".\scripts\Invoke-SPB007-InstitutionalPublish.ps1 -Publish" -ForegroundColor Cyan
}
