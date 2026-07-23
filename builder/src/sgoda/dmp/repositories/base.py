"""Contrato de persistencia para registros DMP."""

from __future__ import annotations

from typing import Protocol, TypeVar

from sgoda.dmp.domain import DmpEntity

T = TypeVar("T", bound=DmpEntity)


class DmpRepository(Protocol):
    def save(self, record: T) -> T: ...

    def get(self, identifier: str) -> DmpEntity | None: ...

    def list(self, record_type: type[T] | None = None) -> tuple[DmpEntity, ...]: ...

    def delete(self, identifier: str) -> bool: ...
