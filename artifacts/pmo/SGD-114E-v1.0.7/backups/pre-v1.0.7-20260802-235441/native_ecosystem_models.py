"""Modelos definitivos de SGD-114E v1.0.6."""

from __future__ import annotations

from copy import deepcopy
from dataclasses import asdict, dataclass
from typing import Any, Mapping


@dataclass(frozen=True, slots=True)
class NativeEcosystemFinding:
    rule_code: str
    message: str
    path: str = ""
    component: str = ""
    value: str = ""
    severity: str = "error"

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class NativeEcosystemValidationResult(dict[str, Any]):
    """Resultado compatible con todos los contratos institucionales."""

    def __init__(
        self,
        payload: Mapping[str, Any] | None = None,
        **values: Any,
    ) -> None:
        merged: dict[str, Any] = {}

        if payload is not None:
            merged.update(dict(payload))

        merged.update(values)
        super().__init__(merged)

    def __getattr__(self, name: str) -> Any:
        aliases = {
            "component_count": "native_component_count",
            "proprietary_dependency_count": (
                "mandatory_proprietary_dependency_count"
            ),
        }

        if name == "version":
            return self.get(
                "implementation_version",
                self.get("version"),
            )

        key = aliases.get(name, name)

        try:
            return self[key]
        except KeyError as error:
            raise AttributeError(name) from error

    def __setattr__(self, name: str, value: Any) -> None:
        self[name] = value

    @property
    def approved(self) -> bool:
        return bool(self.get("approved", False))

    @approved.setter
    def approved(self, value: bool) -> None:
        self["approved"] = bool(value)

    @property
    def component_count(self) -> int:
        return int(self.get("native_component_count", 0))

    @property
    def proprietary_dependency_count(self) -> int:
        return int(
            self.get(
                "mandatory_proprietary_dependency_count",
                0,
            )
        )

    @property
    def findings(self) -> tuple[NativeEcosystemFinding, ...]:
        values = self.get("findings", ())
        result = []

        for item in values:
            if isinstance(item, NativeEcosystemFinding):
                result.append(item)
            elif isinstance(item, Mapping):
                result.append(
                    NativeEcosystemFinding(
                        rule_code=str(
                            item.get("rule_code") or ""
                        ),
                        message=str(
                            item.get("message") or ""
                        ),
                        path=str(item.get("path") or ""),
                        component=str(
                            item.get("component") or ""
                        ),
                        value=str(item.get("value") or ""),
                        severity=str(
                            item.get("severity") or "error"
                        ),
                    )
                )

        return tuple(result)

    @findings.setter
    def findings(self, value: Any) -> None:
        self["findings"] = list(value or [])

    def to_dict(self) -> dict[str, Any]:
        def convert(value: Any) -> Any:
            if isinstance(value, NativeEcosystemFinding):
                return value.to_dict()
            if isinstance(value, Mapping):
                return {
                    str(key): convert(item)
                    for key, item in value.items()
                }
            if isinstance(value, (list, tuple)):
                return [convert(item) for item in value]
            return deepcopy(value)

        return convert(dict(self))

    def copy(self) -> "NativeEcosystemValidationResult":
        return NativeEcosystemValidationResult(
            self.to_dict()
        )