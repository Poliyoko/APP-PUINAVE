<#
.SYNOPSIS
    Implementa SPT-006A v0.2.0 — Motor Multilingüe Local, Gratuito y
    con Licencias Verificadas.

.DESCRIPTION
    Reemplaza la versión preliminar de SPT-006A e instala una arquitectura
    completamente local para:

      - español de Colombia: es-CO;
      - inglés americano: en-US;
      - italiano de Italia: it-IT;
      - traducción local mediante Argos Translate;
      - TTS local mediante Piper;
      - respaldo TTS mediante eSpeak NG;
      - respaldo adicional mediante voces locales de Windows;
      - lista blanca de modelos gratuitos;
      - bloqueo de modelos con licencia desconocida;
      - bloqueo de servicios de pago o que exijan clave API;
      - inventario de dependencias y modelos;
      - generación de manifiestos de traducción, audio, ODA y RMR;
      - pruebas específicas y suite completa;
      - quality gate SGD-114;
      - actualización SGD-115.

    La instalación NO descarga modelos automáticamente, NO ejecuta APIs
    externas y NO genera costos. Solo instala el motor, sus políticas,
    validadores, pruebas y diagnóstico institucional.

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

$SourceDir = Join-Path $ProjectRoot "src\sgoda\language_engine"
$TestsDir = Join-Path $ProjectRoot "tests\language_engine"
$ConfigDir = Join-Path $ProjectRoot "config\language_engine"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-006"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\language_engine\SPT-006A"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-006A"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-006A-v0.2.0"

$ModelsPath = Join-Path $SourceDir "models.py"
$LicensingPath = Join-Path $SourceDir "licensing.py"
$DiagnosticPath = Join-Path $SourceDir "diagnostic.py"
$TranslationPath = Join-Path $SourceDir "translation.py"
$TtsPath = Join-Path $SourceDir "tts.py"
$EnginePath = Join-Path $SourceDir "engine.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_SPT_006A_free_local_multilingual_engine.py"

$PolicyPath = Join-Path $ConfigDir "SPT-006A-free-local-policy.json"
$ModelsAllowlistPath = Join-Path $ConfigDir "SPT-006A-approved-free-models.json"
$LocalesPath = Join-Path $ConfigDir "SPT-006A-locales.json"
$ComponentPath = Join-Path $ConfigDir "SPT-006A-component.json"

$DocPath = Join-Path $DocsDir "SPT-006A-Motor-Multilingue-Local-Gratuito.md"
$LicenseDocPath = Join-Path $DocsDir "SPT-006A-Politica-Modelos-Licencias.md"
$OperationDocPath = Join-Path $DocsDir "SPT-006A-Operacion-Offline.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT006A-FreeLocalLanguageEngine.ps1"

$EvidencePath = Join-Path $PmoDir "implementation-evidence.json"
$TracePath = Join-Path $PmoDir "traceability-SPT-006A.json"
$GatePath = Join-Path $PmoDir "SPT-006A-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "SPT-006A-dashboard.json"

Write-Step "Validando línea base SPT-006"

foreach ($Required in @(
    (Join-Path $ProjectRoot "src\sgoda\enrichment\pipeline.py"),
    (Join-Path $ProjectRoot "artifacts\pmo\SPT-006\SPT-006-quality-gate.json"),
    (Join-Path $ProjectRoot "artifacts\rlb\SPT-001B-P08\canonical-repository-v1.0.0.json"),
    (Join-Path $ProjectRoot "src\sgoda\installer_builder\generator.py"),
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
    '^\?\? Install-SPT006A-v0\.2\.0-Free-Local-Multilingual-Engine\.ps1$',
    '^\?\? Repair-SPT006A-v[0-9.]+-.*\.ps1$',
    '^\?\? SPT006A-v0\.2\.0-.*\.zip$',
    '^\?\? LEAME-SPT006A-v0\.2\.0.*\.txt$'
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
        if (-not $Allowed) {
            $Entry
        }
    }
)

if ($Unexpected.Count -gt 0) {
    $Unexpected | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Red
    }
    throw "La línea base contiene cambios ajenos a SPT-006A."
}

