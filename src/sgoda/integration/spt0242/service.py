from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterable

from .classification import SecretCandidateClassifier
from .config_audit import SecureConfigurationAuditor
from .git_gate import GitSecretGate
from .policy import SecretManagementPolicy
from .rotation import RotationPolicyEngine
from .storage import SecureStoragePlanner


class Spt0242SecretsSecurityService:
    """Secrets, credentials and secure configuration governance service."""

    def __init__(
        self,
        root: str | Path,
        policy: SecretManagementPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or SecretManagementPolicy.default()

    @staticmethod
    def load_spt0241_candidates(path: str | Path) -> list[dict]:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        return list(data.get("secret_candidates") or [])

    def evaluate(
        self,
        *,
        secret_candidates: Iterable[dict],
        tracked_paths: Iterable[str],
        preferred_storage_backend: str = "ENVIRONMENT_VARIABLES",
    ) -> dict[str, Any]:
        assessments = SecretCandidateClassifier.classify_many(secret_candidates)

        auditor = SecureConfigurationAuditor(self.root, self.policy)
        controls = [
            auditor.audit_gitignore(),
            auditor.audit_tracked_sensitive_files(tracked_paths),
            auditor.audit_repository_secret_policy(),
            GitSecretGate.candidate_control(assessments),
        ]

        gate = GitSecretGate.certify(
            controls=controls,
            assessments=assessments,
        )

        rotation_engine = RotationPolicyEngine(self.policy)
        rotation = [
            rotation_engine.plan(item).to_dict()
            for item in assessments
        ]

        storage = SecureStoragePlanner(self.policy).plan(
            preferred_backend=preferred_storage_backend
        )

        return {
            "component": "SPT-024.2",
            "status": (
                "SECURITY_GATE_PASS"
                if gate.passed
                else "SECURITY_GATE_HOLD"
            ),
            "assessments": [item.to_dict() for item in assessments],
            "security_gate": gate.to_dict(),
            "rotation_plan": rotation,
            "secure_storage_plan": storage.to_dict(),
            "secret_values_exposed": False,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "next_component": "SPT-024.3",
        }
