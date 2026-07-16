"""Perfiles y secciones configurables de reportes ejecutivos."""

from __future__ import annotations

ALL_SECTIONS = (
    "summary",
    "audit",
    "components",
    "extensions",
    "resources",
    "lifecycle",
    "history",
    "recommendations",
)

PROFILE_SECTIONS = {
    "executive": (
        "summary",
        "audit",
        "components",
        "extensions",
        "history",
        "recommendations",
    ),
    "technical": ALL_SECTIONS,
    "audit": (
        "summary",
        "audit",
        "resources",
        "lifecycle",
        "history",
        "recommendations",
    ),
}


class ReportProfileError(ValueError):
    """Perfil o selección de secciones inválida."""


def resolve_sections(
    profile: str,
    sections: tuple[str, ...] | None = None,
) -> tuple[str, ...]:
    if profile not in PROFILE_SECTIONS:
        raise ReportProfileError(f"Perfil no soportado: {profile}")

    if sections is None:
        return PROFILE_SECTIONS[profile]

    normalized: list[str] = []
    for section in sections:
        value = section.strip().lower()
        if not value:
            continue
        if value not in ALL_SECTIONS:
            raise ReportProfileError(f"Sección no soportada: {value}")
        if value not in normalized:
            normalized.append(value)

    if not normalized:
        raise ReportProfileError("Debe seleccionar al menos una sección.")

    return tuple(normalized)
