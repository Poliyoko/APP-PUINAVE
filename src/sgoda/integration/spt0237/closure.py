from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


@dataclass(frozen=True)
class ClosureManifest:
    component: str
    status: str
    quality_gates_passed: bool
    governance_passed: bool
    layer1_preserved: bool
    layer2_preserved: bool
    closed_components_preserved: bool
    next_component: str
    manifest_sha256: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "component": self.component,
            "status": self.status,
            "quality_gates_passed": self.quality_gates_passed,
            "governance_passed": self.governance_passed,
            "layer1_preserved": self.layer1_preserved,
            "layer2_preserved": self.layer2_preserved,
            "closed_components_preserved": self.closed_components_preserved,
            "next_component": self.next_component,
            "manifest_sha256": self.manifest_sha256,
        }


class Spt0237ClosureManifestBuilder:
    @staticmethod
    def build(
        *,
        quality_gates_passed: bool,
        governance_passed: bool,
        protected_changes: int,
    ) -> ClosureManifest:
        if not quality_gates_passed:
            raise ValueError("Quality gates must pass before SPT-023.7 closure.")
        if not governance_passed:
            raise ValueError("Governance must pass before SPT-023.7 closure.")
        if protected_changes != 0:
            raise ValueError("Protected components changed; closure forbidden.")

        body = {
            "component": "SPT-023.7",
            "status": "INSTITUTIONALLY_CLOSED",
            "quality_gates_passed": True,
            "governance_passed": True,
            "layer1_preserved": True,
            "layer2_preserved": True,
            "closed_components_preserved": True,
            "next_component": "SPT-023.8",
        }
        sha = hashlib.sha256(_canonical(body)).hexdigest().upper()
        return ClosureManifest(
            component=body["component"],
            status=body["status"],
            quality_gates_passed=True,
            governance_passed=True,
            layer1_preserved=True,
            layer2_preserved=True,
            closed_components_preserved=True,
            next_component="SPT-023.8",
            manifest_sha256=sha,
        )
