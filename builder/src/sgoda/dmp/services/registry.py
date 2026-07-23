"""Servicio funcional para registrar trabajo y evidencias del proyecto."""

from __future__ import annotations

from collections.abc import Callable

from sgoda.dmp.domain import DmpEntity, Evidence, EvidenceType, WorkStatus
from sgoda.dmp.events import DmpEvent
from sgoda.dmp.repositories import DmpRepository, InMemoryDmpRepository

EventHandler = Callable[[DmpEvent], None]


class DmpRegistryService:
    """Fachada de registro y actualización del repositorio documental."""

    def __init__(
        self,
        repository: DmpRepository | None = None,
        *,
        event_handler: EventHandler | None = None,
    ) -> None:
        self._repository = repository or InMemoryDmpRepository()
        self._event_handler = event_handler

    def register(self, record: DmpEntity) -> DmpEntity:
        if self._repository.get(record.identifier) is not None:
            raise ValueError(f"Ya existe un registro con ID {record.identifier}")
        saved = self._repository.save(record)
        self._emit("dmp.record.created", saved)
        return saved

    def update_status(self, identifier: str, status: WorkStatus) -> DmpEntity:
        record = self.require(identifier)
        updated = record.with_changes(status=status)
        self._repository.save(updated)
        self._emit(
            "dmp.record.status_changed",
            updated,
            extra={"previous_status": record.status.value},
        )
        return updated

    def attach_evidence(
        self,
        *,
        identifier: str,
        spb_id: str,
        name: str,
        evidence_type: EvidenceType,
        reference: str,
        checksum: str = "",
    ) -> Evidence:
        evidence = Evidence(
            identifier=identifier,
            name=name,
            status=WorkStatus.COMPLETED,
            spb_id=spb_id,
            evidence_type=evidence_type,
            reference=reference,
            checksum=checksum,
        )
        self.register(evidence)
        self._emit("dmp.evidence.attached", evidence)
        return evidence

    def get(self, identifier: str) -> DmpEntity | None:
        return self._repository.get(identifier)

    def require(self, identifier: str) -> DmpEntity:
        record = self.get(identifier)
        if record is None:
            raise KeyError(f"No existe el registro DMP {identifier}")
        return record

    def list(self, record_type: type[DmpEntity] | None = None) -> tuple[DmpEntity, ...]:
        return self._repository.list(record_type)

    def _emit(
        self,
        event_type: str,
        record: DmpEntity,
        *,
        extra: dict[str, object] | None = None,
    ) -> None:
        if self._event_handler is None:
            return
        payload = record.to_dict()
        payload.update(extra or {})
        self._event_handler(
            DmpEvent.create(
                event_type=event_type,
                aggregate_id=record.identifier,
                payload=payload,
            )
        )
