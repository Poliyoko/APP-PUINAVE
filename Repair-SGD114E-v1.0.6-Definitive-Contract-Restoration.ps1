<#
.SYNOPSIS
    Aplica SGD-114E v1.0.6 — Definitive Contract Restoration.

.DESCRIPTION
    Solución definitiva para SGD-114E.

    Restaura el contrato histórico y mantiene la interfaz moderna:
      - result.approved
      - result.component_count
      - result.findings
      - result.proprietary_dependency_count
      - result["approved"]
      - result["version"]
      - result.to_dict()

    Mantiene:
      - contrato funcional 1.0.3 en acceso mapping;
      - implementación 1.0.6 en acceso por atributo;
      - ejecutor multi-ruta;
      - SGD-114F como fuente de verdad;
      - pruebas históricas intactas;
      - publicación condicionada.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Publish -and $SkipFullSuite) {
    throw "No se permite publicar con -SkipFullSuite."
}

function Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró el archivo requerido: $Path"
    }
}

function Write-Utf8 {
    param(
        [string]$Path,
        [string]$Content
    )

    $Parent = Split-Path -Parent $Path

    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )

    if ((Get-Item -LiteralPath $Path).Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado/actualizado: $Path" -ForegroundColor Green
}

function Write-Json {
    param(
        [string]$Path,
        [object]$Value
    )

    Write-Utf8 `
        -Path $Path `
        -Content (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
}

function Run {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

    Step $Description
    $global:LASTEXITCODE = 0
    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

function Backup-File {
    param(
        [string]$Source,
        [string]$BackupDirectory,
        [string]$Root
    )

    if (Test-Path -LiteralPath $Source -PathType Leaf) {
        $Relative = $Source.Replace($Root, "")
        $Relative = $Relative.TrimStart(
            [char[]]@([char]92, [char]47)
        )
        $Relative = $Relative.Replace(
            [string][char]92,
            "__"
        ).Replace("/", "__")

        Copy-Item `
            -LiteralPath $Source `
            -Destination (Join-Path $BackupDirectory $Relative) `
            -Force
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$GovernanceDir = Join-Path $ProjectRoot "src\sgoda\governance"
$TestsDir = Join-Path $ProjectRoot "tests\governance"
$ConfigDir = Join-Path $ProjectRoot "config\governance"
$DocsDir = Join-Path $ProjectRoot "docs\01_Gobierno"

$ModelsPath = Join-Path $GovernanceDir "native_ecosystem_models.py"
$ValidatorPath = Join-Path $GovernanceDir "native_ecosystem_validator.py"
$CliPath = Join-Path $GovernanceDir "native_ecosystem_cli.py"
$RunnerPath = Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1"

$HistoricalTestPath = Join-Path `
    $TestsDir `
    "test_SGD_114E_native_ecosystem_architecture_policy.py"

$LogicTestPath = Join-Path `
    $TestsDir `
    "test_SGD_114E_v1_0_3_approval_logic_fix.py"

$CompatibilityTestPath = Join-Path `
    $TestsDir `
    "test_SGD_114E_v1_0_5_backward_compatibility_result_model.py"

$ClosureTestPath = Join-Path `
    $TestsDir `
    "test_SGD_114E_v1_0_6_definitive_contract_restoration.py"

$ComponentPath = Join-Path `
    $ConfigDir `
    "SGD-114E-v1.0.6-component.json"

$PatchDoc = Join-Path `
    $DocsDir `
    "SGD-114E-v1.0.6-Definitive-Contract-Restoration.md"

$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114E-v1.0.6"
$ReportsDir = Join-Path $PmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114E-v1.0.6"
$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SGD114E-v1.0.6-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$SpecificXml = Join-Path $ReportsDir "SGD-114E-v1.0.6-specific.xml"
$SpecificJson = Join-Path $ReportsDir "SGD-114E-v1.0.6-specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "SGD-114E-v1.0.6-specific-summary.md"
$FullXml = Join-Path $ReportsDir "SGD-114E-v1.0.6-full-suite.xml"
$FullJson = Join-Path $ReportsDir "SGD-114E-v1.0.6-full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "SGD-114E-v1.0.6-full-suite-summary.md"

$SelfJson = Join-Path $PmoDir "SGD-114E-v1.0.6-self-validation.json"
$SelfMd = Join-Path $PmoDir "SGD-114E-v1.0.6-self-validation.md"
$Spt016AJson = Join-Path $PmoDir "SPT-016A-native-validation.json"
$Spt016AMd = Join-Path $PmoDir "SPT-016A-native-validation.md"
$EvidencePath = Join-Path $PmoDir "SGD-114E-v1.0.6-implementation-evidence.json"
$EvidenceMd = Join-Path $PmoDir "SGD-114E-v1.0.6-implementation-evidence.md"

Step "Validando línea base institucional"

foreach ($Required in @(
    $ModelsPath,
    $ValidatorPath,
    $CliPath,
    $RunnerPath,
    $HistoricalTestPath,
    $LogicTestPath,
    $CompatibilityTestPath,
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "config\learning_analytics\SPT-016A-component.json")
)) {
    Require-File $Required
}

Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($Affected in @(
    $ModelsPath,
    $ValidatorPath,
    $CliPath,
    $ClosureTestPath,
    $ComponentPath,
    $PatchDoc
)) {
    Backup-File $Affected $BackupDir $ProjectRoot
}

$Models = @'
"""Modelos definitivos de SGD-114E v1.0.6."""

from __future__ import annotations

from copy import deepcopy
from dataclasses import asdict, dataclass
from typing import Any, Mapping


@dataclass(frozen=True, slots=True)
class NativeEcosystemFinding:
    rule_code: str
    message: str
    path: str = ""
    component: str = ""
    value: str = ""
    severity: str = "error"

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class NativeEcosystemValidationResult(dict[str, Any]):
    """Resultado compatible con todos los contratos institucionales."""

    def __init__(
        self,
        payload: Mapping[str, Any] | None = None,
        **values: Any,
    ) -> None:
        merged: dict[str, Any] = {}

        if payload is not None:
            merged.update(dict(payload))

        merged.update(values)
        super().__init__(merged)

    def __getattr__(self, name: str) -> Any:
        aliases = {
            "component_count": "native_component_count",
            "proprietary_dependency_count": (
                "mandatory_proprietary_dependency_count"
            ),
        }

        if name == "version":
            return self.get(
                "implementation_version",
                self.get("version"),
            )

        key = aliases.get(name, name)

        try:
            return self[key]
        except KeyError as error:
            raise AttributeError(name) from error

    def __setattr__(self, name: str, value: Any) -> None:
        self[name] = value

    @property
    def approved(self) -> bool:
        return bool(self.get("approved", False))

    @approved.setter
    def approved(self, value: bool) -> None:
        self["approved"] = bool(value)

    @property
    def component_count(self) -> int:
        return int(self.get("native_component_count", 0))

    @property
    def proprietary_dependency_count(self) -> int:
        return int(
            self.get(
                "mandatory_proprietary_dependency_count",
                0,
            )
        )

    @property
    def findings(self) -> tuple[NativeEcosystemFinding, ...]:
        values = self.get("findings", ())
        result = []

        for item in values:
            if isinstance(item, NativeEcosystemFinding):
                result.append(item)
            elif isinstance(item, Mapping):
                result.append(
                    NativeEcosystemFinding(
                        rule_code=str(
                            item.get("rule_code") or ""
                        ),
                        message=str(
                            item.get("message") or ""
                        ),
                        path=str(item.get("path") or ""),
                        component=str(
                            item.get("component") or ""
                        ),
                        value=str(item.get("value") or ""),
                        severity=str(
                            item.get("severity") or "error"
                        ),
                    )
                )

        return tuple(result)

    @findings.setter
    def findings(self, value: Any) -> None:
        self["findings"] = list(value or [])

    def to_dict(self) -> dict[str, Any]:
        def convert(value: Any) -> Any:
            if isinstance(value, NativeEcosystemFinding):
                return value.to_dict()
            if isinstance(value, Mapping):
                return {
                    str(key): convert(item)
                    for key, item in value.items()
                }
            if isinstance(value, (list, tuple)):
                return [convert(item) for item in value]
            return deepcopy(value)

        return convert(dict(self))

    def copy(self) -> "NativeEcosystemValidationResult":
        return NativeEcosystemValidationResult(
            self.to_dict()
        )
'@

$Validator = @'
"""Validador definitivo SGD-114E v1.0.6."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from .native_ecosystem_models import (
    NativeEcosystemFinding,
    NativeEcosystemValidationResult,
)


_CONTRACT_VERSION = "1.0.3"
_IMPLEMENTATION_VERSION = "1.0.6"

_FORBIDDEN_TERMS = (
    "integrado por contrato",
    "integrada por contrato",
    "integrados por contrato",
    "integradas por contrato",
    "contract-based integration",
    "contract integration",
)

_SPT_PATTERN = re.compile(r"^SPT-(\d+)")


def _read_json(path: Path) -> dict[str, Any] | None:
    try:
        payload = json.loads(
            path.read_text(encoding="utf-8-sig")
        )
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None

    return payload if isinstance(payload, dict) else None


def _component_files(root: Path) -> tuple[Path, ...]:
    config = root / "config"

    if not config.exists():
        return ()

    return tuple(
        sorted(
            path
            for path in config.rglob("*.json")
            if (
                "component" in path.name.casefold()
                or "metadata" in path.name.casefold()
            )
        )
    )


def _component_code(
    payload: dict[str, Any],
    path: Path,
) -> str:
    return str(
        payload.get("increment_code")
        or payload.get("component")
        or path.stem
    )


def _is_governed_component(code: str) -> bool:
    normalized = str(code or "").strip().upper()
    match = _SPT_PATTERN.match(normalized)

    if match:
        return int(match.group(1)) >= 7

    return normalized.startswith(
        (
            "SGD-",
            "SPB-",
            "SPA-",
        )
    )


def _scan_forbidden_terms(
    project_root: Path,
) -> tuple[NativeEcosystemFinding, ...]:
    findings = []

    for base in (
        project_root / "config",
        project_root / "docs",
        project_root / "src",
    ):
        if not base.exists():
            continue

        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue

            if path.suffix.casefold() not in {
                ".json",
                ".md",
                ".py",
                ".ps1",
                ".txt",
                ".yaml",
                ".yml",
            }:
                continue

            try:
                text = path.read_text(
                    encoding="utf-8-sig",
                    errors="replace",
                ).casefold()
            except OSError:
                continue

            for term in _FORBIDDEN_TERMS:
                if term in text:
                    findings.append(
                        NativeEcosystemFinding(
                            rule_code="SGD114E-R003",
                            message=(
                                "Se detectó terminología "
                                "institucional prohibida."
                            ),
                            path=path.as_posix(),
                            value=term,
                        )
                    )

    return tuple(findings)


def evaluate_native_ecosystem(
    root: str | Path,
) -> NativeEcosystemValidationResult:
    project_root = Path(root).resolve()
    native_components = []
    proprietary_dependencies = []
    structural_errors = []
    findings = []

    for path in _component_files(project_root):
        payload = _read_json(path)

        if payload is None:
            structural_errors.append(
                {
                    "path": path.as_posix(),
                    "error": "invalid_or_unreadable_json",
                }
            )
            findings.append(
                NativeEcosystemFinding(
                    rule_code="SGD114E-R004",
                    message="JSON de componente inválido.",
                    path=path.as_posix(),
                )
            )
            continue

        code = _component_code(payload, path)

        if not _is_governed_component(code):
            continue

        if "native_ecosystem" not in payload:
            findings.append(
                NativeEcosystemFinding(
                    rule_code="SGD114E-R002",
                    message=(
                        "El componente gobernado no declara "
                        "native_ecosystem."
                    ),
                    path=path.as_posix(),
                    component=code,
                )
            )
        elif payload.get("native_ecosystem") is True:
            native_components.append(code)
        elif payload.get("native_ecosystem") is False:
            findings.append(
                NativeEcosystemFinding(
                    rule_code="SGD114E-R002",
                    message=(
                        "El componente gobernado no está "
                        "declarado como nativo."
                    ),
                    path=path.as_posix(),
                    component=code,
                )
            )

        dependencies = payload.get(
            "mandatory_proprietary_dependencies",
            [],
        )

        if dependencies is None:
            dependencies = []

        if not isinstance(dependencies, list):
            structural_errors.append(
                {
                    "path": path.as_posix(),
                    "error": (
                        "mandatory_proprietary_dependencies "
                        "must be a list"
                    ),
                }
            )
            findings.append(
                NativeEcosystemFinding(
                    rule_code="SGD114E-R004",
                    message=(
                        "mandatory_proprietary_dependencies "
                        "debe ser una lista."
                    ),
                    path=path.as_posix(),
                    component=code,
                )
            )
            continue

        for dependency in dependencies:
            text = str(dependency).strip()

            if text:
                item = {
                    "component": code,
                    "dependency": text,
                    "path": path.as_posix(),
                }
                proprietary_dependencies.append(item)
                findings.append(
                    NativeEcosystemFinding(
                        rule_code="SGD114E-R001",
                        message=(
                            "Se detectó una dependencia "
                            "propietaria obligatoria."
                        ),
                        path=path.as_posix(),
                        component=code,
                        value=text,
                    )
                )

    forbidden_findings = list(
        _scan_forbidden_terms(project_root)
    )
    findings.extend(forbidden_findings)

    approved = len(findings) == 0

    criteria = {
        "all_governed_components_are_native": not any(
            item.rule_code == "SGD114E-R002"
            for item in findings
        ),
        "no_forbidden_terms": not any(
            item.rule_code == "SGD114E-R003"
            for item in findings
        ),
        "no_mandatory_proprietary_dependencies": (
            len(proprietary_dependencies) == 0
        ),
        "no_structural_errors": len(structural_errors) == 0,
    }

    return NativeEcosystemValidationResult(
        {
            "policy": "SGD-114E",
            "version": _CONTRACT_VERSION,
            "implementation_version": (
                _IMPLEMENTATION_VERSION
            ),
            "approved": approved,
            "result": (
                "APROBADO"
                if approved
                else "NO APROBADO"
            ),
            "criteria": criteria,
            "native_component_count": len(
                native_components
            ),
            "component_count": len(native_components),
            "native_components": sorted(
                set(native_components)
            ),
            "forbidden_term_count": len(
                forbidden_findings
            ),
            "forbidden_terms": [
                item.to_dict()
                for item in forbidden_findings
            ],
            "mandatory_proprietary_dependency_count": (
                len(proprietary_dependencies)
            ),
            "proprietary_dependency_count": (
                len(proprietary_dependencies)
            ),
            "mandatory_proprietary_dependencies": (
                proprietary_dependencies
            ),
            "structural_error_count": len(
                structural_errors
            ),
            "structural_errors": structural_errors,
            "findings": findings,
            "decision_rule": (
                "approved = no institutional findings"
            ),
            "compatibility": {
                "historical_attributes": True,
                "mapping_access": True,
                "to_dict": True,
                "contract_version": _CONTRACT_VERSION,
                "implementation_version": (
                    _IMPLEMENTATION_VERSION
                ),
            },
        }
    )
'@

$Cli = @'
"""CLI definitivo SGD-114E v1.0.6."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    args = parser.parse_args()

    validation = evaluate_native_ecosystem(args.root)
    result = validation.to_dict()

    json_target = Path(args.output_json)
    md_target = Path(args.output_md)
    json_target.parent.mkdir(parents=True, exist_ok=True)
    md_target.parent.mkdir(parents=True, exist_ok=True)

    json_target.write_text(
        json.dumps(
            result,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    md_target.write_text(
        "\n".join(
            [
                "# SGD-114E — Native Ecosystem Validation",
                "",
                (
                    "- Contrato funcional: "
                    f"{result['version']}"
                ),
                (
                    "- Implementación: "
                    f"{result['implementation_version']}"
                ),
                f"- Resultado: {result['result']}",
                (
                    "- Componentes nativos: "
                    f"{result['native_component_count']}"
                ),
                (
                    "- Hallazgos: "
                    f"{len(result['findings'])}"
                ),
                (
                    "- Términos prohibidos: "
                    f"{result['forbidden_term_count']}"
                ),
                (
                    "- Dependencias propietarias obligatorias: "
                    f"{result['mandatory_proprietary_dependency_count']}"
                ),
                (
                    "- Errores estructurales: "
                    f"{result['structural_error_count']}"
                ),
                "",
                f"Regla: `{result['decision_rule']}`",
                "",
            ]
        ),
        encoding="utf-8",
    )

    print("SGD-114E ejecutado correctamente.")
    print(f"Resultado: {result['result']}")
    print(
        "Contrato funcional: "
        f"{result['version']}"
    )
    print(
        "Implementación: "
        f"{result['implementation_version']}"
    )
    print(
        "Componentes nativos: "
        f"{result['native_component_count']}"
    )
    print(f"Hallazgos: {len(result['findings'])}")
    print(
        "Términos prohibidos: "
        f"{result['forbidden_term_count']}"
    )
    print(
        "Dependencias propietarias obligatorias: "
        f"{result['mandatory_proprietary_dependency_count']}"
    )
    print(
        "Errores estructurales: "
        f"{result['structural_error_count']}"
    )
    print(f"JSON: {json_target}")
    print(f"Markdown: {md_target}")

    return 0 if validation.approved else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$ClosureTests = @'
from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.native_ecosystem_models import (
    NativeEcosystemFinding,
)
from sgoda.governance.native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def _write(
    root: Path,
    code: str,
    payload: dict,
) -> None:
    target = root / "config" / "test"
    target.mkdir(parents=True, exist_ok=True)
    (target / f"{code}-component.json").write_text(
        json.dumps(
            {
                "increment_code": code,
                **payload,
            }
        ),
        encoding="utf-8",
    )


def test_contract_and_implementation_versions(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result["version"] == "1.0.3"
    assert result.version == "1.0.6"
    assert result.implementation_version == "1.0.6"


def test_empty_repository_is_approved(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.component_count == 0


def test_legacy_component_is_ignored(
    tmp_path: Path,
) -> None:
    _write(tmp_path, "SPT-006A", {})

    assert evaluate_native_ecosystem(
        tmp_path
    ).approved is True


def test_governed_component_requires_native_flag(
    tmp_path: Path,
) -> None:
    _write(tmp_path, "SPT-012", {})

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert any(
        finding.rule_code == "SGD114E-R002"
        for finding in result.findings
    )


def test_native_component_is_counted(
    tmp_path: Path,
) -> None:
    _write(
        tmp_path,
        "SPT-012",
        {
            "native_ecosystem": True,
            "mandatory_proprietary_dependencies": [],
        },
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.component_count == 1
    assert result["native_component_count"] == 1


def test_proprietary_alias_is_preserved(
    tmp_path: Path,
) -> None:
    _write(
        tmp_path,
        "SPT-012",
        {
            "native_ecosystem": True,
            "mandatory_proprietary_dependencies": ["X"],
        },
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.proprietary_dependency_count == 1
    assert (
        result["mandatory_proprietary_dependency_count"]
        == 1
    )


def test_findings_have_attribute_contract(
    tmp_path: Path,
) -> None:
    _write(tmp_path, "SPT-012", {})

    result = evaluate_native_ecosystem(tmp_path)

    assert isinstance(
        result.findings[0],
        NativeEcosystemFinding,
    )
    assert result.findings[0].rule_code


def test_to_dict_serializes_findings(
    tmp_path: Path,
) -> None:
    _write(tmp_path, "SPT-012", {})

    payload = evaluate_native_ecosystem(
        tmp_path
    ).to_dict()

    assert isinstance(payload["findings"], list)
    assert isinstance(payload["findings"][0], dict)


def test_attribute_and_mapping_access_coexist(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved == result["approved"]
    assert result.component_count == result["component_count"]


def test_copy_preserves_contract(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path).copy()

    assert result.approved is True
    assert result["version"] == "1.0.3"
    assert result.version == "1.0.6"
'@

$Component = @'
{
  "increment_code": "SGD-114E-v1.0.6",
  "name": "Definitive Contract Restoration",
  "component_type": "governance_contract_closure",
  "version": "1.0.6",
  "contract_version": "1.0.3",
  "status": "implemented",
  "phase": "Gobierno Digital",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "dependencies": [
    "SGD-114E-v1.0.3",
    "SGD-114E-v1.0.4",
    "SGD-114E-v1.0.5",
    "SGD-114F",
    "SGD-115A",
    "SGD-116",
    "SPB-007"
  ],
  "compatibility_contract": [
    "result.approved",
    "result.component_count",
    "result.findings",
    "result.proprietary_dependency_count",
    "result[approved]",
    "result.to_dict()"
  ]
}
'@

$Documentation = @'
# SGD-114E v1.0.6 — Definitive Contract Restoration

## Solución definitiva

La implementación restaura el contrato histórico completo y conserva la
interfaz moderna.

### Contrato histórico

- `result.approved`
- `result.component_count`
- `result.findings`
- `result.proprietary_dependency_count`

### Contrato moderno

- `result["approved"]`
- `result["native_component_count"]`
- `result.to_dict()`

### Versiones

- `result["version"]`: contrato funcional 1.0.3.
- `result.version`: implementación 1.0.6.
- `result.implementation_version`: implementación 1.0.6.

### Política de aprobación

El repositorio queda aprobado cuando no existen hallazgos institucionales.
Los componentes anteriores a SPT-007 quedan fuera del alcance obligatorio.
'@

Step "Aplicando restauración definitiva del contrato"

Write-Utf8 -Path $ModelsPath -Content $Models
Write-Utf8 -Path $ValidatorPath -Content $Validator
Write-Utf8 -Path $CliPath -Content $Cli
Write-Utf8 -Path $ClosureTestPath -Content $ClosureTests
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $PatchDoc -Content $Documentation

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/native_ecosystem_models.py" `
        "src/sgoda/governance/native_ecosystem_validator.py" `
        "src/sgoda/governance/native_ecosystem_cli.py" `
        "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py" `
        "tests/governance/test_SGD_114E_v1_0_3_approval_logic_fix.py" `
        "tests/governance/test_SGD_114E_v1_0_5_backward_compatibility_result_model.py" `
        "tests/governance/test_SGD_114E_v1_0_6_definitive_contract_restoration.py"
}

Run "Ejecutando todas las pruebas contractuales SGD-114E" {
    & $RunnerPath `
        -Component "SGD-114E-v1.0.6" `
        -TestPath @(
            "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py",
            "tests/governance/test_SGD_114E_v1_0_3_approval_logic_fix.py",
            "tests/governance/test_SGD_114E_v1_0_5_backward_compatibility_result_model.py",
            "tests/governance/test_SGD_114E_v1_0_6_definitive_contract_restoration.py"
        ) `
        -ReportPath "$SpecificXml" `
        -SummaryJson "$SpecificJson" `
        -SummaryMarkdown "$SpecificMd" `
        -Scope "specific"
}

$SpecificSummary = Get-Content `
    -LiteralPath $SpecificJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$SpecificSummary.approved) {
    throw "Las pruebas contractuales SGD-114E no fueron aprobadas."
}

if (-not $SkipFullSuite) {
    Run "Ejecutando suite completa con evidencia JUnit" {
        python -m pytest `
            --junitxml="$FullXml"
    }

    Run "Sincronizando suite completa mediante SGD-114F" {
        python -m sgoda.governance.test_evidence.cli `
            --junit "$FullXml" `
            --component "SGODA-PUINAVE" `
            --scope "full_suite" `
            --output-json "$FullJson" `
            --output-md "$FullMd"
    }

    $FullSummary = Get-Content `
        -LiteralPath $FullJson `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if (-not [bool]$FullSummary.approved) {
        throw "La suite completa no fue aprobada."
    }
}

Step "Autoevaluando SGD-114E"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$SelfJson" `
    --output-md "$SelfMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó su autoevaluación."
}

$SelfResult = Get-Content `
    -LiteralPath $SelfJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$SelfResult.approved) {
    throw "La autoevaluación SGD-114E devolvió NO APROBADO."
}

Step "Revalidando SPT-016A"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$Spt016AJson" `
    --output-md "$Spt016AMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó SPT-016A."
}

$Spt016AResult = Get-Content `
    -LiteralPath $Spt016AJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Spt016AResult.approved) {
    throw "SPT-016A continúa sin aprobación."
}

Step "Generando evidencia y release"

$FullEvidence = $null

if (-not $SkipFullSuite) {
    $FullEvidence = [ordered]@{
        executed = [int]$FullSummary.executed
        passed = [int]$FullSummary.passed
        failures = [int]$FullSummary.failures
        errors = [int]$FullSummary.errors
        skipped = [int]$FullSummary.skipped
        duration_seconds = [double]$FullSummary.duration_seconds
        approved = [bool]$FullSummary.approved
        source_report = [string]$FullSummary.source_report
    }
}

$Evidence = [ordered]@{
    increment_code = "SGD-114E-v1.0.6"
    target_component = "SGD-114E"
    version = "1.0.6"
    contract_version = "1.0.3"
    status = "implemented_tested_and_approved"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    patch_type = "definitive_contract_restoration"
    historical_tests_modified = $false
    specific_tests = [ordered]@{
        executed = [int]$SpecificSummary.executed
        passed = [int]$SpecificSummary.passed
        failures = [int]$SpecificSummary.failures
        errors = [int]$SpecificSummary.errors
        skipped = [int]$SpecificSummary.skipped
        duration_seconds = [double]$SpecificSummary.duration_seconds
        approved = [bool]$SpecificSummary.approved
        source_report = [string]$SpecificSummary.source_report
    }
    full_suite = $FullEvidence
    native_validation = [ordered]@{
        approved = [bool]$SelfResult.approved
        result = [string]$SelfResult.result
        native_components = [int]$SelfResult.native_component_count
        findings = @($SelfResult.findings).Count
        forbidden_terms = [int]$SelfResult.forbidden_term_count
        proprietary_dependencies = (
            [int]$SelfResult.mandatory_proprietary_dependency_count
        )
        structural_errors = [int]$SelfResult.structural_error_count
    }
    spt_016a = [ordered]@{
        approved = [bool]$Spt016AResult.approved
        result = [string]$Spt016AResult.result
    }
    backup = $BackupDir
}

Write-Json -Path $EvidencePath -Value $Evidence

$EvidenceText = @"
# SGD-114E v1.0.6 — Evidencia de cierre definitivo

- Contrato funcional: 1.0.3
- Implementación: 1.0.6
- Pruebas históricas modificadas: NO
- Pruebas específicas: $($SpecificSummary.passed)/$($SpecificSummary.executed)
- Autoevaluación SGD-114E: $($SelfResult.result)
- SPT-016A: $($Spt016AResult.result)
- Componentes nativos: $($SelfResult.native_component_count)
- Hallazgos: $(@($SelfResult.findings).Count)
- Términos prohibidos: $($SelfResult.forbidden_term_count)
- Dependencias propietarias obligatorias: $($SelfResult.mandatory_proprietary_dependency_count)
- Errores estructurales: $($SelfResult.structural_error_count)
"@

if (-not $SkipFullSuite) {
    $EvidenceText += @"

- Suite completa: $($FullSummary.passed)/$($FullSummary.executed)
- Fallos: $($FullSummary.failures)
- Errores: $($FullSummary.errors)
- Omitidas: $($FullSummary.skipped)
"@
}

Write-Utf8 -Path $EvidenceMd -Content $EvidenceText

foreach ($ReleaseFile in @(
    $ModelsPath,
    $ValidatorPath,
    $CliPath,
    $RunnerPath,
    $HistoricalTestPath,
    $LogicTestPath,
    $CompatibilityTestPath,
    $ClosureTestPath,
    $ComponentPath,
    $PatchDoc,
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $SelfJson,
    $SelfMd,
    $Spt016AJson,
    $Spt016AMd,
    $EvidencePath,
    $EvidenceMd
)) {
    Require-File $ReleaseFile
    Copy-Item -LiteralPath $ReleaseFile -Destination $ReleaseDir -Force
}

if (-not $SkipFullSuite) {
    foreach ($File in @(
        $FullXml,
        $FullJson,
        $FullMd
    )) {
        Require-File $File
        Copy-Item -LiteralPath $File -Destination $ReleaseDir -Force
    }
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SGD-114E-v1.0.6"
        version = "1.0.6"
        contract_version = "1.0.3"
        status = "implemented_tested_and_approved"
        files = @(
            Get-ChildItem -LiteralPath $ReleaseDir -File |
                Select-Object -ExpandProperty Name
        )
    })

Run "Regenerando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Run "Regenerando SGD-116" {
    python -m sgoda.roadmap.cli `
        --root "$ProjectRoot" `
        --output "artifacts/roadmap/SGD-116"
}

if ($Publish) {
    Step "Publicando mediante SPB-007"

    & (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1") `
        -Publish `
        -CommitMessage "fix(governance): close SGD-114E contract compatibility" `
        -EvidenceCommitMessage "chore(governance): publish SGD-114E v1.0.6 closure evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SGD-114E v1.0.6 implementado." -ForegroundColor Green
Write-Host "Definitive Contract Restoration: APLICADO." `
    -ForegroundColor Green
Write-Host "Contrato funcional 1.0.3: RESTAURADO." `
    -ForegroundColor Green
Write-Host "Implementación 1.0.6: OPERATIVA." `
    -ForegroundColor Green
Write-Host "Pruebas históricas: INTACTAS." `
    -ForegroundColor Green
Write-Host (
    "Pruebas contractuales: " +
    "$($SpecificSummary.passed)/$($SpecificSummary.executed) APROBADAS."
) -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host (
        "Suite completa: " +
        "$($FullSummary.passed)/$($FullSummary.executed) APROBADAS."
    ) -ForegroundColor Green
}

Write-Host "Autoevaluación SGD-114E: APROBADA." `
    -ForegroundColor Green
Write-Host "SPT-016A: APROBADO POR SGD-114E." `
    -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." `
    -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO." `
    -ForegroundColor Green
Write-Host "Release: releases\SGD-114E-v1.0.6" `
    -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" `
    -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" `
    -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." `
        -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Publicación no solicitada. Reejecute con -Publish." `
        -ForegroundColor Yellow
}
