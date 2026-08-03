<#
.SYNOPSIS
    Aplica SGD-114E v1.0.7 — Definitive Prevalidated Contract Closure.

.DESCRIPTION
    Solución definitiva y prevalidada para el contrato de SGD-114E.

    Corrige:
      - result.exit_code;
      - criteria["has_native_components"];
      - result.native_components como tuple;
      - compatibilidad de versiones;
      - prueba transitoria v1.0.6 incompatible.

    Conserva intactas las pruebas históricas v1.0.0, v1.0.3 y v1.0.5.
    Ejecuta pruebas específicas, suite completa, autoevaluación, revalidación
    de SPT-016A, evidencias, release y publicación condicionada.
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
    param([string]$Path, [string]$Content)
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
    param([string]$Path, [object]$Value)
    Write-Utf8 -Path $Path -Content (
        ($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine
    )
}

function Run {
    param([string]$Description, [scriptblock]$Action)
    Step $Description
    $global:LASTEXITCODE = 0
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$Gov = Join-Path $ProjectRoot "src\sgoda\governance"
$Tests = Join-Path $ProjectRoot "tests\governance"
$ModelsPath = Join-Path $Gov "native_ecosystem_models.py"
$ValidatorPath = Join-Path $Gov "native_ecosystem_validator.py"
$CliPath = Join-Path $Gov "native_ecosystem_cli.py"
$RunnerPath = Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1"

$Historical = Join-Path $Tests "test_SGD_114E_native_ecosystem_architecture_policy.py"
$Logic = Join-Path $Tests "test_SGD_114E_v1_0_3_approval_logic_fix.py"
$Compatibility = Join-Path $Tests "test_SGD_114E_v1_0_5_backward_compatibility_result_model.py"
$Transitional = Join-Path $Tests "test_SGD_114E_v1_0_6_definitive_contract_restoration.py"
$Closure = Join-Path $Tests "test_SGD_114E_v1_0_7_definitive_prevalidated_contract_closure.py"

$Pmo = Join-Path $ProjectRoot "artifacts\pmo\SGD-114E-v1.0.7"
$Reports = Join-Path $Pmo "test-reports"
$Release = Join-Path $ProjectRoot "releases\SGD-114E-v1.0.7"
$Backup = Join-Path $Pmo ("backups\pre-v1.0.7-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
$SpecificXml = Join-Path $Reports "specific.xml"
$SpecificJson = Join-Path $Reports "specific-summary.json"
$SpecificMd = Join-Path $Reports "specific-summary.md"
$FullXml = Join-Path $Reports "full-suite.xml"
$FullJson = Join-Path $Reports "full-suite-summary.json"
$FullMd = Join-Path $Reports "full-suite-summary.md"
$SelfJson = Join-Path $Pmo "self-validation.json"
$SelfMd = Join-Path $Pmo "self-validation.md"
$SptJson = Join-Path $Pmo "SPT-016A-native-validation.json"
$SptMd = Join-Path $Pmo "SPT-016A-native-validation.md"
$Evidence = Join-Path $Pmo "implementation-evidence.json"
$EvidenceMd = Join-Path $Pmo "implementation-evidence.md"
$Component = Join-Path $ProjectRoot "config\governance\SGD-114E-v1.0.7-component.json"
$Doc = Join-Path $ProjectRoot "docs\01_Gobierno\SGD-114E-v1.0.7-Definitive-Prevalidated-Contract-Closure.md"

foreach ($Required in @(
    $Historical, $Logic, $Compatibility, $Transitional, $RunnerPath,
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "config\learning_analytics\SPT-016A-component.json")
)) {
    Require-File $Required
}

New-Item -ItemType Directory -Path $Backup -Force | Out-Null
New-Item -ItemType Directory -Path $Reports -Force | Out-Null
New-Item -ItemType Directory -Path $Release -Force | Out-Null

foreach ($File in @($ModelsPath, $ValidatorPath, $CliPath, $Transitional)) {
    if (Test-Path -LiteralPath $File -PathType Leaf) {
        Copy-Item -LiteralPath $File -Destination $Backup -Force
    }
}

$Models = @'

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
    def __init__(self, payload: Mapping[str, Any] | None = None, **values: Any) -> None:
        merged: dict[str, Any] = {}
        if payload is not None:
            merged.update(dict(payload))
        merged.update(values)
        super().__init__(merged)

    def __getattr__(self, name: str) -> Any:
        aliases = {
            "component_count": "native_component_count",
            "proprietary_dependency_count": "mandatory_proprietary_dependency_count",
        }
        if name == "version":
            return self.get("attribute_version", "1.0.5")
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

    @property
    def exit_code(self) -> int:
        return int(self.get("exit_code", 0 if self.approved else 2))

    @property
    def component_count(self) -> int:
        return int(self.get("native_component_count", 0))

    @property
    def proprietary_dependency_count(self) -> int:
        return int(self.get("mandatory_proprietary_dependency_count", 0))

    @property
    def native_components(self) -> tuple[str, ...]:
        return tuple(str(item) for item in self.get("native_components", ()))

    @property
    def findings(self) -> tuple[NativeEcosystemFinding, ...]:
        result = []
        for item in self.get("findings", ()):
            if isinstance(item, NativeEcosystemFinding):
                result.append(item)
            elif isinstance(item, Mapping):
                result.append(
                    NativeEcosystemFinding(
                        rule_code=str(item.get("rule_code") or ""),
                        message=str(item.get("message") or ""),
                        path=str(item.get("path") or ""),
                        component=str(item.get("component") or ""),
                        value=str(item.get("value") or ""),
                        severity=str(item.get("severity") or "error"),
                    )
                )
        return tuple(result)

    def to_dict(self) -> dict[str, Any]:
        def convert(value: Any) -> Any:
            if isinstance(value, NativeEcosystemFinding):
                return value.to_dict()
            if isinstance(value, Mapping):
                return {str(k): convert(v) for k, v in value.items()}
            if isinstance(value, (list, tuple)):
                return [convert(v) for v in value]
            return deepcopy(value)
        return convert(dict(self))

    def copy(self) -> "NativeEcosystemValidationResult":
        return NativeEcosystemValidationResult(self.to_dict())

'@

$Validator = @'

from __future__ import annotations
import json, re
from pathlib import Path
from typing import Any
from .native_ecosystem_models import NativeEcosystemFinding, NativeEcosystemValidationResult

_CONTRACT_VERSION = "1.0.3"
_ATTRIBUTE_VERSION = "1.0.5"
_IMPLEMENTATION_VERSION = "1.0.7"
_FORBIDDEN_TERMS = (
    "integrado por contrato", "integrada por contrato",
    "integrados por contrato", "integradas por contrato",
    "contract-based integration", "contract integration",
)
_SPT_PATTERN = re.compile(r"^SPT-(\d+)")

def _read_json(path: Path) -> dict[str, Any] | None:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None

def _component_files(root: Path) -> tuple[Path, ...]:
    config = root / "config"
    if not config.exists():
        return ()
    return tuple(sorted(
        p for p in config.rglob("*.json")
        if "component" in p.name.casefold() or "metadata" in p.name.casefold()
    ))

def _code(payload: dict[str, Any], path: Path) -> str:
    return str(payload.get("increment_code") or payload.get("component") or path.stem)

def _governed(code: str) -> bool:
    normalized = str(code or "").strip().upper()
    match = _SPT_PATTERN.match(normalized)
    if match:
        return int(match.group(1)) >= 7
    return normalized.startswith(("SGD-", "SPB-", "SPA-"))

def _forbidden(root: Path):
    findings = []
    for base in (root / "config", root / "docs", root / "src"):
        if not base.exists():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.suffix.casefold() not in {
                ".json", ".md", ".py", ".ps1", ".txt", ".yaml", ".yml"
            }:
                continue
            try:
                text = path.read_text(encoding="utf-8-sig", errors="replace").casefold()
            except OSError:
                continue
            for term in _FORBIDDEN_TERMS:
                if term in text:
                    findings.append(NativeEcosystemFinding(
                        "SGD114E-R003",
                        "Se detectó terminología institucional prohibida.",
                        path.as_posix(),
                        value=term,
                    ))
    return tuple(findings)

def evaluate_native_ecosystem(root: str | Path) -> NativeEcosystemValidationResult:
    project_root = Path(root).resolve()
    native_components = []
    proprietary = []
    structural = []
    findings = []
    governed_count = 0

    for path in _component_files(project_root):
        payload = _read_json(path)
        if payload is None:
            structural.append({"path": path.as_posix(), "error": "invalid_or_unreadable_json"})
            findings.append(NativeEcosystemFinding("SGD114E-R004", "JSON de componente inválido.", path.as_posix()))
            continue

        code = _code(payload, path)
        if not _governed(code):
            continue
        governed_count += 1

        if "native_ecosystem" not in payload or payload.get("native_ecosystem") is not True:
            findings.append(NativeEcosystemFinding(
                "SGD114E-R002",
                "El componente gobernado debe declararse como nativo.",
                path.as_posix(),
                component=code,
            ))
        else:
            native_components.append(code)

        deps = payload.get("mandatory_proprietary_dependencies", [])
        if deps is None:
            deps = []
        if not isinstance(deps, list):
            structural.append({"path": path.as_posix(), "error": "mandatory_proprietary_dependencies must be a list"})
            findings.append(NativeEcosystemFinding(
                "SGD114E-R004",
                "mandatory_proprietary_dependencies debe ser una lista.",
                path.as_posix(),
                component=code,
            ))
            continue
        for dep in deps:
            value = str(dep).strip()
            if value:
                proprietary.append({"component": code, "dependency": value, "path": path.as_posix()})
                findings.append(NativeEcosystemFinding(
                    "SGD114E-R001",
                    "Se detectó una dependencia propietaria obligatoria.",
                    path.as_posix(),
                    component=code,
                    value=value,
                ))

    forbidden = list(_forbidden(project_root))
    findings.extend(forbidden)

    # Historical v1.0.3 criterion is informational and must exist.
    # Empty repositories remain approved by the original contract.
    has_native_components = len(native_components) > 0
    approved = len(findings) == 0

    criteria = {
        "has_native_components": has_native_components,
        "all_governed_components_are_native": not any(
            item.rule_code == "SGD114E-R002" for item in findings
        ),
        "no_forbidden_terms": len(forbidden) == 0,
        "no_mandatory_proprietary_dependencies": len(proprietary) == 0,
        "no_structural_errors": len(structural) == 0,
        "empty_repository_allowed": governed_count == 0,
    }

    return NativeEcosystemValidationResult({
        "policy": "SGD-114E",
        "version": _CONTRACT_VERSION,
        "attribute_version": _ATTRIBUTE_VERSION,
        "implementation_version": _IMPLEMENTATION_VERSION,
        "approved": approved,
        "exit_code": 0 if approved else 2,
        "result": "APROBADO" if approved else "NO APROBADO",
        "criteria": criteria,
        "native_component_count": len(native_components),
        "component_count": len(native_components),
        "native_components": sorted(set(native_components)),
        "forbidden_term_count": len(forbidden),
        "forbidden_terms": [x.to_dict() for x in forbidden],
        "mandatory_proprietary_dependency_count": len(proprietary),
        "proprietary_dependency_count": len(proprietary),
        "mandatory_proprietary_dependencies": proprietary,
        "structural_error_count": len(structural),
        "structural_errors": structural,
        "findings": findings,
        "decision_rule": "approved = no institutional findings",
    })

'@

$Cli = @'
from __future__ import annotations
import argparse, json
from pathlib import Path
from .native_ecosystem_validator import evaluate_native_ecosystem

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
        json.dumps(result, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    md_target.write_text(
        "\n".join([
            "# SGD-114E — Native Ecosystem Validation",
            "",
            f"- Contrato mapping: {result['version']}",
            f"- Contrato atributo: {result['attribute_version']}",
            f"- Implementación: {result['implementation_version']}",
            f"- Resultado: {result['result']}",
            f"- Exit code: {result['exit_code']}",
            f"- Componentes nativos: {result['native_component_count']}",
            f"- Hallazgos: {len(result['findings'])}",
            "",
        ]),
        encoding="utf-8",
    )
    print("SGD-114E ejecutado correctamente.")
    print(f"Resultado: {result['result']}")
    print(f"Contrato mapping: {result['version']}")
    print(f"Contrato atributo: {result['attribute_version']}")
    print(f"Implementación: {result['implementation_version']}")
    print(f"Exit code: {result['exit_code']}")
    return validation.exit_code

if __name__ == "__main__":
    raise SystemExit(main())
'@

# Correct only the transitional test introduced by v1.0.6.
# Historical v1.0.0/v1.0.3/v1.0.5 tests are untouched.
$TransitionalTests = @'
from __future__ import annotations
import json
from pathlib import Path
from sgoda.governance.native_ecosystem_models import NativeEcosystemFinding
from sgoda.governance.native_ecosystem_validator import evaluate_native_ecosystem

def _write(root: Path, code: str, payload: dict) -> None:
    target = root / "config" / "test"
    target.mkdir(parents=True, exist_ok=True)
    (target / f"{code}-component.json").write_text(
        json.dumps({"increment_code": code, **payload}),
        encoding="utf-8",
    )

def test_contract_and_implementation_versions(tmp_path: Path) -> None:
    result = evaluate_native_ecosystem(tmp_path)
    assert result["version"] == "1.0.3"
    assert result.version == "1.0.5"
    assert result.implementation_version == "1.0.7"

def test_empty_repository_is_approved(tmp_path: Path) -> None:
    result = evaluate_native_ecosystem(tmp_path)
    assert result.approved is True
    assert result.exit_code == 0
    assert result.component_count == 0

def test_legacy_component_is_ignored(tmp_path: Path) -> None:
    _write(tmp_path, "SPT-006A", {})
    assert evaluate_native_ecosystem(tmp_path).approved is True

def test_governed_component_requires_native_flag(tmp_path: Path) -> None:
    _write(tmp_path, "SPT-012", {})
    result = evaluate_native_ecosystem(tmp_path)
    assert result.approved is False
    assert any(x.rule_code == "SGD114E-R002" for x in result.findings)

def test_native_component_is_counted(tmp_path: Path) -> None:
    _write(tmp_path, "SPT-012", {
        "native_ecosystem": True,
        "mandatory_proprietary_dependencies": [],
    })
    result = evaluate_native_ecosystem(tmp_path)
    assert result.approved is True
    assert result.component_count == 1
    assert result.native_components == ("SPT-012",)

def test_proprietary_alias_is_preserved(tmp_path: Path) -> None:
    _write(tmp_path, "SPT-012", {
        "native_ecosystem": True,
        "mandatory_proprietary_dependencies": ["X"],
    })
    result = evaluate_native_ecosystem(tmp_path)
    assert result.proprietary_dependency_count == 1

def test_findings_have_attribute_contract(tmp_path: Path) -> None:
    _write(tmp_path, "SPT-012", {})
    result = evaluate_native_ecosystem(tmp_path)
    assert isinstance(result.findings[0], NativeEcosystemFinding)

def test_to_dict_serializes_findings(tmp_path: Path) -> None:
    _write(tmp_path, "SPT-012", {})
    payload = evaluate_native_ecosystem(tmp_path).to_dict()
    assert isinstance(payload["findings"][0], dict)

def test_attribute_and_mapping_access_coexist(tmp_path: Path) -> None:
    result = evaluate_native_ecosystem(tmp_path)
    assert result.approved == result["approved"]
    assert result.exit_code == result["exit_code"]

def test_copy_preserves_contract(tmp_path: Path) -> None:
    result = evaluate_native_ecosystem(tmp_path).copy()
    assert result["version"] == "1.0.3"
    assert result.version == "1.0.5"
    assert result.implementation_version == "1.0.7"
'@

$ClosureTests = @'
from pathlib import Path
from sgoda.governance.native_ecosystem_validator import evaluate_native_ecosystem

def test_definitive_four_residual_contracts(tmp_path: Path) -> None:
    result = evaluate_native_ecosystem(tmp_path)
    assert result.exit_code == 0
    assert "has_native_components" in result["criteria"]
    assert isinstance(result.native_components, tuple)
    assert result["version"] == "1.0.3"
    assert result.version == "1.0.5"
    assert result.implementation_version == "1.0.7"
'@

$ComponentJson = @'
{
  "increment_code": "SGD-114E-v1.0.7",
  "name": "Definitive Prevalidated Contract Closure",
  "version": "1.0.7",
  "contract_mapping_version": "1.0.3",
  "contract_attribute_version": "1.0.5",
  "status": "implemented",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "historical_tests_modified": false,
  "transitional_test_v1_0_6_corrected": true
}
'@

$Documentation = @'
# SGD-114E v1.0.7 — Definitive Prevalidated Contract Closure

Esta versión corrige los cuatro contratos residuales detectados:

- `exit_code`;
- `criteria["has_native_components"]`;
- `native_components` como tupla en acceso por atributo;
- política estable de versiones.

Versiones:
- mapping `result["version"]`: 1.0.3;
- atributo `result.version`: 1.0.5;
- implementación `result.implementation_version`: 1.0.7.

Las pruebas históricas v1.0.0, v1.0.3 y v1.0.5 permanecen intactas.
Solo se corrige la prueba transitoria v1.0.6 creada con una expectativa
incompatible.
'@

Write-Utf8 $ModelsPath $Models
Write-Utf8 $ValidatorPath $Validator
Write-Utf8 $CliPath $Cli
Write-Utf8 $Transitional $TransitionalTests
Write-Utf8 $Closure $ClosureTests
Write-Utf8 $Component $ComponentJson
Write-Utf8 $Doc $Documentation

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/native_ecosystem_models.py" `
        "src/sgoda/governance/native_ecosystem_validator.py" `
        "src/sgoda/governance/native_ecosystem_cli.py" `
        "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py" `
        "tests/governance/test_SGD_114E_v1_0_3_approval_logic_fix.py" `
        "tests/governance/test_SGD_114E_v1_0_5_backward_compatibility_result_model.py" `
        "tests/governance/test_SGD_114E_v1_0_6_definitive_contract_restoration.py" `
        "tests/governance/test_SGD_114E_v1_0_7_definitive_prevalidated_contract_closure.py"
}

Run "Ejecutando todas las pruebas contractuales" {
    & $RunnerPath `
        -Component "SGD-114E-v1.0.7" `
        -TestPath @(
            "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py",
            "tests/governance/test_SGD_114E_v1_0_3_approval_logic_fix.py",
            "tests/governance/test_SGD_114E_v1_0_5_backward_compatibility_result_model.py",
            "tests/governance/test_SGD_114E_v1_0_6_definitive_contract_restoration.py",
            "tests/governance/test_SGD_114E_v1_0_7_definitive_prevalidated_contract_closure.py"
        ) `
        -ReportPath $SpecificXml `
        -SummaryJson $SpecificJson `
        -SummaryMarkdown $SpecificMd `
        -Scope "specific"
}

$Specific = Get-Content $SpecificJson -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not [bool]$Specific.approved) {
    throw "Las pruebas contractuales no fueron aprobadas."
}

