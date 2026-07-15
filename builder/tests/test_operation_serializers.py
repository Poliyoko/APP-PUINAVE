import json

from sgoda.cli.main import main
from sgoda.operations import OperationCollector, serialize_json, serialize_text


def test_serializers_share_the_same_model(tmp_path) -> None:
    main(["init", str(tmp_path), "--project-name", "Serializado"])
    status = OperationCollector(tmp_path).collect()

    text = serialize_text(status, detailed=True)
    payload = json.loads(serialize_json(status, detailed=True))

    assert "Estado Operativo SGODA" in text
    assert "Estado general: HEALTHY" in text
    assert payload["project"]["name"] == "Serializado"
    assert payload["health"] == "HEALTHY"
    assert payload["resources"]["lexicon"] is True
