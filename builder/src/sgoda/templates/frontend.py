"""Plantilla frontend."""


def build_frontend_files() -> dict[str, str]:
    return {
        "frontend/web/README.md": "# Frontend Web SGODA\n",
        "frontend/web/index.html": (
            "<!doctype html>\n"
            '<html lang="es">\n'
            "<head><meta charset=\"utf-8\"><title>SGODA</title></head>\n"
            "<body><h1>SGODA-PUINAVE</h1></body>\n"
            "</html>\n"
        ),
        "frontend/web/styles.css": "body { font-family: sans-serif; }\n",
        "frontend/web/app.js": 'console.log("SGODA listo");\n',
    }
