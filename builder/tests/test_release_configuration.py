"""Pruebas estáticas del workflow de publicación."""

from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = REPOSITORY_ROOT / ".github/workflows/release.yml"
CHANGELOG = REPOSITORY_ROOT / "CHANGELOG.md"
RELEASE_NOTES = (
    REPOSITORY_ROOT / "builder/docs/releases/1.0.0.md"
)
VALIDATOR = (
    REPOSITORY_ROOT / "builder/scripts/validate_release.py"
)


def workflow_text() -> str:
    assert WORKFLOW.is_file()
    return WORKFLOW.read_text(encoding="utf-8")


def test_release_workflow_uses_version_tags() -> None:
    content = workflow_text()
    assert 'tags:' in content
    assert '"v*"' in content
    assert "workflow_dispatch:" in content


def test_release_workflow_builds_and_validates() -> None:
    content = workflow_text()
    assert "python -m build" in content
    assert "python -m twine check ./dist/*" in content
    assert "validate_release.py" in content


def test_release_workflow_creates_github_release() -> None:
    content = workflow_text()
    assert "softprops/action-gh-release@v2" in content
    assert "builder/dist/*.whl" in content
    assert "builder/dist/*.tar.gz" in content


def test_release_documentation_exists() -> None:
    assert CHANGELOG.is_file()
    assert RELEASE_NOTES.is_file()
    assert VALIDATOR.is_file()
