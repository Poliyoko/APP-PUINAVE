"""Servicio operativo de SPT-011."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .database import OperationalRepository
from .flutter_contracts import lexical_card
from .media_adapter import load_media_manifest
from .models import (
    OperationalRequest,
    OperationalResponse,
    RuntimeStatus,
)
from .n8n_contracts import lexical_entry_event
from .rlb_adapter import load_rlb
from .settings import OperationalSettings


class OperationalPlatformService:
    def __init__(
        self,
        settings: OperationalSettings,
        repository: OperationalRepository | None = None,
    ) -> None:
        self.settings = settings
        self.repository = repository or OperationalRepository()
        self._rlb_loaded = False
        self._media_loaded = False

    def load_sources(
        self,
        rlb_path: str | Path,
        media_path: str | Path | None = None,
    ) -> RuntimeStatus:
        entries = load_rlb(
            rlb_path,
            validated_only=self.settings.require_validated_entries,
        )
        self.repository.upsert_entries(entries)
        self._rlb_loaded = True

        if media_path:
            for media in load_media_manifest(media_path):
                if (
                    self.settings.require_validated_entries
                    and not media.get("validated", False)
                ):
                    continue

                entry_id = media["entry_id"]

                if self.repository.get_entry(entry_id) is None:
                    continue

                self.repository.attach_media(
                    entry_id,
                    media,
                )

            self._media_loaded = True

        return self.runtime_status()

    def runtime_status(self) -> RuntimeStatus:
        return RuntimeStatus(
            database_mode=self.settings.database_mode,
            rlb_loaded=self._rlb_loaded,
            media_loaded=self._media_loaded,
            n8n_enabled=self.settings.n8n_enabled,
            flutter_contract_enabled=(
                self.settings.flutter_contract_enabled
            ),
            api_enabled=True,
        )

    def execute(
        self,
        request: OperationalRequest,
    ) -> OperationalResponse:
        handlers = {
            "health": self._health,
            "get_lexical_card": self._get_lexical_card,
            "list_entries": self._list_entries,
            "n8n_event": self._n8n_event,
        }

        handler = handlers.get(request.operation)

        if handler is None:
            return OperationalResponse(
                operation=request.operation,
                status="unsupported_operation",
                data={},
                warnings=(
                    "La operación no está soportada.",
                ),
            )

        return handler(request)

    def _health(
        self,
        request: OperationalRequest,
    ) -> OperationalResponse:
        status = self.runtime_status()

        healthy = (
            status.rlb_loaded
            and status.flutter_contract_enabled
            and status.api_enabled
        )

        return OperationalResponse(
            operation="health",
            status="ok" if healthy else "degraded",
            data={
                "healthy": healthy,
                "database_mode": status.database_mode,
                "rlb_loaded": status.rlb_loaded,
                "media_loaded": status.media_loaded,
                "n8n_enabled": status.n8n_enabled,
                "flutter_contract_enabled": (
                    status.flutter_contract_enabled
                ),
                "api_enabled": status.api_enabled,
                "entry_count": self.repository.count(),
            },
        )

    def _get_lexical_card(
        self,
        request: OperationalRequest,
    ) -> OperationalResponse:
        entry_id = (
            request.entry_id
            or str(request.payload.get("entry_id") or "")
        )

        entry = self.repository.get_entry(entry_id)

        if entry is None:
            return OperationalResponse(
                operation="get_lexical_card",
                status="not_found",
                data={},
            )

        card = lexical_card(
            entry,
            self.repository.media_for(entry_id),
        )

        return OperationalResponse(
            operation="get_lexical_card",
            status="ok",
            data=card,
            sources=(f"RLB:{entry_id}",),
        )

    def _list_entries(
        self,
        request: OperationalRequest,
    ) -> OperationalResponse:
        entries = self.repository.all_entries()

        return OperationalResponse(
            operation="list_entries",
            status="ok",
            data={
                "total": len(entries),
                "entries": list(entries),
            },
            sources=tuple(
                f"RLB:{item['entry_id']}"
                for item in entries
            ),
        )

    def _n8n_event(
        self,
        request: OperationalRequest,
    ) -> OperationalResponse:
        entry_id = (
            request.entry_id
            or str(request.payload.get("entry_id") or "")
        )
        operation = str(
            request.payload.get("event_operation") or ""
        )

        event = lexical_entry_event(
            entry_id,
            operation,
        )

        return OperationalResponse(
            operation="n8n_event",
            status="ok",
            data={
                "event_type": event.event_type,
                "payload": event.payload,
                "idempotency_key": event.idempotency_key,
                "delivery_enabled": self.settings.n8n_enabled,
            },
            sources=(f"RLB:{entry_id}",),
        )