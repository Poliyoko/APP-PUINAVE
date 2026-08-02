<#
.SYNOPSIS
    Implementa SPT-005 — Sistema de Identidad Cultural Configurable.

.DESCRIPTION
    Instala un sistema institucional para separar la identidad técnica
    permanente de la identidad cultural visible del ecosistema SGODA.

    Permite configurar:
      - nombre visible de la plataforma;
      - nombre visible de la aplicación;
      - nombre visible del asistente;
      - nombres en Puinave, español e inglés;
      - eslogan;
      - logotipos e iconos;
      - estado de aprobación cultural;
      - autoridad y acta de aprobación;
      - historial de cambios;
      - activación y reversión de identidades;
      - exportación de configuración para Flutter, web y API.

    No renombra:
      - repositorio Git;
      - namespaces Python;
      - identificadores técnicos;
      - códigos SPT, SPB, SGD o ADR;
      - rutas históricas;
      - evidencias ni releases anteriores.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER SkipFullSuite
    Omite la suite completa. Las pruebas específicas siempre se ejecutan.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Path {
    param([string]$Path, [string]$Description)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontró $Description en: $Path"
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)

    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    $Info = Get-Item -LiteralPath $Path
    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-JsonUtf8 {
    param([string]$Path, [object]$Data)

    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        (($Data | ConvertTo-Json -Depth 50) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\identity"
$TestsDir = Join-Path $ProjectRoot "tests\identity"
$ConfigDir = Join-Path $ProjectRoot "config\identity"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-005"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\identity\SPT-005"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-005"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-005-v0.1.0"

$ModelsPath = Join-Path $SourceDir "models.py"
$RepositoryPath = Join-Path $SourceDir "repository.py"
$ServicePath = Join-Path $SourceDir "service.py"
$ExporterPath = Join-Path $SourceDir "exporter.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_SPT_005_configurable_cultural_identity.py"

$PolicyPath = Join-Path $ConfigDir "SPT-005-identity-policy.json"
$BaselinePath = Join-Path $ConfigDir "SPT-005-identity-baseline.json"
$ComponentPath = Join-Path $ConfigDir "SPT-005-component.json"

$DocPath = Join-Path $DocsDir "SPT-005-Sistema-Identidad-Cultural-Configurable.md"
$ProtocolPath = Join-Path $DocsDir "SPT-005-Protocolo-Aprobacion-Nombre-Puinave.md"
$MigrationPath = Join-Path $DocsDir "SPT-005-Guia-Cambio-Nombre-Visible.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT005-IdentityManagement.ps1"

$EvidencePath = Join-Path $PmoDir "implementation-evidence.json"
$TracePath = Join-Path $PmoDir "traceability-SPT-005.json"
$GatePath = Join-Path $PmoDir "SPT-005-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "SPT-005-dashboard.json"

Write-Step "Validando línea base institucional"

foreach ($Required in @(
    (Join-Path $ProjectRoot "src\sgoda\installer_builder\generator.py"),
    (Join-Path $ProjectRoot "src\sgoda\assistant\service.py"),
    (Join-Path $ProjectRoot "docs\00_INDICE_MAESTRO.md"),
    (Join-Path $ProjectRoot "docs\00_ARQUITECTURA_MAESTRA.md"),
    (Join-Path $ProjectRoot "docs\00_REGISTRO_MAESTRO_COMPONENTES.md"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot ".git")
)) {
    Assert-Path -Path $Required -Description $Required
}

$GitStatus = @(git status --porcelain | Where-Object { $_ })
$AllowedPatterns = @(
    '^\?\? Install-SPT005-Configurable-Cultural-Identity\.ps1$',
    '^\?\? Repair-SPT005-v[0-9.]+-.*\.ps1$',
    '^\?\? SPT005-.*\.zip$',
    '^\?\? LEAME-SPT005.*\.txt$'
)

$Unexpected = @(
    foreach ($Entry in $GitStatus) {
        $Allowed = $false
        foreach ($Pattern in $AllowedPatterns) {
            if ($Entry -match $Pattern) {
                $Allowed = $true
                break
            }
        }
        if (-not $Allowed) { $Entry }
    }
)

if ($Unexpected.Count -gt 0) {
    $Unexpected | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    throw "La línea base contiene cambios ajenos a SPT-005."
}

$ModelsContent = @'
"""Modelos del Sistema de Identidad Cultural Configurable."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class CulturalApproval:
    status: str
    approved_by: str | None = None
    approval_date: str | None = None
    approval_document: str | None = None
    community_scope: str | None = None
    notes: str | None = None


@dataclass(slots=True)
class IdentityProfile:
    identity_id: str
    technical_name: str
    public_name: str
    app_name: str
    assistant_name: str
    puinave_name: str | None
    spanish_name: str
    english_name: str
    slogan: str
    locale_default: str
    logo_path: str | None = None
    icon_path: str | None = None
    active: bool = False
    version: str = "1.0.0"
    approval: CulturalApproval = field(
        default_factory=lambda: CulturalApproval(status="pending")
    )
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class IdentityChange:
    event_id: str
    occurred_at_utc: str
    previous_identity_id: str | None
    new_identity_id: str
    changed_by: str
    reason: str
'@

$RepositoryContent = @'
"""Repositorio persistente de identidades culturales."""

from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

from .models import CulturalApproval, IdentityProfile


class IdentityRepository:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def _load_payload(self) -> dict[str, Any]:
        if not self.path.is_file():
            return {
                "technical_identity": "SGODA-PUINAVE",
                "active_identity_id": None,
                "profiles": [],
            }

        return json.loads(self.path.read_text(encoding="utf-8"))

    @staticmethod
    def _profile_from_dict(payload: dict[str, Any]) -> IdentityProfile:
        approval_payload = dict(payload.get("approval", {}))
        return IdentityProfile(
            identity_id=str(payload["identity_id"]),
            technical_name=str(payload["technical_name"]),
            public_name=str(payload["public_name"]),
            app_name=str(payload["app_name"]),
            assistant_name=str(payload["assistant_name"]),
            puinave_name=payload.get("puinave_name"),
            spanish_name=str(payload["spanish_name"]),
            english_name=str(payload["english_name"]),
            slogan=str(payload["slogan"]),
            locale_default=str(payload.get("locale_default", "es")),
            logo_path=payload.get("logo_path"),
            icon_path=payload.get("icon_path"),
            active=bool(payload.get("active", False)),
            version=str(payload.get("version", "1.0.0")),
            approval=CulturalApproval(
                status=str(approval_payload.get("status", "pending")),
                approved_by=approval_payload.get("approved_by"),
                approval_date=approval_payload.get("approval_date"),
                approval_document=approval_payload.get(
                    "approval_document"
                ),
                community_scope=approval_payload.get("community_scope"),
                notes=approval_payload.get("notes"),
            ),
            metadata=dict(payload.get("metadata", {})),
        )

    def list_profiles(self) -> list[IdentityProfile]:
        payload = self._load_payload()
        return [
            self._profile_from_dict(item)
            for item in payload.get("profiles", [])
        ]

    def get(self, identity_id: str) -> IdentityProfile | None:
        for profile in self.list_profiles():
            if profile.identity_id == identity_id:
                return profile
        return None

    def active(self) -> IdentityProfile | None:
        payload = self._load_payload()
        active_id = payload.get("active_identity_id")
        return self.get(str(active_id)) if active_id else None

    def save_profiles(
        self,
        profiles: list[IdentityProfile],
        active_identity_id: str | None,
    ) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)

        payload = {
            "technical_identity": "SGODA-PUINAVE",
            "active_identity_id": active_identity_id,
            "profiles": [asdict(item) for item in profiles],
        }

        self.path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    def upsert(self, profile: IdentityProfile) -> None:
        profiles = self.list_profiles()
        active_id = (
            self._load_payload().get("active_identity_id")
        )

        replaced = False
        for index, existing in enumerate(profiles):
            if existing.identity_id == profile.identity_id:
                profiles[index] = profile
                replaced = True
                break

        if not replaced:
            profiles.append(profile)

        self.save_profiles(profiles, active_id)
'@

$ServiceContent = @'
"""Servicio de gobierno de identidad cultural."""

from __future__ import annotations

import json
import re
import uuid
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

from .models import CulturalApproval, IdentityChange, IdentityProfile
from .repository import IdentityRepository


APPROVED_STATUSES = {"approved", "active"}
IDENTITY_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]{2,63}$")


class IdentityGovernanceError(ValueError):
    pass


class IdentityService:
    def __init__(
        self,
        *,
        repository: IdentityRepository,
        history_path: str | Path,
    ) -> None:
        self.repository = repository
        self.history_path = Path(history_path)

    @staticmethod
    def validate(profile: IdentityProfile) -> list[str]:
        errors: list[str] = []

        if not IDENTITY_PATTERN.fullmatch(profile.identity_id):
            errors.append("identity_id no cumple la nomenclatura.")

        if profile.technical_name != "SGODA-PUINAVE":
            errors.append(
                "La identidad técnica debe permanecer SGODA-PUINAVE."
            )

        for field_name, value in {
            "public_name": profile.public_name,
            "app_name": profile.app_name,
            "assistant_name": profile.assistant_name,
            "spanish_name": profile.spanish_name,
            "english_name": profile.english_name,
            "slogan": profile.slogan,
        }.items():
            if not str(value).strip():
                errors.append(f"{field_name} no puede estar vacío.")

        if profile.puinave_name:
            if profile.approval.status not in APPROVED_STATUSES:
                errors.append(
                    "Un nombre Puinave no puede activarse sin aprobación."
                )
            if not profile.approval.approved_by:
                errors.append("Falta la autoridad que aprobó el nombre.")
            if not profile.approval.approval_date:
                errors.append("Falta la fecha de aprobación.")
            if not profile.approval.approval_document:
                errors.append("Falta el acta o documento de aprobación.")

        return errors

    def register(self, profile: IdentityProfile) -> IdentityProfile:
        errors = self.validate(profile)
        if errors:
            raise IdentityGovernanceError(" | ".join(errors))

        self.repository.upsert(profile)
        return profile

    def activate(
        self,
        identity_id: str,
        *,
        changed_by: str,
        reason: str,
    ) -> IdentityProfile:
        profile = self.repository.get(identity_id)
        if profile is None:
            raise IdentityGovernanceError(
                f"No existe la identidad: {identity_id}"
            )

        errors = self.validate(profile)
        if errors:
            raise IdentityGovernanceError(" | ".join(errors))

        profiles = self.repository.list_profiles()
        previous = self.repository.active()

        for item in profiles:
            item.active = item.identity_id == identity_id

        self.repository.save_profiles(profiles, identity_id)

        event = IdentityChange(
            event_id=f"IDENTITY-{uuid.uuid4().hex.upper()}",
            occurred_at_utc=datetime.now(timezone.utc).isoformat(),
            previous_identity_id=(
                previous.identity_id if previous else None
            ),
            new_identity_id=identity_id,
            changed_by=changed_by,
            reason=reason,
        )
        self._append_history(event)

        active = self.repository.get(identity_id)
        if active is None:
            raise IdentityGovernanceError(
                "No fue posible recuperar la identidad activada."
            )
        return active

    def _append_history(self, event: IdentityChange) -> None:
        self.history_path.parent.mkdir(parents=True, exist_ok=True)
        with self.history_path.open("a", encoding="utf-8") as stream:
            stream.write(
                json.dumps(asdict(event), ensure_ascii=False) + "\n"
            )

    def create_pending_puinave_proposal(
        self,
        *,
        identity_id: str,
        proposed_name: str,
        proposed_by: str,
    ) -> IdentityProfile:
        return IdentityProfile(
            identity_id=identity_id,
            technical_name="SGODA-PUINAVE",
            public_name=proposed_name,
            app_name=proposed_name,
            assistant_name=f"Asistente {proposed_name}",
            puinave_name=None,
            spanish_name="Plataforma Digital Puinave",
            english_name="Puinave Digital Platform",
            slogan="Tecnología para preservar la memoria del pueblo Puinave.",
            locale_default="es",
            approval=CulturalApproval(
                status="pending",
                notes=(
                    "Propuesta pendiente de validación lingüística, "
                    f"cultural y comunitaria. Propuesta por {proposed_by}."
                ),
            ),
        )
'@

$ExporterContent = @'
"""Exportadores de identidad para clientes SGODA."""

from __future__ import annotations

import json
from pathlib import Path

from .models import IdentityProfile


def export_flutter(
    profile: IdentityProfile,
    output: str | Path,
) -> Path:
    path = Path(output)
    path.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "appName": profile.app_name,
        "assistantName": profile.assistant_name,
        "publicName": profile.public_name,
        "puinaveName": profile.puinave_name,
        "slogan": profile.slogan,
        "logoAsset": profile.logo_path,
        "iconAsset": profile.icon_path,
        "localeDefault": profile.locale_default,
        "identityVersion": profile.version,
    }

    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return path


def export_web(
    profile: IdentityProfile,
    output: str | Path,
) -> Path:
    path = Path(output)
    path.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "title": profile.public_name,
        "applicationName": profile.app_name,
        "assistantName": profile.assistant_name,
        "description": profile.slogan,
        "logo": profile.logo_path,
        "icon": profile.icon_path,
        "lang": profile.locale_default,
        "technicalIdentity": profile.technical_name,
    }

    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return path


def export_api(
    profile: IdentityProfile,
    output: str | Path,
) -> Path:
    path = Path(output)
    path.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "identity_id": profile.identity_id,
        "technical_name": profile.technical_name,
        "public_name": profile.public_name,
        "app_name": profile.app_name,
        "assistant_name": profile.assistant_name,
        "puinave_name": profile.puinave_name,
        "approval_status": profile.approval.status,
        "version": profile.version,
    }

    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return path
'@

$CliContent = @'
"""CLI del Sistema de Identidad Cultural Configurable."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from .exporter import export_api, export_flutter, export_web
from .repository import IdentityRepository
from .service import IdentityService


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    show = subparsers.add_parser("show")
    show.add_argument(
        "--repository",
        default="config/identity/SPT-005-identities.json",
    )

    export = subparsers.add_parser("export")
    export.add_argument(
        "--repository",
        default="config/identity/SPT-005-identities.json",
    )
    export.add_argument(
        "--output",
        default="artifacts/identity/SPT-005/exports",
    )

    activate = subparsers.add_parser("activate")
    activate.add_argument("identity_id")
    activate.add_argument("--changed-by", required=True)
    activate.add_argument("--reason", required=True)
    activate.add_argument(
        "--repository",
        default="config/identity/SPT-005-identities.json",
    )
    activate.add_argument(
        "--history",
        default="artifacts/identity/SPT-005/identity-history.jsonl",
    )

    args = parser.parse_args()
    repository = IdentityRepository(args.repository)

    if args.command == "show":
        active = repository.active()
        print(
            json.dumps(
                asdict(active) if active else None,
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    if args.command == "export":
        active = repository.active()
        if active is None:
            raise SystemExit("No existe una identidad activa.")

        output = Path(args.output)
        export_flutter(active, output / "flutter-identity.json")
        export_web(active, output / "web-identity.json")
        export_api(active, output / "api-identity.json")

        print("SPT-005 exportado correctamente.")
        print(f"Identidad: {active.public_name}")
        print(f"Destino: {output}")
        return 0

    service = IdentityService(
        repository=repository,
        history_path=args.history,
    )
    active = service.activate(
        args.identity_id,
        changed_by=args.changed_by,
        reason=args.reason,
    )

    print("SPT-005 identidad activada.")
    print(f"Identidad: {active.public_name}")
    print(f"ID: {active.identity_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

$InitContent = @'
"""Sistema de Identidad Cultural Configurable."""

from __future__ import annotations

from typing import Any

__all__ = [
    "CulturalApproval",
    "IdentityChange",
    "IdentityGovernanceError",
    "IdentityProfile",
    "IdentityRepository",
    "IdentityService",
    "export_api",
    "export_flutter",
    "export_web",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(name)

    if name in {
        "CulturalApproval",
        "IdentityChange",
        "IdentityProfile",
    }:
        from . import models
        return getattr(models, name)

    if name == "IdentityRepository":
        from . import repository
        return getattr(repository, name)

    if name in {"IdentityGovernanceError", "IdentityService"}:
        from . import service
        return getattr(service, name)

    from . import exporter
    return getattr(exporter, name)
'@

$TestContent = @'
"""Pruebas SPT-005 de identidad cultural configurable."""

import json
from pathlib import Path

import pytest

from sgoda.identity.exporter import (
    export_api,
    export_flutter,
    export_web,
)
from sgoda.identity.models import CulturalApproval, IdentityProfile
from sgoda.identity.repository import IdentityRepository
from sgoda.identity.service import (
    IdentityGovernanceError,
    IdentityService,
)


def _baseline() -> IdentityProfile:
    return IdentityProfile(
        identity_id="sgoda-puinave-baseline",
        technical_name="SGODA-PUINAVE",
        public_name="SGODA-PUINAVE",
        app_name="SGODA-PUINAVE",
        assistant_name="Asistente Virtual SGODA",
        puinave_name=None,
        spanish_name="Plataforma Digital Puinave",
        english_name="Puinave Digital Platform",
        slogan=(
            "Tecnología para preservar la memoria del pueblo Puinave."
        ),
        locale_default="es",
        approval=CulturalApproval(status="baseline"),
    )


def _approved() -> IdentityProfile:
    return IdentityProfile(
        identity_id="nombre-puinave-aprobado",
        technical_name="SGODA-PUINAVE",
        public_name="NOMBRE VALIDADO",
        app_name="NOMBRE VALIDADO",
        assistant_name="Asistente NOMBRE VALIDADO",
        puinave_name="NOMBRE VALIDADO",
        spanish_name="Plataforma Digital Puinave",
        english_name="Puinave Digital Platform",
        slogan="Identidad aprobada por el pueblo Puinave.",
        locale_default="es",
        approval=CulturalApproval(
            status="approved",
            approved_by="Autoridad Cultural Puinave",
            approval_date="2026-08-02",
            approval_document="ACTA-CULTURAL-001",
            community_scope="Pueblo Puinave",
        ),
    )


def _service(tmp_path: Path) -> IdentityService:
    return IdentityService(
        repository=IdentityRepository(tmp_path / "identities.json"),
        history_path=tmp_path / "history.jsonl",
    )


def test_SPT_005_preserva_identidad_tecnica(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    profile = _baseline()

    service.register(profile)

    assert (
        service.repository.get(profile.identity_id).technical_name
        == "SGODA-PUINAVE"
    )


def test_SPT_005_rechaza_cambio_identidad_tecnica(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    profile = _baseline()
    profile.technical_name = "OTRO-NOMBRE"

    with pytest.raises(IdentityGovernanceError):
        service.register(profile)


def test_SPT_005_registra_identidad_base(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    service.register(_baseline())

    assert len(service.repository.list_profiles()) == 1


def test_SPT_005_no_activa_nombre_puinave_sin_aprobacion(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    profile = _baseline()
    profile.identity_id = "propuesta-puinave"
    profile.puinave_name = "PROPUESTA"
    profile.approval = CulturalApproval(status="pending")

    with pytest.raises(IdentityGovernanceError):
        service.register(profile)


def test_SPT_005_activa_identidad_aprobada(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    service.register(_baseline())
    service.register(_approved())

    active = service.activate(
        "nombre-puinave-aprobado",
        changed_by="PMO Digital",
        reason="Acta cultural aprobada.",
    )

    assert active.active is True
    assert active.puinave_name == "NOMBRE VALIDADO"


def test_SPT_005_desactiva_identidad_anterior(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    baseline = _baseline()
    service.register(baseline)
    service.activate(
        baseline.identity_id,
        changed_by="PMO Digital",
        reason="Línea base.",
    )
    service.register(_approved())
    service.activate(
        "nombre-puinave-aprobado",
        changed_by="PMO Digital",
        reason="Nueva identidad.",
    )

    assert service.repository.get(baseline.identity_id).active is False


def test_SPT_005_registra_historial(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    service.register(_baseline())
    service.activate(
        "sgoda-puinave-baseline",
        changed_by="PMO Digital",
        reason="Activación inicial.",
    )

    event = json.loads(
        (tmp_path / "history.jsonl").read_text(
            encoding="utf-8"
        ).strip()
    )
    assert event["new_identity_id"] == "sgoda-puinave-baseline"


def test_SPT_005_exporta_flutter(tmp_path: Path) -> None:
    path = export_flutter(_approved(), tmp_path / "flutter.json")
    payload = json.loads(path.read_text(encoding="utf-8"))

    assert payload["appName"] == "NOMBRE VALIDADO"
    assert payload["assistantName"] == (
        "Asistente NOMBRE VALIDADO"
    )


def test_SPT_005_exporta_web(tmp_path: Path) -> None:
    path = export_web(_approved(), tmp_path / "web.json")
    payload = json.loads(path.read_text(encoding="utf-8"))

    assert payload["title"] == "NOMBRE VALIDADO"
    assert payload["technicalIdentity"] == "SGODA-PUINAVE"


def test_SPT_005_exporta_api(tmp_path: Path) -> None:
    path = export_api(_approved(), tmp_path / "api.json")
    payload = json.loads(path.read_text(encoding="utf-8"))

    assert payload["approval_status"] == "approved"
    assert payload["technical_name"] == "SGODA-PUINAVE"


def test_SPT_005_crea_propuesta_pendiente(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    proposal = service.create_pending_puinave_proposal(
        identity_id="propuesta-comunitaria",
        proposed_name="Nombre por validar",
        proposed_by="Equipo del proyecto",
    )

    assert proposal.approval.status == "pending"
    assert proposal.puinave_name is None


def test_SPT_005_rechaza_identificador_invalido(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    profile = _baseline()
    profile.identity_id = "Nombre Con Espacios"

    with pytest.raises(IdentityGovernanceError):
        service.register(profile)
'@

$PolicyContent = @'
{
  "increment_code": "SPT-005",
  "version": "0.1.0",
  "policy_name": "Sistema de Identidad Cultural Configurable",
  "technical_identity": "SGODA-PUINAVE",
  "technical_identity_mutable": false,
  "public_identity_configurable": true,
  "puinave_name_requires_community_approval": true,
  "approval_document_required": true,
  "approval_authority_required": true,
  "approval_date_required": true,
  "identity_history_required": true,
  "rollback_supported": true,
  "client_exports": [
    "flutter",
    "web",
    "api"
  ],
  "governed_by": [
    "SGD-114-v2.0.1",
    "SGD-115-v1.0.1",
    "SPB-007",
    "SIB-001"
  ]
}
'@

$BaselineContent = @'
{
  "technical_identity": "SGODA-PUINAVE",
  "active_identity_id": "sgoda-puinave-baseline",
  "profiles": [
    {
      "identity_id": "sgoda-puinave-baseline",
      "technical_name": "SGODA-PUINAVE",
      "public_name": "SGODA-PUINAVE",
      "app_name": "SGODA-PUINAVE",
      "assistant_name": "Asistente Virtual SGODA",
      "puinave_name": null,
      "spanish_name": "Plataforma Digital Puinave",
      "english_name": "Puinave Digital Platform",
      "slogan": "Tecnología para preservar la memoria del pueblo Puinave.",
      "locale_default": "es",
      "logo_path": null,
      "icon_path": null,
      "active": true,
      "version": "1.0.0",
      "approval": {
        "status": "baseline",
        "approved_by": null,
        "approval_date": null,
        "approval_document": null,
        "community_scope": null,
        "notes": "Identidad temporal hasta la aprobación cultural."
      },
      "metadata": {
        "technical_namespace": "sgoda",
        "repository_name": "SGODA-PUINAVE"
      }
    }
  ]
}
'@

$ComponentContent = @'
{
  "increment_code": "SPT-005",
  "name": "Sistema de Identidad Cultural Configurable",
  "component_type": "cultural_identity_management",
  "version": "0.1.0",
  "status": "technically_completed",
  "entrypoint": "sgoda.identity.cli",
  "source": [
    "src/sgoda/identity/models.py",
    "src/sgoda/identity/repository.py",
    "src/sgoda/identity/service.py",
    "src/sgoda/identity/exporter.py",
    "src/sgoda/identity/cli.py"
  ],
  "tests": [
    "tests/identity/test_SPT_005_configurable_cultural_identity.py"
  ],
  "documentation": [
    "docs/05_Fase_Tecnologica/SPT-005/SPT-005-Sistema-Identidad-Cultural-Configurable.md",
    "docs/05_Fase_Tecnologica/SPT-005/SPT-005-Protocolo-Aprobacion-Nombre-Puinave.md",
    "docs/05_Fase_Tecnologica/SPT-005/SPT-005-Guia-Cambio-Nombre-Visible.md"
  ],
  "governed_by": [
    "SGD-114-v2.0.1",
    "SGD-115-v1.0.1",
    "SPB-007",
    "SIB-001"
  ]
}
'@

$DocContent = @'
# SPT-005 — Sistema de Identidad Cultural Configurable

## Objetivo

Permitir que la plataforma, la aplicación y el asistente adopten un nombre
avalado por el pueblo Puinave sin renombrar la arquitectura técnica.

## Identidad técnica permanente

`SGODA-PUINAVE`

Se conserva en repositorio, namespaces, pruebas, APIs, trazabilidad,
releases y documentación histórica.

## Identidad visible configurable

Puede incluir:

- nombre público;
- nombre de la aplicación;
- nombre del asistente;
- nombre en Puinave;
- nombre en español;
- nombre en inglés;
- eslogan;
- logotipo;
- icono;
- idioma predeterminado.

## Clientes

La identidad activa se exporta para Flutter, web y API.
'@

$ProtocolContent = @'
# SPT-005 — Protocolo de Aprobación del Nombre Puinave

Un nombre Puinave solo puede activarse cuando exista:

1. propuesta documentada;
2. revisión lingüística;
3. revisión de significado cultural;
4. revisión de pronunciación;
5. aprobación de autoridades, sabedores o instancia comunitaria definida;
6. fecha de aprobación;
7. acta o documento verificable;
8. alcance comunitario de la decisión;
9. registro en el historial institucional;
10. publicación mediante SPB-007.

El sistema no genera ni inventa automáticamente nombres Puinave.
'@

$MigrationContent = @'
# SPT-005 — Guía de Cambio del Nombre Visible

## Procedimiento

1. Registrar un nuevo perfil de identidad.
2. Adjuntar la información de aprobación cultural.
3. Validar el perfil.
4. Activar el perfil.
5. Exportar configuración para Flutter, web y API.
6. Ejecutar pruebas visuales y funcionales.
7. Actualizar SGD-115.
8. Publicar mediante SPB-007.

## Elementos que no cambian

- repositorio Git;
- namespace `sgoda`;
- códigos institucionales;
- rutas de artefactos;
- historial;
- releases anteriores;
- identificadores canónicos.
'@

$InvokeContent = @'
[CmdletBinding()]
param(
    [ValidateSet("show", "export", "activate")]
    [string]$Command = "show",

    [string]$IdentityId = "",
    [string]$ChangedBy = "",
    [string]$Reason = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Repository = "config/identity/SPT-005-identities.json"

if ($Command -eq "show") {
    & python -m sgoda.identity.cli show `
        --repository $Repository
}
elseif ($Command -eq "export") {
    & python -m sgoda.identity.cli export `
        --repository $Repository
}
else {
    if ([string]::IsNullOrWhiteSpace($IdentityId)) {
        throw "IdentityId es obligatorio para activate."
    }
    if ([string]::IsNullOrWhiteSpace($ChangedBy)) {
        throw "ChangedBy es obligatorio para activate."
    }
    if ([string]::IsNullOrWhiteSpace($Reason)) {
        throw "Reason es obligatorio para activate."
    }

    & python -m sgoda.identity.cli activate `
        $IdentityId `
        --changed-by $ChangedBy `
        --reason $Reason `
        --repository $Repository
}

if ($LASTEXITCODE -ne 0) {
    throw "SPT-005 terminó con errores."
}
'@

Write-Step "Instalando SPT-005"

Write-Utf8NoBom -Path $ModelsPath -Content $ModelsContent
Write-Utf8NoBom -Path $RepositoryPath -Content $RepositoryContent
Write-Utf8NoBom -Path $ServicePath -Content $ServiceContent
Write-Utf8NoBom -Path $ExporterPath -Content $ExporterContent
Write-Utf8NoBom -Path $CliPath -Content $CliContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent

Write-Utf8NoBom -Path $PolicyPath -Content $PolicyContent
Write-Utf8NoBom -Path $BaselinePath -Content $BaselineContent
Write-Utf8NoBom -Path (Join-Path $ConfigDir "SPT-005-identities.json") -Content $BaselineContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentContent

Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $ProtocolPath -Content $ProtocolContent
Write-Utf8NoBom -Path $MigrationPath -Content $MigrationContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando evidencia y trazabilidad"

$Timestamp = [DateTime]::UtcNow.ToString("o")

Write-JsonUtf8 -Path $EvidencePath -Data ([ordered]@{
    increment_code = "SPT-005"
    version = "0.1.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    technical_identity = "SGODA-PUINAVE"
    public_identity_configurable = $true
    active_identity = "sgoda-puinave-baseline"
    puinave_name = $null
    puinave_name_status = "pending_community_approval"
    supported_clients = @("flutter", "web", "api")
})

Write-JsonUtf8 -Path $TracePath -Data ([ordered]@{
    increment_code = "SPT-005"
    source = @("src/sgoda/identity/")
    tests = @(
        "tests/identity/test_SPT_005_configurable_cultural_identity.py"
    )
    documentation = @(
        "docs/05_Fase_Tecnologica/SPT-005/SPT-005-Sistema-Identidad-Cultural-Configurable.md",
        "docs/05_Fase_Tecnologica/SPT-005/SPT-005-Protocolo-Aprobacion-Nombre-Puinave.md",
        "docs/05_Fase_Tecnologica/SPT-005/SPT-005-Guia-Cambio-Nombre-Visible.md"
    )
})

Write-Step "Validando sintaxis e importaciones"

& python -m py_compile `
    "src/sgoda/identity/models.py" `
    "src/sgoda/identity/repository.py" `
    "src/sgoda/identity/service.py" `
    "src/sgoda/identity/exporter.py" `
    "src/sgoda/identity/cli.py"

if ($LASTEXITCODE -ne 0) {
    throw "La compilación de SPT-005 falló."
}

& python -c "from sgoda.identity import IdentityProfile, IdentityRepository, IdentityService; print(IdentityProfile.__name__, IdentityRepository.__name__, IdentityService.__name__)"

if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de SPT-005."
}

Write-Step "Ejecutando 12 pruebas específicas SPT-005"

& python -m pytest `
    "tests/identity/test_SPT_005_configurable_cultural_identity.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SPT-005 fallaron."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest

    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

Write-Step "Exportando identidad base"

& python -m sgoda.identity.cli export `
    --repository "config/identity/SPT-005-identities.json" `
    --output "artifacts/identity/SPT-005/exports"

if ($LASTEXITCODE -ne 0) {
    throw "La exportación de identidad SPT-005 falló."
}

foreach ($Export in @(
    (Join-Path $ArtifactsDir "exports\flutter-identity.json"),
    (Join-Path $ArtifactsDir "exports\web-identity.json"),
    (Join-Path $ArtifactsDir "exports\api-identity.json")
)) {
    Assert-Path -Path $Export -Description $Export
}

Write-Step "Publicando release técnico"

New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($Artifact in @(
    $PolicyPath,
    $BaselinePath,
    $ComponentPath,
    $DocPath,
    $ProtocolPath,
    $MigrationPath,
    (Join-Path $ArtifactsDir "exports\flutter-identity.json"),
    (Join-Path $ArtifactsDir "exports\web-identity.json"),
    (Join-Path $ArtifactsDir "exports\api-identity.json")
)) {
    Copy-Item `
        -LiteralPath $Artifact `
        -Destination (Join-Path $ReleaseDir (Split-Path $Artifact -Leaf)) `
        -Force
}

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-005" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate SPT-005 no fue aprobado."
}

$Gate = Get-Content -LiteralPath $GatePath -Raw | ConvertFrom-Json
if (-not $Gate.passed) {
    throw "SPT-005 no contiene passed=true."
}

Write-JsonUtf8 -Path $DashboardPath -Data ([ordered]@{
    increment_code = "SPT-005"
    version = "0.1.0"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    technical_identity = "SGODA-PUINAVE"
    active_public_identity = "SGODA-PUINAVE"
    cultural_name_status = "pending_community_approval"
    specific_tests = 12
    supported_clients = 3
    identity_history = $true
    rollback_supported = $true
    quality_gate = "approved"
    release = "SPT-005-v0.1.0"
})

Write-Step "Actualizando documentación maestra SGD-115"

& python -m sgoda.documentation.master_docs `
    --root "$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"

if ($LASTEXITCODE -ne 0) {
    throw "La actualización SGD-115 falló."
}

Write-Step "Resultado final"

Write-Host "SPT-005 implementado y validado." -ForegroundColor Green
Write-Host "Sistema de Identidad Cultural: OPERATIVO." -ForegroundColor Green
Write-Host "Identidad técnica SGODA-PUINAVE: PRESERVADA." -ForegroundColor Green
Write-Host "Nombre visible configurable: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Aprobación comunitaria: OBLIGATORIA." -ForegroundColor Green
Write-Host "Historial de identidad: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Exportación Flutter/Web/API: APROBADA." -ForegroundColor Green
Write-Host "Pruebas específicas: 12 APROBADAS." -ForegroundColor Green
Write-Host "Quality gate: APROBADO." -ForegroundColor Green
Write-Host "Documentación maestra: ACTUALIZADA." -ForegroundColor Green
Write-Host "Release: releases\SPT-005-v0.1.0" -ForegroundColor Cyan
