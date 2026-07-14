"""Plantillas del componente backend SGODA."""


def build_backend_files() -> dict[str, str]:
    """Devuelve los archivos base de un backend FastAPI."""
    return {
        "backend/README.md": "# Backend SGODA\n\nBackend base generado por SGODA Project Builder.\n",
        "backend/pyproject.toml": """[build-system]
requires = ["setuptools>=70", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "sgoda-backend"
version = "0.1.0"
description = "Backend del ecosistema SGODA"
requires-python = ">=3.11"
dependencies = [
  "fastapi>=0.115",
  "uvicorn[standard]>=0.30"
]

[tool.setuptools]
package-dir = {"" = "src"}

[tool.setuptools.packages.find]
where = ["src"]
""",
        "backend/src/app/__init__.py": "\"\"\"Aplicación backend SGODA.\"\"\"\n",
        "backend/src/app/main.py": """\"\"\"Aplicación principal FastAPI del backend SGODA.\"\"\"

from fastapi import FastAPI

from app.api.health import router as health_router

app = FastAPI(title="SGODA API", version="0.1.0")
app.include_router(health_router)
""",
        "backend/src/app/api/__init__.py": "\"\"\"Rutas API del backend SGODA.\"\"\"\n",
        "backend/src/app/api/health.py": """\"\"\"Endpoint de salud del backend.\"\"\"

from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
""",
        "backend/src/app/core/__init__.py": "\"\"\"Configuración central del backend SGODA.\"\"\"\n",
        "backend/src/app/core/config.py": """\"\"\"Configuración básica del backend.\"\"\"

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class Settings:
    app_name: str = "SGODA API"
    environment: str = "development"


settings = Settings()
""",
        "backend/tests/test_health.py": """\"\"\"Prueba del endpoint de salud.\"\"\"

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
""",
    }
