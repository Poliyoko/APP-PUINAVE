"""Migraciones de esquema soportadas por SGODA."""

from copy import deepcopy
from datetime import UTC, datetime
from typing import Any, Callable

from .models import MigrationStep

CURRENT_SCHEMA_VERSION = "1.3"
SUPPORTED_SCHEMA_VERSIONS = ("1.0", "1.1", "1.2", "1.3")

MigrationFunction = Callable[
    [dict[str, Any]],
    tuple[dict[str, Any], MigrationStep],
]


def migrate_1_0_to_1_1(
    manifest: dict[str, Any],
) -> tuple[dict[str, Any], MigrationStep]:
    updated = deepcopy(manifest)
    updated.setdefault("components", {})
    updated["schema_version"] = "1.1"
    return updated, MigrationStep(
        "1.0",
        "1.1",
        "Añadir registro de componentes.",
    )


def migrate_1_1_to_1_2(
    manifest: dict[str, Any],
) -> tuple[dict[str, Any], MigrationStep]:
    updated = deepcopy(manifest)
    governance = updated.setdefault("governance", {})
    governance.setdefault(
        "frameworks",
        ["DAMA-DMBOK", "FAIR", "CARE"],
    )
    governance.setdefault("data_owner", "Comunidad Puinave")
    governance.setdefault("data_steward", "Equipo SGODA-PUINAVE")
    governance.setdefault("classification", "cultural-community-data")
    governance.setdefault(
        "care",
        {
            "collective_benefit": True,
            "authority_to_control": True,
            "responsibility": True,
            "ethics": True,
        },
    )
    resources = updated.setdefault("resources", {})
    resources.setdefault("lexicon", "data/json/palabras.json")
    resources.setdefault(
        "metadata_catalog",
        "data/metadata/catalog.json",
    )
    updated["schema_version"] = "1.2"
    return updated, MigrationStep(
        "1.1",
        "1.2",
        "Completar gobierno, CARE y recursos de datos.",
    )


def migrate_1_2_to_1_3(
    manifest: dict[str, Any],
) -> tuple[dict[str, Any], MigrationStep]:
    updated = deepcopy(manifest)
    now = datetime.now(UTC).isoformat()
    lifecycle = updated.setdefault("lifecycle", {})
    lifecycle.setdefault("managed_by", "SGODA Project Builder")
    lifecycle["last_migrated_at"] = now
    history = lifecycle.setdefault("migration_history", [])
    history.append(
        {
            "from": "1.2",
            "to": "1.3",
            "migrated_at": now,
        }
    )
    project = updated.setdefault("project", {})
    project["updated_at"] = now
    updated["schema_version"] = "1.3"
    return updated, MigrationStep(
        "1.2",
        "1.3",
        "Añadir metadatos de ciclo de vida e historial de migración.",
    )


MIGRATIONS: dict[str, MigrationFunction] = {
    "1.0": migrate_1_0_to_1_1,
    "1.1": migrate_1_1_to_1_2,
    "1.2": migrate_1_2_to_1_3,
}
