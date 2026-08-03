from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def _component(root: Path, code: str = "SPT-016") -> Path:
    target = root / "config" / "learning"
    target.mkdir(parents=True, exist_ok=True)
    path = target / f"{code}-component.json"
    path.write_text(
        json.dumps(
            {
                "increment_code": code,
                "native_ecosystem": True,
                "mandatory_proprietary_dependencies": [],
            }
        ),
        encoding="utf-8",
    )
    return path


def test_source_policy_terms_do_not_self_trigger(
    tmp_path: Path,
) -> None:
    _component(tmp_path)
    source = tmp_path / "src" / "sgoda" / "governance"
    source.mkdir(parents=True)
    (source / "native_ecosystem_validator.py").write_text(
        'FORBIDDEN = "integrado por contrato"',
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.forbidden_term_count == 0


def test_policy_document_does_not_self_trigger(
    tmp_path: Path,
) -> None:
    _component(tmp_path)
    docs = tmp_path / "docs" / "01_Gobierno"
    docs.mkdir(parents=True)
    (docs / "SGD-114E-Policy.md").write_text(
        "integrado por contrato",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True


def test_active_document_is_still_validated(
    tmp_path: Path,
) -> None:
    _component(tmp_path)
    docs = tmp_path / "docs" / "08_Fase"
    docs.mkdir(parents=True)
    (docs / "SPT-016.md").write_text(
        "integrado por contrato",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert result.forbidden_term_count == 1


def test_artifacts_are_not_active_policy_scope(
    tmp_path: Path,
) -> None:
    _component(tmp_path)
    artifacts = tmp_path / "artifacts" / "legacy"
    artifacts.mkdir(parents=True)
    (artifacts / "old.md").write_text(
        "integrado por contrato",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True


def test_valid_realistic_repository_is_approved(
    tmp_path: Path,
) -> None:
    _component(tmp_path)

    docs = tmp_path / "docs" / "08_Fase"
    docs.mkdir(parents=True)
    (docs / "SPT-016.md").write_text(
        "Componente nativo SGODA-PUINAVE.",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.exit_code == 0
    assert result.scan_scope["source_code_excluded"] is True