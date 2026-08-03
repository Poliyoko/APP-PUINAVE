"""Servicio principal del gestor institucional del diccionario."""

from __future__ import annotations

from typing import Any

from .import_export import (
    entry_from_dict,
    entry_to_dict,
    export_entries,
    load_entries,
)
from .models import DictionaryCommand, DictionaryResult
from .repository import DictionaryRepository
from .validation import validate_entry_payload


class InstitutionalDictionaryManager:
    def __init__(
        self,
        repository: DictionaryRepository | None = None,
    ) -> None:
        self.repository = repository or DictionaryRepository()

    def execute(
        self,
        command: DictionaryCommand,
    ) -> DictionaryResult:
        handlers = {
            "create": self._create,
            "upsert": self._upsert,
            "get": self._get,
            "search": self._search,
            "list": self._list,
            "import_json": self._import_json,
            "export_json": self._export_json,
            "stats": self._stats,
        }

        handler = handlers.get(command.operation)

        if handler is None:
            return DictionaryResult(
                operation=command.operation,
                status="unsupported_operation",
                data={},
                warnings=("La operación no está soportada.",),
            )

        return handler(command.payload)

    def _create(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        errors = validate_entry_payload(payload)

        if errors:
            return DictionaryResult(
                operation="create",
                status="invalid_entry",
                data={"errors": list(errors)},
                warnings=errors,
            )

        entry = entry_from_dict(payload)

        try:
            self.repository.add(entry)
        except ValueError as error:
            return DictionaryResult(
                operation="create",
                status="duplicate",
                data={"entry_id": entry.entry_id},
                warnings=(str(error),),
            )

        return DictionaryResult(
            operation="create",
            status="ok",
            data=entry_to_dict(entry),
        )

    def _upsert(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        errors = validate_entry_payload(payload)

        if errors:
            return DictionaryResult(
                operation="upsert",
                status="invalid_entry",
                data={"errors": list(errors)},
                warnings=errors,
            )

        entry = self.repository.upsert(
            entry_from_dict(payload)
        )

        return DictionaryResult(
            operation="upsert",
            status="ok",
            data=entry_to_dict(entry),
        )

    def _get(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        entry_id = str(payload.get("entry_id") or "").strip()
        entry = self.repository.get(entry_id)

        if entry is None:
            return DictionaryResult(
                operation="get",
                status="not_found",
                data={"entry_id": entry_id},
            )

        return DictionaryResult(
            operation="get",
            status="ok",
            data=entry_to_dict(entry),
        )

    def _search(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        query = str(payload.get("query") or "")
        results = self.repository.search(query)

        return DictionaryResult(
            operation="search",
            status="ok",
            data={
                "query": query,
                "total": len(results),
                "results": [
                    entry_to_dict(item)
                    for item in results
                ],
            },
        )

    def _list(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        entries = self.repository.all()

        return DictionaryResult(
            operation="list",
            status="ok",
            data={
                "total": len(entries),
                "entries": [
                    entry_to_dict(item)
                    for item in entries
                ],
            },
        )

    def _import_json(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        path = str(payload.get("path") or "").strip()
        imported = 0
        rejected = []

        for entry in load_entries(path):
            raw = entry_to_dict(entry)
            errors = validate_entry_payload(raw)

            if errors:
                rejected.append(
                    {
                        "entry_id": entry.entry_id,
                        "errors": list(errors),
                    }
                )
                continue

            self.repository.upsert(entry)
            imported += 1

        return DictionaryResult(
            operation="import_json",
            status="ok",
            data={
                "imported": imported,
                "rejected": rejected,
            },
        )

    def _export_json(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        path = str(payload.get("path") or "").strip()
        export_entries(path, self.repository.all())

        return DictionaryResult(
            operation="export_json",
            status="ok",
            data={
                "path": path,
                "total": len(self.repository.all()),
            },
        )

    def _stats(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        entries = self.repository.all()

        return DictionaryResult(
            operation="stats",
            status="ok",
            data={
                "total": len(entries),
                "validated": sum(
                    1 for item in entries if item.validated
                ),
                "pending_validation": sum(
                    1 for item in entries if not item.validated
                ),
                "with_variants": sum(
                    1
                    for item in entries
                    if item.dialectal_variants
                ),
                "with_examples": sum(
                    1 for item in entries if item.examples
                ),
            },
        )