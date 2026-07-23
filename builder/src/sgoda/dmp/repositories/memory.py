"""Repositorio DMP en memoria para pruebas e integración inicial."""

from __future__ import annotations

from threading import RLock
from typing import TypeVar

from sgoda.dmp.domain import DmpEntity, normalize_identifier

T = TypeVar("T", bound=DmpEntity)


class InMemoryDmpRepository:
    def __init__(self) -> None:
        self._records: dict[str, DmpEntity] = {}
        self._lock = RLock()

    def save(self, record: T) -> T:
        with self._lock:
            self._records[record.identifier] = record
        return record

    def get(self, identifier: str) -> DmpEntity | None:
        with self._lock:
            return self._records.get(normalize_identifier(identifier))

    def list(self, record_type: type[T] | None = None) -> tuple[DmpEntity, ...]:
        with self._lock:
            records = tuple(self._records.values())
        if record_type is None:
            return records
        return tuple(record for record in records if isinstance(record, record_type))

    def delete(self, identifier: str) -> bool:
        with self._lock:
            return self._records.pop(normalize_identifier(identifier), None) is not None
