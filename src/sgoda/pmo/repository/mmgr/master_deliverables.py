from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime
from typing import Any, Mapping


VALID_SUBSYSTEMS = frozenset(
    {
        "Nucleo del Sistema",
        "Builder",
        "CCP",
        "API",
        "ODA",
        "Multimedia",
        "Mobile",
        "Portal Web",
        "IA",
        "DMP",
    }
)


def _clean(value: str) -> str:
    return value.strip()


def _clean_tuple(values: tuple[str, ...]) -> tuple[str, ...]:
    cleaned = tuple(_clean(value) for value in values)

    if any(not value for value in cleaned):
        raise ValueError("Empty values are not allowed.")

    if len(cleaned) != len(set(cleaned)):
        raise ValueError("Duplicate values are not allowed.")

    return cleaned


@dataclass(frozen=True, slots=True)
class DeliverableIdentity:
    code: str
    name: str
    family: str

    def __post_init__(self) -> None:
        code = _clean(self.code).upper()
        name = _clean(self.name)
        family = _clean(self.family).upper()

        if not code:
            raise ValueError("code is required.")
        if not name:
            raise ValueError("name is required.")
        if not family:
            raise ValueError("family is required.")

        object.__setattr__(self, "code", code)
        object.__setattr__(self, "name", name)
        object.__setattr__(self, "family", family)


@dataclass(frozen=True, slots=True)
class ArchitectureMapping:
    subsystems: tuple[str, ...]
    dmp_component: str = ""

    def __post_init__(self) -> None:
        subsystems = _clean_tuple(self.subsystems)

        invalid = sorted(set(subsystems) - VALID_SUBSYSTEMS)

        if invalid:
            raise ValueError(
                "Invalid SGODA subsystem(s): " + ", ".join(invalid)
            )

        dmp_component = _clean(self.dmp_component)

        if dmp_component and "DMP" not in subsystems:
            raise ValueError(
                "dmp_component requires DMP in subsystems."
            )

        object.__setattr__(self, "subsystems", subsystems)
        object.__setattr__(self, "dmp_component", dmp_component)


@dataclass(frozen=True, slots=True)
class Progress:
    current_status: str
    status_history: tuple[str, ...] = ()
    progress_percent: float = 0.0
    weight: float = 1.0

    def __post_init__(self) -> None:
        current_status = _clean(self.current_status).upper()

        if not current_status:
            raise ValueError("current_status is required.")

        if not 0.0 <= float(self.progress_percent) <= 100.0:
            raise ValueError(
                "progress_percent must be between 0 and 100."
            )

        if float(self.weight) < 0.0:
            raise ValueError("weight cannot be negative.")

        history = _clean_tuple(self.status_history)

        object.__setattr__(
            self,
            "current_status",
            current_status,
        )
        object.__setattr__(
            self,
            "status_history",
            history,
        )
        object.__setattr__(
            self,
            "progress_percent",
            float(self.progress_percent),
        )
        object.__setattr__(
            self,
            "weight",
            float(self.weight),
        )


@dataclass(frozen=True, slots=True)
class Verification:
    tests: tuple[str, ...] = ()
    evidences: tuple[str, ...] = ()
    findings: tuple[str, ...] = ()
    pending_actions: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        for name in (
            "tests",
            "evidences",
            "findings",
            "pending_actions",
        ):
            object.__setattr__(
                self,
                name,
                _clean_tuple(getattr(self, name)),
            )


@dataclass(frozen=True, slots=True)
class RepositoryTraceability:
    code_paths: tuple[str, ...] = ()
    dependencies: tuple[str, ...] = ()
    commit: str = ""
    tag: str = ""
    release: str = ""
    baseline: str = ""
    sha256: str = ""

    def __post_init__(self) -> None:
        object.__setattr__(
            self,
            "code_paths",
            _clean_tuple(self.code_paths),
        )
        object.__setattr__(
            self,
            "dependencies",
            _clean_tuple(self.dependencies),
        )

        for name in (
            "commit",
            "tag",
            "release",
            "baseline",
            "sha256",
        ):
            object.__setattr__(
                self,
                name,
                _clean(getattr(self, name)),
            )


@dataclass(frozen=True, slots=True)
class InstitutionalTraceability:
    actas_sgd: tuple[str, ...] = ()
    source_paths: tuple[str, ...] = ()
    closure_date: str = ""
    last_recertification: str = ""

    def __post_init__(self) -> None:
        object.__setattr__(
            self,
            "actas_sgd",
            _clean_tuple(self.actas_sgd),
        )
        object.__setattr__(
            self,
            "source_paths",
            _clean_tuple(self.source_paths),
        )

        for name in (
            "closure_date",
            "last_recertification",
        ):
            value = _clean(getattr(self, name))

            if value:
                datetime.fromisoformat(
                    value.replace("Z", "+00:00")
                )

            object.__setattr__(self, name, value)


@dataclass(frozen=True, slots=True)
class MasterDeliverable:
    identity: DeliverableIdentity
    architecture: ArchitectureMapping
    progress: Progress
    verification: Verification = field(
        default_factory=Verification
    )
    repository: RepositoryTraceability = field(
        default_factory=RepositoryTraceability
    )
    institutional: InstitutionalTraceability = field(
        default_factory=InstitutionalTraceability
    )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(
        cls,
        payload: Mapping[str, Any],
    ) -> "MasterDeliverable":
        return cls(
            identity=DeliverableIdentity(
                **payload["identity"]
            ),
            architecture=ArchitectureMapping(
                subsystems=tuple(
                    payload["architecture"]["subsystems"]
                ),
                dmp_component=payload[
                    "architecture"
                ].get("dmp_component", ""),
            ),
            progress=Progress(
                current_status=payload[
                    "progress"
                ]["current_status"],
                status_history=tuple(
                    payload["progress"].get(
                        "status_history",
                        (),
                    )
                ),
                progress_percent=payload[
                    "progress"
                ].get("progress_percent", 0.0),
                weight=payload[
                    "progress"
                ].get("weight", 1.0),
            ),
            verification=Verification(
                **{
                    key: tuple(value)
                    for key, value in payload.get(
                        "verification",
                        {},
                    ).items()
                }
            ),
            repository=RepositoryTraceability(
                **{
                    key: (
                        tuple(value)
                        if key in (
                            "code_paths",
                            "dependencies",
                        )
                        else value
                    )
                    for key, value in payload.get(
                        "repository",
                        {},
                    ).items()
                }
            ),
            institutional=InstitutionalTraceability(
                **{
                    key: (
                        tuple(value)
                        if key in (
                            "actas_sgd",
                            "source_paths",
                        )
                        else value
                    )
                    for key, value in payload.get(
                        "institutional",
                        {},
                    ).items()
                }
            ),
        )
