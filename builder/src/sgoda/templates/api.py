"""Plantilla de API especializada SGODA."""

from sgoda.templates.module import normalize_module_name


def build_api_files(name: str) -> dict[str, str]:
    """Construye una API FastAPI especializada."""
    api_name = normalize_module_name(name)
    route = api_name.replace("_", "-")
    base = f"backend/src/app/api/{api_name}"

    return {
        f"{base}/__init__.py": f'"""API SGODA: {api_name}."""\n',
        f"{base}/router.py": (
            '"""Router generado por SGODA Project Builder."""\n\n'
            "from fastapi import APIRouter\n\n"
            f'router = APIRouter(prefix="/api/{route}", tags=["{api_name}"])\n\n\n'
            '@router.get("/health")\n'
            "def health() -> dict[str, str]:\n"
            f'    return {{"component": "api:{api_name}", "status": "ok"}}\n'
        ),
        f"{base}/schemas.py": (
            '"""Esquemas iniciales de la API."""\n\n'
            "from pydantic import BaseModel\n\n\n"
            f"class {''.join(part.title() for part in api_name.split('_'))}Item(BaseModel):\n"
            "    id: int\n"
            "    name: str\n"
        ),
        f"backend/tests/test_api_{api_name}.py": (
            f'"""Prueba básica de la API {api_name}."""\n\n'
            f"from app.api.{api_name}.router import health\n\n\n"
            "def test_health() -> None:\n"
            '    assert health()["status"] == "ok"\n'
        ),
        f"docs/06_API/{api_name}.md": (
            f"# API {api_name}\n\n"
            f"Ruta base: `/api/{route}`.\n\n"
            "Generada por SGODA Project Builder.\n"
        ),
    }
