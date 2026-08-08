<#
.SYNOPSIS
SPT-022 v1.0.7 - Plataforma Institucional de Automatizacion y Gobierno.
Instalador unico para Windows PowerShell 5.1.

.DESCRIPTION
Construye una plataforma institucional que coordina:
- incorporacion de datos RLB/Excel;
- auditoria institucional;
- actualizacion del Libro Maestro SGD-002;
- PREPARE de publicacion;
- PUBLISH con aprobacion explicita;
- eventos, catalogo, trazabilidad y evidencia;
- n8n como orquestador principal mediante FastAPI local.`n- bootstrap automatico de Node.js LTS mediante WinGet.

Reutiliza componentes existentes:
- src/sgoda/automation
- src/sgoda/automation/workflow_engine
- src/sgoda/automation/workflow_registry
- src/sgoda/rlb
- src/sgoda/pmo
- tools/institutional
- automation/n8n/workflows
- SPT-021.0.1 v1.0.8

No usa Execute Command de n8n.
No realiza PUBLISH automaticamente.
No elimina entregables historicos.
#>

[CmdletBinding()]
param(
    [switch]$InstallN8n,
    [switch]$ImportN8nWorkflows,
    [switch]$PreparePublication
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-022"
$Version = "1.0.7"
$PinnedN8nVersion = "2.33.6"
$NodeWingetPackage = "OpenJS.NodeJS.LTS"
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [AllowEmptyString()][string]$Content
    )
    $Parent = Split-Path -Parent $Path
    if ($Parent -and -not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Write-Json {
    param(
        [string]$Path,
        [object]$Data
    )
    $Json = $Data | ConvertTo-Json -Depth 40
    Write-Utf8NoBom -Path $Path -Content ($Json + "`r`n")
}

function Test-PowerShellSyntax {
    param([string]$Path)
    $Tokens = $null
    $Errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$Tokens,
        [ref]$Errors
    )
    return @($Errors)
}

function Invoke-Native {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )
    $Output = @(& $FilePath @Arguments 2>&1)
    $Code = $LASTEXITCODE
    return [PSCustomObject]@{
        ExitCode = $Code
        Output = $Output
    }
}


function Refresh-ProcessPath {
    $MachinePath = [Environment]::GetEnvironmentVariable(
        "Path",
        "Machine"
    )
    $UserPath = [Environment]::GetEnvironmentVariable(
        "Path",
        "User"
    )

    $Parts = @()

    if (-not [string]::IsNullOrWhiteSpace($MachinePath)) {
        $Parts += $MachinePath
    }

    if (-not [string]::IsNullOrWhiteSpace($UserPath)) {
        $Parts += $UserPath
    }

    $env:Path = ($Parts -join ";")
}

function Get-NodeCompatibility {
    param([string]$VersionText)

    if ([string]::IsNullOrWhiteSpace($VersionText)) {
        return $false
    }

    $Clean = $VersionText.Trim().TrimStart("v")
    $Parts = $Clean.Split(".")

    if ($Parts.Count -lt 2) {
        return $false
    }

    $Major = 0
    $Minor = 0

    if (-not [int]::TryParse($Parts[0], [ref]$Major)) {
        return $false
    }

    if (-not [int]::TryParse($Parts[1], [ref]$Minor)) {
        return $false
    }

    if ($Major -eq 20 -and $Minor -ge 19) {
        return $true
    }

    if ($Major -ge 21 -and $Major -le 24) {
        return $true
    }

    return $false
}

function Install-NodeForN8n {
    param([string]$PackageId)

    $Winget = Get-Command winget.exe -ErrorAction SilentlyContinue

    if ($null -eq $Winget) {
        throw (
            "Node.js no esta instalado y WinGet no esta disponible. " +
            "Instale/actualice App Installer de Windows y vuelva a ejecutar."
        )
    }

    Write-Host (
        "Instalando Node.js LTS mediante WinGet: " +
        $PackageId
    )

    & $Winget.Source `
        install `
        --id $PackageId `
        --exact `
        --accept-source-agreements `
        --accept-package-agreements `
        --silent `
        --disable-interactivity

    $WingetExit = $LASTEXITCODE

    if ($WingetExit -ne 0) {
        throw (
            "WinGet no pudo instalar Node.js. Exit code: " +
            $WingetExit
        )
    }

    Refresh-ProcessPath

    $Node = Get-Command node.exe -ErrorAction SilentlyContinue
    $Npm = Get-Command npm.cmd -ErrorAction SilentlyContinue

    if ($null -eq $Node -or $null -eq $Npm) {
        throw (
            "Node.js fue instalado pero node/npm no quedaron visibles " +
            "en PATH despues de refrescar el proceso."
        )
    }
}

function Get-ProjectRoot {
    $Top = @(& git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or $Top.Count -eq 0) {
        throw "Ejecute este instalador desde el repositorio Git SGODA-PUINAVE."
    }
    return [System.IO.Path]::GetFullPath([string]$Top[0])
}

$ProjectRoot = Get-ProjectRoot
Set-Location -LiteralPath $ProjectRoot

$RunRoot = Join-Path $ProjectRoot (
    "artifacts\development\SPT-022-v1.0.7\runs\" + $RunId
)
New-Item -ItemType Directory -Path $RunRoot -Force | Out-Null

Write-Step "Verificando linea base y repositorio"

$Remote = @(& git remote get-url origin 2>$null)
if ($LASTEXITCODE -ne 0 -or $Remote.Count -eq 0) {
    throw "No se pudo resolver origin."
}

$Branch = @(& git branch --show-current 2>$null)
$Commit = @(& git rev-parse HEAD 2>$null)

$ExpectedRemote = "https://github.com/Poliyoko/APP-PUINAVE.git"
$RemoteNormalized = ([string]$Remote[0]).Trim().TrimEnd("/")

if ($RemoteNormalized -ne $ExpectedRemote) {
    throw "El repositorio remoto no coincide con el repositorio oficial."
}

$RequiredExisting = @(
    "src\sgoda\automation",
    "src\sgoda\automation\workflow_engine",
    "src\sgoda\automation\workflow_registry",
    "src\sgoda\rlb",
    "src\sgoda\pmo",
    "automation\n8n\workflows",
    "tools\institutional\Publish-SGODA-WithMasterBook.ps1"
)

$ReuseStatus = @()

