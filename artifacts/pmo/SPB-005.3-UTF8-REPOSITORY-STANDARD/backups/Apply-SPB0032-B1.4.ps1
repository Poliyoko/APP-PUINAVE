[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot = (Get-Location).Path,

    [switch]$Apply
)

$ErrorActionPreference = "Stop"

[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$root = (Resolve-Path $RepositoryRoot).Path
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$parent = Split-Path $root -Parent
$archiveRoot = Join-Path $parent "SGODA-PUINAVE-ARCHIVE-SPB-003.2-B1.4-$timestamp"
$evidenceRoot = Join-Path $root "artifacts\development\spb-003.2-b1.4"
$reportJson = Join-Path $evidenceRoot "mojibake-normalization-report.json"

Write-Host ""
Write-Host "SPB-003.2-B1.4 - Normalización del repositorio" -ForegroundColor Cyan
Write-Host "Repositorio: $root"
Write-Host "Modo: $(if ($Apply) { 'APLICAR' } else { 'SIMULACIÓN' })"
Write-Host ""

New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null

$pythonScript = @'
from __future__ import annotations

import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
apply_changes = sys.argv[2].lower() == "true"
report_path = Path(sys.argv[3]).resolve()
archive_root = Path(sys.argv[4]).resolve()

TEXT_EXTENSIONS = {
    ".py", ".md", ".json", ".txt", ".ps1", ".yml", ".yaml",
    ".toml", ".ini", ".cfg", ".csv", ".html", ".xml"
}

SKIP_DIR_NAMES = {
    ".git", ".venv", "venv", "__pycache__", ".pytest_cache",
    ".mypy_cache", ".ruff_cache", "node_modules"
}

# Los expedientes generados y respaldos históricos no forman parte del
# árbol fuente que debe analizarse o normalizarse.
SKIP_PREFIXES = (
    "artifacts/backups/",
    "artifacts/development/",
    "artifacts/closure/",
    "artifacts/spb-003.2/",
    "artifacts/audit/spb-003.2/",
)

SUSPICIOUS = tuple(
    chr(value)
    for value in (
        0x00C3,
        0x00C2,
        0x00E2,
        0x00F0,
        0xFFFD,
        0x0192,
        0x20AC,
        0x2122,
        0x0153,
        0x017E,
    )
)
def score(text: str) -> int:
    return sum(text.count(marker) for marker in SUSPICIOUS)

def decode_candidate(token: str) -> str:
    current = token
    for _ in range(3):
        if score(current) == 0:
            break

        candidates: list[str] = []
        for encoding in ("cp1252", "latin1"):
            try:
                candidates.append(current.encode(encoding).decode("utf-8"))
            except (UnicodeEncodeError, UnicodeDecodeError):
                pass

        if not candidates:
            break

        best = min(candidates, key=lambda value: (score(value), len(value)))
        if score(best) >= score(current):
            break
        current = best

    return current

# Corrige únicamente fragmentos que contienen marcadores sospechosos.
TOKEN_RE = re.compile(r"\S+")

def repair_text(text: str) -> str:
    def replace(match: re.Match[str]) -> str:
        token = match.group(0)
        if not any(marker in token for marker in SUSPICIOUS):
            return token
        return decode_candidate(token)

    previous = text
    for _ in range(3):
        repaired = TOKEN_RE.sub(replace, previous)
        if repaired == previous:
            break
        previous = repaired
    return previous

def relative_posix(path: Path) -> str:
    return path.relative_to(root).as_posix()

def skipped(path: Path) -> bool:
    rel = relative_posix(path)
    if any(part in SKIP_DIR_NAMES for part in path.relative_to(root).parts):
        return True
    return rel.startswith(SKIP_PREFIXES)

def is_backup(path: Path) -> bool:
    name = path.name.lower()
    return (
        ".backup-" in name
        or name.endswith(".bak")
        or name.endswith(".tmp")
        or name.endswith("~")
    )

files_scanned = 0
files_changed: list[dict[str, object]] = []
files_unresolved: list[dict[str, object]] = []
backup_files: list[str] = []

for path in root.rglob("*"):
    if not path.is_file() or skipped(path):
        continue

    rel = relative_posix(path)

    if is_backup(path):
        backup_files.append(rel)
        continue

    if path.suffix.lower() not in TEXT_EXTENSIONS:
        continue

    files_scanned += 1
    try:
        original = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        files_unresolved.append({
            "file": rel,
            "reason": "invalid_utf8",
        })
        continue

    before_score = score(original)
    if before_score == 0:
        continue

    repaired = repair_text(original)
    after_score = score(repaired)

    if repaired != original and after_score < before_score:
        files_changed.append({
            "file": rel,
            "before_score": before_score,
            "after_score": after_score,
            "applied": apply_changes,
        })
        if apply_changes:
            path.write_text(repaired, encoding="utf-8", newline="")
    else:
        files_unresolved.append({
            "file": rel,
            "reason": "no_safe_improvement",
            "score": before_score,
        })

moved_backups: list[dict[str, str]] = []
if apply_changes and backup_files:
    for rel in backup_files:
        source = root / Path(rel)
        destination = archive_root / "repository-backups" / Path(rel)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(source), str(destination))
        moved_backups.append({
            "source": rel,
            "destination": str(destination),
        })

