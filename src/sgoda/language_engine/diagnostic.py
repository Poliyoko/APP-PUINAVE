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