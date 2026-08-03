"""Modelos de arquitectura nativa SGD-114E v1.0.5."""

from __future__ import annotations

from copy import deepcopy
from typing import Any, Iterator, Mapping


class NativeEcosystemValidationResult(dict[str, Any]):
    """Resultado compatible con interfaces histórica y moderna.

    Admite:
        result.approved
        result["approved"]
        result.to_dict()
    """

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
        try:
            return self[name]
        except KeyError as error:
            raise AttributeError(name) from error

    def __setattr__(self, name: str, value: Any) -> None:
        self[name] = value

    def __delattr__(self, name: str) -> None:
        try:
            del self[name]
        except KeyError as error:
            raise AttributeError(name) from error

    def to_dict(self) -> dict[str, Any]:
        return deepcopy(dict(self))

    @property
    def approved(self) -> bool:
        return bool(self.get("approved", False))

    @approved.setter
    def approved(self, value: bool) -> None:
        self["approved"] = bool(value)

    @property
    def native_components(self) -> tuple[str, ...]:
        values = self.get("native_components", ())
        return tuple(str(item) for item in values)

    @native_components.setter
    def native_components(self, value: Any) -> None:
        self["native_components"] = list(value or [])

    @property
    def forbidden_terms(self) -> tuple[Any, ...]:
        values = self.get("forbidden_terms", ())
        return tuple(values)

    @forbidden_terms.setter
    def forbidden_terms(self, value: Any) -> None:
        self["forbidden_terms"] = list(value or [])

    @property
    def mandatory_proprietary_dependencies(
        self,
    ) -> tuple[Any, ...]:
        values = self.get(
            "mandatory_proprietary_dependencies",
            (),
        )
        return tuple(values)

    @mandatory_proprietary_dependencies.setter
    def mandatory_proprietary_dependencies(
        self,
        value: Any,
    ) -> None:
        self[
            "mandatory_proprietary_dependencies"
        ] = list(value or [])

    def copy(self) -> "NativeEcosystemValidationResult":
        return NativeEcosystemValidationResult(self.to_dict())

    def __iter__(self) -> Iterator[str]:
        return super().__iter__()