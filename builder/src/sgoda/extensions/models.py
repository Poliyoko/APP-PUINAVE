"""Modelos comunes para plugins y plantillas externas."""

from dataclasses import asdict, dataclass, field, replace
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Literal

ExtensionType = Literal["plugin", "template"]


@dataclass(frozen=True, slots=True)
class ExtensionManifest:
    schema_version: str
    type: ExtensionType
    name: str
    version: str
    builder_requires: str
    description: str = ""
    entry_point: str | None = None
    files: tuple[str, ...] = ()
    dependencies: dict[str, str] = field(default_factory=dict)

    @property
    def key(self) -> str:
        return f"{self.type}:{self.name}"

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["files"] = list(self.files)
        payload["dependencies"] = dict(self.dependencies)
        return payload


@dataclass(frozen=True, slots=True)
class ExtensionRecord:
    type: ExtensionType
    name: str
    version: str
    installed_path: str
    installed_at: str
    description: str = ""
    enabled: bool = True
    status: str = "compatible"
    builder_requires: str = ""
    dependencies: dict[str, str] = field(default_factory=dict)

    @classmethod
    def create(
        cls,
        manifest: ExtensionManifest,
        installed_path: Path,
    ) -> "ExtensionRecord":
        return cls(
            type=manifest.type,
            name=manifest.name,
            version=manifest.version,
            installed_path=str(installed_path),
            installed_at=datetime.now(UTC).isoformat(),
            description=manifest.description,
            enabled=True,
            status="compatible",
            builder_requires=manifest.builder_requires,
            dependencies=dict(manifest.dependencies),
        )

    @property
    def key(self) -> str:
        return f"{self.type}:{self.name}"

    def with_state(self, *, enabled: bool, status: str) -> "ExtensionRecord":
        return replace(self, enabled=enabled, status=status)

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["dependencies"] = dict(self.dependencies)
        return payload
