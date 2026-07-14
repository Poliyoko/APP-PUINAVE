"""Plantilla de módulos SGODA."""

import re
import unicodedata


def normalize_module_name(name: str) -> str:
    value = unicodedata.normalize("NFKD", name)
    value = "".join(char for char in value if not unicodedata.combining(char))
    value = re.sub(r"[^a-zA-Z0-9_]+", "_", value.lower()).strip("_")

    if not value:
        raise ValueError("El nombre del módulo no puede quedar vacío")

    if value[0].isdigit():
        value = f"module_{value}"

    return value


def build_module_files(name: str) -> dict[str, str]:
    module_name = normalize_module_name(name)
    class_name = "".join(part.title() for part in module_name.split("_"))
    base = f"modules/{module_name}"

    return {
        f"{base}/README.md": f"# Módulo {module_name}\n",
        f"{base}/src/{module_name}/__init__.py": "",
        f"{base}/src/{module_name}/service.py": (
            f"class {class_name}Service:\n"
            "    def health(self) -> dict[str, str]:\n"
            f'        return {{"module": "{module_name}", "status": "ok"}}\n'
        ),
        f"{base}/tests/test_service.py": (
            f"from {module_name}.service import {class_name}Service\n\n"
            "def test_health() -> None:\n"
            f"    assert {class_name}Service().health()[\"status\"] == \"ok\"\n"
        ),
    }