# Traslada expedientes históricos completos fuera del repositorio.
historical_dirs = (
    "artifacts/backups",
    "artifacts/closure",
    "artifacts/spb-003.2",
)
moved_directories: list[dict[str, str]] = []
if apply_changes:
    for rel in historical_dirs:
        source = root / Path(rel)
        if not source.exists():
            continue
        destination = archive_root / "historical-artifacts" / Path(rel)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(source), str(destination))
        moved_directories.append({
            "source": rel,
            "destination": str(destination),
        })

# Limpia el expediente activo para que el nuevo informe no herede mojibake.
active_audit = root / "artifacts" / "audit" / "spb-003.2"
removed_active_audit = False
if apply_changes and active_audit.exists():
    shutil.rmtree(active_audit)
    removed_active_audit = True

report = {
    "project": "SGODA-PUINAVE",
    "increment": "SPB-003.2-B1.4",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "repository": str(root),
    "mode": "apply" if apply_changes else "dry-run",
    "files_scanned": files_scanned,
    "files_changed": files_changed,
    "files_unresolved": files_unresolved,
    "backup_files_detected": backup_files,
    "moved_backups": moved_backups,
    "moved_directories": moved_directories,
    "active_audit_removed": removed_active_audit,
    "external_archive": str(archive_root) if apply_changes else None,
}
report_path.parent.mkdir(parents=True, exist_ok=True)
report_path.write_text(
    json.dumps(report, ensure_ascii=False, indent=2),
    encoding="utf-8",
)

print(json.dumps({
    "mode": report["mode"],
    "files_scanned": files_scanned,
    "files_changed": len(files_changed),
    "files_unresolved": len(files_unresolved),
    "backups_detected": len(backup_files),
    "report": str(report_path),
    "archive": report["external_archive"],
}, ensure_ascii=False, indent=2))
'@

$tempPython = Join-Path $env:TEMP "spb-0032-b1-4-normalize-$timestamp.py"
[System.IO.File]::WriteAllText(
    $tempPython,
    $pythonScript,
    [System.Text.UTF8Encoding]::new($false)
)

try {
    python $tempPython `
        $root `
        $Apply.IsPresent.ToString().ToLowerInvariant() `
        $reportJson `
        $archiveRoot

    if ($LASTEXITCODE -ne 0) {
        throw "Falló el normalizador Python."
    }
}
finally {
    Remove-Item $tempPython -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Informe: $reportJson" -ForegroundColor Green

if (-not $Apply) {
    Write-Host ""
    Write-Host "Simulación completada. Revise el informe y ejecute nuevamente con -Apply." -ForegroundColor Yellow
}
else {
    Write-Host "Normalización aplicada." -ForegroundColor Green
    Write-Host "Archivo externo: $archiveRoot" -ForegroundColor Green
}
