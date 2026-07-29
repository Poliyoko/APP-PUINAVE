[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Write-Step([string]$Message) {
    Write-Host "[SPB-005.1] $Message" -ForegroundColor Cyan
}

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "  CREADO: $Path" -ForegroundColor Green
    }
}

function Write-ManagedFile([string]$RelativePath, [string]$Content) {
    $Target = Join-Path $Root $RelativePath
    $Parent = Split-Path $Target -Parent
    Ensure-Directory $Parent

    if ((Test-Path $Target) -and -not $Force) {
        Write-Host "  CONSERVADO: $RelativePath" -ForegroundColor Yellow
        return
    }

    Set-Content -Path $Target -Value $Content -Encoding utf8
    Write-Host "  ESCRITO: $RelativePath" -ForegroundColor Green
}

Write-Step "Validando repositorio"
if (-not (Test-Path (Join-Path $Root ".git"))) {
    throw "Este script debe ejecutarse dentro del repositorio SGODA-PUINAVE."
}

$currentBranch = (git -C $Root branch --show-current).Trim()
if ($currentBranch -ne "feature/SPB-005.1-foundation-runtime") {
    throw "Rama incorrecta: $currentBranch. Se requiere feature/SPB-005.1-foundation-runtime."
}

$status = git -C $Root status --short
if ($status) {
    throw "El árbol Git debe estar limpio antes de instalar SPB-005.1-F001."
}

Write-Step "Creando estructura del Foundation Runtime"

Write-ManagedFile "src/sgoda/api/__init__.py" ""
Write-ManagedFile "src/sgoda/core/__init__.py" ""

Write-ManagedFile "src/sgoda/core/config.py" @'
from functools import lru_cache
import os

from pydantic import BaseModel


class Settings(BaseModel):
    project_code: str = "SGODA-PUINAVE"
    app_name: str = "SGODA-PUINAVE API"
    app_version: str = "0.1.0"
    environment: str = "development"
    host: str = "127.0.0.1"
    port: int = 8000


@lru_cache
def get_settings() -> Settings:
    return Settings(
        project_code=os.getenv("SGODA_PROJECT_CODE", "SGODA-PUINAVE"),
        app_name=os.getenv("SGODA_APP_NAME", "SGODA-PUINAVE API"),
        app_version=os.getenv("SGODA_APP_VERSION", "0.1.0"),
        environment=os.getenv("SGODA_ENVIRONMENT", "development"),
        host=os.getenv("SGODA_HOST", "127.0.0.1"),
        port=int(os.getenv("SGODA_PORT", "8000")),
    )


settings = get_settings()
'@

Write-ManagedFile "src/sgoda/api/routes.py" @'
from fastapi import APIRouter

from sgoda.core.config import settings

router = APIRouter()


@router.get("/health", tags=["system"])
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": settings.app_name,
        "version": settings.app_version,
        "environment": settings.environment,
    }


@router.get("/version", tags=["system"])
def version() -> dict[str, str]:
    return {
        "project": settings.project_code,
        "version": settings.app_version,
    }
'@

Write-ManagedFile "src/sgoda/main.py" @'
from fastapi import FastAPI

from sgoda.api.routes import router
from sgoda.core.config import settings

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="Backend base del ecosistema SGODA-PUINAVE.",
)

app.include_router(router)
'@

Write-ManagedFile "tests/test_spb_005_1_foundation_runtime.py" @'
from fastapi.testclient import TestClient

from sgoda.main import app

client = TestClient(app)


def test_health_endpoint() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "ok"
    assert payload["service"] == "SGODA-PUINAVE API"
    assert payload["version"] == "0.1.0"


def test_version_endpoint() -> None:
    response = client.get("/version")
    assert response.status_code == 200
    assert response.json() == {
        "project": "SGODA-PUINAVE",
        "version": "0.1.0",
    }
'@

Write-ManagedFile "requirements.txt" @'
fastapi>=0.116,<1.0
uvicorn[standard]>=0.35,<1.0
pydantic>=2.11,<3.0
httpx>=0.28,<1.0
pytest>=8.4,<9.0
'@

Write-ManagedFile ".env.example" @'
SGODA_PROJECT_CODE=SGODA-PUINAVE
SGODA_APP_NAME=SGODA-PUINAVE API
SGODA_APP_VERSION=0.1.0
SGODA_ENVIRONMENT=development
SGODA_HOST=127.0.0.1
SGODA_PORT=8000
'@

Write-ManagedFile "scripts/Start-SGODA.ps1" @'
[CmdletBinding()]
param(
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvPython = Join-Path $Root ".venv\Scripts\python.exe"

if (-not (Test-Path $VenvPython)) {
    throw "No existe .venv. Ejecute primero: .\scripts\Install-SPB0051-F001.ps1"
}

$env:PYTHONPATH = Join-Path $Root "src"
& $VenvPython -m uvicorn sgoda.main:app --host $HostAddress --port $Port --reload
'@

Write-ManagedFile "scripts/Test-SPB0051-F001.ps1" @'
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvPython = Join-Path $Root ".venv\Scripts\python.exe"

if (-not (Test-Path $VenvPython)) {
    throw "No existe .venv. Ejecute primero el instalador."
}

$env:PYTHONPATH = Join-Path $Root "src"
& $VenvPython -m pytest tests/test_spb_005_1_foundation_runtime.py -v
if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas de SPB-005.1-F001 fallaron."
}
'@

if (-not $SkipInstall) {
    Write-Step "Preparando entorno virtual"
    $Venv = Join-Path $Root ".venv"
    if (-not (Test-Path $Venv)) {
        python -m venv $Venv
    }

    $Python = Join-Path $Venv "Scripts\python.exe"
    & $Python -m pip install --upgrade pip
    & $Python -m pip install -r (Join-Path $Root "requirements.txt")
}

Write-Step "Instalación finalizada"
Write-Host ""
Write-Host "Pruebas: .\scripts\Test-SPB0051-F001.ps1" -ForegroundColor White
Write-Host "Inicio:  .\scripts\Start-SGODA.ps1" -ForegroundColor White
