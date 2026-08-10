from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class MultimediaRoute:
    resource_type: str
    language: str | None
    route: str
    provider_family: str
    requires_human_validation: bool


ROUTES: tuple[MultimediaRoute, ...] = (
    MultimediaRoute(
        resource_type="image",
        language=None,
        route="SPT-003A->SPT-003B->ADR-010",
        provider_family="LOCAL_OR_MOCK_IMAGE",
        requires_human_validation=True,
    ),
    MultimediaRoute(
        resource_type="audio_puinave",
        language="pui",
        route="NATIVE_RECORDING->SPT-003B->ADR-010",
        provider_family="NATIVE_HUMAN_RECORDING",
        requires_human_validation=True,
    ),
    MultimediaRoute(
        resource_type="audio_es",
        language="es-CO",
        route="SPT-006A->SPT-003B->ADR-010",
        provider_family="FREE_LOCAL_TTS",
        requires_human_validation=False,
    ),
    MultimediaRoute(
        resource_type="audio_en",
        language="en-US",
        route="SPT-006A->SPT-003B->ADR-010",
        provider_family="FREE_LOCAL_TTS",
        requires_human_validation=False,
    ),
    MultimediaRoute(
        resource_type="audio_it",
        language="it-IT",
        route="SPT-006A->SPT-003B->ADR-010",
        provider_family="FREE_LOCAL_TTS",
        requires_human_validation=False,
    ),
)


def validate_policy() -> None:
    expected = {
        "image",
        "audio_puinave",
        "audio_es",
        "audio_en",
        "audio_it",
    }
    actual = {item.resource_type for item in ROUTES}
    if actual != expected:
        raise ValueError("SPT-023.4 multimedia policy must define exactly five resources.")

    for item in ROUTES:
        if "PAID" in item.provider_family.upper():
            raise ValueError("Paid provider families are forbidden.")
        if item.resource_type == "audio_puinave":
            if item.provider_family != "NATIVE_HUMAN_RECORDING":
                raise ValueError("Puinave audio must use native human recording.")
