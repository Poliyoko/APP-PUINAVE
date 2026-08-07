from dataclasses import dataclass
from importlib import import_module
from typing import Any, Dict, Iterable, Optional, Sequence, Tuple


class ComponentLoadError(RuntimeError):
    pass


@dataclass(frozen=True)
class ComponentDescriptor:
    name: str
    component: Any
    required_methods: Tuple[str, ...] = ()


class InstitutionalComponentLoader:
    def __init__(self) -> None:
        self._components: Dict[str, ComponentDescriptor] = {}

    def register(
        self,
        name: str,
        component: Any,
        required_methods: Sequence[str] = (),
    ) -> ComponentDescriptor:
        if not name or not name.strip():
            raise ValueError("component name is required")
        if component is None:
            raise ValueError("component instance is required")

        descriptor = ComponentDescriptor(
            name=name.strip(),
            component=component,
            required_methods=tuple(required_methods),
        )
        self._validate_descriptor(descriptor)
        self._components[descriptor.name] = descriptor
        return descriptor

    def load_from_module(
        self,
        name: str,
        module_name: str,
        attribute: str,
        required_methods: Sequence[str] = (),
    ) -> ComponentDescriptor:
        try:
            module = import_module(module_name)
            component = getattr(module, attribute)
        except (ImportError, AttributeError) as exc:
            raise ComponentLoadError(
                "cannot load {0} from {1}".format(attribute, module_name)
            ) from exc

        return self.register(name, component, required_methods)

    def get(self, name: str) -> Any:
        try:
            return self._components[name].component
        except KeyError as exc:
            raise ComponentLoadError("component not registered: {0}".format(name)) from exc

    def descriptors(self) -> Iterable[ComponentDescriptor]:
        return tuple(self._components.values())

    def validate_all(self) -> None:
        for descriptor in self._components.values():
            self._validate_descriptor(descriptor)

    @staticmethod
    def _validate_descriptor(descriptor: ComponentDescriptor) -> None:
        missing = [
            method
            for method in descriptor.required_methods
            if not callable(getattr(descriptor.component, method, None))
        ]
        if missing:
            raise ComponentLoadError(
                "component {0} misses methods: {1}".format(
                    descriptor.name, ", ".join(missing)
                )
            )