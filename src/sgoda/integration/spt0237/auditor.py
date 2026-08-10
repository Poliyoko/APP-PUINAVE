from __future__ import annotations

import re
from pathlib import Path

from .models import AuditFinding, AuditReport
from .rules import AuditPolicy
from .scanner import TransversalScanner


class IntelligentAuditor:
    """Deterministic, read-only transversal audit engine."""

    VALID_NAME = re.compile(r"^[A-Za-z0-9_.\-/]+$")

    def __init__(self, root: str | Path, policy: AuditPolicy | None = None):
        self.root = Path(root)
        self.policy = policy or AuditPolicy.default()
        self.scanner = TransversalScanner(self.root)

    def run(self) -> AuditReport:
        report = AuditReport(scope=self.policy.scope)
        inventory = self.scanner.inventory(self.policy.scope)

        self._integrity(report, inventory)
        self._missing(report, inventory)
        self._consistency(report, inventory)
        self._nomenclature(report, inventory)
        self._traceability(report, inventory)
        self._quality(report, inventory)
        self._institutional(report, inventory)

        report.metrics.update({
            "components_scanned": len(inventory),
            "files_scanned": sum(len(v) for v in inventory.values()),
            "dimensions": len(self.policy.dimensions),
            "blocking_findings": len(report.blocking_findings),
        })
        return report

    def _add(self, report, dimension, code, severity, message, subject="", **evidence):
        report.findings.append(
            AuditFinding(dimension, code, severity, message, subject, evidence)
        )

    def _integrity(self, report, inventory):
        if "integrity" not in self.policy.dimensions:
            return
        for component, files in inventory.items():
            for path in files:
                try:
                    size = path.stat().st_size
                    digest = self.scanner.sha256(path) if self.policy.require_sha256 else ""
                    if size == 0:
                        self._add(report, "integrity", "EMPTY_FILE", "ERROR",
                                  "Tracked component resource is empty.",
                                  str(path.relative_to(self.root)))
                    if self.policy.require_sha256 and len(digest) != 64:
                        self._add(report, "integrity", "SHA256_INVALID", "ERROR",
                                  "SHA-256 could not be established.",
                                  str(path.relative_to(self.root)))
                except OSError as exc:
                    self._add(report, "integrity", "UNREADABLE", "ERROR",
                              "Resource cannot be read.",
                              str(path.relative_to(self.root)), error=str(exc))

    def _missing(self, report, inventory):
        if "missing_resources" not in self.policy.dimensions:
            return
        for component, files in inventory.items():
            if len(files) < self.policy.required_files_per_component:
                self._add(report, "missing_resources", "COMPONENT_RESOURCE_MISSING",
                          "ERROR", "No auditable resources were found.", component)

    def _consistency(self, report, inventory):
        if "consistency" not in self.policy.dimensions:
            return
        for component, files in inventory.items():
            if not files:
                continue
            suffixes = {p.suffix.lower() for p in files}
            if self.policy.require_tests and ".py" not in suffixes:
                self._add(report, "consistency", "PYTHON_FOOTPRINT_NOT_FOUND", "WARNING",
                          "No Python footprint detected for component.", component)

    def _nomenclature(self, report, inventory):
        if "nomenclature" not in self.policy.dimensions:
            return
        for files in inventory.values():
            for path in files:
                rel = str(path.relative_to(self.root)).replace("\\", "/")
                if not self.VALID_NAME.match(rel):
                    self._add(report, "nomenclature", "NON_STANDARD_PATH", "WARNING",
                              "Path contains characters outside institutional portable set.", rel)

    def _traceability(self, report, inventory):
        if "traceability" not in self.policy.dimensions:
            return
        for component, files in inventory.items():
            evidence = [
                p for p in files
                if "artifact" in str(p).lower() or "evidence" in p.name.lower()
            ]
            docs = [
                p for p in files
                if p.suffix.lower() == ".md" or "docs" in [part.lower() for part in p.parts]
            ]
            if not evidence:
                self._add(report, "traceability", "EVIDENCE_NOT_DISCOVERED", "WARNING",
                          "Evidence was not discovered by the transversal scanner.", component)
            if self.policy.require_documentation and not docs:
                self._add(report, "traceability", "DOCUMENTATION_NOT_DISCOVERED", "WARNING",
                          "Documentation was not discovered by the transversal scanner.", component)

    def _quality(self, report, inventory):
        if "quality" not in self.policy.dimensions:
            return
        for component, files in inventory.items():
            tests = [p for p in files if "test" in p.name.lower() and p.suffix.lower() == ".py"]
            if self.policy.require_tests and not tests:
                self._add(report, "quality", "TEST_RESOURCE_NOT_DISCOVERED", "WARNING",
                          "No component test resource was discovered.", component)

    def _institutional(self, report, inventory):
        if "institutional_conformity" not in self.policy.dimensions:
            return
        expected = set(self.policy.scope)
        present = {component for component, files in inventory.items() if files}
        missing = sorted(expected - present)
        for component in missing:
            self._add(report, "institutional_conformity", "SCOPE_GAP", "ERROR",
                      "Required closed component is absent from audit inventory.", component)
