from __future__ import annotations

import json
import subprocess
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable


@dataclass(frozen=True)
class AdapterResult:
    component: str
    status: str
    payload: dict[str, Any]
    transport: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "component": self.component,
            "status": self.status,
            "payload": dict(self.payload),
            "transport": self.transport,
        }


class JsonHttpAdapter:
    """Adaptador HTTP JSON desacoplado para servicios locales/institucionales."""

    def __init__(
        self,
        *,
        component: str,
        endpoint: str,
        timeout_seconds: float = 10.0,
    ) -> None:
        self.component = str(component)
        self.endpoint = str(endpoint).strip()
        self.timeout_seconds = float(timeout_seconds)
        if not self.endpoint:
            raise ValueError("HTTP endpoint is required.")

    def invoke(
        self,
        payload: dict[str, Any],
        *,
        expected_status: str,
    ) -> AdapterResult:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(
            self.endpoint,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(
                request,
                timeout=self.timeout_seconds,
            ) as response:
                raw = response.read().decode("utf-8")
        except urllib.error.URLError as exc:
            raise RuntimeError(
                f"{self.component} HTTP adapter failed: {exc}"
            ) from exc

        data = json.loads(raw or "{}")
        status = str(data.get("status") or "")
        if status != expected_status:
            raise ValueError(
                f"{self.component} returned {status!r}; expected {expected_status!r}."
            )

        return AdapterResult(
            component=self.component,
            status=status,
            payload=data,
            transport="HTTP_JSON",
        )


class LocalJsonFileAdapter:
    """Adaptador institucional efectivo por archivo JSON atÃ³mico."""

    def __init__(
        self,
        *,
        component: str,
        path: str | Path,
        status_field: str = "status",
    ) -> None:
        self.component = str(component)
        self.path = Path(path)
        self.status_field = str(status_field)

    def invoke(
        self,
        payload: dict[str, Any],
        *,
        expected_status: str,
    ) -> AdapterResult:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temp = self.path.with_name(self.path.name + ".tmp")
        output = {
            "component": self.component,
            "status": expected_status,
            "input": dict(payload),
        }
        temp.write_text(
            json.dumps(output, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        temp.replace(self.path)

        data = json.loads(self.path.read_text(encoding="utf-8"))
        status = str(data.get(self.status_field) or "")
        if status != expected_status:
            raise ValueError(
                f"{self.component} file adapter status mismatch."
            )

        return AdapterResult(
            component=self.component,
            status=status,
            payload=data,
            transport="LOCAL_JSON_FILE",
        )


class LocalCommandAdapter:
    """Adaptador efectivo para herramientas institucionales ejecutables locales."""

    def __init__(
        self,
        *,
        component: str,
        command_factory: Callable[[dict[str, Any]], list[str]],
        timeout_seconds: float = 60.0,
    ) -> None:
        self.component = str(component)
        self.command_factory = command_factory
        self.timeout_seconds = float(timeout_seconds)

    def invoke(
        self,
        payload: dict[str, Any],
        *,
        expected_status: str,
    ) -> AdapterResult:
        command = self.command_factory(dict(payload))
        if not command:
            raise ValueError("Local command adapter produced an empty command.")

        completed = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=self.timeout_seconds,
        )
        if completed.returncode != 0:
            raise RuntimeError(
                f"{self.component} command failed: "
                + (completed.stderr or completed.stdout or "").strip()
            )

        data = json.loads((completed.stdout or "{}").strip() or "{}")
        status = str(data.get("status") or "")
        if status != expected_status:
            raise ValueError(
                f"{self.component} returned {status!r}; expected {expected_status!r}."
            )

        return AdapterResult(
            component=self.component,
            status=status,
            payload=data,
            transport="LOCAL_COMMAND",
        )
