$ErrorActionPreference = "Stop"

$Distro = "Ubuntu-24.04"
$PythonWsl = "/opt/sgoda-real508-venv/bin/python"
$RootWindows = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$RootWsl = (wsl -d $Distro -u root -- wslpath -a $RootWindows).Trim()

if ([string]::IsNullOrWhiteSpace($RootWsl)) {
    throw "SGODA_WSL_PROJECT_PATH_FAIL"
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SGODA-PUINAVE REAL508 - BACKEND INSTITUCIONAL" -ForegroundColor Cyan
Write-Host "============================================================"
Write-Host "DATASET=REAL508"
Write-Host "LEXICAL_REAL=508"
Write-Host "AUDIO_PUINAVE_REAL=508"
Write-Host "IMAGES_REAL=30"
Write-Host "PILOTO25=FROZEN_REFERENCE_ONLY"

& wsl -d $Distro -u root -- systemctl is-active --quiet postgresql
if ($LASTEXITCODE -ne 0) { throw "POSTGRESQL_NOT_ACTIVE" }

& wsl -d $Distro -u root -- test -x $PythonWsl
if ($LASTEXITCODE -ne 0) { throw "SGODA_WSL_VENV_NOT_FOUND" }

Write-Host "POSTGRESQL_WSL_NATIVE=PASS" -ForegroundColor Green
Write-Host "PYTHON_WSL_NATIVE=PASS" -ForegroundColor Green

$RuntimeDir = "/run/sgoda-real508"
$Runtime = "$RuntimeDir/sgoda_real508_runtime.py"

$Python = @(
    "from pathlib import Path"
    "import psycopg"
    "from sgoda.operational_platform.api import create_app"
    "from sgoda.operational_platform.postgres_repository import PostgreSQLOperationalRepository"
    ""
    "ROOT = Path(r'$RootWsl')"
    ""
    "def find_settings():"
    "    candidates = ["
    "        ROOT / 'config' / 'operational-settings.json',"
    "        ROOT / 'config' / 'operational_settings.json',"
    "        ROOT / 'config' / 'real508' / 'operational-settings.json',"
    "        ROOT / 'config' / 'real508' / 'operational_settings.json',"
    "    ]"
    "    for candidate in candidates:"
    "        if candidate.is_file():"
    "            return candidate"
    "    matches = sorted(ROOT.rglob('*operational*settings*.json'))"
    "    if not matches:"
    "        raise RuntimeError('OPERATIONAL_SETTINGS_NOT_FOUND')"
    "    return matches[0]"
    ""
    "class ResilientConnection:"
    "    def __init__(self):"
    "        self._connection = None"
    ""
    "    def _connect(self):"
    "        connection = psycopg.connect("
    "            host='127.0.0.1',"
    "            port=5432,"
    "            dbname='sgoda',"
    "            user='sgoda',"
    "            connect_timeout=5,"
    "        )"
    "        connection.autocommit = True"
    "        return connection"
    ""
    "    def cursor(self):"
    "        if self._connection is None or self._connection.closed:"
    "            self._connection = self._connect()"
    "        return self._connection.cursor()"
    ""
    "repository = PostgreSQLOperationalRepository(ResilientConnection())"
    ""
    "app = create_app("
    "    settings_path=ROOT / 'config' / 'operational_platform' / 'SPT-011-runtime.json',"
    "    rlb_path='REAL508_POSTGRESQL',"
    "    media_path=None,"
    "    repository=repository,"
    ")"
)

$PythonSource = $Python -join "`n"

$PythonSource | wsl -d $Distro -u root -- bash -c "mkdir -p '$RuntimeDir'; cat > '$Runtime'"
if ($LASTEXITCODE -ne 0) { throw "REAL508_RUNTIME_WRITE_FAIL" }

& wsl -d $Distro -u root -- env "PYTHONPATH=$RootWsl/src" $PythonWsl -m py_compile $Runtime
if ($LASTEXITCODE -ne 0) { throw "REAL508_RUNTIME_COMPILE_FAIL" }

Write-Host "REAL508_RUNTIME_COMPILE=PASS" -ForegroundColor Green
Write-Host "FASTAPI_ARCHITECTURE=WSL_NATIVE" -ForegroundColor Green
Write-Host "WINDOWS_POSTGRESQL_BRIDGE=NOT_REQUIRED" -ForegroundColor Green

Write-Host ""
Write-Host "Iniciando FastAPI REAL508 en puerto 8000..." -ForegroundColor Yellow
Write-Host "NO CIERRE ESTA CONSOLA." -ForegroundColor Cyan
Write-Host ""

# REAL508_MANAGED_UVICORN_START
$ExistingListener = & wsl -d $Distro -u root -- bash -lc "ss -lntp | grep ':8000 ' || true"

if ($ExistingListener -match "LISTEN") {
    Write-Host "REAL508_PORT_8000=ALREADY_LISTENING" -ForegroundColor Yellow
}
else {
    $StartCommand = "nohup env PGPASSFILE=/root/.pgpass PYTHONPATH='$RootWsl/src:/run/sgoda-real508' '$PythonWsl' -m uvicorn sgoda_real508_runtime:app --app-dir /run/sgoda-real508 --host 0.0.0.0 --port 8000 --log-level info > /run/sgoda-real508/uvicorn.log 2>&1 < /dev/null & echo `$!"

    $ServerPid = (& wsl -d $Distro -u root -- bash -lc $StartCommand | Select-Object -Last 1).Trim()

    if (-not $ServerPid -or $ServerPid -notmatch '^\d+$') {
        throw "SGODA_REAL508_FASTAPI_PROCESS_START_FAIL"
    }

    Write-Host "REAL508_UVICORN_PID=$ServerPid" -ForegroundColor Green
}

$FastApiReady = $false

for ($Attempt = 1; $Attempt -le 20; $Attempt++) {
    Start-Sleep -Seconds 1

    try {
        $Health = Invoke-WebRequest -Uri "http://127.0.0.1:8000/health" -UseBasicParsing -TimeoutSec 2

        if ($Health.StatusCode -eq 200) {
            $FastApiReady = $true
            break
        }
    }
    catch {
    }
}

if (-not $FastApiReady) {
    Write-Host "----- UVICORN LOG -----" -ForegroundColor Yellow
    & wsl -d $Distro -u root -- bash -lc "tail -n 50 /run/sgoda-real508/uvicorn.log 2>/dev/null || true"
    throw "SGODA_REAL508_FASTAPI_HEALTH_FAIL"
}

Write-Host "FASTAPI_HTTP=200" -ForegroundColor Green
Write-Host "SGODA_REAL508_FASTAPI_START=PASS" -ForegroundColor Green
Write-Host "REAL508_URL=http://127.0.0.1:8000" -ForegroundColor Cyan
