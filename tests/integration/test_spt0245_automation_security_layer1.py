import json
from pathlib import Path

from sgoda.integration.spt0245 import (
    AutomationSecurityAuditor,
    AutomationSecurityGate,
    AutomationSecurityPolicy,
    Spt0245AutomationSecurityService,
    WorkflowSecurityGuard,
)


def write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return path


def workflow(**overrides):
    data = {
        "name": "test",
        "active": False,
        "nodes": [],
        "connections": {},
    }
    data.update(overrides)
    return data


def test_default_policy_requires_secret_indirection():
    assert AutomationSecurityPolicy.default().require_credentials_indirection is True


def test_default_policy_requires_webhook_auth():
    assert AutomationSecurityPolicy.default().require_webhook_authentication is True


def test_default_policy_disallows_paid_api():
    assert AutomationSecurityPolicy.default().paid_api_allowed is False


def test_guard_hashes_workflow(tmp_path):
    path = write_json(tmp_path / "automation" / "n8n" / "workflows" / "a.json", workflow())
    assert len(WorkflowSecurityGuard.sha256(path)) == 64


def test_guard_detects_plaintext_secret():
    data = workflow(credentials={"token": "abcdefghijkl"})
    assert WorkflowSecurityGuard.contains_plaintext_secret(data) is True


def test_guard_allows_env_reference():
    data = workflow(credentials={"token": "{{$env.API_TOKEN}}"})
    assert WorkflowSecurityGuard.contains_plaintext_secret(data) is False


def test_guard_detects_webhook():
    data = workflow(nodes=[{"type": "n8n-nodes-base.webhook"}])
    assert WorkflowSecurityGuard.has_webhook(data) is True


def test_guard_detects_webhook_auth_marker():
    data = workflow(
        nodes=[
            {
                "type": "n8n-nodes-base.webhook",
                "parameters": {"authentication": "headerAuth"},
            }
        ]
    )
    assert WorkflowSecurityGuard.webhook_auth_marker(data) is True


def test_guard_detects_unsafe_execute_command():
    data = workflow(
        nodes=[
            {
                "type": "n8n-nodes-base.executeCommand",
                "parameters": {"command": "cmd /c del /s x"},
            }
        ]
    )
    assert WorkflowSecurityGuard.unsafe_execute_command(data) is True


def test_guard_allows_safe_non_command_workflow():
    assert WorkflowSecurityGuard.unsafe_execute_command(workflow()) is False


def test_active_marker_false_by_default():
    assert WorkflowSecurityGuard.active_marker(workflow()) is False


def test_active_marker_true():
    assert WorkflowSecurityGuard.active_marker(workflow(active=True)) is True


def test_auditor_discovers_workflow(tmp_path):
    write_json(tmp_path / "automation" / "n8n" / "workflows" / "a.json", workflow())
    assert len(AutomationSecurityAuditor(tmp_path).files()) == 1


def test_auditor_excludes_tests(tmp_path):
    write_json(tmp_path / "tests" / "a.json", workflow())
    assert AutomationSecurityAuditor(tmp_path).files() == []


def test_surface_contains_sha(tmp_path):
    write_json(tmp_path / "automation" / "n8n" / "workflows" / "a.json", workflow())
    surface = AutomationSecurityAuditor(tmp_path).discover_surfaces()[0]
    assert len(surface.metadata["sha256"]) == 64