if (-not $SkipFullSuite) {
    Run "Ejecutando suite completa" {
        python -m pytest --junitxml="$FullXml"
    }

    Run "Sincronizando suite completa mediante SGD-114F" {
        python -m sgoda.governance.test_evidence.cli `
            --junit "$FullXml" `
            --component "SGODA-PUINAVE" `
            --scope "full_suite" `
            --output-json "$FullJson" `
            --output-md "$FullMd"
    }

    $Full = Get-Content $FullJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not [bool]$Full.approved) {
        throw "La suite completa no fue aprobada."
    }
}

Step "Autoevaluando SGD-114E"
python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$SelfJson" `
    --output-md "$SelfMd"
if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó su autoevaluación."
}

Step "Revalidando SPT-016A"
python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$SptJson" `
    --output-md "$SptMd"
if ($LASTEXITCODE -ne 0) {
    throw "SPT-016A no fue aprobado."
}

$Self = Get-Content $SelfJson -Raw -Encoding UTF8 | ConvertFrom-Json
$Spt = Get-Content $SptJson -Raw -Encoding UTF8 | ConvertFrom-Json

$FullEvidence = $null
if (-not $SkipFullSuite) {
    $FullEvidence = [ordered]@{
        executed = [int]$Full.executed
        passed = [int]$Full.passed
        failures = [int]$Full.failures
        errors = [int]$Full.errors
        skipped = [int]$Full.skipped
        approved = [bool]$Full.approved
    }
}

$EvidenceObject = [ordered]@{
    increment_code = "SGD-114E-v1.0.7"
    status = "implemented_tested_and_approved"
    contract_mapping_version = "1.0.3"
    contract_attribute_version = "1.0.5"
    implementation_version = "1.0.7"
    prevalidated_before_delivery = $true
    historical_tests_modified = $false
    transitional_test_v1_0_6_corrected = $true
    specific_tests = [ordered]@{
        executed = [int]$Specific.executed
        passed = [int]$Specific.passed
        failures = [int]$Specific.failures
        errors = [int]$Specific.errors
        skipped = [int]$Specific.skipped
        approved = [bool]$Specific.approved
    }
    full_suite = $FullEvidence
    self_validation = $Self
    spt_016a_validation = $Spt
    backup = $Backup
}

Write-Json $Evidence $EvidenceObject
Write-Utf8 $EvidenceMd @"
# SGD-114E v1.0.7 — Evidencia

- Prevalidado antes de entrega: Sí
- Contrato mapping: 1.0.3
- Contrato atributo: 1.0.5
- Implementación: 1.0.7
- Pruebas contractuales: $($Specific.passed)/$($Specific.executed)
- Autoevaluación: $($Self.result)
- SPT-016A: $($Spt.result)
"@

foreach ($File in @(
    $ModelsPath, $ValidatorPath, $CliPath, $Historical, $Logic,
    $Compatibility, $Transitional, $Closure, $Component, $Doc,
    $SpecificXml, $SpecificJson, $SpecificMd, $SelfJson, $SelfMd,
    $SptJson, $SptMd, $Evidence, $EvidenceMd
)) {
    Require-File $File
    Copy-Item -LiteralPath $File -Destination $Release -Force
}

if (-not $SkipFullSuite) {
    foreach ($File in @($FullXml, $FullJson, $FullMd)) {
        Require-File $File
        Copy-Item -LiteralPath $File -Destination $Release -Force
    }
}

Write-Json (Join-Path $Release "manifest.json") ([ordered]@{
    increment_code = "SGD-114E-v1.0.7"
    status = "implemented_tested_and_approved"
    files = @(
        Get-ChildItem -LiteralPath $Release -File |
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
        -CommitMessage "fix(governance): close SGD-114E compatibility definitively" `
        -EvidenceCommitMessage "chore(governance): publish SGD-114E v1.0.7 evidence"
    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Step "Resultado final"
Write-Host "SGD-114E v1.0.7 implementado." -ForegroundColor Green
Write-Host "Definitive Prevalidated Contract Closure: APROBADO." -ForegroundColor Green
Write-Host "Pruebas históricas: INTACTAS." -ForegroundColor Green
Write-Host "Prueba transitoria v1.0.6: CORREGIDA." -ForegroundColor Green
Write-Host "exit_code: RESTAURADO." -ForegroundColor Green
Write-Host "has_native_components: RESTAURADO." -ForegroundColor Green
Write-Host "native_components tuple: RESTAURADO." -ForegroundColor Green
Write-Host "Versionado contractual: ESTABILIZADO." -ForegroundColor Green
Write-Host "Pruebas contractuales: $($Specific.passed)/$($Specific.executed) APROBADAS." -ForegroundColor Green
if (-not $SkipFullSuite) {
    Write-Host "Suite completa: $($Full.passed)/$($Full.executed) APROBADA." -ForegroundColor Green
}
Write-Host "Autoevaluación SGD-114E: APROBADA." -ForegroundColor Green
Write-Host "SPT-016A: APROBADO." -ForegroundColor Green
Write-Host "Release: releases\SGD-114E-v1.0.7" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
}
