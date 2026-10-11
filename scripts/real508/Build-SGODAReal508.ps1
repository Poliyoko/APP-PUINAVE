param(
    [string]$WebApiBase = 'http://127.0.0.1:8000',
    [string]$MobileApiBase,
    [switch]$BuildAndroid
)
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$AppRoot = Join-Path $RepoRoot 'apps\sgoda_puinave_demo'

function Assert-Real508([string]$BaseUrl) {
    $Uri = [Uri]$BaseUrl
    if ($Uri.Scheme -notin @('http', 'https') -or -not $Uri.Host) {
        throw 'REAL508_API_URL_INVALID'
    }
    $Status = Invoke-RestMethod -Uri ($BaseUrl.TrimEnd('/') + '/dataset/status') -TimeoutSec 30
    if ($Status.dataset -ne 'REAL508' -or $Status.ready -ne $true -or $Status.record_count -ne 508) {
        throw 'REAL508_BACKEND_INCOMPLETE: se requieren los 508 IDs reales.'
    }
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'FLUTTER_SDK_NOT_FOUND' }
Assert-Real508 $WebApiBase
if ($BuildAndroid) {
    if (-not $MobileApiBase) { throw 'MOBILE_API_BASE_REQUIRED' }
    if (([Uri]$MobileApiBase).IsLoopback) { throw 'MOBILE_API_LOOPBACK_FORBIDDEN: use la IP LAN o URL del backend.' }
    Assert-Real508 $MobileApiBase
}

Push-Location $AppRoot
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'FLUTTER_PUB_GET_FAIL' }
    & flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'FLUTTER_ANALYZE_FAIL' }
    & flutter test
    if ($LASTEXITCODE -ne 0) { throw 'FLUTTER_TEST_FAIL' }
    & flutter build web --release "--dart-define=SGODA_API_BASE=$($WebApiBase.TrimEnd('/'))"
    if ($LASTEXITCODE -ne 0) { throw 'REAL508_WEB_BUILD_FAIL' }
    if ($BuildAndroid) {
        # APK interno instalable; no afirma firma de publicación en Play Store.
        & flutter build apk --debug "--dart-define=SGODA_API_BASE=$($MobileApiBase.TrimEnd('/'))"
        if ($LASTEXITCODE -ne 0) { throw 'REAL508_ANDROID_BUILD_FAIL' }
        Get-FileHash 'build\app\outputs\flutter-apk\app-debug.apk' -Algorithm SHA256
    }
    Write-Host 'REAL508_BUILD=PASS; DATASET=508; PILOT_FALLBACK=FALSE'
} finally {
    Pop-Location
}
