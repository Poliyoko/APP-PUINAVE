from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .deps import audit_dependencies
from .hardening import audit_workflows
from .models import Control
from .vulnerability import run_optional_pip_audit


class SupplyChainLayer2Auditor:
    def __init__(self, root: Path, workflow_paths: Iterable[str], dependency_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.workflow_paths = list(workflow_paths)
        self.dependency_paths = list(dependency_paths)

    def assess(self) -> dict:
        hardening = audit_workflows(self.root, self.workflow_paths)
        deps = audit_dependencies(self.root, self.dependency_paths)
        vuln = run_optional_pip_audit(self.root)

        controls = [
            Control(
                "SC2-ACTIONS-MUTABLE",
                "No mutable action references",
                not hardening["mutable_action_refs"],
                True,
                bool(self.workflow_paths),
                "No mutable action refs." if not hardening["mutable_action_refs"] else
                f"Mutable action refs detected: {len(hardening['mutable_action_refs'])}.",
            ),
            Control(
                "SC2-WRITE-ALL",
                "No permissions write-all",
                not hardening["write_all_permissions"],
                True,
                bool(self.workflow_paths),
                "No write-all workflow permissions." if not hardening["write_all_permissions"] else
                f"write-all detected in {len(hardening['write_all_permissions'])} workflow(s).",
            ),
            Control(
                "SC2-DANGEROUS-RUN",
                "No dangerous dynamic shell execution",
                not hardening["dangerous_run_markers"],
                True,
                bool(self.workflow_paths),
                "No dangerous run marker." if not hardening["dangerous_run_markers"] else
                f"Dangerous run markers detected: {len(hardening['dangerous_run_markers'])}.",
            ),
            Control(
                "SC2-DEPENDENCY-SOURCE",
                "Secure dependency sources",
                not deps["insecure_sources"] and not deps["unpinned_vcs"],
                True,
                bool(self.dependency_paths),
                "Dependency source integrity passed." if not deps["insecure_sources"] and not deps["unpinned_vcs"] else
                "Insecure dependency source or unpinned VCS reference detected.",
            ),
            Control(
                "SC2-LOCKFILE",
                "Lockfile governance",
                not deps["missing_lock_companion"],
                True,
                bool(self.dependency_paths),
                "Lockfile companion policy passed." if not deps["missing_lock_companion"] else
                f"Missing lockfile companion for {len(deps['missing_lock_companion'])} manifest(s).",
            ),
            Control(
                "SC2-VULNERABILITY",
                "Known vulnerability gate",
                vuln.get("blocking_vulnerabilities", 0) == 0,
                True,
                bool(vuln.get("executed", False)),
                "No vulnerabilities detected by available auditor." if vuln.get("executed", False) and vuln.get("blocking_vulnerabilities", 0) == 0 else
                ("Vulnerability auditor unavailable; control non-applicable." if not vuln.get("executed", False) else
                 f"Known vulnerabilities detected: {vuln.get('blocking_vulnerabilities', 0)}."),
            ),
            Control(
                "SC2-ACTIONS-SHA",
                "Third-party actions immutable SHA hardening",
                not hardening["unpinned_action_refs"],
                False,
                bool(self.workflow_paths),
                "All action refs immutable SHA pins." if not hardening["unpinned_action_refs"] else
                f"{len(hardening['unpinned_action_refs'])} non-SHA action ref(s) remain as hardening advisory.",
            ),
        ]

        failed = [
            c.control_id for c in controls
            if c.blocking and c.applicable and not c.passed
        ]

        return {
            "status": "SUPPLY_CHAIN_LAYER2_GATE_PASS" if not failed else "SUPPLY_CHAIN_LAYER2_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [c.__dict__ for c in controls],
            "hardening": hardening,
            "dependencies": deps,
            "vulnerability": vuln,
            "workflow_executed": False,
            "package_installed": False,
            "release_published": False,
            "secret_values_exposed": False,
        }