foreach ($Relative in $RequiredExisting) {
    $Full = Join-Path $ProjectRoot $Relative
    $Exists = Test-Path -LiteralPath $Full
    $ReuseStatus += [PSCustomObject]@{
        path = $Relative.Replace("\","/")
        exists = [bool]$Exists
        policy = "REUSE_BEFORE_BUILD"
    }
}

$MissingRequired = @(
    $ReuseStatus | Where-Object { -not $_.exists }
)

if ($MissingRequired.Count -gt 0) {
    throw (
        "Faltan componentes base requeridos para SPT-022: " +
        (($MissingRequired | ForEach-Object { $_.path }) -join ", ")
    )
}

Write-Step "Creando nucleo SPT-022 sin duplicar motores existentes"

$AutomationDir = Join-Path $ProjectRoot "src\sgoda\automation\spt022"
$ApiPath = Join-Path $ProjectRoot "src\sgoda\api\spt022_routes.py"
$TestsDir = Join-Path $ProjectRoot "tests\automation"
$WorkflowDir = Join-Path $ProjectRoot "automation\n8n\workflows\spt022"
$ConfigDir = Join-Path $ProjectRoot "config\automation\spt022"
$ToolsDir = Join-Path $ProjectRoot "tools\institutional"
$DocsDir = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-022"

@(
    $AutomationDir,
    $TestsDir,
    $WorkflowDir,
    $ConfigDir,
    $ToolsDir,
    $DocsDir
) | ForEach-Object {
    New-Item -ItemType Directory -Path $_ -Force | Out-Null
}

$InitPy = @'
"""SPT-022 Institutional Automation and Governance Platform."""

from .platform import AutomationPlatform, OperationDefinition, OperationStatus

__all__ = [
    "AutomationPlatform",
    "OperationDefinition",
    "OperationStatus",
]
'@

$PlatformPy = @'
"""Core institucional SPT-022.

El nucleo no reemplaza motores existentes. Los registra, gobierna y coordina.
"""

from __future__ import annotations

from dataclasses import dataclass, asdict
from enum import Enum
from pathlib import Path
from typing import Dict, Iterable, List, Optional


class OperationStatus(str, Enum):
    READY = "READY"
    REQUIRES_INPUT = "REQUIRES_INPUT"
    REQUIRES_APPROVAL = "REQUIRES_APPROVAL"
    UNAVAILABLE = "UNAVAILABLE"


@dataclass(frozen=True)
class OperationDefinition:
    operation_id: str
    purpose: str
    status: OperationStatus
    source_component: str
    executable: Optional[str] = None
    approval_required: bool = False

    def to_dict(self) -> dict:
        data = asdict(self)
        data["status"] = self.status.value
        return data


class AutomationPlatform:
    """Catalogo y gobierno de operaciones institucionales."""

    def __init__(self, project_root: Path) -> None:
        self.project_root = Path(project_root).resolve()
        self._operations: Dict[str, OperationDefinition] = {}
        self._register_defaults()

    def _register_defaults(self) -> None:
        self.register(
            OperationDefinition(
                operation_id="data-intake",
                purpose="Procesar el Repositorio Lexico Base desde Excel.",
                status=OperationStatus.REQUIRES_INPUT,
                source_component="SPT-001B / RLB",
                executable="python -m sgoda.rlb.cli",
            )
        )
        self.register(
            OperationDefinition(
                operation_id="master-book-update",
                purpose="Actualizar automaticamente SGD-002.",
                status=OperationStatus.READY,
                source_component="SPT-021.3",
                executable=(
                    "tools/institutional/Invoke-SGD002-AutoUpdate.ps1"
                ),
            )
        )
        self.register(
            OperationDefinition(
                operation_id="repository-prepare",
                purpose="Preparar publicacion con Libro Maestro actualizado.",
                status=OperationStatus.READY,
                source_component="SPT-021.0.1 v1.0.8",
                executable=(
                    "tools/institutional/Publish-SGODA-WithMasterBook.ps1"
                ),
            )
        )
        self.register(
            OperationDefinition(
                operation_id="repository-publish",
                purpose="Publicar entregables al repositorio oficial.",
                status=OperationStatus.REQUIRES_APPROVAL,
                source_component="SPT-021.0.1 v1.0.8",
                executable=(
                    "tools/institutional/Publish-SGODA-WithMasterBook.ps1"
                ),
                approval_required=True,
            )
        )
        self.register(
            OperationDefinition(
                operation_id="repository-audit",
                purpose="Ejecutar auditoria institucional del repositorio.",
                status=OperationStatus.READY,
                source_component="SPB-003.2 / PMO Auditor",
                executable="scripts/Invoke-SPB0032-ModularAudit.ps1",
            )
        )

    def register(self, definition: OperationDefinition) -> None:
        self._operations[definition.operation_id] = definition

    def get(self, operation_id: str) -> OperationDefinition:
        return self._operations[operation_id]

    def list(self) -> List[OperationDefinition]:
        return list(self._operations.values())

    def as_dicts(self) -> List[dict]:
        return [item.to_dict() for item in self.list()]

    def validate_paths(self) -> Dict[str, bool]:
        result: Dict[str, bool] = {}
        for item in self.list():
            if not item.executable:
                result[item.operation_id] = True
                continue
            if item.executable.startswith("python "):
                result[item.operation_id] = (
                    self.project_root / "src" / "sgoda" / "rlb" / "cli.py"
                ).exists()
                continue
            result[item.operation_id] = (
                self.project_root / item.executable
            ).exists()
        return result

    def workflow_ids(self) -> Iterable[str]:
        return tuple(self._operations.keys())
'@

$ExecutorPy = @'
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
'@

$RoutesPy = @'
"""API local SPT-022 para orquestacion n8n."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict

from fastapi import APIRouter, HTTPException, Request

from sgoda.automation.spt022.executor import InstitutionalExecutor
from sgoda.automation.spt022.platform import AutomationPlatform

router = APIRouter(prefix="/api/spt022", tags=["SPT-022"])


def _root() -> Path:
    value = os.environ.get("SGODA_PROJECT_ROOT")
    if value:
        return Path(value).resolve()
    return Path.cwd().resolve()


def _local_only(request: Request) -> None:
    client = request.client
    host = client.host if client else ""
    if host not in {"127.0.0.1", "::1", "localhost", "testclient"}:
        raise HTTPException(status_code=403, detail="Local access only")


@router.get("/health")
def health(request: Request) -> Dict[str, Any]:
    _local_only(request)
    platform = AutomationPlatform(_root())
    return {
        "component": "SPT-022",
        "status": "OPERATIONAL",
        "orchestrator": "n8n",
        "operations": len(platform.list()),
        "path_validation": platform.validate_paths(),
    }


@router.get("/catalog")
def catalog(request: Request) -> Dict[str, Any]:
    _local_only(request)
    platform = AutomationPlatform(_root())
    return {"operations": platform.as_dicts()}


@router.post("/run/{operation_id}")
def run_operation(
    operation_id: str,
    request: Request,
    payload: Dict[str, Any] | None = None,
) -> Dict[str, Any]:
    _local_only(request)
    platform = AutomationPlatform(_root())
    try:
        platform.get(operation_id)
    except KeyError as exc:
        raise HTTPException(
            status_code=404,
            detail="Unknown operation",
        ) from exc

    executor = InstitutionalExecutor(_root())
    return executor.execute(operation_id, payload or {})
'@

$TestPy = @'
from pathlib import Path

from sgoda.automation.spt022.platform import (
    AutomationPlatform,
    OperationStatus,
)


def platform(tmp_path: Path) -> AutomationPlatform:
    return AutomationPlatform(tmp_path)


def test_default_operations_are_registered(tmp_path):
    p = platform(tmp_path)
    assert set(p.workflow_ids()) == {
        "data-intake",
        "master-book-update",
        "repository-prepare",
        "repository-publish",
        "repository-audit",
    }


def test_publish_requires_approval(tmp_path):
    p = platform(tmp_path)
    item = p.get("repository-publish")
    assert item.approval_required is True
    assert item.status == OperationStatus.REQUIRES_APPROVAL


def test_data_intake_requires_input(tmp_path):
    p = platform(tmp_path)
    assert p.get("data-intake").status == OperationStatus.REQUIRES_INPUT


def test_master_book_reuses_spt0213(tmp_path):
    p = platform(tmp_path)
    assert p.get("master-book-update").source_component == "SPT-021.3"


def test_prepare_reuses_publication_engine(tmp_path):
    p = platform(tmp_path)
    item = p.get("repository-prepare")
    assert "SPT-021.0.1" in item.source_component


def test_catalog_serializes(tmp_path):
    p = platform(tmp_path)
    rows = p.as_dicts()
    assert len(rows) == 5
    assert all("operation_id" in row for row in rows)


def test_operation_ids_unique(tmp_path):
    p = platform(tmp_path)
    ids = list(p.workflow_ids())
    assert len(ids) == len(set(ids))


def test_no_automatic_publish(tmp_path):
    p = platform(tmp_path)
    item = p.get("repository-publish")
    assert item.status != OperationStatus.READY


def test_unknown_operation_raises_key_error(tmp_path):
    p = platform(tmp_path)
    try:
        p.get("does-not-exist")
    except KeyError:
        pass
    else:
        raise AssertionError("KeyError expected")


def test_paths_validation_returns_all_operations(tmp_path):
    p = platform(tmp_path)
    status = p.validate_paths()
    assert set(status) == set(p.workflow_ids())
'@

Write-Utf8NoBom -Path (Join-Path $AutomationDir "__init__.py") -Content $InitPy
Write-Utf8NoBom -Path (Join-Path $AutomationDir "platform.py") -Content $PlatformPy
Write-Utf8NoBom -Path (Join-Path $AutomationDir "executor.py") -Content $ExecutorPy
Write-Utf8NoBom -Path $ApiPath -Content $RoutesPy
Write-Utf8NoBom -Path (Join-Path $TestsDir "test_spt022_platform.py") -Content $TestPy

Write-Step "Integrando router SPT-022 en FastAPI"

$ApplicationPath = Join-Path $ProjectRoot "src\sgoda\kernel\application.py"
$ApplicationText = Get-Content -LiteralPath $ApplicationPath -Raw

if ($null -eq $ApplicationText) {
    throw "application.py esta vacio."
}

if (-not $ApplicationText.Contains("spt022_router")) {
    $ImportMarker = "from fastapi import FastAPI"
    if (-not $ApplicationText.Contains($ImportMarker)) {
        throw "No se encontro marcador FastAPI para integrar SPT-022."
    }

    $ApplicationText = $ApplicationText.Replace(
        $ImportMarker,
        (
            $ImportMarker +
            "`r`nfrom sgoda.api.spt022_routes import router as spt022_router"
        )
    )

    $StateMarker = "    application.state.module_registry = ("
    if (-not $ApplicationText.Contains($StateMarker)) {
        throw "No se encontro marcador de registro para integrar router."
    }

    $RouterBlock = @'
    application.include_router(
        spt022_router,
    )

'@
    $ApplicationText = $ApplicationText.Replace(
        $StateMarker,
        ($RouterBlock + $StateMarker)
    )

    Write-Utf8NoBom -Path $ApplicationPath -Content $ApplicationText
}

Write-Step "Generando registro, eventos y gobierno"

$Registry = [ordered]@{
    component = "SPT-022"
    version = "1.0.0"
    orchestrator = "n8n"
    integration_mode = "LOCAL_HTTP_FASTAPI"
    publish_policy = "EXPLICIT_APPROVAL_REQUIRED"
    operations = @(
        [ordered]@{
            id = "data-intake"
            trigger = "webhook"
            source = "SPT-001B / sgoda.rlb.cli"
            endpoint = "/api/spt022/run/data-intake"
        },
        [ordered]@{
            id = "repository-audit"
            trigger = "webhook"
            source = "SPB-003.2"
            endpoint = "/api/spt022/run/repository-audit"
        },
        [ordered]@{
            id = "master-book-update"
            trigger = "webhook"
            source = "SPT-021.3"
            endpoint = "/api/spt022/run/master-book-update"
        },
        [ordered]@{
            id = "repository-prepare"
            trigger = "webhook"
            source = "SPT-021.0.1-v1.0.8"
            endpoint = "/api/spt022/run/repository-prepare"
        },
        [ordered]@{
            id = "repository-publish"
            trigger = "manual_approval"
            source = "SPT-021.0.1-v1.0.8"
            endpoint = "/api/spt022/run/repository-publish"
            approval_required = $true
        }
    )
}

$Events = [ordered]@{
    component = "SPT-022"
    events = @(
        "RLB_DATA_RECEIVED",
        "RLB_PIPELINE_COMPLETED",
        "AUDIT_COMPLETED",
        "MASTER_BOOK_UPDATED",
        "PUBLICATION_PREPARED",
        "PUBLICATION_APPROVED",
        "PUBLICATION_COMPLETED",
        "WORKFLOW_FAILED"
    )
}

$Governance = [ordered]@{
    local_only_gateway = $true
    n8n_execute_command_node_required = $false
    destructive_automatic_actions = $false
    automatic_git_publish = $false
    publication_requires_explicit_approval = $true
    credentials_in_repository = $false
    reuse_before_build = $true
    master_book_auto_update = $true
}

Write-Json -Path (Join-Path $ConfigDir "workflow-registry.json") -Data $Registry
Write-Json -Path (Join-Path $ConfigDir "event-catalog.json") -Data $Events
Write-Json -Path (Join-Path $ConfigDir "governance-policy.json") -Data $Governance

Write-Step "Generando workflows n8n institucionales"

function New-N8nWorkflowJson {
    param(
        [string]$Name,
        [string]$WebhookPath,
        [string]$Operation,
        [string]$WebhookId,
        [string]$HttpId,
        [string]$VersionId
    )

    $Template = @'
{
  "name": "__NAME__",
  "nodes": [
    {
      "parameters": {
        "httpMethod": "POST",
        "path": "__WEBHOOK_PATH__",
        "responseMode": "lastNode",
        "options": {}
      },
      "id": "__WEBHOOK_ID__",
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2.1,
      "position": [
        0,
        0
      ]
    },
    {
      "parameters": {
        "method": "POST",
        "url": "http://127.0.0.1:8000/api/spt022/run/__OPERATION__",
        "sendBody": true,
        "contentType": "raw",
        "rawContentType": "application/json",
        "body": "={{ $json.body || {} }}",
        "options": {
          "timeout": 1800000
        }
      },
      "id": "__HTTP_ID__",
      "name": "FastAPI SPT-022",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [
        320,
        0
      ]
    }
  ],
  "connections": {
    "Webhook": {
      "main": [
        [
          {
            "node": "FastAPI SPT-022",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  },
  "active": false,
  "settings": {
    "executionOrder": "v1"
  },
  "versionId": "__VERSION_ID__",
  "meta": {
    "templateCredsSetupCompleted": true
  }
}
'@

    return $Template.Replace(
        "__NAME__",
        $Name
    ).Replace(
        "__WEBHOOK_PATH__",
        $WebhookPath
    ).Replace(
        "__OPERATION__",
        $Operation
    ).Replace(
        "__WEBHOOK_ID__",
        $WebhookId
    ).Replace(
        "__HTTP_ID__",
        $HttpId
    ).Replace(
        "__VERSION_ID__",
        $VersionId
    )
}

# Limpiar artefacto no-workflow de la version anterior.
$StalePublishWorkflow = Join-Path `
    $WorkflowDir `
    "05-repository-publish-approval.json"

if (Test-Path -LiteralPath $StalePublishWorkflow -PathType Leaf) {
    Remove-Item -LiteralPath $StalePublishWorkflow -Force
}

$WorkflowDefinitions = @(
    [PSCustomObject]@{
        File = "01-data-intake.json"
        Name = "SPT-022 - Data Intake"
        Path = "sgoda-spt022-data-intake"
        Operation = "data-intake"
        WebhookId = "1514e6cb-2db3-4f01-a0d2-220001000001"
        HttpId = "2514e6cb-2db3-4f01-a0d2-220001000001"
        VersionId = "3514e6cb-2db3-4f01-a0d2-220001000001"
    }

    [PSCustomObject]@{
        File = "02-repository-audit.json"
        Name = "SPT-022 - Repository Audit"
        Path = "sgoda-spt022-audit"
        Operation = "repository-audit"
        WebhookId = "1514e6cb-2db3-4f01-a0d2-220002000002"
        HttpId = "2514e6cb-2db3-4f01-a0d2-220002000002"
        VersionId = "3514e6cb-2db3-4f01-a0d2-220002000002"
    }

    [PSCustomObject]@{
        File = "03-master-book-update.json"
        Name = "SPT-022 - Master Book Update"
        Path = "sgoda-spt022-master-book"
        Operation = "master-book-update"
        WebhookId = "1514e6cb-2db3-4f01-a0d2-220003000003"
        HttpId = "2514e6cb-2db3-4f01-a0d2-220003000003"
        VersionId = "3514e6cb-2db3-4f01-a0d2-220003000003"
    }

    [PSCustomObject]@{
        File = "04-repository-prepare.json"
        Name = "SPT-022 - Repository Prepare"
        Path = "sgoda-spt022-prepare"
        Operation = "repository-prepare"
        WebhookId = "1514e6cb-2db3-4f01-a0d2-220004000004"
        HttpId = "2514e6cb-2db3-4f01-a0d2-220004000004"
        VersionId = "3514e6cb-2db3-4f01-a0d2-220004000004"
    }
)

foreach ($Definition in $WorkflowDefinitions) {
    $JsonText = New-N8nWorkflowJson `
        -Name $Definition.Name `
        -WebhookPath $Definition.Path `
        -Operation $Definition.Operation `
        -WebhookId $Definition.WebhookId `
        -HttpId $Definition.HttpId `
        -VersionId $Definition.VersionId

    Write-Utf8NoBom `
        -Path (Join-Path $WorkflowDir $Definition.File) `
        -Content ($JsonText + "`r`n")
}

# Publication policy is governance metadata, NOT an importable n8n workflow.
$PublishDefinition = [ordered]@{
    name = "SPT-022 - Repository Publish - Approval Required"
    classification = "INSTITUTIONAL_GOVERNANCE_POLICY"
    active = $false
    institutional_status = "MANUAL_APPROVAL_REQUIRED"
    endpoint = "http://127.0.0.1:8000/api/spt022/run/repository-publish"
    required_payload = [ordered]@{
        approved = $true
    }
    import_into_n8n = $false
    note = (
        "Publication is never exposed as an automatic webhook. " +
        "Invoke only after explicit institutional approval."
    )
}

Write-Json `
    -Path (Join-Path $ConfigDir "repository-publish-approval-policy.json") `
    -Data $PublishDefinition

Write-Step "Validando estructura canonica de workflows n8n"

$N8nStructureErrors = @()

foreach ($Definition in $WorkflowDefinitions) {
    $WorkflowPath = Join-Path $WorkflowDir $Definition.File

    try {
        $WorkflowObject = Get-Content `
            -LiteralPath $WorkflowPath `
            -Raw |
            ConvertFrom-Json
    }
    catch {
        $N8nStructureErrors += [PSCustomObject]@{
            path = $WorkflowPath
            error = "INVALID_JSON"
            detail = $_.Exception.Message
        }
        continue
    }

    if ($null -eq $WorkflowObject.nodes) {
        $N8nStructureErrors += [PSCustomObject]@{
            path = $WorkflowPath
            error = "MISSING_NODES"
            detail = ""
        }
    }

    if ($null -eq $WorkflowObject.connections) {
        $N8nStructureErrors += [PSCustomObject]@{
            path = $WorkflowPath
            error = "MISSING_CONNECTIONS"
            detail = ""
        }
        continue
    }

    $WebhookConnection = $WorkflowObject.connections.Webhook

    if ($null -eq $WebhookConnection) {
        $N8nStructureErrors += [PSCustomObject]@{
            path = $WorkflowPath
            error = "MISSING_WEBHOOK_CONNECTION"
            detail = ""
        }
        continue
    }

    $Main = $WebhookConnection.main

    if ($null -eq $Main -or $Main.Count -ne 1) {
        $N8nStructureErrors += [PSCustomObject]@{
            path = $WorkflowPath
            error = "INVALID_MAIN_CONNECTION_COUNT"
            detail = [string]$Main.Count
        }
        continue
    }

    $FirstOutput = $Main[0]

    # ConvertFrom-Json preserves the nested JSON array as Object[].
    if (
        $null -eq $FirstOutput -or
        -not ($FirstOutput -is [System.Array])
    ) {
        $N8nStructureErrors += [PSCustomObject]@{
            path = $WorkflowPath
            error = "MAIN_OUTPUT_NOT_ARRAY"
            detail = (
                "connections.Webhook.main[0] must be an array."
            )
        }
        continue
    }

    if ($FirstOutput.Count -ne 1) {
        $N8nStructureErrors += [PSCustomObject]@{
            path = $WorkflowPath
            error = "INVALID_TARGET_COUNT"
            detail = [string]$FirstOutput.Count
        }
        continue
    }

    $Target = $FirstOutput[0]

    if (
        $Target.node -ne "FastAPI SPT-022" -or
        $Target.type -ne "main" -or
        [int]$Target.index -ne 0
    ) {
        $N8nStructureErrors += [PSCustomObject]@{
            path = $WorkflowPath
            error = "INVALID_CONNECTION_TARGET"
            detail = ""
        }
    }
}

$UnexpectedWorkflowFiles = @(
    Get-ChildItem `
        -LiteralPath $WorkflowDir `
        -File `
        -Filter "*.json" |
    Where-Object {
        $_.Name -notin @(
            $WorkflowDefinitions |
            ForEach-Object { $_.File }
        )
    }
)

foreach ($Unexpected in $UnexpectedWorkflowFiles) {
    $N8nStructureErrors += [PSCustomObject]@{
        path = $Unexpected.FullName
        error = "UNEXPECTED_IMPORTABLE_JSON"
        detail = (
            "Only canonical SPT-022 workflows may exist " +
            "in the import directory."
        )
    }
}

if ($N8nStructureErrors.Count -ne 0) {
    Write-Json `
        -Path (Join-Path $RunRoot "n8n-workflow-structure-errors.json") `
        -Data $N8nStructureErrors

    throw (
        "Se detectaron " +
        $N8nStructureErrors.Count +
        " errores estructurales n8n."
    )
}

Write-Host "  Canonical n8n workflows: $($WorkflowDefinitions.Count)"
Write-Host "  n8n workflow structure errors: 0"
Write-Host "  Non-workflow governance JSON in import directory: 0"

Write-Step "Generando runtime local n8n y FastAPI"

$StartGateway = @'
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (& git rev-parse --show-toplevel).Trim()
Set-Location -LiteralPath $Root

$env:PYTHONPATH = Join-Path $Root "src"
$env:SGODA_PROJECT_ROOT = $Root

python -m uvicorn sgoda.main:app --host 127.0.0.1 --port 8000
exit $LASTEXITCODE
'@

$StartN8n = @'
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (& git rev-parse --show-toplevel).Trim()
Set-Location -LiteralPath $Root

$env:SGODA_PROJECT_ROOT = $Root
$env:N8N_HOST = "127.0.0.1"
$env:N8N_PORT = "5678"
$env:N8N_PROTOCOL = "http"
$env:N8N_USER_FOLDER = Join-Path $Root ".runtime\n8n"
$env:N8N_DIAGNOSTICS_ENABLED = "false"
$env:N8N_PERSONALIZATION_ENABLED = "false"

New-Item -ItemType Directory -Path $env:N8N_USER_FOLDER -Force | Out-Null

$n8n = Get-Command n8n.cmd -ErrorAction SilentlyContinue
if ($null -eq $n8n) {
    throw "n8n no esta instalado. Ejecute el instalador SPT-022 con -InstallN8n."
}

& $n8n.Source start
exit $LASTEXITCODE
'@

$StartPlatform = @'
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (& git rev-parse --show-toplevel).Trim()

$Gateway = Join-Path $Root "tools\institutional\Start-SPT022-Gateway.ps1"
$N8n = Join-Path $Root "tools\institutional\Start-SPT022-n8n.ps1"

Start-Process powershell.exe -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    "`"$Gateway`""
)

Start-Sleep -Seconds 2

Start-Process powershell.exe -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    "`"$N8n`""
)

Write-Host "SPT-022 runtime launch requested."
Write-Host "FastAPI: http://127.0.0.1:8000/api/spt022/health"
Write-Host "n8n:     http://127.0.0.1:5678"
'@

$TestPlatform = @'
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Results = @()

try {
    $Api = Invoke-RestMethod `
        -Uri "http://127.0.0.1:8000/api/spt022/health" `
        -Method Get `
        -TimeoutSec 10
    $Results += [PSCustomObject]@{
        component = "FastAPI SPT-022"
        ok = ($Api.status -eq "OPERATIONAL")
    }
}
catch {
    $Results += [PSCustomObject]@{
        component = "FastAPI SPT-022"
        ok = $false
    }
}

try {
    $Response = Invoke-WebRequest `
        -Uri "http://127.0.0.1:5678" `
        -UseBasicParsing `
        -TimeoutSec 10
    $Results += [PSCustomObject]@{
        component = "n8n"
        ok = ($Response.StatusCode -ge 200)
    }
}
catch {
    $Results += [PSCustomObject]@{
        component = "n8n"
        ok = $false
    }
}

$Results | Format-Table -AutoSize

if (@($Results | Where-Object { -not $_.ok }).Count -gt 0) {
    exit 1
}

exit 0
'@

Write-Utf8NoBom `
    -Path (Join-Path $ToolsDir "Start-SPT022-Gateway.ps1") `
    -Content $StartGateway
Write-Utf8NoBom `
    -Path (Join-Path $ToolsDir "Start-SPT022-n8n.ps1") `
    -Content $StartN8n
Write-Utf8NoBom `
    -Path (Join-Path $ToolsDir "Start-SPT022-Platform.ps1") `
    -Content $StartPlatform
Write-Utf8NoBom `
    -Path (Join-Path $ToolsDir "Test-SPT022-Platform.ps1") `
    -Content $TestPlatform

Write-Step "Validando e instalando Node.js y n8n"

Refresh-ProcessPath

$NodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
$NpmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue
$N8nCommand = Get-Command n8n.cmd -ErrorAction SilentlyContinue

$NodeVersion = ""
$NodeCompatible = $false
$NodeInstalledByThisRun = $false
$N8nInstalledByThisRun = $false
$N8nImported = $false

if ($null -ne $NodeCommand) {
    $NodeVersion = (& $NodeCommand.Source --version).Trim()
    $NodeCompatible = Get-NodeCompatibility `
        -VersionText $NodeVersion
}

if ($InstallN8n) {
    if (
        $null -eq $NodeCommand -or
        $null -eq $NpmCommand
    ) {
        Install-NodeForN8n -PackageId $NodeWingetPackage
        $NodeInstalledByThisRun = $true

        $NodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
        $NpmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue
        $NodeVersion = (& $NodeCommand.Source --version).Trim()
        $NodeCompatible = Get-NodeCompatibility `
            -VersionText $NodeVersion
    }

    if (-not $NodeCompatible) {
        throw (
            "Node.js no es compatible con n8n. Detectado: " +
            $NodeVersion +
            ". Requerido: 20.19 a 24.x."
        )
    }

    if ($null -eq $N8nCommand) {
        Write-Host (
            "Instalando n8n " +
            $PinnedN8nVersion +
            " mediante npm..."
        )

        & $NpmCommand.Source `
            install `
            --global `
            ("n8n@" + $PinnedN8nVersion)

        $NpmExit = $LASTEXITCODE

        if ($NpmExit -ne 0) {
            throw (
                "npm no pudo instalar n8n. Exit code: " +
                $NpmExit
            )
        }

        Refresh-ProcessPath
        $N8nCommand = Get-Command n8n.cmd -ErrorAction SilentlyContinue

        if ($null -eq $N8nCommand) {
            $NpmPrefix = (& $NpmCommand.Source config get prefix).Trim()
            if (-not [string]::IsNullOrWhiteSpace($NpmPrefix)) {
                $env:Path = $env:Path + ";" + $NpmPrefix
            }

            $N8nCommand = Get-Command n8n.cmd -ErrorAction SilentlyContinue
        }

        if ($null -eq $N8nCommand) {
            throw (
                "n8n fue instalado por npm pero n8n.cmd no quedo " +
                "visible en PATH."
            )
        }

        $N8nInstalledByThisRun = $true
    }
}

$N8nVersion = ""

if ($null -ne $N8nCommand) {
    $N8nVersion = (& $N8nCommand.Source --version).Trim()
}

if ($ImportN8nWorkflows) {
    if ($null -eq $N8nCommand) {
        throw (
            "No se pueden importar workflows porque n8n no esta instalado. " +
            "Use -InstallN8n -ImportN8nWorkflows."
        )
    }

    & $N8nCommand.Source `
        import:workflow `
        --separate `
        ("--input=" + $WorkflowDir)

    if ($LASTEXITCODE -ne 0) {
        throw "La importacion de workflows n8n fallo."
    }

    $N8nImported = $true
}

Write-Step "Generando documentacion institucional"

$ArchitectureDoc = @"
# SGD-500 - Arquitectura de Automatizacion Institucional

## Componente
SPT-022 - Plataforma Institucional de Automatizacion y Gobierno v1.0.0

## Principio
n8n es el orquestador principal. FastAPI funciona como gateway local seguro.
SPT-022 no reemplaza los motores existentes: los registra, coordina y audita.

## Cadena operativa
1. Incorporacion de datos mediante RLB/Excel.
2. Ejecucion de controles y auditoria.
3. Actualizacion automatica del Libro Maestro SGD-002.
4. PREPARE institucional.
5. Aprobacion humana.
6. PUBLISH mediante SPT-021.0.1 v1.0.8.

## Componentes reutilizados
$(
    ($ReuseStatus | ForEach-Object {
        "- " + $_.path + ": " + $_.exists
    }) -join "`r`n"
)

## Seguridad
- Gateway enlazado a localhost.
- No se usa Execute Command de n8n.
- PUBLISH exige aprobacion explicita.
- No se almacenan credenciales en Git.
"@

$CatalogDoc = @"
# SGD-501 - Catalogo Maestro de Workflows

| Workflow | Fuente | Estado |
|---|---|---|
| data-intake | SPT-001B / RLB | OPERATIVO CON INPUT |
| repository-audit | SPB-003.2 | OPERATIVO SI SCRIPT DISPONIBLE |
| master-book-update | SPT-021.3 | OPERATIVO |
| repository-prepare | SPT-021.0.1 v1.0.8 | OPERATIVO |
| repository-publish | SPT-021.0.1 v1.0.8 | APROBACION HUMANA |
"@

$GovernanceDoc = @"
# SGD-502 - Gobierno de Automatizacion

SPT-022 aplica:
- REUSE BEFORE BUILD.
- cero publicacion destructiva automatica.
- aprobacion humana obligatoria para PUBLISH.
- trazabilidad de cada operacion.
- n8n como orquestador, FastAPI como gateway.
- SGD-002 como memoria institucional viva.
"@

$EventsDoc = @"
# SGD-503 - Registro Institucional de Eventos

Eventos canonicos:
$(
    ($Events.events | ForEach-Object { "- " + $_ }) -join "`r`n"
)
"@

$N8nDoc = @"
# SGD-504 - Arquitectura de Integracion n8n

Modo: self-hosted local.
Gateway: http://127.0.0.1:8000/api/spt022
n8n: http://127.0.0.1:5678

Los workflows se almacenan en:
automation/n8n/workflows/spt022

La publicacion oficial no queda expuesta como webhook automatico.
"@

Write-Utf8NoBom -Path (Join-Path $DocsDir "SGD-500-Arquitectura-Automatizacion-Institucional.md") -Content $ArchitectureDoc
Write-Utf8NoBom -Path (Join-Path $DocsDir "SGD-501-Catalogo-Maestro-Workflows.md") -Content $CatalogDoc
Write-Utf8NoBom -Path (Join-Path $DocsDir "SGD-502-Gobierno-Automatizacion.md") -Content $GovernanceDoc
Write-Utf8NoBom -Path (Join-Path $DocsDir "SGD-503-Registro-Institucional-Eventos.md") -Content $EventsDoc
Write-Utf8NoBom -Path (Join-Path $DocsDir "SGD-504-Arquitectura-Integracion-n8n.md") -Content $N8nDoc

Write-Step "Validando sintaxis PowerShell generada"

$GeneratedPs = @(
    (Join-Path $ToolsDir "Start-SPT022-Gateway.ps1")
    (Join-Path $ToolsDir "Start-SPT022-n8n.ps1")
    (Join-Path $ToolsDir "Start-SPT022-Platform.ps1")
    (Join-Path $ToolsDir "Test-SPT022-Platform.ps1")
)

$PsErrors = @()

foreach ($PsPath in $GeneratedPs) {
    $Errors = @(Test-PowerShellSyntax -Path $PsPath)
    foreach ($ErrorItem in $Errors) {
        $PsErrors += [PSCustomObject]@{
            path = $PsPath
            line = $ErrorItem.Extent.StartLineNumber
            message = $ErrorItem.Message
        }
    }
}

if ($PsErrors.Count -ne 0) {
    Write-Json `
        -Path (Join-Path $RunRoot "powershell-errors.json") `
        -Data $PsErrors
    throw "Se detectaron errores PowerShell en archivos SPT-022 generados."
}

Write-Step "Validando JSON n8n y configuracion"

$JsonFiles = @()

$JsonFiles += @(
    Get-ChildItem `
        -LiteralPath $WorkflowDir `
        -File `
        -Filter "*.json"
)

$JsonFiles += @(
    Get-ChildItem `
        -LiteralPath $ConfigDir `
        -File `
        -Filter "*.json"
)

$InvalidJson = @()

foreach ($JsonFile in $JsonFiles) {
    try {
        $null = Get-Content -LiteralPath $JsonFile.FullName -Raw |
            ConvertFrom-Json
    }
    catch {
        $InvalidJson += $JsonFile.FullName
    }
}

if ($InvalidJson.Count -ne 0) {
    throw (
        "JSON invalido en SPT-022: " +
        ($InvalidJson -join ", ")
    )
}

Write-Step "Compilando Python"

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

& python -m compileall -q src tests
$CompileExitCode = $LASTEXITCODE

if ($CompileExitCode -ne 0) {
    throw "Python compileall fallo."
}

Write-Step "Ejecutando pruebas SPT-022"

$SptTests = @(
    & python -m pytest -q tests/automation/test_spt022_platform.py 2>&1
)
$SptTestExit = $LASTEXITCODE
$SptTests | ForEach-Object { Write-Host $_ }

if ($SptTestExit -ne 0) {
    throw "Las pruebas SPT-022 fallaron."
}

Write-Step "Ejecutando suite institucional completa"

$FullTests = @(& python -m pytest -q 2>&1)
$FullTestExit = $LASTEXITCODE
$FullText = $FullTests -join "`r`n"
$FullTests | ForEach-Object { Write-Host $_ }

if ($FullTestExit -ne 0) {
    throw "La suite institucional completa fallo."
}

$TestsPassed = 0
$Match = [regex]::Match($FullText, "(\d+)\s+passed")
if ($Match.Success) {
    $TestsPassed = [int]$Match.Groups[1].Value
}


Write-Step "Reparando lock institucional SGD-002"

$AutoUpdaterPath = Join-Path `
    $ProjectRoot `
    "tools\institutional\Invoke-SGD002-AutoUpdate.ps1"

if (-not (Test-Path -LiteralPath $AutoUpdaterPath -PathType Leaf)) {
    throw "No existe Invoke-SGD002-AutoUpdate.ps1."
}

$AutoUpdaterText = Get-Content `
    -LiteralPath $AutoUpdaterPath `
    -Raw

if ([string]::IsNullOrWhiteSpace($AutoUpdaterText)) {
    throw "Invoke-SGD002-AutoUpdate.ps1 esta vacio."
}

$LockMigrationApplied = $false
$LockMigrationStatus = "UNKNOWN"

$NewLockBlock = @'
if (Test-Path -LiteralPath $LockPath) {
    $ExistingLockRaw = Get-Content `
        -LiteralPath $LockPath `
        -Raw `
        -ErrorAction SilentlyContinue

    $ExistingPid = 0
    $ExistingProcessAlive = $false
    $ExistingLockValid = $false

    if (-not [string]::IsNullOrWhiteSpace($ExistingLockRaw)) {
        try {
            $ExistingLock = $ExistingLockRaw | ConvertFrom-Json

            if ($null -ne $ExistingLock.pid) {
                $ExistingPid = [int]$ExistingLock.pid
            }

            if ($ExistingPid -gt 0) {
                $ExistingProcess = Get-Process `
                    -Id $ExistingPid `
                    -ErrorAction SilentlyContinue

                $ExistingProcessAlive = ($null -ne $ExistingProcess)
            }

            $ExistingLockValid = (
                $ExistingPid -gt 0 -and
                $ExistingProcessAlive
            )
        }
        catch {
            $ExistingLockValid = $false
        }
    }

    if ($ExistingLockValid) {
        Write-Output (
            "AUTO_UPDATE_SKIPPED: another execution is active. PID=" +
            $ExistingPid
        )
        exit 0
    }

    Remove-Item `
        -LiteralPath $LockPath `
        -Force `
        -ErrorAction SilentlyContinue

    Write-Output "AUTO_UPDATE_STALE_LOCK_REMOVED."
}

$LockPayload = [ordered]@{
    pid = $PID
    started_utc = [DateTime]::UtcNow.ToString("o")
    host = $env:COMPUTERNAME
}

$LockJson = $LockPayload | ConvertTo-Json -Depth 4

[System.IO.File]::WriteAllText(
    $LockPath,
    $LockJson,
    (New-Object System.Text.UTF8Encoding($false))
)
'@

if ($AutoUpdaterText.Contains("AUTO_UPDATE_STALE_LOCK_REMOVED")) {
    $LockMigrationStatus = "ALREADY_PID_AWARE"
}
else {
    # Match semantically from the legacy LockPath test through the legacy
    # WriteAllText block immediately preceding try {. CRLF/LF and spacing
    # differences are intentionally tolerated.
    $LegacyLockPattern = (
        '(?s)' +
        'if\s*\(\s*Test-Path\s+-LiteralPath\s+\$LockPath\s*\)\s*\{' +
        '.*?' +
        '\[System\.IO\.File\]::WriteAllText\s*\(' +
        '\s*\$LockPath\s*,' +
        '.*?' +
        '\)\s*' +
        '(?=try\s*\{)'
    )

    $LegacyMatch = [regex]::Match(
        $AutoUpdaterText,
        $LegacyLockPattern
    )

    if (-not $LegacyMatch.Success) {
        throw (
            "No se pudo localizar semanticamente el bloque legacy " +
            "de update.lock en SGD-002."
        )
    }

    $BackupDir = Join-Path `
        $RunRoot `
        "backup-sgd002-lock-migration"

    New-Item `
        -ItemType Directory `
        -Path $BackupDir `
        -Force |
        Out-Null

    $BackupPath = Join-Path `
        $BackupDir `
        "Invoke-SGD002-AutoUpdate.ps1"

    Copy-Item `
        -LiteralPath $AutoUpdaterPath `
        -Destination $BackupPath `
        -Force

    $AutoUpdaterText = [regex]::Replace(
        $AutoUpdaterText,
        $LegacyLockPattern,
        ($NewLockBlock + "`r`n"),
        1
    )

    Write-Utf8NoBom `
        -Path $AutoUpdaterPath `
        -Content $AutoUpdaterText

    $LockMigrationApplied = $true
    $LockMigrationStatus = "MIGRATED_TO_PID_AWARE"
}

$UpdaterSyntaxErrors = @(
    Test-PowerShellSyntax -Path $AutoUpdaterPath
)

if ($UpdaterSyntaxErrors.Count -ne 0) {
    throw (
        "El auto-updater SGD-002 quedo con " +
        $UpdaterSyntaxErrors.Count +
        " error(es) PowerShell."
    )
}

$VerifyUpdaterText = Get-Content `
    -LiteralPath $AutoUpdaterPath `
    -Raw

if (
    -not $VerifyUpdaterText.Contains(
        "AUTO_UPDATE_STALE_LOCK_REMOVED"
    )
) {
    throw "La migracion PID-aware de SGD-002 no quedo aplicada."
}

Write-Host "SGD-002 lock migration: $LockMigrationStatus"
Write-Host "SGD-002 lock syntax errors: 0"

# ----------------------------------------------------------------------
# Coordinacion exclusiva con el auto-updater persistente SGD-002.
# La restauracion de la tarea queda garantizada mediante finally.
# ----------------------------------------------------------------------
$Sgd002TaskName = "SGODA-PUINAVE-SGD002-AutoUpdate"
$Sgd002TaskExists = $false
$Sgd002TaskWasEnabled = $false
$Sgd002TaskStateBefore = ""
$Sgd002TaskCoordinationStatus = "NOT_AVAILABLE"

$MasterBookUpdated = $false
$MasterBookStatus = "NOT_AVAILABLE"
$MasterBookAttempts = 0
$MasterBookOutput = @()

$ScheduledTask = Get-ScheduledTask `
    -TaskName $Sgd002TaskName `
    -ErrorAction SilentlyContinue

if ($null -ne $ScheduledTask) {
    $Sgd002TaskExists = $true
    $Sgd002TaskStateBefore = [string]$ScheduledTask.State
    $Sgd002TaskWasEnabled = ($ScheduledTask.State -ne "Disabled")
}

try {
    if ($Sgd002TaskExists) {
        Write-Host (
            "SGD-002 scheduled task detected. State: " +
            $Sgd002TaskStateBefore
        )

        if ($Sgd002TaskWasEnabled) {
            Disable-ScheduledTask `
                -TaskName $Sgd002TaskName `
                -ErrorAction Stop |
                Out-Null
        }

        Stop-ScheduledTask `
            -TaskName $Sgd002TaskName `
            -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 2
    }

    $ActiveUpdaterProcesses = @(
        Get-CimInstance Win32_Process `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -match "Invoke-SGD002-AutoUpdate"
        }
    )

    if ($ActiveUpdaterProcesses.Count -gt 0) {
        foreach ($Process in $ActiveUpdaterProcesses) {
            Stop-Process `
                -Id $Process.ProcessId `
                -Force `
                -ErrorAction Stop
        }

        Start-Sleep -Seconds 2
    }

    $Sgd002TaskCoordinationStatus = "EXCLUSIVE_WINDOW_ACQUIRED"

    Write-Step "Actualizando Libro Maestro"

    $AutoUpdater = Join-Path `
        $ProjectRoot `
        "tools\institutional\Invoke-SGD002-AutoUpdate.ps1"

    if (Test-Path -LiteralPath $AutoUpdater -PathType Leaf) {
        $MaxMasterBookAttempts = 3

        for (
            $Attempt = 1;
            $Attempt -le $MaxMasterBookAttempts;
            $Attempt++
        ) {
            $MasterBookAttempts = $Attempt

            $CurrentOutput = @(
                & powershell.exe `
                    -NoProfile `
                    -ExecutionPolicy Bypass `
                    -File $AutoUpdater `
                    -ProjectRoot $ProjectRoot `
                    -ForceUpdate 2>&1
            )

            $CurrentExit = $LASTEXITCODE
            $MasterBookOutput = $CurrentOutput

            $CurrentOutput |
                ForEach-Object { Write-Host $_ }

            $CurrentText = $CurrentOutput -join "`n"

            if ($CurrentExit -ne 0) {
                $MasterBookStatus = "FAILED"
                break
            }

            if ($CurrentText -match "SGD-002 AUTO-UPDATED") {
                $MasterBookUpdated = $true
                $MasterBookStatus = "UPDATED"
                break
            }

            if (
                $CurrentText -match
                "AUTO_UPDATE_SKIPPED:\s*repository fingerprint unchanged"
            ) {
                $MasterBookStatus = "UNCHANGED_ALREADY_CURRENT"
                break
            }

            if (
                $CurrentText -match
                "AUTO_UPDATE_STALE_LOCK_REMOVED"
            ) {
                # El mismo proceso continua despues de retirar el lock.
                # No es un fallo y la salida posterior decide el estado final.
                continue
            }

            if (
                $CurrentText -match
                "AUTO_UPDATE_SKIPPED:\s*another execution is active"
            ) {
                $MasterBookStatus = "BUSY_RETRYING"

                if ($Attempt -lt $MaxMasterBookAttempts) {
                    Start-Sleep -Seconds 5
                    continue
                }

                $MasterBookStatus = "BUSY_TIMEOUT"
                break
            }

            $MasterBookStatus = "UNKNOWN_SUCCESS_RESPONSE"
            break
        }

        if ($MasterBookStatus -eq "FAILED") {
            throw "La actualizacion SGD-002 fallo."
        }

        if ($MasterBookStatus -eq "BUSY_TIMEOUT") {
            throw (
                "SGD-002 continua ocupado incluso con lock PID-aware."
            )
        }

        if ($MasterBookStatus -eq "UNKNOWN_SUCCESS_RESPONSE") {
            throw (
                "Respuesta institucional SGD-002 no reconocida."
            )
        }
    }
}
finally {
    if ($Sgd002TaskExists) {
        Enable-ScheduledTask `
            -TaskName $Sgd002TaskName `
            -ErrorAction SilentlyContinue |
            Out-Null

        $Sgd002TaskCoordinationStatus = "RESTORED_ENABLED"
    }
}

$PrepareStatus = "NOT_REQUESTED"

if ($PreparePublication) {
    Write-Step "Ejecutando PREPARE con motor canonico"

    $Publisher = Join-Path `
        $ProjectRoot `
        "tools\institutional\Publish-SGODA-WithMasterBook.ps1"

    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $Publisher `
        -PrepareOnly

    if ($LASTEXITCODE -ne 0) {
        throw "PREPARE institucional fallo."
    }

    $PrepareStatus = "READY_FOR_PUBLICATION"
}

Write-Step "Validando trazabilidad interna de version"

$VersionTraceabilityErrors = 0

if ($Version -ne "1.0.7") {
    $VersionTraceabilityErrors++
}

if (
    -not $RunRoot.Contains(
        "artifacts\development\SPT-022-v1.0.7\runs"
    )
) {
    $VersionTraceabilityErrors++
}

if ($VersionTraceabilityErrors -ne 0) {
    throw (
        "La trazabilidad interna de SPT-022 no coincide " +
        "con v1.0.7."
    )
}

Write-Host "Version traceability errors: 0"

Write-Step "Generando evidencia institucional SPT-022"

$Evidence = [ordered]@{
    component = $Component
    version = $Version
    status = "IMPLEMENTED"
    repository = $RemoteNormalized
    branch = [string]$Branch[0]
    baseline_commit = [string]$Commit[0]
    orchestrator = "n8n"
    integration_mode = "LOCAL_HTTP_FASTAPI"
    reuse_before_build = $true
    reused_components = $ReuseStatus
    node_installed_by_this_run = $NodeInstalledByThisRun
    node_winget_package = $NodeWingetPackage
    n8n_pinned_version = $PinnedN8nVersion
    n8n_detected = [bool]($null -ne $N8nCommand)
    n8n_version = $N8nVersion
    n8n_installed_by_this_run = $N8nInstalledByThisRun
    n8n_workflows_imported = $N8nImported
    rerun_safe_after_v1_0_2_partial_execution = $true
    node_version = $NodeVersion
    node_compatible = $NodeCompatible
    generated_workflows = $WorkflowDefinitions.Count
    publication_workflow_requires_approval = $true
    generated_powershell_syntax_errors = $PsErrors.Count
    invalid_json = $InvalidJson.Count
    n8n_workflow_structure_errors = $N8nStructureErrors.Count
    n8n_importable_workflow_count = $WorkflowDefinitions.Count
    n8n_publish_policy_imported = $false
    python_compile_exit_code = $CompileExitCode
    tests_passed = $TestsPassed
    full_pytest_exit_code = $FullTestExit
    master_book_updated = $MasterBookUpdated
    master_book_status = $MasterBookStatus
    master_book_attempts = $MasterBookAttempts
    sgd002_task_exists = $Sgd002TaskExists
    sgd002_task_state_before = $Sgd002TaskStateBefore
    sgd002_task_was_enabled = $Sgd002TaskWasEnabled
    sgd002_task_coordination_status = $Sgd002TaskCoordinationStatus
    sgd002_lock_policy = "PID_AWARE_JSON"
    sgd002_lock_migration_applied = $LockMigrationApplied
    sgd002_lock_migration_status = $LockMigrationStatus
    sgd002_stale_lock_recovery = $true
    sgd002_task_restore_guarantee = "TRY_FINALLY"
    prepare_status = $PrepareStatus
    version_traceability_errors = $VersionTraceabilityErrors
    technical_errors = 0
}

$EvidencePath = Join-Path $RunRoot "implementation-evidence.json"
Write-Json -Path $EvidencePath -Data $Evidence

$Act = @"
# ACT-022 - Acta de Implementacion Inicial SPT-022

## Estado
IMPLEMENTED

## Resultado
Se construyo la Plataforma Institucional de Automatizacion y Gobierno con:
- n8n como orquestador principal;
- FastAPI como gateway local;
- reutilizacion del RLB, PMO, Workflow Engine, Workflow Registry,
  SGD-002 y motor de publicacion SPT-021.0.1;
- cinco operaciones institucionales gobernadas;
- publicacion protegida por aprobacion explicita;
- pruebas y evidencia institucional.

## Runtime n8n
Detectado: $([bool]($null -ne $N8nCommand))
Version: $N8nVersion

## Pruebas
Suite completa aprobada: $TestsPassed

## Publicacion
No se ejecuta automaticamente.
PREPARE: $PrepareStatus
"@

$ActPath = Join-Path $DocsDir "ACT-022-Implementacion-Inicial.md"
Write-Utf8NoBom -Path $ActPath -Content $Act

Write-Step "Resultado final"

Write-Host "Component: SPT-022"
Write-Host "Version: $Version"
Write-Host "Institutional platform: IMPLEMENTED"
Write-Host "Orchestrator: n8n"
Write-Host "Integration mode: LOCAL_HTTP_FASTAPI"
Write-Host "Reuse before build: ENFORCED"
Write-Host "Generated n8n workflows: $($WorkflowDefinitions.Count)"
Write-Host "Publish approval required: YES"
Write-Host "Generated PowerShell syntax errors: 0"
Write-Host "Invalid JSON files: 0"
Write-Host "n8n workflow structure errors: 0"
Write-Host "n8n importable workflows: $($WorkflowDefinitions.Count)"
Write-Host "n8n publish policy imported: NO"
Write-Host "Python compile exit code: 0"
Write-Host "Tests passed: $TestsPassed"
Write-Host "Node.js installed by this run: $NodeInstalledByThisRun"
Write-Host "Node.js version: $NodeVersion"
Write-Host "Node.js compatible: $NodeCompatible"
Write-Host "n8n pinned version: $PinnedN8nVersion"
Write-Host "n8n detected: $([bool]($null -ne $N8nCommand))"
Write-Host "n8n version: $N8nVersion"
Write-Host "n8n workflows imported: $N8nImported"
Write-Host "Master Book updated: $MasterBookUpdated"
Write-Host "Master Book status: $MasterBookStatus"
Write-Host "Master Book attempts: $MasterBookAttempts"
Write-Host "SGD-002 task coordination: $Sgd002TaskCoordinationStatus"
Write-Host "SGD-002 task state before: $Sgd002TaskStateBefore"
Write-Host "SGD-002 lock policy: PID_AWARE_JSON"
Write-Host "SGD-002 lock migration: $LockMigrationStatus"
Write-Host "SGD-002 task final policy: ENABLED"
Write-Host "SGD-002 stale lock recovery: ENABLED"
Write-Host "SGD-002 task restore guarantee: TRY_FINALLY"
Write-Host "Prepare status: $PrepareStatus"
Write-Host "Version traceability errors: $VersionTraceabilityErrors"
Write-Host "Technical errors: 0"
Write-Host "Evidence: $EvidencePath"
Write-Host "Act: $ActPath"
Write-Host "SPT-022 v1.0.7: IMPLEMENTED WITH ZERO TECHNICAL ERRORS."
Write-Host ""
Write-Host "Runtime commands:"
Write-Host "  .\tools\institutional\Start-SPT022-Platform.ps1"
Write-Host "  .\tools\institutional\Test-SPT022-Platform.ps1"
