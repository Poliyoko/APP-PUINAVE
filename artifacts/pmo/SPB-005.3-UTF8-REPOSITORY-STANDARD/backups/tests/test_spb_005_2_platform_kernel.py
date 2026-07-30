"""Pruebas de SPB-005.2 - SGODA Platform Kernel."""

from fastapi.testclient import TestClient

from sgoda.main import app


client = TestClient(app)


def test_kernel_status() -> None:
    response = client.get("/kernel/status")

    assert response.status_code == 200

    payload = response.json()

    assert payload["status"] == "operational"
    assert payload["kernel"] == "SGODA Platform Kernel"
    assert payload["registered_modules"] >= 6
    assert payload["enabled_modules"] >= 1


def test_kernel_modules() -> None:
    response = client.get("/kernel/modules")

    assert response.status_code == 200

    payload = response.json()
    module_codes = {
        module["code"]
        for module in payload["modules"]
    }

    assert "kernel" in module_codes
    assert "pmo" in module_codes
    assert "dictionary" in module_codes
    assert "media" in module_codes
    assert "oda" in module_codes
    assert "automation" in module_codes


def test_kernel_metadata() -> None:
    response = client.get("/kernel/metadata")

    assert response.status_code == 200

    payload = response.json()

    assert payload["project"] == "SGODA-PUINAVE"
    assert payload["version"] == "0.5.2"
    assert "git" in payload


def test_repository_audit() -> None:
    response = client.get("/kernel/audit/repository")

    assert response.status_code == 200

    payload = response.json()

    assert payload["audit_mode"] == "read-only"
    assert "working_tree_clean" in payload
    assert "pending_changes" in payload


def test_foundation_endpoints_remain_available() -> None:
    health_response = client.get("/health")
    version_response = client.get("/version")

    assert health_response.status_code == 200
    assert version_response.status_code == 200
