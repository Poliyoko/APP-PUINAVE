"""Pruebas SGD-115 del sistema maestro de documentación."""

import json
from pathlib import Path

from sgoda.documentation.master_docs import (
    discover_components,
    publish_artifacts,
    validate_master_documents,
    write_master_documents,
)


def _repository(tmp_path: Path) -> Path:
    root = tmp_path
    (root / "config" / "sample").mkdir(parents=True)
    (root / "docs" / "01_Gobierno").mkdir(parents=True)
    (root / "docs" / "03_ADR").mkdir(parents=True)
    (root / "docs" / "05_Fase_Tecnologica").mkdir(parents=True)
    (root / "docs" / "15_Historial").mkdir(parents=True)
    (root / "src" / "sgoda" / "sample").mkdir(parents=True)
    (root / "tests" / "sample").mkdir(parents=True)
    (root / "artifacts" / "pmo" / "SPT-TEST").mkdir(parents=True)
    (root / "releases" / "SPT-TEST-v1.0.0").mkdir(parents=True)
    (root / "dashboard").mkdir()
    (root / "scripts").mkdir()

    component = {
        "increment_code": "SPT-TEST",
        "component_type": "sample_component",
        "version": "1.0.0",
        "status": "technically_completed",
        "source": ["src/sgoda/sample/module.py"],
        "tests": ["tests/sample/test_module.py"],
    }

    (root / "config" / "sample" / "SPT-TEST-component.json").write_text(
        json.dumps(component),
        encoding="utf-8",
    )
    (root / "src" / "sgoda" / "sample" / "module.py").write_text(
        "VALUE = 1\n",
        encoding="utf-8",
    )
    (root / "tests" / "sample" / "test_module.py").write_text(
        "def test_value(): assert True\n",
        encoding="utf-8",
    )
    (
        root
        / "docs"
        / "05_Fase_Tecnologica"
        / "SPT-TEST-Implementacion.md"
    ).write_text(
        "# SPT-TEST\n",
        encoding="utf-8",
    )
    (
        root
        / "artifacts"
        / "pmo"
        / "SPT-TEST"
        / "evidence.json"
    ).write_text(
        "{}\n",
        encoding="utf-8",
    )

    return root


def test_SGD_115_descubre_componentes(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    records = discover_components(root)

    assert len(records) == 1
    assert records[0].code == "SPT-TEST"
    assert records[0].version == "1.0.0"


def test_SGD_115_genera_tres_documentos(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    outputs = write_master_documents(root)

    assert set(outputs) == {"index", "architecture", "registry"}
    assert all(path.is_file() for path in outputs.values())


def test_SGD_115_indice_contiene_componente(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    outputs = write_master_documents(root)

    text = outputs["index"].read_text(encoding="utf-8")

    assert "SPT-TEST" in text
    assert "Arquitectura Maestra" in text


def test_SGD_115_arquitectura_contiene_capas(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    outputs = write_master_documents(root)

    text = outputs["architecture"].read_text(encoding="utf-8")

    assert "## 3. Capas arquitectónicas" in text
    assert "## 6. Seguridad y soberanía cultural" in text


def test_SGD_115_registro_contiene_trazabilidad(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    outputs = write_master_documents(root)

    text = outputs["registry"].read_text(encoding="utf-8")

    assert "src/sgoda/sample/module.py" in text
    assert "tests/sample/test_module.py" in text
    assert "SPT-TEST-v1.0.0" in text


def test_SGD_115_validacion_aprobada(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    write_master_documents(root)

    result = validate_master_documents(root)

    assert result.passed is True
    assert result.component_count == 1
    assert result.broken_paths == []


def test_SGD_115_detecta_documento_faltante(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    outputs = write_master_documents(root)
    outputs["architecture"].unlink()

    result = validate_master_documents(root)

    assert result.passed is False
    assert "architecture" in result.missing_required_sections


def test_SGD_115_publica_inventario_evento_y_validacion(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    write_master_documents(root)

    artifacts = publish_artifacts(
        root,
        root / "artifacts" / "documentation" / "SGD-115",
    )

    assert artifacts["inventory"].is_file()
    assert artifacts["validation"].is_file()
    assert artifacts["event"].is_file()

    validation = json.loads(
        artifacts["validation"].read_text(encoding="utf-8")
    )
    assert validation["passed"] is True