"""Proveedores multimedia y fábrica institucional."""

from __future__ import annotations

import hashlib
import os
from dataclasses import dataclass
from typing import Any

from .contracts import (
    ResultadoProveedor,
    SolicitudProveedor,
)


SUPPORTED_JOB_TYPES = {
    "generate_image",
    "generate_tts",
    "record_native_audio",
}


@dataclass(slots=True)
class ProveedorSimulado:
    name: str = "mock-provider"

    def supports(self, job_type: str) -> bool:
        return job_type in SUPPORTED_JOB_TYPES

    def execute(
        self,
        request: SolicitudProveedor,
    ) -> ResultadoProveedor:
        if not self.supports(request.job_type):
            return ResultadoProveedor(
                success=False,
                provider=self.name,
                error=f"Tipo no soportado: {request.job_type}",
            )

        if request.payload.get("simulate_error"):
            return ResultadoProveedor(
                success=False,
                provider=self.name,
                error="Error simulado del proveedor.",
            )

        canonical = (
            f"{request.job_id}|{request.job_type}|"
            f"{request.resource_id}|{request.language}|"
            f"{request.payload}"
        ).encode("utf-8")

        digest = hashlib.sha256(canonical).hexdigest()
        media_bytes = (
            f"SGODA-MOCK-MEDIA:{digest}"
        ).encode("utf-8")

        media_type = {
            "generate_image": "image/png",
            "generate_tts": "audio/wav",
            "record_native_audio": "audio/wav",
        }[request.job_type]

        return ResultadoProveedor(
            success=True,
            provider=self.name,
            external_id=f"MOCK-{digest[:20].upper()}",
            media_bytes=media_bytes,
            media_type=media_type,
            metadata={
                "simulated": True,
                "job_type": request.job_type,
                "language": request.language,
            },
        )


@dataclass(slots=True)
class ProveedorExternoDeshabilitado:
    name: str
    required_environment_variable: str

    def supports(self, job_type: str) -> bool:
        return job_type in SUPPORTED_JOB_TYPES

    def execute(
        self,
        request: SolicitudProveedor,
    ) -> ResultadoProveedor:
        if not os.getenv(self.required_environment_variable):
            return ResultadoProveedor(
                success=False,
                provider=self.name,
                error=(
                    "Proveedor deshabilitado: falta la variable de "
                    f"entorno {self.required_environment_variable}."
                ),
            )

        return ResultadoProveedor(
            success=False,
            provider=self.name,
            error=(
                "El contrato del proveedor está configurado, pero la "
                "llamada externa no está habilitada en SPT-003B v0.1.0."
            ),
        )


def construir_proveedor(
    provider_name: str,
) -> Any:
    normalized = provider_name.strip().casefold()

    if normalized == "mock":
        return ProveedorSimulado()

    if normalized == "openai-image":
        return ProveedorExternoDeshabilitado(
            name="openai-image",
            required_environment_variable="OPENAI_API_KEY",
        )

    if normalized == "google-tts":
        return ProveedorExternoDeshabilitado(
            name="google-tts",
            required_environment_variable="GOOGLE_APPLICATION_CREDENTIALS",
        )

    if normalized == "azure-speech":
        return ProveedorExternoDeshabilitado(
            name="azure-speech",
            required_environment_variable="AZURE_SPEECH_KEY",
        )

    raise ValueError(f"Proveedor desconocido: {provider_name}")