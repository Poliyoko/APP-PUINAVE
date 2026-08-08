"""Core institucional SPT-022.

El nucleo no reemplaza motores existentes. Los registra, gobierna y coordina.
"""

from __future__ import annotations

from dataclasses import dataclass, asdict
from enum import Enum
from pathlib import Path
from typing import Dict, Iterable, List, Optional


class OperationStatus(str, Enum):
    READY = "READY"
    REQUIRES_INPUT = "REQUIRES_INPUT"
    REQUIRES_APPROVAL = "REQUIRES_APPROVAL"
    UNAVAILABLE = "UNAVAILABLE"


@dataclass(frozen=True)
class OperationDefinition:
    operation_id: str
    purpose: str
    status: OperationStatus
    source_component: str
    executable: Optional[str] = None
    approval_required: bool = False

    def to_dict(self) -> dict:
        data = asdict(self)
        data["status"] = self.status.value
        return data


class AutomationPlatform:
    """Catalogo y gobierno de operaciones institucionales."""

    def __init__(self, project_root: Path) -> None:
        self.project_root = Path(project_root).resolve()
        self._operations: Dict[str, OperationDefinition] = {}
        self._register_defaults()

    def _register_defaults(self) -> None:
        self.register(
            OperationDefinition(
                operation_id="data-intake",
                purpose="Procesar el Repositorio Lexico Base desde Excel.",
                status=OperationStatus.REQUIRES_INPUT,
                source_component="SPT-001B / RLB",
                executable="python -m sgoda.rlb.cli",
            )
        )
        self.register(
            OperationDefinition(
                operation_id="master-book-update",
                purpose="Actualizar automaticamente SGD-002.",
                status=OperationStatus.READY,
                source_component="SPT-021.3",
                executable=(
                    "tools/institutional/Invoke-SGD002-AutoUpdate.ps1"
                ),
            )
        )
        self.register(
            OperationDefinition(
                operation_id="repository-prepare",
                purpose="Preparar publicacion con Libro Maestro actualizado.",
                status=OperationStatus.READY,
                source_component="SPT-021.0.1 v1.0.8",
                executable=(
                    "tools/institutional/Publish-SGODA-WithMasterBook.ps1"
                ),
            )
        )
        self.register(
            OperationDefinition(
                operation_id="repository-publish",
                purpose="Publicar entregables al repositorio oficial.",
                status=OperationStatus.REQUIRES_APPROVAL,
                source_component="SPT-021.0.1 v1.0.8",
                executable=(
                    "tools/institutional/Publish-SGODA-WithMasterBook.ps1"
                ),
                approval_required=True,
            )
        )
        self.register(
            OperationDefinition(
                operation_id="repository-audit",
                purpose="Ejecutar auditoria institucional del repositorio.",
                status=OperationStatus.READY,
                source_component="SPB-003.2 / PMO Auditor",
                executable="scripts/Invoke-SPB0032-ModularAudit.ps1",
            )
        )

    def register(self, definition: OperationDefinition) -> None:
        self._operations[definition.operation_id] = definition

    def get(self, operation_id: str) -> OperationDefinition:
        return self._operations[operation_id]

    def list(self) -> List[OperationDefinition]:
        return list(self._operations.values())

    def as_dicts(self) -> List[dict]:
        return [item.to_dict() for item in self.list()]

    def validate_paths(self) -> Dict[str, bool]:
        result: Dict[str, bool] = {}
        for item in self.list():
            if not item.executable:
                result[item.operation_id] = True
                continue
            if item.executable.startswith("python "):
                result[item.operation_id] = (
                    self.project_root / "src" / "sgoda" / "rlb" / "cli.py"
                ).exists()
                continue
            result[item.operation_id] = (
                self.project_root / item.executable
            ).exists()
        return result

    def workflow_ids(self) -> Iterable[str]:
        return tuple(self._operations.keys())