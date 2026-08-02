from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass(slots=True)
class IncrementSpec:
    code: str
    name: str
    component_type: str
    version: str = "0.1.0"
    description: str = ""
    governed_by: list[str] = field(
        default_factory=lambda: [
            "SGD-114-v2.0.1",
            "SGD-115-v1.0.1",
            "SPB-007",
        ]
    )


@dataclass(slots=True)
class GeneratedPackage:
    root: Path
    installer_path: Path
    repair_template_path: Path
    component_path: Path
    policy_path: Path
    documentation_path: Path
    test_path: Path
    manifest_path: Path
    publication_commands_path: Path