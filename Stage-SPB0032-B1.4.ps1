[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot = (Get-Location).Path,

    [switch]$Apply
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path $RepositoryRoot).Path
Push-Location $root

try {
    if (-not (Test-Path ".git")) {
        throw "No se encontró .git en la raíz."
    }

    $gitignoreLines = @(
        "# Python",
        "__pycache__/",
        "*.py[cod]",
        ".pytest_cache/",
        ".mypy_cache/",
        ".ruff_cache/",
        ".venv/",
        "venv/",
        "",
        "# Respaldos y temporales",
        "*.bak",
        "*.tmp",
        "*~",
        "*.backup-*",
        "",
        "# Artefactos generados o históricos",
        "artifacts/backups/",
        "artifacts/development/",
        "artifacts/closure/",
        "artifacts/spb-003.2/",
        "artifacts/audit/spb-003.2/",
        "",
        "# Paquetes locales",
        "*.zip"
    )

    $gitignore = Join-Path $root ".gitignore"
    $gitignoreContent = $gitignoreLines -join [Environment]::NewLine

    $targets = @(
        ".gitignore",
        "README.md",
        ".github/workflows/spb-003-2-closure-audit.yml",
        "docs",
        "knowledge",
        "scripts",
        "src",
        "tests"
    )

    Write-Host "Archivos previstos para incorporación:" -ForegroundColor Cyan
    $targets | ForEach-Object {
        $exists = Test-Path $_
        "{0,-55} {1}" -f $_, $(if ($exists) { "OK" } else { "NO EXISTE" })
    }

    Write-Host ""
    Write-Host "Se excluyen deliberadamente:" -ForegroundColor Yellow
    Write-Host "- Instaladores y scripts heredados situados en la raíz."
    Write-Host "- Respaldos y temporales."
    Write-Host "- Artefactos de ejecución y auditorías regenerables."
    Write-Host "- Commits, pushes y tags automáticos."
    Write-Host ""

    if (-not $Apply) {
        Write-Host "Simulación completada. Use -Apply para crear .gitignore y preparar staging." -ForegroundColor Yellow
        return
    }

    [System.IO.File]::WriteAllText(
        $gitignore,
        $gitignoreContent,
        [System.Text.UTF8Encoding]::new($false)
    )

    foreach ($target in $targets) {
        if (Test-Path $target) {
            git add -- $target
            if ($LASTEXITCODE -ne 0) {
                throw "No se pudo agregar: $target"
            }
        }
    }

    Write-Host ""
    Write-Host "Staging preparado. No se creó commit." -ForegroundColor Green
    git status --short
}
finally {
    Pop-Location
}
