"""Pruebas de metadatos de distribución."""

from pathlib import Path
import tomllib


def test_pyproject_distribution_metadata() -> None:
    root = Path(__file__).resolve().parents[1]
    payload = tomllib.loads(
        (root / "pyproject.toml").read_text(encoding="utf-8")
    )
    project = payload["project"]

    assert project["name"] == "sgoda-builder"
    assert project["version"] == "1.2.0"
    assert project["requires-python"] == ">=3.11"
    assert project["scripts"]["sgoda"] == "sgoda.cli.main:main"


def test_manifest_exists() -> None:
    root = Path(__file__).resolve().parents[1]
    assert (root / "MANIFEST.in").is_file()
