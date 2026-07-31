"""Registro central de módulos de SGODA-PUINAVE."""

from __future__ import annotations

from threading import RLock

from sgoda.kernel.models import ModuleDescriptor


class ModuleRegistry:
    """Registro seguro de módulos y capacidades."""

    def __init__(self) -> None:
        self._modules: dict[str, ModuleDescriptor] = {}
        self._lock = RLock()

    def register(
        self,
        module: ModuleDescriptor,
        *,
        replace: bool = False,
    ) -> None:
        """Registra un módulo en el Kernel."""

        normalized_code = module.code.strip().lower()

        if not normalized_code:
            raise ValueError("El código del módulo no puede estar vacío.")

        with self._lock:
            if normalized_code in self._modules and not replace:
                raise ValueError(
                    f"El módulo '{normalized_code}' ya está registrado."
                )

            self._modules[normalized_code] = module

    def get(self, code: str) -> ModuleDescriptor | None:
        """Obtiene un módulo mediante su código."""

        with self._lock:
            return self._modules.get(code.strip().lower())

    def list_modules(self) -> list[ModuleDescriptor]:
        """Devuelve los módulos registrados."""

        with self._lock:
            return sorted(
                self._modules.values(),
                key=lambda item: item.code,
            )

    def count(self) -> int:
        """Devuelve el número total de módulos."""

        with self._lock:
            return len(self._modules)

    def enabled_count(self) -> int:
        """Devuelve el número de módulos habilitados."""

        with self._lock:
            return sum(
                1 for module in self._modules.values()
                if module.enabled
            )

    def clear(self) -> None:
        """Limpia el registro, principalmente para pruebas."""

        with self._lock:
            self._modules.clear()


module_registry = ModuleRegistry()
