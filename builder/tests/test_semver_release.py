"""Pruebas de consistencia SemVer."""

from pathlib import Path
import re
import tomllib

import sgoda


SEMVER = re.compile(r"^\d+\.\d+\.\d+$")


def test_version_is_semver() -> None:
    assert SEMVER.fullmatch(sgoda.__version__)


def test_pyproject_and_package_versions_match() -> None:
    root = Path(__file__).resolve().parents[1]
    payload = tomllib.loads(
        (root / "pyproject.toml").read_text(encoding="utf-8")
    )
    assert payload["project"]["version"] == sgoda.__version__
    assert sgoda.__version__ == "1.7.0"


def test_changelog_contains_current_version() -> None:
    repository_root = Path(__file__).resolve().parents[2]
    changelog = (
        repository_root / "CHANGELOG.md"
    ).read_text(encoding="utf-8")
    assert "## [1.0.0]" in changelog
