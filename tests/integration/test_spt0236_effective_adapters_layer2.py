import json
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

import pytest

from sgoda.integration.spt0236.adapters import JsonHttpAdapter, LocalJsonFileAdapter
from sgoda.integration.spt0236.bindings import EffectiveAdapterRegistry
from sgoda.integration.spt0236.bridge import Spt0236Layer2Bridge
from sgoda.integration.spt0236.contracts import PIPELINE
from sgoda.integration.spt0236.service import Spt0236Layer1Service
from sgoda.integration.spt0236.state import OrchestrationStateStore


def server_for(status):
    expected_response_status = str(status)

    class IsolatedHandler(BaseHTTPRequestHandler):
        def do_POST(self):
            length = int(self.headers.get("Content-Length", "0"))
            self.rfile.read(length)
            body = json.dumps(
                {"status": expected_response_status}
            ).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            return

    server = HTTPServer(("127.0.0.1", 0), IsolatedHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, f"http://127.0.0.1:{server.server_address[1]}/"


def core_handlers():
    mapping = {}
    for step in PIPELINE:
        if step.component.startswith("SPT-023."):
            mapping[step.component] = (
                lambda expected: (
                    lambda payload: {"status": expected, "payload": payload}
                )
            )(step.success_status)
    return mapping


def test_http_adapter_accepts_expected_status():
    server, endpoint = server_for("ORCHESTRATION_EXPOSED")
    try:
        result = JsonHttpAdapter(
            component="FASTAPI",
            endpoint=endpoint,
        ).invoke({}, expected_status="ORCHESTRATION_EXPOSED")
        assert result.status == "ORCHESTRATION_EXPOSED"
    finally:
        server.shutdown()


def test_http_adapter_rejects_wrong_status():
    server, endpoint = server_for("WRONG")
    try:
        with pytest.raises(ValueError):
            JsonHttpAdapter(
                component="FASTAPI",
                endpoint=endpoint,
            ).invoke({}, expected_status="ORCHESTRATION_EXPOSED")
    finally:
        server.shutdown()


def test_file_adapter_persists_expected_status(tmp_path):
    path = tmp_path / "pmo.json"
    result = LocalJsonFileAdapter(
        component="PMO_DIGITAL",
        path=path,
    ).invoke({"x": 1}, expected_status="PMO_REGISTERED")
    assert result.status == "PMO_REGISTERED"
    assert path.exists()


def test_file_adapter_writes_valid_json(tmp_path):
    path = tmp_path / "auditor.json"
    LocalJsonFileAdapter(
        component="AUDITOR_INSTITUCIONAL",
        path=path,
    ).invoke({}, expected_status="AUDIT_APPROVED")
    assert json.loads(path.read_text(encoding="utf-8"))["status"] == "AUDIT_APPROVED"


def test_registry_exposes_five_bindings(tmp_path):
    registry = EffectiveAdapterRegistry(
        fastapi_endpoint="http://127.0.0.1:1/",
        n8n_endpoint="http://127.0.0.1:2/",
        pmo_state_path=str(tmp_path / "pmo.json"),
        auditor_state_path=str(tmp_path / "audit.json"),
        sgd002_state_path=str(tmp_path / "sgd002.json"),
    )
    assert len(registry.bindings()) == 5


def test_registry_can_disable_unconfigured_bindings():
    registry = EffectiveAdapterRegistry()
    assert all(not item.enabled for item in registry.bindings())


def test_registry_builds_local_handlers(tmp_path):
    registry = EffectiveAdapterRegistry(
        pmo_state_path=str(tmp_path / "pmo.json"),
        auditor_state_path=str(tmp_path / "audit.json"),
        sgd002_state_path=str(tmp_path / "sgd002.json"),
    )
    handlers = registry.build_handlers()
    assert {"PMO_DIGITAL", "AUDITOR_INSTITUCIONAL", "SGD-002"} <= set(handlers)


def test_registry_builds_http_handlers():
    registry = EffectiveAdapterRegistry(
        fastapi_endpoint="http://127.0.0.1:1/",
        n8n_endpoint="http://127.0.0.1:2/",
    )
    handlers = registry.build_handlers()
    assert {"FASTAPI", "N8N"} <= set(handlers)


def test_bridge_requires_all_core_handlers(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(),
        core_handlers={},
    )
    with pytest.raises(ValueError):
        bridge.validate_bindings()


def test_bridge_validates_core_handlers(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(),
        core_handlers=core_handlers(),
    )
    assert bridge.validate_bindings()["valid"] is True


def test_bridge_validation_disables_paid_api(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(),
        core_handlers=core_handlers(),
    )
    assert bridge.validate_bindings()["paid_api_used"] is False


def test_bridge_executes_with_local_institutional_adapters(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(tmp_path / "pmo.json"),
            auditor_state_path=str(tmp_path / "audit.json"),
            sgd002_state_path=str(tmp_path / "sgd002.json"),
        ),
        core_handlers=core_handlers(),
    )
    result = bridge.execute(lexical_id="LEX-001")
    assert result["orchestration_complete"] is True


def test_bridge_executes_with_n8n_http_adapter(tmp_path):
    n8n_server, n8n_endpoint = server_for("WORKFLOW_COORDINATED")
    try:
        service = Spt0236Layer1Service(
            OrchestrationStateStore(tmp_path / "state.json")
        )
        bridge = Spt0236Layer2Bridge(
            orchestrator=service,
            adapters=EffectiveAdapterRegistry(
                n8n_endpoint=n8n_endpoint,
                pmo_state_path=str(tmp_path / "pmo.json"),
                auditor_state_path=str(tmp_path / "audit.json"),
                sgd002_state_path=str(tmp_path / "sgd002.json"),
            ),
            core_handlers=core_handlers(),
        )
        result = bridge.execute(lexical_id="LEX-001")
        assert result["orchestration_complete"] is True
    finally:
        n8n_server.shutdown()


def test_bridge_executes_with_fastapi_http_adapter(tmp_path):
    api_server, api_endpoint = server_for("ORCHESTRATION_EXPOSED")
    try:
        service = Spt0236Layer1Service(
            OrchestrationStateStore(tmp_path / "state.json")
        )
        bridge = Spt0236Layer2Bridge(
            orchestrator=service,
            adapters=EffectiveAdapterRegistry(
                fastapi_endpoint=api_endpoint,
                pmo_state_path=str(tmp_path / "pmo.json"),
                auditor_state_path=str(tmp_path / "audit.json"),
                sgd002_state_path=str(tmp_path / "sgd002.json"),
            ),
            core_handlers=core_handlers(),
        )
        result = bridge.execute(lexical_id="LEX-001")
        assert result["orchestration_complete"] is True
    finally:
        api_server.shutdown()


def test_bridge_executes_with_both_http_adapters(tmp_path):
    n8n_server, n8n_endpoint = server_for("WORKFLOW_COORDINATED")
    api_server, api_endpoint = server_for("ORCHESTRATION_EXPOSED")
    try:
        service = Spt0236Layer1Service(
            OrchestrationStateStore(tmp_path / "state.json")
        )
        bridge = Spt0236Layer2Bridge(
            orchestrator=service,
            adapters=EffectiveAdapterRegistry(
                fastapi_endpoint=api_endpoint,
                n8n_endpoint=n8n_endpoint,
                pmo_state_path=str(tmp_path / "pmo.json"),
                auditor_state_path=str(tmp_path / "audit.json"),
                sgd002_state_path=str(tmp_path / "sgd002.json"),
            ),
            core_handlers=core_handlers(),
        )
        result = bridge.execute(lexical_id="LEX-001")
        assert result["effective_adapters"] is True
    finally:
        n8n_server.shutdown()
        api_server.shutdown()


def test_bridge_points_to_layer3(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(tmp_path / "pmo.json"),
            auditor_state_path=str(tmp_path / "audit.json"),
            sgd002_state_path=str(tmp_path / "sgd002.json"),
        ),
        core_handlers=core_handlers(),
    )
    result = bridge.execute(lexical_id="LEX-001")
    assert result["next_component"] == "SPT-023.6-CAPA-3"


def test_pmo_file_is_created(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    pmo = tmp_path / "pmo.json"
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(pmo),
            auditor_state_path=str(tmp_path / "audit.json"),
            sgd002_state_path=str(tmp_path / "sgd002.json"),
        ),
        core_handlers=core_handlers(),
    )
    bridge.execute(lexical_id="LEX-001")
    assert pmo.exists()


def test_auditor_file_is_created(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    audit = tmp_path / "audit.json"
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(tmp_path / "pmo.json"),
            auditor_state_path=str(audit),
            sgd002_state_path=str(tmp_path / "sgd002.json"),
        ),
        core_handlers=core_handlers(),
    )
    bridge.execute(lexical_id="LEX-001")
    assert audit.exists()


def test_sgd002_file_is_created(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    sgd = tmp_path / "sgd002.json"
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(tmp_path / "pmo.json"),
            auditor_state_path=str(tmp_path / "audit.json"),
            sgd002_state_path=str(sgd),
        ),
        core_handlers=core_handlers(),
    )
    bridge.execute(lexical_id="LEX-001")
    assert sgd.exists()


def test_orchestration_remains_idempotent(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(tmp_path / "pmo.json"),
            auditor_state_path=str(tmp_path / "audit.json"),
            sgd002_state_path=str(tmp_path / "sgd002.json"),
        ),
        core_handlers=core_handlers(),
    )
    one = bridge.execute(lexical_id="LEX-001")
    two = service.execute_with_handlers(
        orchestration_id=one["orchestration_id"],
        handlers=bridge.handlers(),
    )
    assert one["completed_steps"] == two["completed_steps"]


def test_state_store_preserves_completed_steps(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(tmp_path / "pmo.json"),
            auditor_state_path=str(tmp_path / "audit.json"),
            sgd002_state_path=str(tmp_path / "sgd002.json"),
        ),
        core_handlers=core_handlers(),
    )
    result = bridge.execute(lexical_id="LEX-001")
    stored = service.state_store.get(result["orchestration_id"])
    assert len(stored["completed_steps"]) == 10


def test_http_binding_is_decoupled_from_core_handlers(tmp_path):
    registry = EffectiveAdapterRegistry(
        fastapi_endpoint="http://127.0.0.1:1/"
    )
    assert "FASTAPI" in registry.build_handlers()
    assert "SPT-023.1" not in registry.build_handlers()
