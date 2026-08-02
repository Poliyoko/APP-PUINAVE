from __future__ import annotations

import hashlib
import json
import shutil
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from string import Template

from .models import GeneratedPackage, IncrementSpec
from .validator import validate_code, validate_generated_package, validate_name

INSTALLER_TEMPLATE = Template(r'''<#
.SYNOPSIS
    Instalador institucional generado para $code.
#>
[CmdletBinding()]
param(
    [string]$$ProjectRoot = (Get-Location).Path,
    [switch]$$SkipFullSuite
)
Set-StrictMode -Version Latest
$$ErrorActionPreference = "Stop"
$$ProjectRoot = [System.IO.Path]::GetFullPath($$ProjectRoot)
Set-Location -LiteralPath $$ProjectRoot
$$env:PYTHONPATH = Join-Path $$ProjectRoot "src"
if (-not (Test-Path -LiteralPath ".git")) {
    throw "Ejecute desde la raÃ­z del repositorio."
}
# TODO: implementar $code â€” $name.
& python -m py_compile "src/sgoda/<module>/module.py"
if ($$LASTEXITCODE -ne 0) { throw "La sintaxis fallÃ³." }
& python -m pytest "tests/<module>/test_$safe_code.py" -q
if ($$LASTEXITCODE -ne 0) { throw "Las pruebas especÃ­ficas fallaron." }
if (-not $$SkipFullSuite) {
    & python -m pytest
    if ($$LASTEXITCODE -ne 0) { throw "La suite completa fallÃ³." }
}
& python -m sgoda.governance.evidence_policy `
    --root "$$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "$code" `
    --status "technically_completed" `
    --output "artifacts/pmo/$code/$code-quality-gate.json"
if ($$LASTEXITCODE -ne 0) { throw "El quality gate fallÃ³." }
& python -m sgoda.documentation.master_docs `
    --root "$$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"
if ($$LASTEXITCODE -ne 0) { throw "SGD-115 fallÃ³." }
Write-Host "$code instalado y validado." -ForegroundColor Green
''')

REPAIR_TEMPLATE = Template(r'''<#
.SYNOPSIS
    Plantilla de correctivo versionado para $code.
#>
[CmdletBinding()]
param([string]$$ProjectRoot = (Get-Location).Path)
Set-StrictMode -Version Latest
$$ErrorActionPreference = "Stop"
$$ProjectRoot = [System.IO.Path]::GetFullPath($$ProjectRoot)
Set-Location -LiteralPath $$ProjectRoot
$$env:PYTHONPATH = Join-Path $$ProjectRoot "src"
$$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$$BackupDir = Join-Path $$ProjectRoot "artifacts/pmo/$code/backups/$$Timestamp"
New-Item -ItemType Directory -Path $$BackupDir -Force | Out-Null
try {
    # TODO: validar instalaciÃ³n parcial, respaldar y corregir.
    & python -m py_compile "src/sgoda/<module>/module.py"
    if ($$LASTEXITCODE -ne 0) { throw "La sintaxis continÃºa con errores." }
    & python -m pytest "tests/<module>/test_$safe_code.py::test_case" -q
    if ($$LASTEXITCODE -ne 0) { throw "La prueba puntual continÃºa fallando." }
    & python -m pytest "tests/<module>/test_$safe_code.py" -q
    if ($$LASTEXITCODE -ne 0) { throw "Las pruebas especÃ­ficas fallaron." }
    & python -m pytest
    if ($$LASTEXITCODE -ne 0) { throw "La suite completa fallÃ³." }
    Write-Host "Correctivo $code validado." -ForegroundColor Green
}
catch {
    Write-Host "Correctivo fallido. Respaldo: $$BackupDir" -ForegroundColor Red
    throw
}
''')


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def _safe(code: str) -> str:
    return code.replace("-", "_").replace(".", "_")


def generate_package(
    *,
    output_root: str | Path,
    spec: IncrementSpec,
    force: bool = False,
    preview: bool = False,
) -> GeneratedPackage:
    spec.code = validate_code(spec.code)
    spec.name = validate_name(spec.name)
    target = Path(output_root).resolve() / spec.code

    if target.exists() and not force:
        raise FileExistsError(f"El destino ya existe: {target}")

    if not preview:
        if target.exists() and force:
            backup = target.with_name(
                f"{target.name}.backup-"
                f"{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}"
            )
            shutil.copytree(target, backup)
            shutil.rmtree(target)
        target.mkdir(parents=True, exist_ok=True)

        safe_code = _safe(spec.code)
        component = {
            "increment_code": spec.code,
            "name": spec.name,
            "component_type": spec.component_type,
            "version": spec.version,
            "status": "generated_not_implemented",
            "generated_by": "SIB-001",
            "governed_by": spec.governed_by,
        }
        policy = {
            "increment_code": spec.code,
            "version": spec.version,
            "fail_fast": True,
            "backup_before_repair": True,
            "specific_tests_required": True,
            "full_suite_required": True,
            "quality_gate_required": True,
            "publication": "SPB-007_only",
        }
        files = {
            "installer.ps1": INSTALLER_TEMPLATE.substitute(
                code=spec.code, name=spec.name, safe_code=safe_code
            ),
            "repair-template.ps1": REPAIR_TEMPLATE.substitute(
                code=spec.code, safe_code=safe_code
            ),
            "component.json": json.dumps(component, ensure_ascii=False, indent=2),
            "policy.json": json.dumps(policy, ensure_ascii=False, indent=2),
            "README.md": (
                f"# {spec.code} â€” {spec.name}\n\n"
                "Generado por SIB-001. Pendiente de implementaciÃ³n funcional.\n\n"
                "Ante errores: detener, respaldar, corregir con Repair versionado, "
                "repetir pruebas y publicar solo por SPB-007.\n"
            ),
            "test_increment.py": (
                f'def test_{safe_code}_generated_contract():\n'
                f'    assert "{spec.code}"\n'
                f'    assert "{spec.name}"\n'
            ),
            "PUBLICATION-COMMANDS.ps1": (
                f'.\\scripts\\Invoke-SPB007-InstitutionalPublish.ps1 `\n'
                f'    -Publish `\n'
                f'    -CommitMessage "feat({spec.component_type}): implement {spec.code}" `\n'
                f'    -EvidenceCommitMessage "chore({spec.component_type}): publish {spec.code} evidence"\n'
            ),
        }
        manifest_files = []
        for name, content in files.items():
            path = target / name
            _write(path, content)
            payload = path.read_bytes()
            manifest_files.append({
                "path": name,
                "size": len(payload),
                "sha256": hashlib.sha256(payload).hexdigest(),
            })
        manifest = {
            "generator": "SIB-001",
            "generated_at_utc": datetime.now(timezone.utc).isoformat(),
            "specification": asdict(spec),
            "files": manifest_files,
        }
        _write(target / "manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))
        errors = validate_generated_package(target)
        if errors:
            raise RuntimeError(" | ".join(errors))

    return GeneratedPackage(
        root=target,
        installer_path=target / "installer.ps1",
        repair_template_path=target / "repair-template.ps1",
        component_path=target / "component.json",
        policy_path=target / "policy.json",
        documentation_path=target / "README.md",
        test_path=target / "test_increment.py",
        manifest_path=target / "manifest.json",
        publication_commands_path=target / "PUBLICATION-COMMANDS.ps1",
    )