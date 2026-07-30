[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Resolve-Path $RepositoryRoot).Path
Set-Location $root

# Normalizar la consola de Windows/PowerShell a UTF-8.
try {
    chcp 65001 | Out-Null
} catch {
    # PowerShell moderno puede no requerir chcp.
}

[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$testPath = Join-Path $root "tests\pmo\utf8\test_repository_utf8.py"
if (-not (Test-Path $testPath)) {
    throw "No se encontró la prueba UTF-8: $testPath"
}

$backupRoot = Join-Path $root "artifacts\pmo\SPB-005.3-UTF8-REPOSITORY-STANDARD\patch-backups"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
Copy-Item $testPath (Join-Path $backupRoot "test_repository_utf8.py.before-v1.2") -Force

$testContent = @'
from pathlib import Path

from sgoda.pmo.utf8.repository_utf8 import detect_newline_style, scan_file


def test_detects_utf8_file(tmp_path: Path) -> None:
    path = tmp_path / "sample.md"
    path.write_text("Auditoría Puinave", encoding="utf-8")

    result = scan_file(path, tmp_path)

    assert result.utf8_valid is True
    assert result.bom is False
    assert result.status == "COMPLIANT"


def test_detects_utf8_bom(tmp_path: Path) -> None:
    path = tmp_path / "sample.txt"
    path.write_bytes(b"\xef\xbb\xbfTexto")

    result = scan_file(path, tmp_path)

    assert result.bom is True
    assert result.status == "NON_COMPLIANT"


def test_detects_mojibake(tmp_path: Path) -> None:
    path = tmp_path / "sample.md"

    # Se construye en tiempo de ejecución para impedir que el normalizador
    # repare el propio fixture dentro del archivo de prueba.
    corrupted = bytes(
        [65, 117, 100, 105, 116, 111, 114, 195, 131, 194, 173, 97]
    ).decode("utf-8")
    path.write_text(corrupted, encoding="utf-8")

    result = scan_file(path, tmp_path)

    assert result.mojibake is True
    assert result.status == "NON_COMPLIANT"


def test_detects_mixed_newlines() -> None:
    assert detect_newline_style(b"a\r\nb\nc") == "MIXED"
'@

[System.IO.File]::WriteAllText(
    $testPath,
    $testContent,
    [System.Text.UTF8Encoding]::new($false)
)

$env:PYTHONPATH = "src"

Write-Host ""
Write-Host "Ejecutando pruebas UTF-8 corregidas..."
python -m pytest tests/pmo/utf8/test_repository_utf8.py -q
$testExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "Ejecutando auditoría UTF-8 final..."
python -m sgoda.pmo.utf8.repository_utf8 --root .
$auditExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "Incidencias restantes:"
$incidentPath = Join-Path $root "artifacts\pmo\SPB-005.3-UTF8-REPOSITORY-STANDARD\utf8-incidents.csv"

if ((Test-Path $incidentPath) -and ((Get-Item $incidentPath).Length -gt 0)) {
    Import-Csv $incidentPath -Encoding utf8 |
        Select-Object path, encoding, bom, mojibake, replacement_character, detail |
        Format-Table -AutoSize
}
else {
    Write-Host "Ninguna."
}

Write-Host ""
Write-Host "Parche SPB-005.3 v1.2 aplicado."
Write-Host "Pruebas exit code  : $testExitCode"
Write-Host "Auditoría exit code: $auditExitCode"

if ($testExitCode -ne 0) {
    exit $testExitCode
}

exit $auditExitCode
