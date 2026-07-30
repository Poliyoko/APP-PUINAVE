[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Resolve-Path $RepositoryRoot).Path
Set-Location $root

try { chcp 65001 | Out-Null } catch {}
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$modulePath = Join-Path $root "src\sgoda\pmo\utf8\repository_utf8.py"
$testPath = Join-Path $root "tests\pmo\utf8\test_repository_utf8.py"

if (-not (Test-Path $modulePath)) { throw "Missing file: $modulePath" }
if (-not (Test-Path $testPath)) { throw "Missing file: $testPath" }

$backupRoot = Join-Path $root "artifacts\pmo\SPB-005.3-UTF8-REPOSITORY-STANDARD\patch-backups"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
Copy-Item $modulePath (Join-Path $backupRoot "repository_utf8.py.before-v1.4") -Force
Copy-Item $testPath (Join-Path $backupRoot "test_repository_utf8.py.before-v1.4") -Force

$module = @'
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
    ".ruff_cache", "node_modules", "artifacts", "dist", "build",
}

# Unicode escapes keep this source stable under every text editor.
MOJIBAKE_MARKERS = (
    "\u00c3",
    "\u00c2",
    "\u00e2\u20ac",
    "\u00f0\u0178",
    "\ufffd",
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
        relative_parts = path.relative_to(root).parts
        if any(part in EXCLUDED_DIRECTORIES for part in relative_parts):
            continue
        if path.suffix.lower() in TEXT_EXTENSIONS:
            yield path


def detect_newline_style(data: bytes) -> str:
    has_crlf = b"\r\n" in data
    has_lf = b"\n" in data.replace(b"\r\n", b"")
    if has_crlf and has_lf:
        return "MIXED"
    if has_crlf:
        return "CRLF"
    if has_lf:
        return "LF"
    return "NONE"


def count_mojibake(text: str) -> int:
    return sum(text.count(marker) for marker in MOJIBAKE_MARKERS)


def repair_mojibake(text: str) -> tuple[str, bool]:
    current_score = count_mojibake(text)
    if current_score == 0:
        return text, False

    candidates: list[str] = []
    for source_encoding in ("cp1252", "latin-1"):
        try:
            candidate = text.encode(source_encoding).decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            continue
        candidates.append(candidate)

    if not candidates:
        return text, False

    best = min(candidates, key=count_mojibake)
    if count_mojibake(best) < current_score and "\ufffd" not in best:
        return best, True
    return text, False


def scan_file(path: Path, root: Path) -> ScanResult:
    data = path.read_bytes()
    bom = data.startswith(b"\xef\xbb\xbf")

    try:
        text = data.decode("utf-8-sig")
        encoding = "UTF-8-BOM" if bom else "UTF-8"
        utf8_valid = True
        decode_detail = ""
    except UnicodeDecodeError as exc:
        text = data.decode("cp1252", errors="replace")
        encoding = "NON-UTF8"
        utf8_valid = False
        decode_detail = str(exc)

    mojibake = count_mojibake(text) > 0
    replacement = "\ufffd" in text

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


def normalize_file(path: Path, backup_root: Path, root: Path) -> dict[str, str]:
    data = path.read_bytes()
    relative = path.relative_to(root)
    backup = backup_root / relative
    backup.parent.mkdir(parents=True, exist_ok=True)

    if not backup.exists():
        shutil.copy2(path, backup)

    try:
        text = data.decode("utf-8-sig")
        source_encoding = (
            "utf-8-bom" if data.startswith(b"\xef\xbb\xbf") else "utf-8"
        )
    except UnicodeDecodeError:
        text = data.decode("cp1252")
        source_encoding = "cp1252"

    repaired_text, repaired = repair_mojibake(text)
    path.write_text(repaired_text, encoding="utf-8", newline="")

    return {
        "path": relative.as_posix(),
        "source_encoding": source_encoding,
        "target_encoding": "utf-8",
        "mojibake_repaired": str(repaired),
    }


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
            normalized.append(normalize_file(root / item.path, backup_root, root))

    after = [scan_file(path, root) for path in iter_text_files(root)]
    inventory = [asdict(item) for item in after]
    incidents = [row for row in inventory if row["status"] != "COMPLIANT"]

    total = len(inventory)
    compliant = total - len(incidents)
    compliance = round((compliant / total * 100), 2) if total else 100.0
    repaired_count = sum(
        row["mojibake_repaired"] == "True" for row in normalized
    )

    summary = {
        "identifier": "SPB-005.3-UTF8-REPOSITORY-STANDARD",
        "version": "1.4",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "root": str(root),
        "apply_normalization": apply,
        "files_scanned": total,
        "files_compliant": compliant,
        "files_non_compliant": len(incidents),
        "files_normalized": len(normalized),
        "mojibake_repaired": repaired_count,
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
        "# UTF-8 Repository Audit",
        "",
        f"- Identifier: {summary['identifier']}",
        f"- Version: {summary['version']}",
        f"- Files scanned: {total}",
        f"- Compliant files: {compliant}",
        f"- Non-compliant files: {len(incidents)}",
        f"- Normalized files: {len(normalized)}",
        f"- Mojibake repaired: {repaired_count}",
        f"- Compliance: {compliance}%",
        "",
        "PASS" if not incidents else "FAIL",
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

$tests = @'
from pathlib import Path

from sgoda.pmo.utf8.repository_utf8 import (
    detect_newline_style,
    repair_mojibake,
    scan_file,
)


def test_detects_utf8_file(tmp_path: Path) -> None:
    path = tmp_path / "sample.md"
    correct = "Auditor\u00eda Puinave"
    path.write_text(correct, encoding="utf-8")

    result = scan_file(path, tmp_path)

    assert result.utf8_valid is True
    assert result.bom is False
    assert result.mojibake is False
    assert result.status == "COMPLIANT"


def test_detects_utf8_bom(tmp_path: Path) -> None:
    path = tmp_path / "sample.txt"
    path.write_bytes(b"\xef\xbb\xbfTexto")

    result = scan_file(path, tmp_path)

    assert result.bom is True
    assert result.status == "NON_COMPLIANT"


def test_detects_mojibake(tmp_path: Path) -> None:
    path = tmp_path / "sample.md"
    correct = "Auditor\u00eda"
    corrupted = correct.encode("utf-8").decode("cp1252")
    path.write_text(corrupted, encoding="utf-8")

    result = scan_file(path, tmp_path)

    assert result.mojibake is True
    assert result.status == "NON_COMPLIANT"


def test_repairs_reversible_mojibake() -> None:
    correct = "Auditor\u00eda"
    corrupted = correct.encode("utf-8").decode("cp1252")

    repaired, changed = repair_mojibake(corrupted)

    assert changed is True
    assert repaired == correct


def test_detects_mixed_newlines() -> None:
    assert detect_newline_style(b"a\r\nb\nc") == "MIXED"
'@

[System.IO.File]::WriteAllText(
    $modulePath, $module, [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::WriteAllText(
    $testPath, $tests, [System.Text.UTF8Encoding]::new($false)
)

$env:PYTHONPATH = "src"

Write-Host ""
Write-Host "Running UTF-8 tests v1.4..."
python -m pytest tests/pmo/utf8/test_repository_utf8.py -q
$testExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "Applying UTF-8 normalization v1.4..."
python -m sgoda.pmo.utf8.repository_utf8 --root . --apply
$auditExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "Remaining incidents:"
$incidentPath = Join-Path $root "artifacts\pmo\SPB-005.3-UTF8-REPOSITORY-STANDARD\utf8-incidents.csv"
if ((Test-Path $incidentPath) -and ((Get-Item $incidentPath).Length -gt 0)) {
    Import-Csv $incidentPath -Encoding utf8 |
        Select-Object path, encoding, bom, mojibake, replacement_character, detail |
        Format-Table -AutoSize
}
else {
    Write-Host "None."
}

Write-Host ""
Write-Host "SPB-005.3 v1.4 patch completed."
Write-Host "Tests exit code: $testExitCode"
Write-Host "Audit exit code: $auditExitCode"

if ($testExitCode -ne 0) { exit $testExitCode }
exit $auditExitCode
