from pathlib import Path

from fastapi.testclient import TestClient

from sgoda.operational_platform.api import create_app


class PostgreSQLContractRepository:
    def __init__(self):
        self.entries = {
            "000001": {
                "entry_id": "000001",
                "puinave": "AMDA",
                "spanish": "Huérfana",
                "english_us": "",
                "italian": "",
                "validated": True,
                "category": "",
                "metadata": {},
            },
            "000508": {
                "entry_id": "000508",
                "puinave": "CANARIO-508",
                "spanish": "CANARIO-508-ES",
                "english_us": "",
                "italian": "",
                "validated": True,
                "category": "",
                "metadata": {},
            },
        }

    def get_entry(self, entry_id):
        value = self.entries.get(entry_id)
        return dict(value) if value else None

    def all_entries(self):
        return tuple(
            dict(self.entries[key])
            for key in sorted(self.entries)
        )

    def media_for(self, entry_id):
        if entry_id not in self.entries:
            return ()

        return (
            {
                "resource_type": "audio",
                "language": "pu",
                "path": f"audio/pu/{entry_id}.mp3",
                "validated": True,
                "autoplay": False,
                "metadata": {},
            },
        )

    def count(self):
        return len(self.entries)


def _settings_path():
    root = Path(__file__).resolve().parents[2]

    from sgoda.operational_platform.settings import OperationalSettings

    for candidate in sorted((root / "config").rglob("*.json")):
        try:
            OperationalSettings.from_json(candidate)
            return candidate
        except Exception:
            continue

    raise RuntimeError("OperationalSettings no encontrado")


def test_injected_repository_does_not_require_rlb_json():
    repository = PostgreSQLContractRepository()

    app = create_app(
        settings_path=_settings_path(),
        rlb_path="R29_POSTGRESQL_NO_JSON_REQUIRED.json",
        media_path=None,
        repository=repository,
    )

    client = TestClient(app)

    response = client.get("/lexical/000001")

    assert response.status_code == 200

    payload = response.json()

    assert payload["status"] == "ok"
    assert payload["data"]
    assert payload["sources"] == ["RLB:000001"]


def test_postgresql_contract_reaches_last_real508_id():
    repository = PostgreSQLContractRepository()

    app = create_app(
        settings_path=_settings_path(),
        rlb_path="R29_POSTGRESQL_NO_JSON_REQUIRED.json",
        repository=repository,
    )

    client = TestClient(app)

    response = client.get("/lexical/000508")

    assert response.status_code == 200

    payload = response.json()

    assert payload["status"] == "ok"
    assert payload["sources"] == ["RLB:000508"]

    serialized = str(payload["data"])

    assert "000508" in serialized


def test_postgresql_contract_preserves_404():
    repository = PostgreSQLContractRepository()

    app = create_app(
        settings_path=_settings_path(),
        rlb_path="R29_POSTGRESQL_NO_JSON_REQUIRED.json",
        repository=repository,
    )

    client = TestClient(app)

    response = client.get("/lexical/999999")

    assert response.status_code == 404
    assert response.json()["detail"] == "Entrada léxica no encontrada."


def test_existing_create_app_signature_is_preserved():
    import inspect

    parameters = inspect.signature(create_app).parameters

    assert "settings_path" in parameters
    assert "rlb_path" in parameters
    assert "media_path" in parameters
    assert "repository" in parameters

    assert parameters["media_path"].default is None
    assert parameters["repository"].default is None
