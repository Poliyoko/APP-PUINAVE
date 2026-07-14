"""Pruebas estáticas de la configuración de integración continua."""

from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = REPOSITORY_ROOT / ".github/workflows/builder-ci.yml"
SMOKE_SCRIPT = REPOSITORY_ROOT / "builder/scripts/ci_smoke_test.py"


def workflow_text() -> str:
    assert WORKFLOW.is_file()
    return WORKFLOW.read_text(encoding="utf-8")


def test_workflow_has_expected_triggers() -> None:
    content = workflow_text()

    assert "push:" in content
    assert "pull_request:" in content
    assert "workflow_dispatch:" in content
    assert '"feature/**"' in content


def test_workflow_runs_quality_matrix() -> None:
    content = workflow_text()

    assert "ubuntu-latest" in content
    assert "windows-latest" in content
    assert '"3.11"' in content
    assert '"3.14"' in content
    assert "python -m compileall -f ./src" in content
    assert "python -m pytest ./tests -v" in content


def test_workflow_builds_and_checks_distributions() -> None:
    content = workflow_text()

    assert "python -m build" in content
    assert "python -m twine check ./dist/*" in content
    assert "actions/upload-artifact@v4" in content
    assert "builder/dist/*.whl" in content
    assert "builder/dist/*.tar.gz" in content


def test_workflow_runs_installed_package_smoke_test() -> None:
    content = workflow_text()

    assert "ci_smoke_test.py" in content
    assert "--wheel-glob" in content
    assert SMOKE_SCRIPT.is_file()


def test_smoke_script_covers_core_commands() -> None:
    content = SMOKE_SCRIPT.read_text(encoding="utf-8")

    for command in (
        '"version"',
        '"doctor"',
        '"init"',
        '"validate"',
        '"audit"',
        '"quality"',
    ):
        assert command in content
