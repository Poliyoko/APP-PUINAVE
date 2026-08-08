"""Executor seguro SPT-022 para componentes institucionales existentes."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Optional

from .platform import AutomationPlatform


class InstitutionalExecutor:
    def __init__(self, project_root: Path) -> None:
        self.project_root = Path(project_root).resolve()
        self.platform = AutomationPlatform(self.project_root)

    def _run(
        self,
        args: list[str],
        timeout: int = 1800,
    ) -> Dict[str, Any]:
        env = os.environ.copy()
        env["PYTHONPATH"] = str(self.project_root / "src")
        completed = subprocess.run(
            args,
            cwd=str(self.project_root),
            env=env,
            capture_output=True,
            text=True,
            timeout=timeout,
            shell=False,
        )
        return {
            "exit_code": completed.returncode,
            "stdout": completed.stdout[-20000:],
            "stderr": completed.stderr[-20000:],
            "success": completed.returncode == 0,
        }

    def execute(
        self,
        operation_id: str,
        payload: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        payload = payload or {}
        self.platform.get(operation_id)

        if operation_id == "data-intake":
            excel = str(payload.get("excel", "")).strip()
            if not excel:
                return {
                    "success": False,
                    "status": "REQUIRES_INPUT",
                    "message": "Se requiere payload.excel.",
                }
            excel_path = Path(excel)
            if not excel_path.is_absolute():
                excel_path = self.project_root / excel_path
            if not excel_path.exists():
                return {
                    "success": False,
                    "status": "INPUT_NOT_FOUND",
                    "message": str(excel_path),
                }
            return self._run(
                [
                    sys.executable,
                    "-m",
                    "sgoda.rlb.cli",
                    "--excel",
                    str(excel_path),
                ]
            )

        powershell = os.environ.get(
            "WINDIR",
            r"C:\Windows",
        )
        ps_exe = str(
            Path(powershell)
            / "System32"
            / "WindowsPowerShell"
            / "v1.0"
            / "powershell.exe"
        )

        if operation_id == "master-book-update":
            script = (
                self.project_root
                / "tools"
                / "institutional"
                / "Invoke-SGD002-AutoUpdate.ps1"
            )
            return self._run(
                [
                    ps_exe,
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(script),
                    "-ProjectRoot",
                    str(self.project_root),
                ]
            )

        if operation_id == "repository-prepare":
            script = (
                self.project_root
                / "tools"
                / "institutional"
                / "Publish-SGODA-WithMasterBook.ps1"
            )
            return self._run(
                [
                    ps_exe,
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(script),
                    "-PrepareOnly",
                ]
            )

        if operation_id == "repository-publish":
            if payload.get("approved") is not True:
                return {
                    "success": False,
                    "status": "APPROVAL_REQUIRED",
                    "message": (
                        "repository-publish requiere approved=true."
                    ),
                }
            script = (
                self.project_root
                / "tools"
                / "institutional"
                / "Publish-SGODA-WithMasterBook.ps1"
            )
            return self._run(
                [
                    ps_exe,
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(script),
                ]
            )

        if operation_id == "repository-audit":
            script = (
                self.project_root
                / "scripts"
                / "Invoke-SPB0032-ModularAudit.ps1"
            )
            if not script.exists():
                return {
                    "success": False,
                    "status": "AUDITOR_SCRIPT_NOT_FOUND",
                    "message": str(script),
                }
            return self._run(
                [
                    ps_exe,
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(script),
                ]
            )

        return {
            "success": False,
            "status": "UNKNOWN_OPERATION",
            "message": operation_id,
        }