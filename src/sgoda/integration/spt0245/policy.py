from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class AutomationSecurityPolicy:
    require_credentials_indirection: bool
    require_webhook_authentication: bool
    forbid_plaintext_credentials: bool
    forbid_unrestricted_execute_command: bool
    require_workflow_integrity_hash: bool
    require_audit_traceability: bool
    require_disabled_by_default_for_untrusted_workflows: bool
    require_local_or_approved_free_runtime: bool
    paid_api_allowed: bool

    @classmethod
    def default(cls) -> "AutomationSecurityPolicy":
        return cls(
            require_credentials_indirection=True,
            require_webhook_authentication=True,
            forbid_plaintext_credentials=True,
            forbid_unrestricted_execute_command=True,
            require_workflow_integrity_hash=True,
            require_audit_traceability=True,
            require_disabled_by_default_for_untrusted_workflows=True,
            require_local_or_approved_free_runtime=True,
            paid_api_allowed=False,
        )

    @classmethod
    def from_json(cls, path: str | Path) -> "AutomationSecurityPolicy":
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        default = cls.default()
        return cls(
            **{
                field_name: bool(
                    data.get(field_name, getattr(default, field_name))
                )
                for field_name in cls.__dataclass_fields__
            }
        )
