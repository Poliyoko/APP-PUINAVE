"""Contrato institucional SPT-001B-P06 para SGD-114."""

import json
from pathlib import Path

from sgoda.rlb.pipeline import ejecutar_pipeline


def test_SPT_001B_P06_declara_componente_y_artefactos() -> None:
    """Verifica identidad, módulos y evidencia real del incremento."""

    root = Path(__file__).resolve().parents[2]
    config_path = root / "config" / "rlb" / "SPT-001B-P06-component.json"

    assert config_path.is_file()

    config = json.loads(config_path.read_text(encoding="utf-8"))

    assert config["increment_code"] == "SPT-001B-P06"
    assert config["status"] == "technically_completed"
    assert config["entrypoint"] == "sgoda.rlb.cli"
    assert callable(ejecutar_pipeline)

    for relative in config["implementation_modules"]:
        assert (root / relative).is_file()

    artifacts = root / "artifacts" / "rlb" / "SPT-001B-P06"

    assert (artifacts / "palabras-canonicas.json").is_file()
    assert (artifacts / "perfil-rlb.json").is_file()
    assert (artifacts / "errores-importacion.json").is_file()
    assert (artifacts / "resumen-ejecucion.json").is_file()