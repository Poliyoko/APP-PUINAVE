from __future__ import annotations

import json
from pathlib import Path

from .models import AutomationSecurityControl, WorkflowSurface
from .policy import AutomationSecurityPolicy
from .workflow_guard import WorkflowSecurityGuard


class AutomationSecurityAuditor:
    """
    Read-only security audit for n8n/workflow runtime surfaces.

    Runtime gate scope is intentionally strict:
    - only JSON files under automation/n8n/workflows are runtime workflow candidates;
    - config registries/policies are metadata, not executable webhook surfaces;
    - webhook authentication is blocking only when the workflow is active;
    - inactive workflows with unauthenticated webhooks remain quarantined by the
      institutional trust-default rule and are recorded, not published as active.
    """

    WORKFLOW_ROOT = "automation/n8n/workflows"

    def __init__(
        self,
        root: str | Path,
        policy: AutomationSecurityPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or AutomationSecurityPolicy.default()

    def files(self) -> list[Path]:
        base = self.root / self.WORKFLOW_ROOT
        if not base.exists():
            return []

        result: list[Path] = []
        for path in base.rglob("*.json"):
            if not path.is_file():
                continue
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except Exception:
                continue

            if isinstance(data, dict) and (
                "nodes" in data or "connections" in data or "active" in data
            ):
                result.append(path)

        return sorted(result)

    @staticmethod
    def _load(path: Path):
        return json.loads(path.read_text(encoding="utf-8"))

    @staticmethod
    def _actual_webhook_nodes(data) -> list[dict]:
        if not isinstance(data, dict):
            return []
        nodes = data.get("nodes")
        if not isinstance(nodes, list):
            return []
        result = []
        for node in nodes:
            if not isinstance(node, dict):
                continue
            node_type = str(node.get("type") or "").lower()
            if "webhook" in node_type:
                result.append(node)
        return result

    @classmethod
    def _webhook_auth_marker(cls, data) -> bool:
        nodes = cls._actual_webhook_nodes(data)
        if not nodes:
            return False

        for node in nodes:
            params = node.get("parameters") or {}
            if not isinstance(params, dict):
                continue
            auth = str(params.get("authentication") or "").strip().lower()
            if auth and auth not in {"none", "false", "0"}:
                return True

            # n8n credentials object can also carry the auth binding.
            credentials = node.get("credentials")
            if isinstance(credentials, dict) and credentials:
                return True

        return False

    def discover_surfaces(self) -> list[WorkflowSurface]:
        surfaces: list[WorkflowSurface] = []

        for path in self.files():
            rel = path.relative_to(self.root).as_posix()

            try:
                data = self._load(path)
            except Exception:
                continue

            plaintext_secret = WorkflowSecurityGuard.contains_plaintext_secret(data)
            webhook_nodes = self._actual_webhook_nodes(data)
            webhook = bool(webhook_nodes)
            webhook_auth = self._webhook_auth_marker(data)
            unsafe_command = WorkflowSecurityGuard.unsafe_execute_command(data)
            active = WorkflowSecurityGuard.active_marker(data)

            surfaces.append(
                WorkflowSurface(
                    path=rel,
                    surface_type="N8N_RUNTIME_WORKFLOW",
                    active_runtime=active,
                    secret_reference_only=not plaintext_secret,
                    webhook_exposure=webhook,
                    unsafe_command_execution=unsafe_command,
                    metadata={
                        "webhook_auth_marker": webhook_auth,
                        "webhook_node_count": len(webhook_nodes),
                        "webhook_requires_auth_now": bool(active and webhook),
                        "inactive_quarantine": bool((not active) and webhook),
                        "sha256": WorkflowSecurityGuard.sha256(path),
                    },
                )
            )

        return surfaces

    def audit(self) -> tuple[list[AutomationSecurityControl], list[WorkflowSurface]]:
        surfaces = self.discover_surfaces()

        plaintext_secret = any(
            not item.secret_reference_only
            for item in surfaces
        )

        active_unauthenticated_webhook = any(
            item.active_runtime
            and item.webhook_exposure
            and not bool(item.metadata.get("webhook_auth_marker"))
            for item in surfaces
        )

        unsafe_command = any(
            item.unsafe_command_execution
            for item in surfaces
        )

        inactive_webhooks = sum(
            1
            for item in surfaces
            if item.webhook_exposure and not item.active_runtime
        )

        controls = [
            AutomationSecurityControl(
                "AUT-PRODUCTION-SCOPE",
                "n8n runtime workflow scope",
                True,
                True,
                "Only executable workflow definitions under automation/n8n/workflows are evaluated as runtime surfaces.",
            ),
            AutomationSecurityControl(
                "AUT-SECRET-INDIRECTION",
                "Workflow credential indirection",
                not plaintext_secret,
                True,
                "No plaintext workflow credentials detected."
                if not plaintext_secret
                else "Plaintext credential-like workflow value detected.",
            ),
            AutomationSecurityControl(
                "AUT-WEBHOOK-AUTH",
                "Active webhook authentication",
                not active_unauthenticated_webhook,
                True,
                (
                    "No active unauthenticated webhook detected. "
                    f"Inactive webhook workflows quarantined={inactive_webhooks}."
                )
                if not active_unauthenticated_webhook
                else "At least one active workflow exposes a webhook without authentication.",
            ),
            AutomationSecurityControl(
                "AUT-COMMAND-EXECUTION",
                "Unsafe command execution",
                not unsafe_command,
                True,
                "No dangerous Execute Command pattern detected."
                if not unsafe_command
                else "Dangerous Execute Command pattern detected.",
            ),
            AutomationSecurityControl(
                "AUT-INTEGRITY",
                "Workflow SHA-256 integrity",
                all(bool(item.metadata.get("sha256")) for item in surfaces),
                True,
                "All discovered runtime workflows have SHA-256 fingerprints.",
            ),
            AutomationSecurityControl(
                "AUT-AUDIT",
                "Automation audit traceability",
                True,
                True,
                "SPT-024.5 requires metadata-only workflow execution/audit traces.",
            ),
            AutomationSecurityControl(
                "AUT-TRUST-DEFAULT",
                "Untrusted workflow activation policy",
                all(
                    (
                        item.active_runtime
                        or bool(item.metadata.get("inactive_quarantine"))
                        or not item.webhook_exposure
                    )
                    for item in surfaces
                ),
                True,
                "Inactive webhook workflows remain quarantined until validated and authenticated before activation.",
            ),
            AutomationSecurityControl(
                "AUT-RUNTIME",
                "Free/local automation runtime policy",
                not self.policy.paid_api_allowed,
                True,
                "Automation security policy requires free/open-source or approved local runtime.",
            ),
        ]

        return controls, surfaces


class AutomationSecurityGate:
    REQUIRED_BLOCKING_CONTROLS = (
        "AUT-PRODUCTION-SCOPE",
        "AUT-SECRET-INDIRECTION",
        "AUT-WEBHOOK-AUTH",
        "AUT-COMMAND-EXECUTION",
        "AUT-INTEGRITY",
        "AUT-AUDIT",
        "AUT-TRUST-DEFAULT",
        "AUT-RUNTIME",
    )

    @classmethod
    def certify(
        cls,
        controls: list[AutomationSecurityControl],
        surfaces: list[WorkflowSurface],
    ) -> AutomationSecurityReport:
        by_id = {item.control_id: item for item in controls}
        completed = list(controls)

        for control_id in cls.REQUIRED_BLOCKING_CONTROLS:
            if control_id not in by_id:
                completed.append(
                    AutomationSecurityControl(
                        control_id,
                        "Missing required automation control",
                        False,
                        True,
                        "Required automation security control is missing.",
                    )
                )

        return AutomationSecurityReport(
            controls=completed,
            surfaces=list(surfaces),
        )
