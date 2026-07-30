from fastapi.testclient import TestClient

from sgoda.main import app

client = TestClient(app)


def test_health_endpoint() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "ok"
    assert payload["service"] == "SGODA-PUINAVE API"
    assert payload["version"] == "0.1.0"


def test_version_endpoint() -> None:
    response = client.get("/version")
    assert response.status_code == 200
    assert response.json() == {
        "project": "SGODA-PUINAVE",
        "version": "0.1.0",
    }
