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