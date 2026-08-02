import json
from pathlib import Path

import pytest

from sgoda.installer_builder.generator import generate_package
from sgoda.installer_builder.models import IncrementSpec
from sgoda.installer_builder.validator import (
    SpecificationError,
    validate_code,
    validate_generated_package,
    validate_name,
)


def _spec() -> IncrementSpec:
    return IncrementSpec(
        code="SPT-999A",
        name="Componente Institucional de Prueba",
        component_type="test_component",
    )


def test_SIB_001_valida_codigo() -> None:
    assert validate_code("spt-004c") == "SPT-004C"
    assert validate_code("ADR-012") == "ADR-012"


def test_SIB_001_rechaza_codigo_invalido() -> None:
    with pytest.raises(SpecificationError):
        validate_code("componente nuevo")


def test_SIB_001_valida_nombre() -> None:
    assert validate_name("  Motor   Institucional  ") == "Motor Institucional"


def test_SIB_001_genera_paquete_completo(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec())
    assert package.root.is_dir()
    assert validate_generated_package(package.root) == []


def test_SIB_001_instalador_fail_fast(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec())
    text = package.installer_path.read_text(encoding="utf-8")
    assert '$ErrorActionPreference = "Stop"' in text
    assert "python -m pytest" in text
    assert "evidence_policy" in text


def test_SIB_001_correctivo_con_respaldo(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec())
    text = package.repair_template_path.read_text(encoding="utf-8")
    assert "backups" in text
    assert "prueba puntual" in text.casefold()
    assert "suite completa" in text.casefold()


def test_SIB_001_manifiesto_sha256(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec())
    manifest = json.loads(package.manifest_path.read_text(encoding="utf-8"))
    assert manifest["generator"] == "SIB-001"
    assert len(manifest["files"]) == 7
    assert all(len(item["sha256"]) == 64 for item in manifest["files"])


def test_SIB_001_no_sobrescribe_sin_force(tmp_path: Path) -> None:
    generate_package(output_root=tmp_path, spec=_spec())
    with pytest.raises(FileExistsError):
        generate_package(output_root=tmp_path, spec=_spec())


def test_SIB_001_force_crea_respaldo(tmp_path: Path) -> None:
    generate_package(output_root=tmp_path, spec=_spec())
    generate_package(output_root=tmp_path, spec=_spec(), force=True)
    assert len(list(tmp_path.glob("SPT-999A.backup-*"))) == 1


def test_SIB_001_comandos_spb007(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec())
    text = package.publication_commands_path.read_text(encoding="utf-8")
    assert "Invoke-SPB007-InstitutionalPublish.ps1" in text
    assert "-EvidenceCommitMessage" in text


def test_SIB_001_preview_no_escribe(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec(), preview=True)
    assert not package.root.exists()


def test_SIB_001_declara_gobierno(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec())
    component = json.loads(package.component_path.read_text(encoding="utf-8"))
    assert "SGD-114-v2.0.1" in component["governed_by"]
    assert component["generated_by"] == "SIB-001"