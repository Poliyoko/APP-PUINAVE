from dataclasses import dataclass, field
from typing import Dict, Tuple


@dataclass(frozen=True)
class DependencyRequirement:
    component_id: str
    minimum_version: str = "0.0.0"
    maximum_version: str = ""

    def __post_init__(self) -> None:
        if not self.component_id or not self.component_id.strip():
            raise ValueError("component_id is required")
        object.__setattr__(self, "component_id", self.component_id.strip())


@dataclass(frozen=True)
class DependencyComponent:
    component_id: str
    version: str
    dependencies: Tuple[DependencyRequirement, ...] = ()
    metadata: Dict[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.component_id or not self.component_id.strip():
            raise ValueError("component_id is required")
        if not self.version or not self.version.strip():
            raise ValueError("version is required")
        object.__setattr__(self, "component_id", self.component_id.strip())
        object.__setattr__(self, "version", self.version.strip())
        object.__setattr__(self, "dependencies", tuple(self.dependencies))
        object.__setattr__(self, "metadata", dict(self.metadata))