def test_plaintext_secret_fails_control(tmp_path):
    write_json(
        tmp_path / "automation" / "n8n" / "workflows" / "a.json",
        workflow(credentials={"password": "abcdefghijkl"}),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-SECRET-INDIRECTION"].passed is False


def test_env_secret_reference_passes(tmp_path):
    write_json(
        tmp_path / "automation" / "n8n" / "workflows" / "a.json",
        workflow(credentials={"password": "{{$env.DB_PASSWORD}}"}),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-SECRET-INDIRECTION"].passed is True


def test_unauthenticated_webhook_fails(tmp_path):
    write_json(
        tmp_path / "automation" / "n8n" / "workflows" / "a.json",
        workflow(active=True, nodes=[{"type": "n8n-nodes-base.webhook"}]),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-WEBHOOK-AUTH"].passed is False


def test_authenticated_webhook_passes(tmp_path):
    write_json(
        tmp_path / "automation" / "n8n" / "workflows" / "a.json",
        workflow(
            nodes=[
                {
                    "type": "n8n-nodes-base.webhook",
                    "parameters": {"authentication": "headerAuth"},
                }
            ]
        ),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-WEBHOOK-AUTH"].passed is True


def test_unsafe_command_fails(tmp_path):
    write_json(
        tmp_path / "automation" / "n8n" / "workflows" / "a.json",
        workflow(
            nodes=[
                {
                    "type": "n8n-nodes-base.executeCommand",
                    "parameters": {"command": "bash -c rm -rf /tmp/x"},
                }
            ]
        ),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-COMMAND-EXECUTION"].passed is False


def test_integrity_control_passes(tmp_path):
    write_json(tmp_path / "automation" / "n8n" / "workflows" / "a.json", workflow())
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-INTEGRITY"].passed is True


def test_audit_control_passes(tmp_path):
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-AUDIT"].passed is True


def test_trust_default_control_passes(tmp_path):
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-TRUST-DEFAULT"].passed is True


def test_runtime_control_passes(tmp_path):
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-RUNTIME"].passed is True


def test_gate_blocks_missing_controls():
    report = AutomationSecurityGate.certify([], [])
    assert report.conformant is False


def test_gate_expected_count():
    assert len(AutomationSecurityGate.REQUIRED_BLOCKING_CONTROLS) == 8


def test_service_passes_empty_repo(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["status"] == "AUTOMATION_SECURITY_GATE_PASS"


def test_service_does_not_start_n8n(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["n8n_started_by_gate"] is False


def test_service_does_not_execute_workflow(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["workflow_executed_by_gate"] is False


def test_service_does_not_call_webhook(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["webhook_called_by_gate"] is False


def test_service_never_exposes_secrets(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["secret_values_exposed"] is False


def test_service_preserves_closed_components(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["closed_components_mutated"] is False


def test_service_uses_no_paid_api(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["paid_api_used"] is False


def test_service_points_to_spt0246(tmp_path):
    assert Spt0245AutomationSecurityService(tmp_path).evaluate()["next_component"] == "SPT-024.6"


def test_surface_reports_runtime_state(tmp_path):
    write_json(tmp_path / "automation" / "n8n" / "workflows" / "a.json", workflow(active=True))
    surface = AutomationSecurityAuditor(tmp_path).discover_surfaces()[0]
    assert surface.active_runtime is True


def test_surface_reports_secret_reference_only(tmp_path):
    write_json(
        tmp_path / "automation" / "n8n" / "workflows" / "a.json",
        workflow(credentials={"token": "{{$env.X_TOKEN}}"}),
    )
    surface = AutomationSecurityAuditor(tmp_path).discover_surfaces()[0]
    assert surface.secret_reference_only is True


def test_surface_reports_webhook(tmp_path):
    write_json(
        tmp_path / "automation" / "n8n" / "workflows" / "a.json",
        workflow(active=True, nodes=[{"type": "n8n-nodes-base.webhook"}]),
    )
    surface = AutomationSecurityAuditor(tmp_path).discover_surfaces()[0]
    assert surface.webhook_exposure is True


def test_surface_reports_command_safety(tmp_path):
    write_json(tmp_path / "automation" / "n8n" / "workflows" / "a.json", workflow())
    surface = AutomationSecurityAuditor(tmp_path).discover_surfaces()[0]
    assert surface.unsafe_command_execution is False


def test_sha_is_uppercase(tmp_path):
    path = write_json(tmp_path / "automation" / "n8n" / "workflows" / "a.json", workflow())
    value = WorkflowSecurityGuard.sha256(path)
    assert value == value.upper()


def test_policy_requires_integrity_hash():
    assert AutomationSecurityPolicy.default().require_workflow_integrity_hash is True


def test_config_registry_is_not_runtime_workflow(tmp_path):
    write_json(
        tmp_path / "config" / "automation" / "workflow-registry.json",
        {"workflow": "webhook", "active": False},
    )
    assert AutomationSecurityAuditor(tmp_path).files() == []


def test_inactive_unauthenticated_webhook_is_quarantined_not_blocking(tmp_path):
    write_json(
        tmp_path / "automation" / "n8n" / "workflows" / "a.json",
        workflow(
            active=False,
            nodes=[{"type": "n8n-nodes-base.webhook", "parameters": {}}],
        ),
    )
    controls, surfaces = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-WEBHOOK-AUTH"].passed is True
    assert surfaces[0].metadata["inactive_quarantine"] is True


def test_active_unauthenticated_webhook_is_blocking(tmp_path):
    write_json(
        tmp_path / "automation" / "n8n" / "workflows" / "a.json",
        workflow(
            active=True,
            nodes=[{"type": "n8n-nodes-base.webhook", "parameters": {}}],
        ),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-WEBHOOK-AUTH"].passed is False


def test_active_authenticated_webhook_passes(tmp_path):
    write_json(
        tmp_path / "automation" / "n8n" / "workflows" / "a.json",
        workflow(
            active=True,
            nodes=[
                {
                    "type": "n8n-nodes-base.webhook",
                    "parameters": {"authentication": "headerAuth"},
                }
            ],
        ),
    )
    controls, _ = AutomationSecurityAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["AUT-WEBHOOK-AUTH"].passed is True
