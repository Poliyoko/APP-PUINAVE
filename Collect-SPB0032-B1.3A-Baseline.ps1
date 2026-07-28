[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path $RepositoryRoot).Path
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputRoot = Join-Path $root "artifacts\development\spb-003.2-b1.3a"
$work = Join-Path $outputRoot "baseline-$timestamp"
$zip = Join-Path $outputRoot "SPB-003.2-B1.3A-baseline-$timestamp.zip"

New-Item -ItemType Directory -Force -Path $work | Out-Null

$paths = @(
    "src\sgoda\pmo\audit",
    "src\sgoda\pmo\closure",
    "tests",
    ".github\workflows\spb-003-2-closure-audit.yml",
    ".github\workflows\spb-003.2-closure.yml",
    "Start-SPB0032-Closure.ps1",
    "Upgrade-SPB0032-NativeAuditor-AutoClosure.ps1",
    "Refactor-SPB0032-ModularRepositoryAuditor.ps1",
    "Install-SPB0032RepositoryAuditor.ps1",
    ".gitignore",
    "pyproject.toml",
    "builder\pyproject.toml",
    "builder\requirements.txt"
)

foreach ($relative in $paths) {
    $source = Join-Path $root $relative
    if (-not (Test-Path $source)) {
        continue
    }

    $target = Join-Path $work $relative
    $targetParent = Split-Path -Parent $target
    New-Item -ItemType Directory -Force -Path $targetParent | Out-Null

    if ((Get-Item $source).PSIsContainer) {
        Copy-Item $source $target -Recurse -Force
    }
    else {
        Copy-Item $source $target -Force
    }
}

# Excluir caches, entornos y respaldos del paquete de diagnóstico.
Get-ChildItem $work -Recurse -Force |
    Where-Object {
        $_.FullName -match "\\(__pycache__|\.pytest_cache|\.venv)(\\|$)" -or
        $_.Name -match "\.backup-\d{8}-\d{6}$" -or
        $_.Extension -eq ".pyc"
    } |
    Sort-Object FullName -Descending |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

$diagnostics = Join-Path $work "_diagnostics"
New-Item -ItemType Directory -Force -Path $diagnostics | Out-Null

Push-Location $root
try {
    git status --short |
        Out-File (Join-Path $diagnostics "git-status-short.txt") -Encoding utf8

    git branch --show-current |
        Out-File (Join-Path $diagnostics "git-current-branch.txt") -Encoding utf8

    git remote -v |
        Out-File (Join-Path $diagnostics "git-remotes.txt") -Encoding utf8

    git log -10 --oneline --decorate |
        Out-File (Join-Path $diagnostics "git-last-10-commits.txt") -Encoding utf8

    Get-ChildItem "src\sgoda\pmo\audit" -Recurse -File |
        Select-Object FullName, Length, LastWriteTime |
        Format-Table -AutoSize |
        Out-String |
        Out-File (Join-Path $diagnostics "audit-files.txt") -Encoding utf8

    Get-ChildItem "src\sgoda\pmo\closure" -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object FullName, Length, LastWriteTime |
        Format-Table -AutoSize |
        Out-String |
        Out-File (Join-Path $diagnostics "closure-files.txt") -Encoding utf8
}
finally {
    Pop-Location
}

$manifest = [ordered]@{
    scope = "SPB-003.2-B1.3A"
    generated_at = (Get-Date).ToString("o")
    repository_root = $root
    current_branch = (git -C $root branch --show-current)
    purpose = "Captura segura de la implementación existente antes del refactor"
    excludes = @(
        "__pycache__",
        ".pytest_cache",
        ".venv",
        "*.pyc",
        "*.backup-*"
    )
}

$manifest |
    ConvertTo-Json -Depth 5 |
    Set-Content (Join-Path $work "manifest.json") -Encoding utf8

if (Test-Path $zip) {
    Remove-Item $zip -Force
}

Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force

Write-Host ""
Write-Host "Captura terminada." -ForegroundColor Green
Write-Host "Archivo generado:" -ForegroundColor Cyan
Write-Host $zip
