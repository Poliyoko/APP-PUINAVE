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