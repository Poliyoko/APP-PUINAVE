"""Plantilla backend."""


def build_backend_files() -> dict[str, str]:
    return {
        "backend/README.md": "# Backend SGODA\n",
        "backend/src/app/__init__.py": "",
        "backend/src/app/main.py": (
            '"""Aplicación backend SGODA."""\n\n'
            'APP_NAME = "SGODA API"\n'
        ),
    }
