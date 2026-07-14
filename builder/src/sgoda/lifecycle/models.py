"""Modelos del ciclo de vida SGODA."""

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True, slots=True)
class MigrationStep:
    """Paso individual de migración."""

    source: str
    target: str
    description: str


@dataclass(frozen=True, slots=True)
class MigrationReport:
    """Resultado de una migración."""

    workspace: Path
    source_version: str
    target_version: str
    changed: bool
    dry_run: bool
    backup_path: Path | None
    steps: tuple[MigrationStep, ...]

    @property
    def status(self) -> str:
        return "UP_TO_DATE" if not self.changed else (
            "PLANNED" if self.dry_run else "MIGRATED"
        )

    def to_dict(self) -> dict[str, object]:
        return {
            "workspace": str(self.workspace),
            "source_version": self.source_version,
            "target_version": self.target_version,
            "status": self.status,
            "changed": self.changed,
            "dry_run": self.dry_run,
            "backup_path": str(self.backup_path) if self.backup_path else None,
            "steps": [
                {
                    "source": step.source,
                    "target": step.target,
                    "description": step.description,
                }
                for step in self.steps
            ],
        }

    def to_text(self) -> str:
        lines = [
            "Migración SGODA",
            f"Proyecto: {self.workspace}",
            f"Origen: {self.source_version}",
            f"Destino: {self.target_version}",
            f"Estado: {self.status}",
        ]
        if self.backup_path:
            lines.append(f"Respaldo: {self.backup_path}")
        if self.steps:
            lines.append("Pasos:")
            for step in self.steps:
                lines.append(
                    f"- {step.source} -> {step.target}: {step.description}"
                )
        else:
            lines.append("No se requieren cambios.")
        return "\n".join(lines)
