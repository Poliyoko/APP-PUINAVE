from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Dict, Tuple


class ServiceStatus(str, Enum):
    AVAILABLE = "AVAILABLE"
    DEGRADED = "DEGRADED"
    UNAVAILABLE = "UNAVAILABLE"
    RETIRED = "RETIRED"


@dataclass(frozen=True)
class ServiceEndpoint:
    protocol: str
    address: str

    def __post_init__(self) -> None:
        if not self.protocol or not self.protocol.strip():
            raise ValueError("protocol is required")
        if not self.address or not self.address.strip():
            raise ValueError("address is required")


@dataclass(frozen=True)
class ServiceDefinition:
    service_id: str
    name: str
    version: str
    capabilities: Tuple[str, ...]
    endpoints: Tuple[ServiceEndpoint, ...]
    metadata: Dict[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.service_id or not self.service_id.strip():
            raise ValueError("service_id is required")
        if not self.name or not self.name.strip():
            raise ValueError("name is required")
        if not self.version or not self.version.strip():
            raise ValueError("version is required")
        if not self.endpoints:
            raise ValueError("at least one endpoint is required")

        object.__setattr__(self, "service_id", self.service_id.strip())
        object.__setattr__(self, "name", self.name.strip())
        object.__setattr__(
            self,
            "capabilities",
            tuple(sorted(set(self.capabilities))),
        )
        object.__setattr__(self, "endpoints", tuple(self.endpoints))
        object.__setattr__(self, "metadata", dict(self.metadata))


@dataclass
class ServiceRecord:
    definition: ServiceDefinition
    status: ServiceStatus = ServiceStatus.AVAILABLE
    last_heartbeat_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )