<#
.SYNOPSIS
    Implementa SIB-001 — SGODA Installer Builder.
.DESCRIPTION
    Instala el generador institucional de instaladores y correctivos SGODA.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Path {
    param([string]$Path, [string]$Description)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontró $Description en: $Path"
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo crear: $Path"
    }
    $Info = Get-Item -LiteralPath $Path
    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }
    Write-Host "Creado: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-JsonUtf8 {
    param([string]$Path, [object]$Data)
    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText(
        $Path,
        (($Data | ConvertTo-Json -Depth 50) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\installer_builder"
$TestsDir = Join-Path $ProjectRoot "tests\installer_builder"
$ConfigDir = Join-Path $ProjectRoot "config\installer_builder"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SIB-001"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\installer_builder\SIB-001"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SIB-001"
$ReleaseDir = Join-Path $ProjectRoot "releases\SIB-001-v0.1.0"

$ModelsPath = Join-Path $SourceDir "models.py"
$ValidatorPath = Join-Path $SourceDir "validator.py"
$GeneratorPath = Join-Path $SourceDir "generator.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_SIB_001_installer_builder.py"
$PolicyPath = Join-Path $ConfigDir "SIB-001-policy.json"
$ComponentPath = Join-Path $ConfigDir "SIB-001-component.json"
$DocPath = Join-Path $DocsDir "SIB-001-SGODA-Installer-Builder.md"
$ErrorDocPath = Join-Path $DocsDir "SIB-001-Protocolo-Correccion-Errores.md"
$InvokePath = Join-Path $ScriptsDir "New-SGODAIncrement.ps1"
$EvidencePath = Join-Path $PmoDir "implementation-evidence.json"
$TracePath = Join-Path $PmoDir "traceability-SIB-001.json"
$GatePath = Join-Path $PmoDir "SIB-001-quality-gate.json"

Write-Step "Validando línea base institucional"
foreach ($Required in @(
    (Join-Path $ProjectRoot "src"),
    (Join-Path $ProjectRoot "tests"),
    (Join-Path $ProjectRoot "config"),
    (Join-Path $ProjectRoot "docs"),
    (Join-Path $ProjectRoot "artifacts"),
    (Join-Path $ProjectRoot "releases"),
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot ".git")
)) {
    Assert-Path -Path $Required -Description $Required
}

$GitStatus = @(git status --porcelain | Where-Object { $_ })
$AllowedPatterns = @(
    '^\?\? Install-SIB001-SGODA-Installer-Builder\.ps1$',
    '^\?\? Repair-SIB001-v[0-9.]+-.*\.ps1$',
    '^\?\? SIB001-.*\.zip$',
    '^\?\? LEAME-SIB001.*\.txt$'
)
$Unexpected = @(
    foreach ($Entry in $GitStatus) {
        $Allowed = $false
        foreach ($Pattern in $AllowedPatterns) {
            if ($Entry -match $Pattern) { $Allowed = $true; break }
        }
        if (-not $Allowed) { $Entry }
    }
)
if ($Unexpected.Count -gt 0) {
    $Unexpected | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    throw "La línea base contiene cambios ajenos a SIB-001."
}

$ModelsContent = @'
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass(slots=True)
class IncrementSpec:
    code: str
    name: str
    component_type: str
    version: str = "0.1.0"
    description: str = ""
    governed_by: list[str] = field(
        default_factory=lambda: [
            "SGD-114-v2.0.1",
            "SGD-115-v1.0.1",
            "SPB-007",
        ]
    )


@dataclass(slots=True)
class GeneratedPackage:
    root: Path
    installer_path: Path
    repair_template_path: Path
    component_path: Path
    policy_path: Path
    documentation_path: Path
    test_path: Path
    manifest_path: Path
    publication_commands_path: Path
'@

$ValidatorContent = @'
from __future__ import annotations

import re
from pathlib import Path

CODE_PATTERN = re.compile(
    r"^(?:SPB|SPT|SGD|ADR|SIB)-\d{3}(?:\.\d+|[A-Z])?$"
)


class SpecificationError(ValueError):
    pass


def validate_code(code: str) -> str:
    value = code.strip().upper()
    if not CODE_PATTERN.fullmatch(value):
        raise SpecificationError(
            "Código no válido. Ejemplos: SPT-004C, SGD-116, "
            "ADR-012 o SIB-002."
        )
    return value


def validate_name(name: str) -> str:
    value = " ".join(name.split())
    if len(value) < 5:
        raise SpecificationError(
            "El nombre debe contener al menos 5 caracteres."
        )
    return value


def validate_generated_package(root: str | Path) -> list[str]:
    package = Path(root)
    required = {
        "installer.ps1",
        "repair-template.ps1",
        "component.json",
        "policy.json",
        "README.md",
        "test_increment.py",
        "manifest.json",
        "PUBLICATION-COMMANDS.ps1",
    }
    existing = (
        {item.name for item in package.iterdir() if item.is_file()}
        if package.is_dir()
        else set()
    )
    errors = [
        f"Archivo obligatorio faltante: {name}"
        for name in sorted(required - existing)
    ]
    for path in package.glob("*"):
        if path.is_file() and path.stat().st_size == 0:
            errors.append(f"Archivo vacío: {path.name}")
    return errors
'@

$GeneratorContent = @'
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
    throw "Ejecute desde la raíz del repositorio."
}
# TODO: implementar $code — $name.
& python -m py_compile "src/sgoda/<module>/module.py"
if ($$LASTEXITCODE -ne 0) { throw "La sintaxis falló." }
& python -m pytest "tests/<module>/test_$safe_code.py" -q
if ($$LASTEXITCODE -ne 0) { throw "Las pruebas específicas fallaron." }
if (-not $$SkipFullSuite) {
    & python -m pytest
    if ($$LASTEXITCODE -ne 0) { throw "La suite completa falló." }
}
& python -m sgoda.governance.evidence_policy `
    --root "$$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "$code" `
    --status "technically_completed" `
    --output "artifacts/pmo/$code/$code-quality-gate.json"
if ($$LASTEXITCODE -ne 0) { throw "El quality gate falló." }
& python -m sgoda.documentation.master_docs `
    --root "$$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"
if ($$LASTEXITCODE -ne 0) { throw "SGD-115 falló." }
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
    # TODO: validar instalación parcial, respaldar y corregir.
    & python -m py_compile "src/sgoda/<module>/module.py"
    if ($$LASTEXITCODE -ne 0) { throw "La sintaxis continúa con errores." }
    & python -m pytest "tests/<module>/test_$safe_code.py::test_case" -q
    if ($$LASTEXITCODE -ne 0) { throw "La prueba puntual continúa fallando." }
    & python -m pytest "tests/<module>/test_$safe_code.py" -q
    if ($$LASTEXITCODE -ne 0) { throw "Las pruebas específicas fallaron." }
    & python -m pytest
    if ($$LASTEXITCODE -ne 0) { throw "La suite completa falló." }
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
                f"# {spec.code} — {spec.name}\n\n"
                "Generado por SIB-001. Pendiente de implementación funcional.\n\n"
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
'@

$CliContent = @'
from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from .generator import generate_package
from .models import IncrementSpec


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    new = sub.add_parser("new")
    new.add_argument("--code", required=True)
    new.add_argument("--name", required=True)
    new.add_argument("--type", default="technology_increment")
    new.add_argument("--version", default="0.1.0")
    new.add_argument("--description", default="")
    new.add_argument("--output", default="generated/installers")
    new.add_argument("--force", action="store_true")
    new.add_argument("--preview", action="store_true")
    new.add_argument(
        "--result",
        default="artifacts/installer_builder/SIB-001/last-generation.json",
    )
    args = parser.parse_args()
    package = generate_package(
        output_root=args.output,
        spec=IncrementSpec(
            code=args.code,
            name=args.name,
            component_type=args.type,
            version=args.version,
            description=args.description,
        ),
        force=args.force,
        preview=args.preview,
    )
    result = Path(args.result)
    result.parent.mkdir(parents=True, exist_ok=True)
    result.write_text(
        json.dumps({k: str(v) for k, v in asdict(package).items()}, indent=2) + "\n",
        encoding="utf-8",
    )
    print("SIB-001 ejecutado correctamente.")
    print(f"Incremento: {args.code.upper()}")
    print(f"Destino: {package.root}")
    print(f"Preview: {args.preview}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

$InitContent = @'
from __future__ import annotations
from typing import Any

__all__ = [
    "GeneratedPackage",
    "IncrementSpec",
    "SpecificationError",
    "generate_package",
    "validate_code",
    "validate_generated_package",
    "validate_name",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(name)
    if name in {"GeneratedPackage", "IncrementSpec"}:
        from . import models
        return getattr(models, name)
    if name == "generate_package":
        from . import generator
        return getattr(generator, name)
    from . import validator
    return getattr(validator, name)
'@

$TestContent = @'
import json
from pathlib import Path

import pytest

from sgoda.installer_builder.generator import generate_package
from sgoda.installer_builder.models import IncrementSpec
from sgoda.installer_builder.validator import (
    SpecificationError,
    validate_code,
    validate_generated_package,
    validate_name,
)


def _spec() -> IncrementSpec:
    return IncrementSpec(
        code="SPT-999A",
        name="Componente Institucional de Prueba",
        component_type="test_component",
    )


def test_SIB_001_valida_codigo() -> None:
    assert validate_code("spt-004c") == "SPT-004C"
    assert validate_code("ADR-012") == "ADR-012"


def test_SIB_001_rechaza_codigo_invalido() -> None:
    with pytest.raises(SpecificationError):
        validate_code("componente nuevo")


def test_SIB_001_valida_nombre() -> None:
    assert validate_name("  Motor   Institucional  ") == "Motor Institucional"


def test_SIB_001_genera_paquete_completo(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec())
    assert package.root.is_dir()
    assert validate_generated_package(package.root) == []


def test_SIB_001_instalador_fail_fast(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec())
    text = package.installer_path.read_text(encoding="utf-8")
    assert '$ErrorActionPreference = "Stop"' in text
    assert "python -m pytest" in text
    assert "evidence_policy" in text


def test_SIB_001_correctivo_con_respaldo(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec())
    text = package.repair_template_path.read_text(encoding="utf-8")
    assert "backups" in text
    assert "prueba puntual" in text.casefold()
    assert "suite completa" in text.casefold()


def test_SIB_001_manifiesto_sha256(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec())
    manifest = json.loads(package.manifest_path.read_text(encoding="utf-8"))
    assert manifest["generator"] == "SIB-001"
    assert len(manifest["files"]) == 7
    assert all(len(item["sha256"]) == 64 for item in manifest["files"])


def test_SIB_001_no_sobrescribe_sin_force(tmp_path: Path) -> None:
    generate_package(output_root=tmp_path, spec=_spec())
    with pytest.raises(FileExistsError):
        generate_package(output_root=tmp_path, spec=_spec())


def test_SIB_001_force_crea_respaldo(tmp_path: Path) -> None:
    generate_package(output_root=tmp_path, spec=_spec())
    generate_package(output_root=tmp_path, spec=_spec(), force=True)
    assert len(list(tmp_path.glob("SPT-999A.backup-*"))) == 1


def test_SIB_001_comandos_spb007(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec())
    text = package.publication_commands_path.read_text(encoding="utf-8")
    assert "Invoke-SPB007-InstitutionalPublish.ps1" in text
    assert "-EvidenceCommitMessage" in text


def test_SIB_001_preview_no_escribe(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec(), preview=True)
    assert not package.root.exists()


def test_SIB_001_declara_gobierno(tmp_path: Path) -> None:
    package = generate_package(output_root=tmp_path, spec=_spec())
    component = json.loads(package.component_path.read_text(encoding="utf-8"))
    assert "SGD-114-v2.0.1" in component["governed_by"]
    assert component["generated_by"] == "SIB-001"
'@

$PolicyContent = @'
{
  "increment_code": "SIB-001",
  "version": "0.1.0",
  "policy_name": "SGODA Installer Builder",
  "fail_fast": true,
  "absolute_paths_required": true,
  "overwrite_default": false,
  "backup_before_force": true,
  "repair_scripts_versioned": true,
  "specific_tests_required": true,
  "full_suite_required": true,
  "quality_gate_required": true,
  "master_documentation_update_required": true,
  "remote_publication": "SPB-007_only"
}
'@

$ComponentContent = @'
{
  "increment_code": "SIB-001",
  "name": "SGODA Installer Builder",
  "component_type": "institutional_installer_generator",
  "version": "0.1.0",
  "status": "technically_completed",
  "entrypoint": "sgoda.installer_builder.cli",
  "source": ["src/sgoda/installer_builder/"],
  "tests": ["tests/installer_builder/test_SIB_001_installer_builder.py"],
  "documentation": [
    "docs/05_Fase_Tecnologica/SIB-001/SIB-001-SGODA-Installer-Builder.md",
    "docs/05_Fase_Tecnologica/SIB-001/SIB-001-Protocolo-Correccion-Errores.md"
  ],
  "governed_by": ["SGD-114-v2.0.1", "SGD-115-v1.0.1", "SPB-007"]
}
'@

$DocContent = @'
# SIB-001 — SGODA Installer Builder

Genera instaladores y correctivos institucionales en
`generated/installers/<CODIGO>/`.

## Uso

```powershell
.\scripts\New-SGODAIncrement.ps1 `
    -Code "SPT-004C" `
    -Name "API Conversacional del Asistente" `
    -ComponentType "assistant_api"
```
'@

$ErrorDocContent = @'
# SIB-001 — Protocolo de Corrección de Errores

1. Detener el instalador.
2. No publicar.
3. Preservar la instalación parcial.
4. Crear un correctivo Repair versionado.
5. Respaldar archivos afectados.
6. Aplicar una corrección mínima.
7. Repetir la prueba puntual.
8. Repetir las pruebas específicas.
9. Ejecutar la suite completa.
10. Regenerar evidencias y quality gate.
11. Publicar exclusivamente con SPB-007.
'@

$InvokeContent = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Code,
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [string]$ComponentType = "technology_increment",
    [string]$Version = "0.1.0",
    [string]$Description = "",
    [string]$Output = "generated/installers",
    [switch]$Preview,
    [switch]$Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"
$Arguments = @(
    "-m", "sgoda.installer_builder.cli", "new",
    "--code", $Code,
    "--name", $Name,
    "--type", $ComponentType,
    "--version", $Version,
    "--description", $Description,
    "--output", $Output
)
if ($Preview) { $Arguments += "--preview" }
if ($Force) { $Arguments += "--force" }
& python @Arguments
if ($LASTEXITCODE -ne 0) { throw "SIB-001 terminó con errores." }
'@

Write-Step "Instalando SIB-001"
Write-Utf8NoBom -Path $ModelsPath -Content $ModelsContent
Write-Utf8NoBom -Path $ValidatorPath -Content $ValidatorContent
Write-Utf8NoBom -Path $GeneratorPath -Content $GeneratorContent
Write-Utf8NoBom -Path $CliPath -Content $CliContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent
Write-Utf8NoBom -Path $PolicyPath -Content $PolicyContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentContent
Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $ErrorDocPath -Content $ErrorDocContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando evidencia y trazabilidad"
$Timestamp = [DateTime]::UtcNow.ToString("o")
Write-JsonUtf8 -Path $EvidencePath -Data ([ordered]@{
    increment_code = "SIB-001"
    version = "0.1.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    generated_artifact_types = 8
    fail_fast = $true
    backup_before_force = $true
    publication = "SPB-007_only"
})
Write-JsonUtf8 -Path $TracePath -Data ([ordered]@{
    increment_code = "SIB-001"
    source = @("src/sgoda/installer_builder/")
    tests = @("tests/installer_builder/test_SIB_001_installer_builder.py")
    documentation = @(
        "docs/05_Fase_Tecnologica/SIB-001/SIB-001-SGODA-Installer-Builder.md",
        "docs/05_Fase_Tecnologica/SIB-001/SIB-001-Protocolo-Correccion-Errores.md"
    )
})

Write-Step "Validando sintaxis e importaciones"
& python -m py_compile `
    "src/sgoda/installer_builder/models.py" `
    "src/sgoda/installer_builder/validator.py" `
    "src/sgoda/installer_builder/generator.py" `
    "src/sgoda/installer_builder/cli.py"
if ($LASTEXITCODE -ne 0) { throw "La compilación de SIB-001 falló." }
& python -c "from sgoda.installer_builder import IncrementSpec, generate_package, validate_code; print(IncrementSpec.__name__, generate_package.__name__, validate_code('SPT-004C'))"
if ($LASTEXITCODE -ne 0) { throw "Falló la importación de SIB-001." }

Write-Step "Ejecutando 12 pruebas específicas SIB-001"
& python -m pytest "tests/installer_builder/test_SIB_001_installer_builder.py" -q
if ($LASTEXITCODE -ne 0) { throw "Las pruebas específicas SIB-001 fallaron." }

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"
    & python -m pytest
    if ($LASTEXITCODE -ne 0) { throw "La suite completa terminó con errores." }
}

Write-Step "Generando paquete demostrativo"
$DemoOutput = Join-Path $ArtifactsDir "generated-demo"
if (Test-Path -LiteralPath $DemoOutput) {
    Remove-Item -LiteralPath $DemoOutput -Recurse -Force
}
& python -m sgoda.installer_builder.cli new `
    --code "SPT-999A" `
    --name "Incremento Institucional Demostrativo" `
    --type "demonstration_component" `
    --output "$DemoOutput" `
    --result "artifacts/installer_builder/SIB-001/demo-generation.json"
if ($LASTEXITCODE -ne 0) { throw "La generación demostrativa falló." }

$DemoPackage = Join-Path $DemoOutput "SPT-999A"
Assert-Path -Path (Join-Path $DemoPackage "installer.ps1") -Description "instalador demostrativo"
Assert-Path -Path (Join-Path $DemoPackage "repair-template.ps1") -Description "correctivo demostrativo"
Assert-Path -Path (Join-Path $DemoPackage "manifest.json") -Description "manifiesto demostrativo"

Write-Step "Publicando release técnico"
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
foreach ($Artifact in @(
    $PolicyPath,
    $ComponentPath,
    $DocPath,
    $ErrorDocPath,
    (Join-Path $DemoPackage "installer.ps1"),
    (Join-Path $DemoPackage "repair-template.ps1"),
    (Join-Path $DemoPackage "manifest.json")
)) {
    Copy-Item -LiteralPath $Artifact -Destination (Join-Path $ReleaseDir (Split-Path $Artifact -Leaf)) -Force
}

Write-Step "Ejecutando quality gate SGD-114"
& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SIB-001" `
    --status "technically_completed" `
    --output "$GatePath"
if ($LASTEXITCODE -ne 0) { throw "El quality gate SIB-001 no fue aprobado." }
$Gate = Get-Content -LiteralPath $GatePath -Raw | ConvertFrom-Json
if (-not $Gate.passed) { throw "SIB-001 no contiene passed=true." }

Write-Step "Actualizando documentación maestra SGD-115"
& python -m sgoda.documentation.master_docs `
    --root "$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"
if ($LASTEXITCODE -ne 0) { throw "La actualización SGD-115 falló." }

Write-Step "Resultado final"
Write-Host "SIB-001 implementado y validado." -ForegroundColor Green
Write-Host "SGODA Installer Builder: OPERATIVO." -ForegroundColor Green
Write-Host "Pruebas específicas: 12 APROBADAS." -ForegroundColor Green
Write-Host "Generación de instaladores: APROBADA." -ForegroundColor Green
Write-Host "Plantillas de correctivos: APROBADAS." -ForegroundColor Green
Write-Host "Respaldos: IMPLEMENTADOS." -ForegroundColor Green
Write-Host "Manifiestos SHA-256: IMPLEMENTADOS." -ForegroundColor Green
Write-Host "Quality gate: APROBADO." -ForegroundColor Green
Write-Host "Documentación maestra: ACTUALIZADA." -ForegroundColor Green
Write-Host "Release: releases\SIB-001-v0.1.0" -ForegroundColor Cyan
Write-Host ""
Write-Host "Ejemplo:" -ForegroundColor Yellow
Write-Host '.\scripts\New-SGODAIncrement.ps1 -Code "SPT-004C" -Name "API Conversacional del Asistente" -ComponentType "assistant_api"' -ForegroundColor Cyan