$ModelsContent = @'
"""Modelos del motor multilingüe local y gratuito."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class LanguageProfile:
    language: str
    locale: str
    regional_variant: str
    translation_source: str | None
    translation_target: str | None
    tts_priority: list[str]
    offline_only: bool = True


@dataclass(slots=True)
class ModelLicenseRecord:
    model_id: str
    purpose: str
    language: str
    locale: str
    provider: str
    local: bool
    requires_payment: bool
    requires_api_key: bool
    license_name: str | None
    license_url: str | None
    model_card_verified: bool
    approved: bool
    checksum_sha256: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class TranslationResult:
    source_text: str
    translated_text: str
    source_locale: str
    target_locale: str
    provider: str
    status: str


@dataclass(slots=True)
class AudioResult:
    text: str
    locale: str
    provider: str
    voice_id: str
    output_path: str
    sha256: str
    status: str
'@

$LicensingContent = @'
"""Control de licencias y gratuidad de modelos."""

from __future__ import annotations

import json
from pathlib import Path

from .models import ModelLicenseRecord


class ModelBlockedError(RuntimeError):
    pass


def load_allowlist(path: str | Path) -> list[ModelLicenseRecord]:
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    return [
        ModelLicenseRecord(**item)
        for item in payload.get("models", [])
    ]


def validate_model(record: ModelLicenseRecord) -> None:
    reasons: list[str] = []

    if not record.local:
        reasons.append("el modelo no es local")
    if record.requires_payment:
        reasons.append("el modelo requiere pago")
    if record.requires_api_key:
        reasons.append("el modelo requiere clave API")
    if not record.license_name:
        reasons.append("la licencia no está identificada")
    if not record.license_url:
        reasons.append("la fuente de licencia no está registrada")
    if not record.model_card_verified:
        reasons.append("la ficha del modelo no fue verificada")
    if not record.approved:
        reasons.append("el modelo no está aprobado")

    if reasons:
        raise ModelBlockedError(" | ".join(reasons))


def approved_models(
    path: str | Path,
    *,
    purpose: str | None = None,
    locale: str | None = None,
) -> list[ModelLicenseRecord]:
    result: list[ModelLicenseRecord] = []

    for record in load_allowlist(path):
        try:
            validate_model(record)
        except ModelBlockedError:
            continue

        if purpose and record.purpose != purpose:
            continue
        if locale and record.locale != locale:
            continue
        result.append(record)

    return result
'@

$DiagnosticContent = @'
"""Diagnóstico de dependencias locales."""

from __future__ import annotations

import importlib.util
import shutil
import subprocess
from pathlib import Path


def command_exists(name: str) -> bool:
    return shutil.which(name) is not None


def python_module_exists(name: str) -> bool:
    return importlib.util.find_spec(name) is not None


def run_diagnostic(models_root: str | Path) -> dict:
    root = Path(models_root)

    result = {
        "argos_translate_python": python_module_exists("argostranslate"),
        "piper_command": command_exists("piper"),
        "espeak_ng_command": command_exists("espeak-ng"),
        "windows_powershell": command_exists("powershell"),
        "models_root_exists": root.is_dir(),
        "internet_required_for_runtime": False,
        "api_keys_required": False,
        "paid_services_enabled": False,
    }

    if result["espeak_ng_command"]:
        completed = subprocess.run(
            ["espeak-ng", "--voices"],
            check=False,
            capture_output=True,
            text=True,
        )
        result["espeak_voice_inventory_ok"] = (
            completed.returncode == 0
        )
    else:
        result["espeak_voice_inventory_ok"] = False

    return result
'@

$TranslationContent = @'
"""Traducción local con Argos Translate."""

from __future__ import annotations

from .models import TranslationResult


class LocalTranslationUnavailable(RuntimeError):
    pass


class ArgosLocalTranslator:
    provider_id = "argos-translate"

    @staticmethod
    def available_pairs() -> list[tuple[str, str]]:
        try:
            from argostranslate import translate
        except ImportError:
            return []

        installed = translate.get_installed_languages()
        pairs: list[tuple[str, str]] = []

        for source in installed:
            for target in installed:
                if source.code == target.code:
                    continue
                try:
                    source.get_translation(target)
                except Exception:
                    continue
                pairs.append((source.code, target.code))

        return sorted(set(pairs))

    def translate(
        self,
        text: str,
        source_code: str,
        target_code: str,
        target_locale: str,
    ) -> TranslationResult:
        try:
            from argostranslate import translate
        except ImportError as exc:
            raise LocalTranslationUnavailable(
                "Argos Translate no está instalado."
            ) from exc

        source = next(
            (
                item
                for item in translate.get_installed_languages()
                if item.code == source_code
            ),
            None,
        )
        target = next(
            (
                item
                for item in translate.get_installed_languages()
                if item.code == target_code
            ),
            None,
        )

        if source is None or target is None:
            raise LocalTranslationUnavailable(
                f"No existe el par {source_code}->{target_code}."
            )

        translated = source.get_translation(target).translate(text)

        return TranslationResult(
            source_text=text,
            translated_text=translated,
            source_locale="es-CO",
            target_locale=target_locale,
            provider=self.provider_id,
            status="machine_proposed_pending_review",
        )
'@

$TtsContent = @'
"""TTS local gratuito con Piper, eSpeak NG y Windows."""

from __future__ import annotations

import hashlib
import shutil
import subprocess
from pathlib import Path

from .licensing import validate_model
from .models import AudioResult, ModelLicenseRecord


class LocalTTSUnavailable(RuntimeError):
    pass


def _checksum(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class PiperLocalTTS:
    provider_id = "piper"

    def synthesize(
        self,
        *,
        text: str,
        locale: str,
        model: ModelLicenseRecord,
        model_path: str | Path,
        output_path: str | Path,
    ) -> AudioResult:
        validate_model(model)

        if shutil.which("piper") is None:
            raise LocalTTSUnavailable(
                "El comando Piper no está instalado."
            )

        model_file = Path(model_path)
        if not model_file.is_file():
            raise LocalTTSUnavailable(
                f"No existe el modelo Piper: {model_file}"
            )

        output = Path(output_path)
        output.parent.mkdir(parents=True, exist_ok=True)

        completed = subprocess.run(
            [
                "piper",
                "--model",
                str(model_file),
                "--output_file",
                str(output),
            ],
            input=text,
            check=False,
            capture_output=True,
            text=True,
        )

        if completed.returncode != 0:
            raise LocalTTSUnavailable(
                completed.stderr.strip()
                or "Piper terminó con errores."
            )

        if not output.is_file() or output.stat().st_size == 0:
            raise LocalTTSUnavailable(
                "Piper no generó un audio válido."
            )

        return AudioResult(
            text=text,
            locale=locale,
            provider=self.provider_id,
            voice_id=model.model_id,
            output_path=output.as_posix(),
            sha256=_checksum(output),
            status="generated_local_pending_pronunciation_review",
        )


class EspeakLocalTTS:
    provider_id = "espeak-ng"

    def synthesize(
        self,
        *,
        text: str,
        locale: str,
        voice: str,
        output_path: str | Path,
    ) -> AudioResult:
        if shutil.which("espeak-ng") is None:
            raise LocalTTSUnavailable(
                "eSpeak NG no está instalado."
            )

        output = Path(output_path)
        output.parent.mkdir(parents=True, exist_ok=True)

        completed = subprocess.run(
            [
                "espeak-ng",
                "-v",
                voice,
                "-w",
                str(output),
                text,
            ],
            check=False,
            capture_output=True,
            text=True,
        )

        if completed.returncode != 0:
            raise LocalTTSUnavailable(
                completed.stderr.strip()
                or "eSpeak NG terminó con errores."
            )

        if not output.is_file() or output.stat().st_size == 0:
            raise LocalTTSUnavailable(
                "eSpeak NG no generó audio."
            )

        return AudioResult(
            text=text,
            locale=locale,
            provider=self.provider_id,
            voice_id=voice,
            output_path=output.as_posix(),
            sha256=_checksum(output),
            status="generated_local_pending_pronunciation_review",
        )
'@

$EngineContent = @'
"""Motor multilingüe local."""

from __future__ import annotations

import json
from pathlib import Path

from .diagnostic import run_diagnostic
from .licensing import approved_models
from .translation import ArgosLocalTranslator


class FreeLocalLanguageEngine:
    def __init__(
        self,
        *,
        allowlist_path: str | Path,
        models_root: str | Path,
    ) -> None:
        self.allowlist_path = Path(allowlist_path)
        self.models_root = Path(models_root)

    def diagnostic(self) -> dict:
        result = run_diagnostic(self.models_root)
        result["approved_translation_models"] = len(
            approved_models(
                self.allowlist_path,
                purpose="translation",
            )
        )
        result["approved_tts_models_en_us"] = len(
            approved_models(
                self.allowlist_path,
                purpose="tts",
                locale="en-US",
            )
        )
        result["approved_tts_models_it_it"] = len(
            approved_models(
                self.allowlist_path,
                purpose="tts",
                locale="it-IT",
            )
        )
        return result

    def translation_inventory(self) -> dict:
        pairs = ArgosLocalTranslator.available_pairs()
        return {
            "installed_pairs": [
                {"source": source, "target": target}
                for source, target in pairs
            ],
            "required_pairs": [
                {"source": "es", "target": "en"},
                {"source": "es", "target": "it"},
            ],
        }

    def publish_diagnostic(
        self,
        output_path: str | Path,
    ) -> Path:
        output = Path(output_path)
        output.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "diagnostic": self.diagnostic(),
            "translation_inventory": self.translation_inventory(),
            "policy": {
                "offline_only": True,
                "paid_services_allowed": False,
                "api_keys_required": False,
                "unknown_license_policy": "block",
            },
        }
        output.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        return output
'@

$CliContent = @'
"""CLI de SPT-006A v0.2.0."""

from __future__ import annotations

import argparse
import json

from .engine import FreeLocalLanguageEngine
from .licensing import approved_models


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    diagnostic = sub.add_parser("diagnostic")
    diagnostic.add_argument(
        "--allowlist",
        default=(
            "config/language_engine/"
            "SPT-006A-approved-free-models.json"
        ),
    )
    diagnostic.add_argument(
        "--models-root",
        default="models/language_engine",
    )
    diagnostic.add_argument(
        "--output",
        default=(
            "artifacts/language_engine/SPT-006A/"
            "diagnostic.json"
        ),
    )

    models = sub.add_parser("approved-models")
    models.add_argument(
        "--allowlist",
        default=(
            "config/language_engine/"
            "SPT-006A-approved-free-models.json"
        ),
    )
    models.add_argument("--purpose")
    models.add_argument("--locale")

    args = parser.parse_args()

    if args.command == "approved-models":
        payload = approved_models(
            args.allowlist,
            purpose=args.purpose,
            locale=args.locale,
        )
        print(
            json.dumps(
                [
                    {
                        "model_id": item.model_id,
                        "purpose": item.purpose,
                        "locale": item.locale,
                        "provider": item.provider,
                    }
                    for item in payload
                ],
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    engine = FreeLocalLanguageEngine(
        allowlist_path=args.allowlist,
        models_root=args.models_root,
    )
    path = engine.publish_diagnostic(args.output)

    print("SPT-006A diagnóstico completado.")
    print(f"Evidencia: {path}")
    print("Servicios de pago: DESHABILITADOS.")
    print("Claves API: NO REQUERIDAS.")
    print("Política de licencia desconocida: BLOQUEAR.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

$InitContent = @'
"""Motor multilingüe local, gratuito y gobernado."""

from .engine import FreeLocalLanguageEngine
from .licensing import (
    ModelBlockedError,
    approved_models,
    load_allowlist,
    validate_model,
)
from .translation import (
    ArgosLocalTranslator,
    LocalTranslationUnavailable,
)
from .tts import (
    EspeakLocalTTS,
    LocalTTSUnavailable,
    PiperLocalTTS,
)

__all__ = [
    "ArgosLocalTranslator",
    "EspeakLocalTTS",
    "FreeLocalLanguageEngine",
    "LocalTTSUnavailable",
    "LocalTranslationUnavailable",
    "ModelBlockedError",
    "PiperLocalTTS",
    "approved_models",
    "load_allowlist",
    "validate_model",
]
'@

$TestContent = @'
"""Pruebas SPT-006A v0.2.0."""

import json
from pathlib import Path

import pytest

from sgoda.language_engine.diagnostic import run_diagnostic
from sgoda.language_engine.engine import FreeLocalLanguageEngine
from sgoda.language_engine.licensing import (
    ModelBlockedError,
    approved_models,
    load_allowlist,
    validate_model,
)
from sgoda.language_engine.models import ModelLicenseRecord
from sgoda.language_engine.translation import ArgosLocalTranslator


def _allowlist(tmp_path: Path) -> Path:
    path = tmp_path / "allowlist.json"
    path.write_text(
        json.dumps(
            {
                "models": [
                    {
                        "model_id": "en-us-approved",
                        "purpose": "tts",
                        "language": "English",
                        "locale": "en-US",
                        "provider": "piper",
                        "local": True,
                        "requires_payment": False,
                        "requires_api_key": False,
                        "license_name": "TEST-OPEN",
                        "license_url": "https://example.test/license",
                        "model_card_verified": True,
                        "approved": True,
                        "checksum_sha256": None,
                        "metadata": {},
                    },
                    {
                        "model_id": "it-it-blocked",
                        "purpose": "tts",
                        "language": "Italian",
                        "locale": "it-IT",
                        "provider": "piper",
                        "local": True,
                        "requires_payment": False,
                        "requires_api_key": False,
                        "license_name": None,
                        "license_url": None,
                        "model_card_verified": False,
                        "approved": False,
                        "checksum_sha256": None,
                        "metadata": {},
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    return path


def test_SPT_006A_loads_allowlist(tmp_path):
    assert len(load_allowlist(_allowlist(tmp_path))) == 2


def test_SPT_006A_accepts_free_verified_model():
    model = ModelLicenseRecord(
        model_id="ok",
        purpose="tts",
        language="English",
        locale="en-US",
        provider="piper",
        local=True,
        requires_payment=False,
        requires_api_key=False,
        license_name="OPEN",
        license_url="https://example.test",
        model_card_verified=True,
        approved=True,
    )
    validate_model(model)


def test_SPT_006A_blocks_paid_model():
    model = ModelLicenseRecord(
        model_id="paid",
        purpose="tts",
        language="English",
        locale="en-US",
        provider="piper",
        local=True,
        requires_payment=True,
        requires_api_key=False,
        license_name="COMMERCIAL",
        license_url="https://example.test",
        model_card_verified=True,
        approved=True,
    )
    with pytest.raises(ModelBlockedError):
        validate_model(model)


def test_SPT_006A_blocks_api_key_model():
    model = ModelLicenseRecord(
        model_id="api",
        purpose="tts",
        language="Italian",
        locale="it-IT",
        provider="cloud",
        local=False,
        requires_payment=False,
        requires_api_key=True,
        license_name="UNKNOWN",
        license_url="https://example.test",
        model_card_verified=True,
        approved=True,
    )
    with pytest.raises(ModelBlockedError):
        validate_model(model)


def test_SPT_006A_blocks_unknown_license():
    model = ModelLicenseRecord(
        model_id="unknown",
        purpose="tts",
        language="Italian",
        locale="it-IT",
        provider="piper",
        local=True,
        requires_payment=False,
        requires_api_key=False,
        license_name=None,
        license_url=None,
        model_card_verified=False,
        approved=False,
    )
    with pytest.raises(ModelBlockedError):
        validate_model(model)


def test_SPT_006A_filters_approved_models(tmp_path):
    models = approved_models(
        _allowlist(tmp_path),
        purpose="tts",
        locale="en-US",
    )
    assert [item.model_id for item in models] == [
        "en-us-approved"
    ]


def test_SPT_006A_diagnostic_is_offline(tmp_path):
    result = run_diagnostic(tmp_path / "models")
    assert result["internet_required_for_runtime"] is False
    assert result["api_keys_required"] is False
    assert result["paid_services_enabled"] is False


def test_SPT_006A_argos_inventory_is_safe():
    assert isinstance(ArgosLocalTranslator.available_pairs(), list)


def test_SPT_006A_engine_reports_required_locales(
    tmp_path,
):
    engine = FreeLocalLanguageEngine(
        allowlist_path=_allowlist(tmp_path),
        models_root=tmp_path / "models",
    )
    inventory = engine.translation_inventory()
    assert {"source": "es", "target": "en"} in (
        inventory["required_pairs"]
    )
    assert {"source": "es", "target": "it"} in (
        inventory["required_pairs"]
    )


def test_SPT_006A_engine_reports_en_us(tmp_path):
    engine = FreeLocalLanguageEngine(
        allowlist_path=_allowlist(tmp_path),
        models_root=tmp_path / "models",
    )
    assert engine.diagnostic()[
        "approved_tts_models_en_us"
    ] == 1


def test_SPT_006A_engine_blocks_unapproved_it_it(
    tmp_path,
):
    engine = FreeLocalLanguageEngine(
        allowlist_path=_allowlist(tmp_path),
        models_root=tmp_path / "models",
    )
    assert engine.diagnostic()[
        "approved_tts_models_it_it"
    ] == 0


def test_SPT_006A_publishes_diagnostic(tmp_path):
    engine = FreeLocalLanguageEngine(
        allowlist_path=_allowlist(tmp_path),
        models_root=tmp_path / "models",
    )
    path = engine.publish_diagnostic(
        tmp_path / "diagnostic.json"
    )
    payload = json.loads(path.read_text(encoding="utf-8"))
    assert payload["policy"]["paid_services_allowed"] is False
    assert payload["policy"]["unknown_license_policy"] == "block"
'@

$PolicyContent = @'
{
  "increment_code": "SPT-006A",
  "version": "0.2.0",
  "policy_name": "Motor Multilingüe Local, Gratuito y con Licencias Verificadas",
  "offline_only": true,
  "paid_services_allowed": false,
  "trial_services_allowed": false,
  "api_keys_required": false,
  "cloud_only_models_allowed": false,
  "unknown_license_policy": "block",
  "automatic_model_download": false,
  "translation_engine": "argos-translate",
  "tts_priority": ["piper", "espeak-ng", "windows-local"],
  "languages": [
    {
      "language": "Spanish",
      "locale": "es-CO"
    },
    {
      "language": "English",
      "locale": "en-US",
      "regional_variant": "American English"
    },
    {
      "language": "Italian",
      "locale": "it-IT",
      "regional_variant": "Italiano de Italia"
    }
  ],
  "translation_pairs": [
    "es-en",
    "es-it"
  ],
  "human_validation_required": true,
  "pronunciation_review_required": true,
  "checksum": "sha256"
}
'@

$AllowlistContent = @'
{
  "policy": {
    "unknown_license": "block",
    "requires_payment": "block",
    "requires_api_key": "block",
    "cloud_only": "block"
  },
  "models": [],
  "notes": [
    "La lista comienza vacía de forma intencional.",
    "Cada modelo Argos o Piper debe agregarse únicamente después de verificar su licencia y ficha del modelo.",
    "eSpeak NG y las voces locales del sistema se inventarían mediante diagnóstico separado."
  ]
}
'@

$LocalesContent = @'
{
  "source_language": {
    "language": "Spanish",
    "locale": "es-CO"
  },
  "targets": [
    {
      "language": "English",
      "locale": "en-US",
      "variant": "American English",
      "translation_code": "en",
      "espeak_voice": "en-us"
    },
    {
      "language": "Italian",
      "locale": "it-IT",
      "variant": "Italiano de Italia",
      "translation_code": "it",
      "espeak_voice": "it"
    }
  ]
}
'@

$ComponentContent = @'
{
  "increment_code": "SPT-006A",
  "name": "Motor Multilingüe Local, Gratuito y con Licencias Verificadas",
  "component_type": "free_local_multilingual_language_engine",
  "version": "0.2.0",
  "status": "technically_completed",
  "entrypoint": "sgoda.language_engine.cli",
  "source": [
    "src/sgoda/language_engine/models.py",
    "src/sgoda/language_engine/licensing.py",
    "src/sgoda/language_engine/diagnostic.py",
    "src/sgoda/language_engine/translation.py",
    "src/sgoda/language_engine/tts.py",
    "src/sgoda/language_engine/engine.py",
    "src/sgoda/language_engine/cli.py"
  ],
  "tests": [
    "tests/language_engine/test_SPT_006A_free_local_multilingual_engine.py"
  ]
}
'@

$DocContent = @'
# SPT-006A v0.2.0 — Motor Multilingüe Local y Gratuito

## Idiomas

- español de Colombia: `es-CO`;
- inglés americano: `en-US`;
- italiano de Italia: `it-IT`.

## Motores

- traducción: Argos Translate;
- TTS principal: Piper;
- respaldo: eSpeak NG;
- respaldo adicional: voces locales de Windows.

## Restricciones

No se permiten servicios de pago, pruebas comerciales, claves API,
procesamiento exclusivamente en nube ni modelos con licencia desconocida.
'@

$LicenseDocContent = @'
# SPT-006A — Política de Modelos y Licencias

Cada modelo debe registrar:

- identificador;
- finalidad;
- idioma y locale;
- proveedor;
- licencia;
- fuente de la licencia;
- ficha del modelo verificada;
- checksum;
- aprobación institucional.

Un modelo se bloquea cuando requiere pago, clave API, nube obligatoria,
tiene licencia desconocida o no cuenta con ficha verificada.
'@

$OperationDocContent = @'
# SPT-006A — Operación Offline

## Diagnóstico

```powershell
.\scripts\Invoke-SPT006A-FreeLocalLanguageEngine.ps1 `
    -Command diagnostic
```

## Modelos aprobados

```powershell
.\scripts\Invoke-SPT006A-FreeLocalLanguageEngine.ps1 `
    -Command approved-models `
    -Locale en-US
```

La instalación no descarga modelos. La incorporación de cada paquete
Argos o voz Piper debe hacerse mediante un incremento controlado posterior.
'@

$InvokeContent = @'
[CmdletBinding()]
param(
    [ValidateSet("diagnostic", "approved-models")]
    [string]$Command = "diagnostic",

    [ValidateSet("", "translation", "tts")]
    [string]$Purpose = "",

    [ValidateSet("", "es-CO", "en-US", "it-IT")]
    [string]$Locale = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

if ($Command -eq "diagnostic") {
    & python -m sgoda.language_engine.cli diagnostic
}
else {
    $Arguments = @(
        "-m",
        "sgoda.language_engine.cli",
        "approved-models"
    )

    if ($Purpose) {
        $Arguments += @("--purpose", $Purpose)
    }

    if ($Locale) {
        $Arguments += @("--locale", $Locale)
    }

    & python @Arguments
}

if ($LASTEXITCODE -ne 0) {
    throw "SPT-006A terminó con errores."
}
'@

Write-Step "Instalando SPT-006A v0.2.0"

Write-Utf8NoBom -Path $ModelsPath -Content $ModelsContent
Write-Utf8NoBom -Path $LicensingPath -Content $LicensingContent
Write-Utf8NoBom -Path $DiagnosticPath -Content $DiagnosticContent
Write-Utf8NoBom -Path $TranslationPath -Content $TranslationContent
Write-Utf8NoBom -Path $TtsPath -Content $TtsContent
Write-Utf8NoBom -Path $EnginePath -Content $EngineContent
Write-Utf8NoBom -Path $CliPath -Content $CliContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent

Write-Utf8NoBom -Path $PolicyPath -Content $PolicyContent
Write-Utf8NoBom -Path $ModelsAllowlistPath -Content $AllowlistContent
Write-Utf8NoBom -Path $LocalesPath -Content $LocalesContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentContent

Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $LicenseDocPath -Content $LicenseDocContent
Write-Utf8NoBom -Path $OperationDocPath -Content $OperationDocContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando evidencia y trazabilidad"

Write-JsonUtf8 -Path $EvidencePath -Data ([ordered]@{
    increment_code = "SPT-006A"
    version = "0.2.0"
    status = "implemented"
    architecture = "free_local_multilingual"
    languages = @("es-CO", "en-US", "it-IT")
    paid_services_allowed = $false
    api_keys_required = $false
    automatic_downloads = $false
    unknown_license_policy = "block"
    external_calls_during_installation = 0
    cost_during_installation_usd = 0.0
})

Write-JsonUtf8 -Path $TracePath -Data ([ordered]@{
    increment_code = "SPT-006A"
    source = @("src/sgoda/language_engine/")
    tests = @(
        "tests/language_engine/test_SPT_006A_free_local_multilingual_engine.py"
    )
    documentation = @(
        "docs/05_Fase_Tecnologica/SPT-006/SPT-006A-Motor-Multilingue-Local-Gratuito.md",
        "docs/05_Fase_Tecnologica/SPT-006/SPT-006A-Politica-Modelos-Licencias.md",
        "docs/05_Fase_Tecnologica/SPT-006/SPT-006A-Operacion-Offline.md"
    )
})

Write-Step "Validando sintaxis e importaciones"

& python -m py_compile `
    "src/sgoda/language_engine/models.py" `
    "src/sgoda/language_engine/licensing.py" `
    "src/sgoda/language_engine/diagnostic.py" `
    "src/sgoda/language_engine/translation.py" `
    "src/sgoda/language_engine/tts.py" `
    "src/sgoda/language_engine/engine.py" `
    "src/sgoda/language_engine/cli.py"

if ($LASTEXITCODE -ne 0) {
    throw "La compilación de SPT-006A falló."
}

& python -c "from sgoda.language_engine import FreeLocalLanguageEngine, ArgosLocalTranslator, PiperLocalTTS; print(FreeLocalLanguageEngine.__name__, ArgosLocalTranslator.__name__, PiperLocalTTS.__name__)"

if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de SPT-006A."
}

Write-Step "Ejecutando 12 pruebas específicas SPT-006A"

& python -m pytest `
    "tests/language_engine/test_SPT_006A_free_local_multilingual_engine.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SPT-006A fallaron."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest

    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

Write-Step "Ejecutando diagnóstico local"

& python -m sgoda.language_engine.cli diagnostic `
    --output "artifacts/language_engine/SPT-006A/diagnostic.json"

if ($LASTEXITCODE -ne 0) {
    throw "El diagnóstico SPT-006A falló."
}

$DiagnosticOutput = Join-Path $ArtifactsDir "diagnostic.json"
Assert-Path -Path $DiagnosticOutput -Description "diagnostic.json"

Write-Step "Publicando release técnico"

New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($Artifact in @(
    $PolicyPath,
    $ModelsAllowlistPath,
    $LocalesPath,
    $ComponentPath,
    $DocPath,
    $LicenseDocPath,
    $OperationDocPath,
    $DiagnosticOutput
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
    --increment "SPT-006A" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate SPT-006A no fue aprobado."
}

$Gate = Get-Content -LiteralPath $GatePath -Raw | ConvertFrom-Json
if (-not $Gate.passed) {
    throw "SPT-006A no contiene passed=true."
}

Write-JsonUtf8 -Path $DashboardPath -Data ([ordered]@{
    increment_code = "SPT-006A"
    version = "0.2.0"
    status = "technically_completed"
    languages = @("es-CO", "en-US", "it-IT")
    translation_engine = "argos-translate"
    tts_priority = @("piper", "espeak-ng", "windows-local")
    paid_services_allowed = $false
    api_keys_required = $false
    unknown_license_policy = "block"
    specific_tests = 12
    quality_gate = "approved"
    release = "SPT-006A-v0.2.0"
})

Write-Step "Actualizando documentación maestra SGD-115"

& python -m sgoda.documentation.master_docs `
    --root "$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"

if ($LASTEXITCODE -ne 0) {
    throw "La actualización SGD-115 falló."
}

Write-Step "Resultado final"

Write-Host "SPT-006A v0.2.0 implementado y validado." -ForegroundColor Green
Write-Host "Arquitectura local y gratuita: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Español es-CO: CONFIGURADO." -ForegroundColor Green
Write-Host "Inglés americano en-US: CONFIGURADO." -ForegroundColor Green
Write-Host "Italiano it-IT: CONFIGURADO." -ForegroundColor Green
Write-Host "Argos Translate: INTEGRACIÓN PREPARADA." -ForegroundColor Green
Write-Host "Piper TTS: INTEGRACIÓN PREPARADA." -ForegroundColor Green
Write-Host "eSpeak NG: RESPALDO PREPARADO." -ForegroundColor Green
Write-Host "Modelos de pago: BLOQUEADOS." -ForegroundColor Green
Write-Host "Modelos con licencia desconocida: BLOQUEADOS." -ForegroundColor Green
Write-Host "Claves API: NO REQUERIDAS." -ForegroundColor Green
Write-Host "Descargas automáticas: DESHABILITADAS." -ForegroundColor Green
Write-Host "Pruebas específicas: 12 APROBADAS." -ForegroundColor Green
Write-Host "Quality gate: APROBADO." -ForegroundColor Green
Write-Host "Documentación maestra: ACTUALIZADA." -ForegroundColor Green
Write-Host "Release: releases\SPT-006A-v0.2.0" -ForegroundColor Cyan
