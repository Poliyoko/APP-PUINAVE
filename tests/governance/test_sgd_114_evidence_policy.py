"""Pruebas funcionales de SGD-114 v1.1."""

import json
import subprocess
import sys
from pathlib import Path

from sgoda.governance.evidence_policy import (
    ErrorPoliticaSGD114,
    cargar_politica,
    escribir_resultado,
    evaluar_incremento,
    normalizar_codigo,
)


def _crear_politica(tmp_path: Path) -> Path:
    policy = {
        "policy_code": "SGD-114",
        "policy_name": "Política de prueba",
        "version": "1.1.0",
        "status": "implemented",
        "required_categories": [
            {
                "code": "source",
                "description": "Código",
                "patterns": ["src/**/*", "config/**/*"],
            },
            {
                "code": "tests",
                "description": "Pruebas",
                "patterns": ["tests/**/*.py"],
            },
            {
                "code": "documentation",
                "description": "Documentación",
                "patterns": ["docs/**/*.md"],
            },
            {
                "code": "evidence",
                "description": "Evidencia",
                "patterns": ["artifacts/**/*"],
            },
            {
                "code": "traceability",
                "description": "Trazabilidad",
                "patterns": ["artifacts/**/traceability*.json"],
            },
        ],
        "closure_rule": "all_required_categories_must_pass",
        "allowed_statuses": [
            "technically_completed",
            "institutionally_closed",
        ],
        "institutional_closure_status": "institutionally_closed",
        "code_matching": "normalized_alphanumeric",
        "bootstrap_policy": "evidence_first_then_self_validate",
    }

    path = tmp_path / "policy.json"
    path.write_text(json.dumps(policy), encoding="utf-8")
    return path


def _crear_incremento_completo(
    root: Path,
    code: str,
) -> None:
    alternate = code.replace("-", "_")

    files = {
        root / "config" / f"{code}-config.json": "{}\n",
        root / "tests" / f"test_{alternate}.py": (
            "def test_ok(): assert True\n"
        ),
        root / "docs" / f"{code}-Documento.md": "# Documento\n",
        root / "artifacts" / code / "evidence.json": "{}\n",
        root / "artifacts" / code / "traceability.json": "{}\n",
    }

    for path, content in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")


def test_normaliza_variantes_del_codigo() -> None:
    assert normalizar_codigo("SGD-114") == "sgd114"
    assert normalizar_codigo("sgd_114") == "sgd114"
    assert normalizar_codigo("SGD 114") == "sgd114"


def test_autoriza_cierre_con_evidencias_completas(
    tmp_path: Path,
) -> None:
    policy = cargar_politica(_crear_politica(tmp_path))
    _crear_incremento_completo(tmp_path, "SGD-114")

    result = evaluar_incremento(
        repository_root=tmp_path,
        policy=policy,
        increment_code="SGD-114",
        requested_status="institutionally_closed",
    )

    assert result.passed is True
    assert result.closure_authorized is True
    assert result.missing_categories == []


def test_bloquea_cierre_si_faltan_evidencias(
    tmp_path: Path,
) -> None:
    policy = cargar_politica(_crear_politica(tmp_path))

    source = tmp_path / "config" / "SGD-115-config.json"
    source.parent.mkdir(parents=True)
    source.write_text("{}\n", encoding="utf-8")

    result = evaluar_incremento(
        repository_root=tmp_path,
        policy=policy,
        increment_code="SGD-115",
        requested_status="institutionally_closed",
    )

    assert result.passed is False
    assert result.closure_authorized is False
    assert set(result.missing_categories) == {
        "tests",
        "documentation",
        "evidence",
        "traceability",
    }


def test_genera_evidencia_json(
    tmp_path: Path,
) -> None:
    policy = cargar_politica(_crear_politica(tmp_path))
    _crear_incremento_completo(tmp_path, "SPT-902")

    result = evaluar_incremento(
        repository_root=tmp_path,
        policy=policy,
        increment_code="SPT-902",
        requested_status="technically_completed",
    )

    target = escribir_resultado(
        result,
        tmp_path / "result.json",
    )
    data = json.loads(target.read_text(encoding="utf-8"))

    assert data["policy_version"] == "1.1.0"
    assert data["passed"] is True
    assert len(data["categories"]) == 5


def test_rechaza_estado_no_autorizado(
    tmp_path: Path,
) -> None:
    policy = cargar_politica(_crear_politica(tmp_path))

    try:
        evaluar_incremento(
            repository_root=tmp_path,
            policy=policy,
            increment_code="SPT-903",
            requested_status="invented_status",
        )
    except ErrorPoliticaSGD114 as error:
        assert "Estado no permitido" in str(error)
    else:
        raise AssertionError(
            "Debía rechazarse un estado no autorizado."
        )


def test_cli_no_emite_advertencia_runpy(
    tmp_path: Path,
) -> None:
    policy_path = _crear_politica(tmp_path)
    _crear_incremento_completo(tmp_path, "SGD-114")

    output_path = tmp_path / "gate.json"

    process = subprocess.run(
        [
            sys.executable,
            "-m",
            "sgoda.governance.evidence_policy",
            "--root",
            str(tmp_path),
            "--policy",
            str(policy_path),
            "--increment",
            "SGD-114",
            "--status",
            "institutionally_closed",
            "--output",
            str(output_path),
        ],
        capture_output=True,
        text=True,
        check=False,
    )

    assert process.returncode == 0
    assert "RuntimeWarning" not in process.stderr
    assert "Cumplimiento: APROBADO" in process.stdout
    assert "Cierre institucional: AUTORIZADO" in process.stdout
    assert output_path.is_file()