[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [switch]$ApplyNormalization,

    [Parameter(Mandatory = $false)]
    [switch]$RunTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content
    )

    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    $baseUri = [System.Uri]((Resolve-Path $BasePath).Path.TrimEnd('\') + '\')
    $targetUri = [System.Uri](Resolve-Path $TargetPath).Path
    return [System.Uri]::UnescapeDataString(
        $baseUri.MakeRelativeUri($targetUri).ToString()
    ).Replace('/', '\')
}

$root = (Resolve-Path $RepositoryRoot).Path
Set-Location $root

$artifactRoot = Join-Path $root "artifacts\pmo\SPB-005.3-UTF8-REPOSITORY-STANDARD"
$backupRoot = Join-Path $artifactRoot "backups"
New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

$editorConfig = @'
root = true

[*]
charset = utf-8
insert_final_newline = true
trim_trailing_whitespace = true
end_of_line = lf

[*.ps1]
end_of_line = crlf

[*.bat]
end_of_line = crlf

[*.cmd]
end_of_line = crlf

[*.md]
trim_trailing_whitespace = false
'@

$gitAttributes = @'
* text=auto

*.py   text eol=lf working-tree-encoding=UTF-8
*.md   text eol=lf working-tree-encoding=UTF-8
*.txt  text eol=lf working-tree-encoding=UTF-8
*.json text eol=lf working-tree-encoding=UTF-8
*.yml  text eol=lf working-tree-encoding=UTF-8
*.yaml text eol=lf working-tree-encoding=UTF-8
*.toml text eol=lf working-tree-encoding=UTF-8
*.ini  text eol=lf working-tree-encoding=UTF-8
*.cfg  text eol=lf working-tree-encoding=UTF-8
*.csv  text eol=lf working-tree-encoding=UTF-8
*.rst  text eol=lf working-tree-encoding=UTF-8
*.sh   text eol=lf working-tree-encoding=UTF-8

*.ps1  text eol=crlf working-tree-encoding=UTF-8
*.bat  text eol=crlf working-tree-encoding=UTF-8
*.cmd  text eol=crlf working-tree-encoding=UTF-8

*.png  binary
*.jpg  binary
*.jpeg binary
*.gif  binary
*.webp binary
*.mp3  binary
*.wav  binary
*.ogg  binary
*.pdf  binary
*.xlsx binary
*.docx binary
*.pptx binary
*.zip  binary
'@

$policy = @'
# Estándar UTF-8 del Repositorio SGODA-PUINAVE

## Identificador

SPB-005.3 — UTF-8 Repository Standard

## Objetivo

Garantizar que el código fuente, los scripts, la documentación, los datos, la configuración y los artefactos del PMO Digital utilicen UTF-8 de forma consistente.

## Reglas obligatorias

1. Los archivos de texto del repositorio deben almacenarse en UTF-8.
2. El código fuente y los scripts deben usar UTF-8 sin BOM.
3. Python debe leer y escribir texto indicando `encoding="utf-8"`.
4. PowerShell debe usar funciones basadas en `System.IO.File` con `UTF8Encoding($false)` cuando se requiera comportamiento uniforme entre versiones.
5. No se permite introducir caracteres de reemplazo `�`.
6. No se permite introducir secuencias de mojibake como `Ã`, `Â`, `â€™`, `â€œ` o `â€`.
7. La auditoría UTF-8 debe ejecutarse antes del cierre de entregables y antes de releases.
8. Los archivos binarios quedan excluidos de la normalización textual.

## Lectura y escritura en Python

```python
from pathlib import Path

text = Path("archivo.md").read_text(encoding="utf-8")
Path("salida.md").write_text(text, encoding="utf-8")
```

## Lectura y escritura en PowerShell

```powershell
$content = [System.IO.File]::ReadAllText(
    $Path,
    [System.Text.Encoding]::UTF8
)

[System.IO.File]::WriteAllText(
    $Path,
    $content,
    [System.Text.UTF8Encoding]::new($false)
)
```

## Evidencias

La auditoría genera inventario, resumen JSON, informe Markdown y listado de incidencias bajo:

`artifacts/pmo/SPB-005.3-UTF8-REPOSITORY-STANDARD/`
'@

$adr = @'
# ADR-009 — Estándar UTF-8 del Repositorio

- **Estado:** Aceptado
- **Decisión:** Usar UTF-8 como codificación obligatoria para todos los archivos textuales.
- **Ámbito:** código, scripts, documentación, datos, configuración y artefactos.
- **Motivación:** evitar pérdida o corrupción de caracteres en lengua Puinave, español e inglés, y asegurar interoperabilidad entre Windows, Linux, GitHub, Python y PowerShell.
- **Consecuencias positivas:** consistencia, portabilidad, trazabilidad y reducción de mojibake.
- **Riesgos:** archivos históricos pueden contener corrupción previa; su reparación debe conservar copia de seguridad y evidencia.
- **Controles:** `.editorconfig`, `.gitattributes`, auditor automático, normalizador y pruebas.
'@

$moduleInit = @'
"""Servicios de auditoría y normalización UTF-8 del PMO Digital."""
'@

$utf8Module = @'
from __future__ import annotations

import argparse
import csv
import json
import shutil
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

TEXT_EXTENSIONS = {
    ".py", ".ps1", ".psm1", ".psd1", ".md", ".txt", ".json", ".yml",
    ".yaml", ".toml", ".ini", ".cfg", ".csv", ".rst", ".sh", ".bat",
    ".cmd", ".xml", ".html", ".css", ".js", ".ts",
}

EXCLUDED_DIRECTORIES = {
    ".git", ".venv", "venv", "__pycache__", ".pytest_cache", ".mypy_cache",
    ".ruff_cache", "node_modules",
}

MOJIBAKE_MARKERS = (
    "Ã", "Â", "â€™", "â€œ", "â€", "â€“", "â€”", "ðŸ", "�",
)


@dataclass(frozen=True)
class ScanResult:
    path: str
    encoding: str
    utf8_valid: bool
    bom: bool
    mojibake: bool
    replacement_character: bool
    newline_style: str
    status: str
    detail: str


def iter_text_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if any(part in EXCLUDED_DIRECTORIES for part in path.parts):
            continue
        if path.suffix.lower() in TEXT_EXTENSIONS:
            yield path


def detect_newline_style(data: bytes) -> str:
    has_crlf = b"\r\n" in data
    reduced = data.replace(b"\r\n", b"")
    has_lf = b"\n" in reduced
    if has_crlf and has_lf:
        return "MIXED"
    if has_crlf:
        return "CRLF"
    if has_lf:
        return "LF"
    return "NONE"


def scan_file(path: Path, root: Path) -> ScanResult:
    data = path.read_bytes()
    bom = data.startswith(b"\xef\xbb\xbf")

    try:
        text = data.decode("utf-8-sig")
        encoding = "UTF-8-BOM" if bom else "UTF-8"
        utf8_valid = True
    except UnicodeDecodeError as exc:
        text = data.decode("cp1252", errors="replace")
        encoding = "NON-UTF8"
        utf8_valid = False
        decode_detail = str(exc)
    else:
        decode_detail = ""

    mojibake = any(marker in text for marker in MOJIBAKE_MARKERS)
    replacement = "�" in text

    problems: list[str] = []
    if not utf8_valid:
        problems.append("invalid_utf8")
    if bom:
        problems.append("bom")
    if mojibake:
        problems.append("mojibake")
    if replacement:
        problems.append("replacement_character")

    status = "COMPLIANT" if not problems else "NON_COMPLIANT"
    detail = ",".join(problems) or "ok"
    if decode_detail:
        detail = f"{detail}: {decode_detail}"

    return ScanResult(
        path=path.relative_to(root).as_posix(),
        encoding=encoding,
        utf8_valid=utf8_valid,
        bom=bom,
        mojibake=mojibake,
        replacement_character=replacement,
        newline_style=detect_newline_style(data),
        status=status,
        detail=detail,
    )


def normalize_file(path: Path, backup_root: Path, root: Path) -> str:
    data = path.read_bytes()
    relative = path.relative_to(root)
    backup = backup_root / relative
    backup.parent.mkdir(parents=True, exist_ok=True)

    if not backup.exists():
        shutil.copy2(path, backup)

    try:
        text = data.decode("utf-8-sig")
        source_encoding = "utf-8"
    except UnicodeDecodeError:
        text = data.decode("cp1252")
        source_encoding = "cp1252"

    path.write_text(text, encoding="utf-8", newline="")
    return source_encoding


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return

    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def run(root: Path, artifact_root: Path, apply: bool) -> int:
    backup_root = artifact_root / "backups"
    artifact_root.mkdir(parents=True, exist_ok=True)
    backup_root.mkdir(parents=True, exist_ok=True)

    before = [scan_file(path, root) for path in iter_text_files(root)]
    normalized: list[dict[str, str]] = []

    if apply:
        for item in before:
            if item.status != "NON_COMPLIANT":
                continue
            source = root / item.path
            source_encoding = normalize_file(source, backup_root, root)
            normalized.append(
                {
                    "path": item.path,
                    "source_encoding": source_encoding,
                    "target_encoding": "utf-8",
                }
            )

    after = [scan_file(path, root) for path in iter_text_files(root)]

    inventory = [asdict(item) for item in after]
    incidents = [row for row in inventory if row["status"] != "COMPLIANT"]

    total = len(inventory)
    compliant = total - len(incidents)
    compliance = round((compliant / total * 100), 2) if total else 100.0

    summary = {
        "identifier": "SPB-005.3-UTF8-REPOSITORY-STANDARD",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "root": str(root),
        "apply_normalization": apply,
        "files_scanned": total,
        "files_compliant": compliant,
        "files_non_compliant": len(incidents),
        "files_normalized": len(normalized),
        "compliance_percent": compliance,
    }

    write_csv(artifact_root / "encoding-inventory.csv", inventory)
    write_csv(artifact_root / "utf8-incidents.csv", incidents)
    write_csv(artifact_root / "normalized-files.csv", normalized)
    (artifact_root / "utf8-summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    report = [
        "# Auditoría UTF-8 del Repositorio",
        "",
        f"- **Identificador:** {summary['identifier']}",
        f"- **Archivos revisados:** {total}",
        f"- **Archivos conformes:** {compliant}",
        f"- **Archivos no conformes:** {len(incidents)}",
        f"- **Archivos normalizados:** {len(normalized)}",
        f"- **Cumplimiento:** {compliance}%",
        "",
        "## Resultado",
        "",
        "PASS" if not incidents else "FAIL",
        "",
        "## Evidencias",
        "",
        "- `encoding-inventory.csv`",
        "- `utf8-incidents.csv`",
        "- `normalized-files.csv`",
        "- `utf8-summary.json`",
    ]
    (artifact_root / "utf8-report.md").write_text(
        "\n".join(report) + "\n",
        encoding="utf-8",
    )

    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if not incidents else 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--artifact-root",
        default="artifacts/pmo/SPB-005.3-UTF8-REPOSITORY-STANDARD",
    )
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    artifact_root = (root / args.artifact_root).resolve()
    return run(root, artifact_root, args.apply)


if __name__ == "__main__":
    raise SystemExit(main())
'@

$testModule = @'
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
    path.write_text("AuditorÃ­a", encoding="utf-8")

    result = scan_file(path, tmp_path)

    assert result.mojibake is True
    assert result.status == "NON_COMPLIANT"


def test_detects_mixed_newlines() -> None:
    assert detect_newline_style(b"a\r\nb\nc") == "MIXED"
'@

$workflow = @'
name: UTF-8 Repository Compliance

on:
  pull_request:
  push:
    branches:
      - main
      - develop

jobs:
  utf8-compliance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Audit UTF-8 repository compliance
        env:
          PYTHONPATH: src
        run: |
          python -m sgoda.pmo.utf8.repository_utf8 --root .
'@

$paths = @{
    ".editorconfig" = $editorConfig
    ".gitattributes" = $gitAttributes
    "docs\standards\UTF8-Repository-Standard.md" = $policy
    "docs\03_ADR\ADR-009-UTF8-Repository-Standard.md" = $adr
    "src\sgoda\pmo\utf8\__init__.py" = $moduleInit
    "src\sgoda\pmo\utf8\repository_utf8.py" = $utf8Module
    "tests\pmo\utf8\test_repository_utf8.py" = $testModule
    ".github\workflows\utf8-repository-compliance.yml" = $workflow
}

$manifest = [System.Collections.Generic.List[string]]::new()

foreach ($relativePath in $paths.Keys) {
    $target = Join-Path $root $relativePath
    if (Test-Path $target) {
        $backup = Join-Path $backupRoot $relativePath
        $backupDirectory = Split-Path -Parent $backup
        if (-not (Test-Path $backupDirectory)) {
            New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
        }
        Copy-Item $target $backup -Force
        $manifest.Add("BACKUP`t$relativePath")
    }

    Write-Utf8NoBom -Path $target -Content $paths[$relativePath]
    $manifest.Add("WRITE`t$relativePath")
}

$commands = @'
# Auditoría solamente
$env:PYTHONPATH = "src"
python -m sgoda.pmo.utf8.repository_utf8 --root .

# Normalización con copias de seguridad y evidencias
$env:PYTHONPATH = "src"
python -m sgoda.pmo.utf8.repository_utf8 --root . --apply

# Pruebas
$env:PYTHONPATH = "src"
python -m pytest tests/pmo/utf8/test_repository_utf8.py -q
'@

Write-Utf8NoBom -Path (Join-Path $artifactRoot "recommended-commands.ps1") -Content $commands
Write-Utf8NoBom -Path (Join-Path $artifactRoot "implementation-manifest.txt") -Content (($manifest -join [Environment]::NewLine) + [Environment]::NewLine)

$env:PYTHONPATH = "src"

$auditArgs = @(
    "-m", "sgoda.pmo.utf8.repository_utf8",
    "--root", "."
)

if ($ApplyNormalization) {
    $auditArgs += "--apply"
}

Write-Host ""
Write-Host "Ejecutando auditoría UTF-8..."
& python @auditArgs
$auditExitCode = $LASTEXITCODE

if ($RunTests) {
    Write-Host ""
    Write-Host "Ejecutando pruebas UTF-8..."
    & python -m pytest tests/pmo/utf8/test_repository_utf8.py -q
    $testExitCode = $LASTEXITCODE
}
else {
    $testExitCode = 0
}

Write-Host ""
Write-Host "SPB-005.3 instalado."
Write-Host "Archivos creados/actualizados: $($paths.Count)"
Write-Host "Evidencias: artifacts/pmo/SPB-005.3-UTF8-REPOSITORY-STANDARD"
Write-Host ""
Write-Host "Auditoría exit code: $auditExitCode"
Write-Host "Pruebas exit code  : $testExitCode"
Write-Host ""
Write-Host "Siguiente ejecución recomendada:"
Write-Host '  .\Apply-SPB0053-UTF8RepositoryStandard.ps1 -RepositoryRoot (Get-Location).Path -ApplyNormalization -RunTests'

if ($testExitCode -ne 0) {
    exit $testExitCode
}

exit $auditExitCode
