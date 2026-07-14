"""Constantes globales del SGODA Project Builder."""

APP_NAME = "SGODA Project Builder"
VERSION = "0.3.0"
AUTHOR = "Proyecto SGODA-PUINAVE"
COPYRIGHT = "(C) 2026 Proyecto SGODA-PUINAVE"

DEFAULT_DIRECTORIES: tuple[str, ...] = (
    ".github/workflows",
    "assets/audio/en",
    "assets/audio/es",
    "assets/audio/pu",
    "assets/branding",
    "assets/icons",
    "assets/images",
    "automation/n8n",
    "backend",
    "data/excel",
    "data/json",
    "data/metadata",
    "data/prompts",
    "data/validation",
    "database/diagrams",
    "database/migrations",
    "database/seed",
    "docs/00_Gobierno",
    "docs/01_CCP",
    "docs/02_Arquitectura",
    "docs/03_ADR",
    "docs/04_ODA",
    "docs/05_Modelo_Datos",
    "docs/06_API",
    "docs/07_Data_Governance",
    "docs/08_Desarrollo",
    "docs/09_Investigacion",
    "docs/10_Calidad",
    "frontend/flutter",
    "frontend/web",
    "infrastructure",
    "scripts",
    "tests",
)

REQUIRED_PROJECT_FILES: tuple[str, ...] = (
    ".gitignore",
    "README.md",
    "sgoda.project.json",
    "data/json/palabras.json",
)
