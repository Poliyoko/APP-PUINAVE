"""Constantes del Builder."""

APP_NAME = "SGODA Project Builder"
VERSION = "0.8.0"

DEFAULT_DIRECTORIES = (
    "backend",
    "frontend/web",
    "database",
    "modules",
    "automation/n8n",
    "docs/00_Gobierno",
    "docs/03_ADR",
    "docs/07_Data_Governance",
    "docs/08_Desarrollo",
    "data/json",
    "data/metadata",
    "data/validation",
    "tests",
)

REQUIRED_PROJECT_FILES = (
    "README.md",
    ".gitignore",
    "sgoda.project.json",
    "data/json/palabras.json",
    "data/metadata/catalog.json",
    "docs/00_Gobierno/README.md",
)
