"""Plantilla del backend SGODA."""


def build_backend_files() -> dict[str, str]:
    """Devuelve los archivos base del backend."""
    return {
        "backend/README.md": "# Backend SGODA\n",
        "backend/pyproject.toml": """[build-system]
requires = ["setuptools>=70", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "sgoda-backend"
version = "0.1.0"
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
        "backend/src/app/__init__.py": '"""Backend SGODA."""\n',
        "backend/src/app/main.py": """from fastapi import FastAPI

from app.api.health import router

app = FastAPI(title="SGODA API", version="0.1.0")
app.include_router(router)
""",
        "backend/src/app/api/__init__.py": "",
        "backend/src/app/api/health.py": """from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
""",
        "backend/src/app/core/__init__.py": "",
        "backend/src/app/core/config.py": 'APP_NAME = "SGODA API"\n',
        "backend/tests/test_health.py": """def test_placeholder() -> None:
    assert True
""",
    }
