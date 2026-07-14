"""Plantilla de base de datos."""


def build_database_files() -> dict[str, str]:
    return {
        "database/README.md": "# Base de datos SGODA\n",
        "database/schema.sql": (
            "CREATE TABLE IF NOT EXISTS palabra (\n"
            "    id BIGSERIAL PRIMARY KEY,\n"
            "    termino_puinave VARCHAR(300) NOT NULL,\n"
            "    significado_es TEXT\n"
            ");\n"
        ),
        "database/seed/001_comunidad.sql": (
            "-- Datos iniciales de la comunidad Puinave\n"
        ),
        "database/migrations/README.md": "# Migraciones\n",
    }
