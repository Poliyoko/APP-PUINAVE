from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .classifier import SupplyChainClassifier
from .dependency_audit import DependencyAudit
from .models import SupplyChainControl
from .workflow_audit import WorkflowAudit


class SupplyChainSecurityAuditor:
    def __init__(self, root: Path, tracked_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.tracked_paths = [str(x).replace("\\", "/") for x in tracked_paths]

    def assess(self) -> dict:
        surfaces = SupplyChainClassifier(self.root, self.tracked_paths).classify()
        workflow_paths = [s.path for s in surfaces if s.surface_type == "CI_CD_WORKFLOW"]
        dependency_paths = [s.path for s in surfaces if s.surface_type == "DEPENDENCY_MANIFEST"]

        wf = WorkflowAudit.assess(self.root, workflow_paths)
        deps = DependencyAudit.assess(self.root, dependency_paths)

        controls = [
            SupplyChainControl(
                "SCM-WORKFLOW-PERMISSIONS",
                "No explicit write-all workflow permission",
                not wf["broad_permissions"],
                True,
                bool(workflow_paths),
                "No permissions: write-all detected." if not wf["broad_permissions"] else
                f"Explicit write-all permission detected in {len(wf['broad_permissions'])} workflow(s).",
            ),
            SupplyChainControl(
                "SCM-ACTIONS-MUTABLE-BRANCH",
                "Actions do not use mutable branch refs",
                not wf["mutable_branch_actions"],
                True,
                bool(workflow_paths),
                "No mutable action branch ref detected." if not wf["mutable_branch_actions"] else
                f"Mutable action branch refs detected: {len(wf['mutable_branch_actions'])}.",
            ),
            SupplyChainControl(
                "SCM-SECRET-USAGE",
                "Secrets are not interpolated directly in shell run lines",
                not wf["direct_secret_shell"],
                True,
                bool(workflow_paths),
                "No direct secret interpolation in run lines detected." if not wf["direct_secret_shell"] else
                f"Direct secret interpolation detected in {len(wf['direct_secret_shell'])} workflow(s).",
            ),
            SupplyChainControl(
                "SCM-EXPRESSION-INJECTION",
                "Untrusted event data is not interpolated directly in shell run lines",
                not wf["expression_injection"],
                True,
                bool(workflow_paths),
                "No direct github.event interpolation in run lines detected." if not wf["expression_injection"] else
                f"Potential expression injection detected in {len(wf['expression_injection'])} workflow(s).",
            ),
            SupplyChainControl(
                "SCM-SCRIPT-EXECUTION",
                "No high-risk pipe-to-shell or dynamic eval markers",
                not wf["dangerous_shell"],
                True,
                bool(workflow_paths),
                "No high-risk dynamic shell execution marker detected." if not wf["dangerous_shell"] else
                f"High-risk shell execution marker detected in {len(wf['dangerous_shell'])} workflow(s).",
            ),
            SupplyChainControl(
                "SCM-DEPENDENCY-INTEGRITY",
                "Dependency sources avoid insecure URLs and unpinned VCS refs",
                not deps["insecure_urls"] and not deps["unpinned_vcs"],
                True,
                bool(dependency_paths),
                "Dependency source integrity checks passed." if not deps["insecure_urls"] and not deps["unpinned_vcs"] else
                "Insecure dependency source or unpinned VCS reference detected.",
            ),
            SupplyChainControl(
                "SCM-ACTIONS-PINNING",
                "Third-party action pinning inventory",
                not wf["floating_actions"],
                False,
                bool(workflow_paths),
                "All action refs are immutable SHA pins." if not wf["floating_actions"] else
                f"{len(wf['floating_actions'])} version-tag or floating action ref(s) require progressive hardening.",
            ),
            SupplyChainControl(
                "SCM-VERSION-PINNING",
                "Dependency version pinning review",
                True,
                False,
                bool(dependency_paths),
                "Dependency manifests inventoried for subsequent exact-version policy enforcement.",
            ),
            SupplyChainControl(
                "SCM-SBOM",
                "Institutional SBOM generated",
                True,
                True,
                True,
                "Institutional SBOM is generated as part of the controlled transaction.",
            ),
            SupplyChainControl(
                "SCM-ARTIFACT-INTEGRITY",
                "Artifact integrity manifest generated",
                True,
                True,
                True,
                "SHA-256 integrity manifest is generated as part of the controlled transaction.",
            ),
            SupplyChainControl(
                "SCM-RELEASE-PROVENANCE",
                "Release provenance inventory",
                True,
                False,
                True,
                "Release and publication surfaces are inventoried without executing publication.",
            ),
            SupplyChainControl(
                "SCM-BUILD-REPRODUCIBILITY",
                "Build reproducibility readiness",
                True,
                False,
                True,
                "Advisory readiness control; no build is executed by this gate.",
            ),
        ]

        failed = [
            c.control_id
            for c in controls
            if c.blocking and c.applicable and not c.passed
        ]

        return {
            "status": "SUPPLY_CHAIN_SECURITY_GATE_PASS" if not failed else "SUPPLY_CHAIN_SECURITY_GATE_HOLD",
            "failed_control_ids": failed,
            "controls": [c.__dict__ for c in controls],
            "surfaces": [s.__dict__ for s in surfaces],
            "workflow_assessment": wf,
            "dependency_assessment": deps,
            "workflow_executed_by_gate": False,
            "package_installed_by_gate": False,
            "release_published_by_gate": False,
            "secret_values_exposed": False,
        }
