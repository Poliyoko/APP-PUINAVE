from __future__ import annotations

import hashlib
import shlex
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .validators import validate_image_file, validate_wav_file


@dataclass(frozen=True)
class ExecutionResult:
    resource_id: str
    resource_type: str
    status: str
    output_path: str
    sha256: str
    validation: dict[str, object]
    provider: str
    reused: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "resource_id": self.resource_id,
            "resource_type": self.resource_type,
            "status": self.status,
            "output_path": self.output_path,
            "sha256": self.sha256,
            "validation": dict(self.validation),
            "provider": self.provider,
            "reused": self.reused,
        }


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def _render_command(template: str, values: dict[str, str]) -> list[str]:
    rendered = template
    for key, value in values.items():
        rendered = rendered.replace("{" + key + "}", value)

    # Windows CreateProcess receives argv, not a shell command string.
    # shlex.split(..., posix=False) preserves the surrounding quotes on a
    # quoted executable path, which makes Windows try to execute a filename
    # that literally starts with a quote and can produce WinError 5.
    # posix=True removes grouping quotes while preserving paths with spaces.
    return shlex.split(rendered, posix=True)


class LocalMultimediaExecutor:
    """Ejecutor gobernado exclusivamente por comandos locales configurados.

    No contiene URLs, SDKs remotos ni credenciales. La ejecuciÃ³n externa queda
    limitada a comandos locales definidos por la configuraciÃ³n institucional.
    """

    def __init__(
        self,
        *,
        image_command: str | None = None,
        tts_command: str | None = None,
    ) -> None:
        self.image_command = (image_command or "").strip() or None
        self.tts_command = (tts_command or "").strip() or None

    def _run_local(
        self,
        *,
        command_template: str,
        values: dict[str, str],
        output: Path,
    ) -> None:
        command = _render_command(command_template, values)
        if not command:
            raise ValueError("Local provider command is empty.")

        output.parent.mkdir(parents=True, exist_ok=True)

        completed = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=120,
        )
        if completed.returncode != 0:
            raise RuntimeError(
                "Local provider failed: "
                + (completed.stderr or completed.stdout or "").strip()
            )
        if not output.is_file():
            raise RuntimeError("Local provider did not create the expected output.")

    def execute_image(
        self,
        *,
        resource_id: str,
        lexical_id: str,
        puinave: str,
        prompt: str,
        output_path: str | Path,
    ) -> ExecutionResult:
        if self.image_command is None:
            raise RuntimeError("No local image provider is configured.")

        output = Path(output_path)
        self._run_local(
            command_template=self.image_command,
            values={
                "resource_id": resource_id,
                "lexical_id": lexical_id,
                "puinave": puinave,
                "prompt": prompt,
                "output": str(output),
            },
            output=output,
        )
        validation = validate_image_file(output)
        return ExecutionResult(
            resource_id=resource_id,
            resource_type="image",
            status="GENERATED_LOCAL",
            output_path=str(output),
            sha256=_sha256(output),
            validation=validation,
            provider="LOCAL_IMAGE_COMMAND",
        )

    def execute_tts(
        self,
        *,
        resource_id: str,
        lexical_id: str,
        resource_type: str,
        language: str,
        text: str,
        output_path: str | Path,
    ) -> ExecutionResult:
        if self.tts_command is None:
            raise RuntimeError("No local TTS provider is configured.")

        output = Path(output_path)
        self._run_local(
            command_template=self.tts_command,
            values={
                "resource_id": resource_id,
                "lexical_id": lexical_id,
                "resource_type": resource_type,
                "language": language,
                "text": text,
                "output": str(output),
            },
            output=output,
        )
        validation = validate_wav_file(output)
        return ExecutionResult(
            resource_id=resource_id,
            resource_type=resource_type,
            status="GENERATED_LOCAL",
            output_path=str(output),
            sha256=_sha256(output),
            validation=validation,
            provider="FREE_LOCAL_TTS_COMMAND",
        )

    def import_native_audio(
        self,
        *,
        resource_id: str,
        lexical_id: str,
        source_path: str | Path,
        output_path: str | Path,
    ) -> ExecutionResult:
        source = Path(source_path)
        validation_source = validate_wav_file(source)

        output = Path(output_path)
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, output)

        validation = validate_wav_file(output)
        if validation["size_bytes"] != validation_source["size_bytes"]:
            raise RuntimeError("Native audio copy size mismatch.")

        return ExecutionResult(
            resource_id=resource_id,
            resource_type="audio_puinave",
            status="IMPORTED_NATIVE",
            output_path=str(output),
            sha256=_sha256(output),
            validation=validation,
            provider="NATIVE_HUMAN_RECORDING",
        )
