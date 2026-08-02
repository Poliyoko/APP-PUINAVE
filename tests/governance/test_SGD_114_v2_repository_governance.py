"""Pruebas SGD-114 v2.0 del gobierno del repositorio."""

import json
import shutil
import subprocess
from pathlib import Path

from sgoda.governance.repository_governance import (
    auditar_repositorio,
    ejecutar_gobierno_repositorio,
    generar_manifiesto,
)


def _policy(tmp_path: Path) -> Path:
    policy = {
        "policy_code": "SGD-114",
        "policy_version": "2.0.0",
        "required_directories": [
            "src",
            "tests",
            "docs",
            "config",
            "scripts",
            "artifacts",
            "dashboard",
            "releases",
        ],
        "required_repository_files": ["pytest.ini"],
        "ignored_directories": [
            ".git",
            ".venv",
            "__pycache__",
        ],
        "manifest_extensions": [
            ".py",
            ".md",
            ".json",
            ".ini",
        ],
        "maximum_manifest_file_size_bytes": 1048576,
    }

    path = tmp_path / "policy.json"
    path.write_text(
        json.dumps(policy),
        encoding="utf-8",
    )
    return path


def _repository(tmp_path: Path) -> Path:
    for directory in (
        "src",
        "tests",
        "docs",
        "config",
        "scripts",
        "artifacts",
        "dashboard",
        "releases",
    ):
        (tmp_path / directory).mkdir(
            parents=True,
            exist_ok=True,
        )

    files = {
        "src/module.py": "VALUE = 1\n",
        "tests/test_module.py": (
            "def test_ok(): assert True\n"
        ),
        "docs/readme.md": "# Documento\n",
        "config/config.json": "{}\n",
        "scripts/run.py": "print('ok')\n",
        "artifacts/evidence.json": "{}\n",
        "dashboard/status.json": "{}\n",
        "releases/release.json": "{}\n",
        "pytest.ini": "[pytest]\ntestpaths = tests\n",
    }

    for relative, content in files.items():
        path = tmp_path / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    subprocess.run(
        ["git", "init"],
        cwd=tmp_path,
        capture_output=True,
        check=True,
    )

    return tmp_path


def test_SGD_114_v2_audita_estructura_completa(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    policy = _policy(tmp_path)

    result = auditar_repositorio(
        repository_root=root,
        policy_path=policy,
    )

    assert result.passed is True
    assert result.missing_directories == []
    assert result.missing_files == []
    assert result.metrics["source_files"] == 1
    assert result.metrics["test_files"] == 1


def test_SGD_114_v2_detecta_directorio_faltante(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    policy = _policy(tmp_path)

    shutil.rmtree(root / "dashboard")

    result = auditar_repositorio(
        repository_root=root,
        policy_path=policy,
    )

    assert result.passed is False
    assert "dashboard" in result.missing_directories
    assert (
        result.checks[
            "required_directories_present"
        ]
        is False
    )


def test_SGD_114_v2_genera_hashes_sha256(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    policy = _policy(tmp_path)

    manifest_path = generar_manifiesto(
        repository_root=root,
        policy_path=policy,
        output_path=tmp_path / "manifest.json",
    )

    manifest = json.loads(
        manifest_path.read_text(encoding="utf-8")
    )

    assert manifest["total_files"] >= 9

    for item in manifest["files"]:
        assert len(item["sha256"]) == 64
        int(item["sha256"], 16)
        assert item["size_bytes"] > 0


def test_SGD_114_v2_excluye_directorios_ignorados(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    policy = _policy(tmp_path)

    ignored = root / ".venv" / "ignored.py"
    ignored.parent.mkdir(parents=True)
    ignored.write_text("SECRET = True\n", encoding="utf-8")

    manifest_path = generar_manifiesto(
        repository_root=root,
        policy_path=policy,
        output_path=tmp_path / "manifest.json",
    )

    manifest = json.loads(
        manifest_path.read_text(encoding="utf-8")
    )

    paths = {
        item["path"]
        for item in manifest["files"]
    }

    assert ".venv/ignored.py" not in paths


def test_SGD_114_v2_genera_auditoria_manifiesto_evento(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    policy = _policy(tmp_path)

    execution = ejecutar_gobierno_repositorio(
        repository_root=root,
        policy_path=policy,
        audit_output=tmp_path / "audit.json",
        manifest_output=tmp_path / "manifest.json",
        event_output=tmp_path / "event.json",
    )

    assert execution["audit"].passed is True
    assert execution["audit_path"].is_file()
    assert execution["manifest_path"].is_file()
    assert execution["event_path"].is_file()

    event = json.loads(
        execution["event_path"].read_text(
            encoding="utf-8"
        )
    )

    assert (
        event["event_type"]
        == "InstitutionalRepositoryAudited"
    )
    assert event["policy_version"] == "2.0.0"


def test_SGD_114_v2_git_limpio_opcional(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    policy = _policy(tmp_path)

    relaxed = auditar_repositorio(
        repository_root=root,
        policy_path=policy,
        require_clean_git=False,
    )
    strict = auditar_repositorio(
        repository_root=root,
        policy_path=policy,
        require_clean_git=True,
    )

    assert relaxed.passed is True
    assert relaxed.git["clean"] is False
    assert strict.passed is False
    assert (
        strict.checks["git_clean_when_required"]
        is False
    )