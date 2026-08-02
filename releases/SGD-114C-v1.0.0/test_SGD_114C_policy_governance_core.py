import json
from pathlib import Path

from sgoda.governance.policy_context import PolicyContext
from sgoda.governance.policy_engine import evaluate_policy
from sgoda.governance.policy_models import (
    PolicyRule,
    RuleResult,
    RuleStatus,
    Severity,
)
from sgoda.governance.policy_registry import (
    PolicyRegistry,
    build_default_registry,
)
from sgoda.governance.policy_report import evaluation_to_dict


def _minimum_repository(root: Path, increment: str) -> None:
    (root / ".git").mkdir()
    (root / "tests").mkdir()
    (root / "tests/test_example.py").write_text(
        "def test_ok(): assert True\n",
        encoding="utf-8",
    )
    (root / "pytest.ini").write_text(
        "[pytest]\n",
        encoding="utf-8",
    )

    descriptor = (
        root
        / "config"
        / "roadmap"
        / f"{increment}-component.json"
    )
    descriptor.parent.mkdir(parents=True)
    descriptor.write_text("{}", encoding="utf-8")

    (root / "releases" / f"{increment}-v1.0.0").mkdir(
        parents=True
    )

    legacy = root / "config/governance/sgd-114-policy.json"
    legacy.parent.mkdir(parents=True, exist_ok=True)
    legacy.write_text("{}", encoding="utf-8")

    evidence = root / "artifacts/pmo" / increment
    evidence.mkdir(parents=True)
    (evidence / "evidence.json").write_text(
        "{}",
        encoding="utf-8",
    )

    validation = root / "artifacts/roadmap/SGD-116/validation.json"
    validation.parent.mkdir(parents=True)
    validation.write_text(
        json.dumps(
            {
                "passed": True,
                "missing_dependencies": [],
                "broken_paths": [],
                "dependency_cycles": [],
                "duplicate_codes": [],
                "missing_master_documents": [],
            }
        ),
        encoding="utf-8",
    )

    for name in (
        "00_INDICE_MAESTRO.md",
        "00_ARQUITECTURA_MAESTRA.md",
        "00_REGISTRO_MAESTRO_COMPONENTES.md",
        "00_ROADMAP_MAESTRO.md",
        "00_DEPENDENCIAS_MAESTRAS.md",
        "00_TIMELINE_MAESTRO.md",
        "00_METRICAS_ECOSISTEMA.md",
    ):
        path = root / "docs" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("# Documento\n", encoding="utf-8")


def test_SGD_114C_approves_complete_context(tmp_path: Path) -> None:
    _minimum_repository(tmp_path, "SGD-116B")
    context = PolicyContext(
        tmp_path,
        "SGD-116B",
        {"policy_code": "SGD-114C", "version": "1.0.0"},
    )

    result = evaluate_policy(
        context,
        build_default_registry(),
    )

    assert result.approved is True
    assert result.exit_code == 0
    assert result.blocking_rules == ()


def test_SGD_114C_blocks_missing_release(tmp_path: Path) -> None:
    _minimum_repository(tmp_path, "SGD-116B")
    release = tmp_path / "releases/SGD-116B-v1.0.0"
    release.rmdir()

    result = evaluate_policy(
        PolicyContext(tmp_path, "SGD-116B", {}),
        build_default_registry(),
    )

    assert result.approved is False
    assert "SGD114C-R003" in {
        item.rule.code for item in result.blocking_rules
    }


def test_SGD_114C_registry_rejects_duplicates() -> None:
    registry = PolicyRegistry()
    rule = PolicyRule(
        "R1",
        "Test",
        "Test",
        Severity.INFO,
        "test",
    )

    def executor(context, registered_rule):
        return RuleResult(
            registered_rule,
            RuleStatus.PASSED,
            "ok",
        )

    registry.register(rule, executor)

    try:
        registry.register(rule, executor)
    except ValueError:
        pass
    else:
        raise AssertionError("El registro aceptó una regla duplicada")


def test_SGD_114C_report_is_normalized(tmp_path: Path) -> None:
    _minimum_repository(tmp_path, "SGD-116B")

    result = evaluate_policy(
        PolicyContext(tmp_path, "SGD-116B", {}),
        build_default_registry(),
    )

    payload = evaluation_to_dict(result)

    assert payload["approved"] is True
    assert payload["exit_code"] == 0
    assert len(payload["results"]) == 8


def test_SGD_114C_roadmap_failure_is_blocking(tmp_path: Path) -> None:
    _minimum_repository(tmp_path, "SGD-116B")
    validation = tmp_path / "artifacts/roadmap/SGD-116/validation.json"
    validation.write_text(
        json.dumps(
            {
                "passed": False,
                "missing_dependencies": [{"target": "SGD-999"}],
                "broken_paths": [],
                "dependency_cycles": [],
                "duplicate_codes": [],
                "missing_master_documents": [],
            }
        ),
        encoding="utf-8",
    )

    result = evaluate_policy(
        PolicyContext(tmp_path, "SGD-116B", {}),
        build_default_registry(),
    )

    assert result.approved is False
    assert "SGD114C-R004" in {
        item.rule.code for item in result.blocking_rules
    }