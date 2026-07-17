"""Diagnóstico del ecosistema avanzado de plantillas."""

from __future__ import annotations

from dataclasses import asdict, dataclass
import json
from pathlib import Path
from typing import Any

from sgoda import __version__

from .compatibility import CompatibilityError, requirement_satisfied
from .integrity import verify_integrity
from .registry import ExtensionRegistry
from .template_validator import TemplateValidationError, TemplateValidator


@dataclass(frozen=True, slots=True)
class TemplateDiagnostic:
    name: str
    enabled: bool
    compatibility: str
    validation: str
    integrity: str
    modified_files: tuple[str, ...] = ()
    missing_files: tuple[str, ...] = ()
    added_files: tuple[str, ...] = ()
    issues: tuple[str, ...] = ()

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["issues"] = list(self.issues)
        return payload


@dataclass(frozen=True, slots=True)
class TemplateDoctorReport:
    installed: int
    enabled: int
    disabled: int
    incompatible: int
    invalid: int
    integrity_failures: int
    diagnostics: tuple[TemplateDiagnostic, ...]
    status: str
    builder_version: str

    def to_dict(self) -> dict[str, Any]:
        return {
            **asdict(self),
            "diagnostics": [
                diagnostic.to_dict()
                for diagnostic in self.diagnostics
            ],
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), ensure_ascii=False, indent=2)

    def to_text(self) -> str:
        return "\n".join([
            "Template Ecosystem Doctor",
            "-" * 60,
            f"Plantillas instaladas: {self.installed}",
            f"Habilitadas: {self.enabled}",
            f"Deshabilitadas: {self.disabled}",
            f"Incompatibles: {self.incompatible}",
            f"Inválidas: {self.invalid}",
            f"Fallos de integridad: {self.integrity_failures}",
            "-" * 60,
            f"Estado: {self.status}",
        ])


class TemplateDoctor:
    def __init__(self, workspace: str | Path) -> None:
        root = Path(workspace).expanduser().resolve() / ".sgoda" / "extensions"
        self.registry = ExtensionRegistry(root)

    def run(self) -> TemplateDoctorReport:
        records = self.registry.list("template")
        diagnostics: list[TemplateDiagnostic] = []

        for record in records:
            issues: list[str] = []
            try:
                compatible = requirement_satisfied(
                    record.builder_requires,
                    __version__,
                )
            except CompatibilityError:
                compatible = False
            compatibility = "compatible" if compatible else "incompatible"
            if not compatible:
                issues.append("builder_incompatible")

            try:
                TemplateValidator().validate(
                    record.installed_path,
                    strict_variables=False,
                )
                validation = "valid"
            except TemplateValidationError as exc:
                validation = "invalid"
                issues.append(str(exc))

            integrity_result = verify_integrity(
                name=record.name,
                root=record.installed_path,
                expected_checksum=record.checksum,
                expected_manifest_hash=record.manifest_hash,
                expected_file_hashes=record.file_hashes,
            )
            if integrity_result.status == "ERROR":
                issues.append("integrity_failed")

            diagnostics.append(
                TemplateDiagnostic(
                    name=record.name,
                    enabled=record.enabled,
                    compatibility=compatibility,
                    validation=validation,
                    integrity=integrity_result.status,
                    modified_files=integrity_result.modified_files,
                    missing_files=integrity_result.missing_files,
                    added_files=integrity_result.added_files,
                    issues=tuple(issues),
                )
            )

        incompatible = sum(
            item.compatibility == "incompatible"
            for item in diagnostics
        )
        invalid = sum(item.validation == "invalid" for item in diagnostics)
        integrity_failures = sum(
            item.integrity == "ERROR"
            for item in diagnostics
        )
        status = (
            "ERROR"
            if incompatible or invalid or integrity_failures
            else "HEALTHY"
        )
        return TemplateDoctorReport(
            installed=len(records),
            enabled=sum(record.enabled for record in records),
            disabled=sum(not record.enabled for record in records),
            incompatible=incompatible,
            invalid=invalid,
            integrity_failures=integrity_failures,
            diagnostics=tuple(diagnostics),
            status=status,
            builder_version=__version__,
        )
