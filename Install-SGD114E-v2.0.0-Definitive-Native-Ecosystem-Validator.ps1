<#
.SYNOPSIS
    Instala SGD-114E v2.0.0 — Definitive Native Ecosystem Validator.

.DESCRIPTION
    Consolida definitivamente SGD-114E.

    Corrige:
      - exit_code;
      - criteria.has_native_components;
      - empty_repository_allowed como política;
      - repository_is_empty como estado;
      - native_components tuple/list;
      - compatibilidad de versiones;
      - hallazgos y aliases históricos.

    Mantiene intactas las pruebas históricas y reemplaza únicamente
    la prueba transitoria v1.0.6 por un contrato compatible.
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
        -Content (
            ($Value | ConvertTo-Json -Depth 100) +
            [Environment]::NewLine
        )
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

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$GovernanceDir = Join-Path $ProjectRoot "src\sgoda\governance"
$TestsDir = Join-Path $ProjectRoot "tests\governance"
$ModelsPath = Join-Path $GovernanceDir "native_ecosystem_models.py"
$ValidatorPath = Join-Path $GovernanceDir "native_ecosystem_validator.py"
$CliPath = Join-Path $GovernanceDir "native_ecosystem_cli.py"
$RunnerPath = Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1"

$HistoricalPath = Join-Path $TestsDir "test_SGD_114E_native_ecosystem_architecture_policy.py"
$LogicPath = Join-Path $TestsDir "test_SGD_114E_v1_0_3_approval_logic_fix.py"
$CompatibilityPath = Join-Path $TestsDir "test_SGD_114E_v1_0_5_backward_compatibility_result_model.py"
$TransitionalPath = Join-Path $TestsDir "test_SGD_114E_v1_0_6_definitive_contract_restoration.py"
$V2TestPath = Join-Path $TestsDir "test_SGD_114E_v2_0_0_definitive_native_ecosystem_validator.py"

$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114E-v2.0.0"
$ReportsDir = Join-Path $PmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114E-v2.0.0"
$BackupDir = Join-Path $PmoDir ("backups\pre-v2.0.0-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$SpecificXml = Join-Path $ReportsDir "specific.xml"
$SpecificJson = Join-Path $ReportsDir "specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "specific-summary.md"
$FullXml = Join-Path $ReportsDir "full-suite.xml"
$FullJson = Join-Path $ReportsDir "full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "full-suite-summary.md"

$SelfJson = Join-Path $PmoDir "self-validation.json"
$SelfMd = Join-Path $PmoDir "self-validation.md"
$SptJson = Join-Path $PmoDir "SPT-016A-native-validation.json"
$SptMd = Join-Path $PmoDir "SPT-016A-native-validation.md"
$EvidencePath = Join-Path $PmoDir "implementation-evidence.json"
$EvidenceMd = Join-Path $PmoDir "implementation-evidence.md"

$ComponentPath = Join-Path $ProjectRoot "config\governance\SGD-114E-v2.0.0-component.json"
$DocPath = Join-Path $ProjectRoot "docs\01_Gobierno\SGD-114E-v2.0.0-Definitive-Native-Ecosystem-Validator.md"

foreach ($Required in @(
    $HistoricalPath,
    $LogicPath,
    $CompatibilityPath,
    $TransitionalPath,
    $RunnerPath,
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "config\learning_analytics\SPT-016A-component.json")
)) {
    Require-File $Required
}

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($File in @(
    $ModelsPath,
    $ValidatorPath,
    $CliPath,
    $TransitionalPath
)) {
    if (Test-Path -LiteralPath $File -PathType Leaf) {
        Copy-Item `
            -LiteralPath $File `
            -Destination $BackupDir `
            -Force
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
    """Resultado institucional compatible con contratos históricos y modernos."""

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
        return int(
            self.get(
                "exit_code",
                0 if self.approved else 2,
            )
        )

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
    def native_components(self) -> tuple[str, ...]:
        return tuple(
            str(item)
            for item in self.get("native_components", ())
        )

    @property
    def findings(self) -> tuple[NativeEcosystemFinding, ...]:
        converted = []

        for item in self.get("findings", ()):
            if isinstance(item, NativeEcosystemFinding):
                converted.append(item)
            elif isinstance(item, Mapping):
                converted.append(
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

        return tuple(converted)

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

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from .native_ecosystem_models import (
    NativeEcosystemFinding,
    NativeEcosystemValidationResult,
)


_MAPPING_CONTRACT_VERSION = "1.0.3"
_ATTRIBUTE_CONTRACT_VERSION = "1.0.5"
_IMPLEMENTATION_VERSION = "2.0.0"

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

    governed_count = 0
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

        governed_count += 1

        if payload.get("native_ecosystem") is True:
            native_components.append(code)
        else:
            findings.append(
                NativeEcosystemFinding(
                    rule_code="SGD114E-R002",
                    message=(
                        "El componente gobernado debe "
                        "declararse como nativo."
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
            value = str(dependency).strip()

            if value:
                proprietary_dependencies.append(
                    {
                        "component": code,
                        "dependency": value,
                        "path": path.as_posix(),
                    }
                )
                findings.append(
                    NativeEcosystemFinding(
                        rule_code="SGD114E-R001",
                        message=(
                            "Se detectó una dependencia "
                            "propietaria obligatoria."
                        ),
                        path=path.as_posix(),
                        component=code,
                        value=value,
                    )
                )

    forbidden_findings = list(
        _scan_forbidden_terms(project_root)
    )
    findings.extend(forbidden_findings)

    repository_is_empty = governed_count == 0
    has_native_components = len(native_components) > 0
    approved = len(findings) == 0

    criteria = {
        "has_native_components": has_native_components,
        "all_governed_components_are_native": not any(
            item.rule_code == "SGD114E-R002"
            for item in findings
        ),
        "no_forbidden_terms": len(forbidden_findings) == 0,
        "no_mandatory_proprietary_dependencies": (
            len(proprietary_dependencies) == 0
        ),
        "no_structural_errors": len(structural_errors) == 0,
        "empty_repository_allowed": True,
    }

    return NativeEcosystemValidationResult(
        {
            "policy": "SGD-114E",
            "version": _MAPPING_CONTRACT_VERSION,
            "attribute_version": (
                _ATTRIBUTE_CONTRACT_VERSION
            ),
            "implementation_version": (
                _IMPLEMENTATION_VERSION
            ),
            "approved": approved,
            "exit_code": 0 if approved else 2,
            "result": (
                "APROBADO"
                if approved
                else "NO APROBADO"
            ),
            "repository_is_empty": repository_is_empty,
            "governed_component_count": governed_count,
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
                finding.to_dict()
                for finding in forbidden_findings
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
        }
    )

'@

$Cli = @'
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
                "# SGD-114E v2.0.0",
                "",
                f"- Resultado: {result['result']}",
                f"- Exit code: {result['exit_code']}",
                f"- Mapping contract: {result['version']}",
                f"- Attribute contract: {result['attribute_version']}",
                f"- Implementation: {result['implementation_version']}",
                f"- Repository empty: {result['repository_is_empty']}",
                f"- Native components: {result['native_component_count']}",
                f"- Findings: {len(result['findings'])}",
                "",
            ]
        ),
        encoding="utf-8",
    )

    print("SGD-114E v2.0.0 ejecutado correctamente.")
    print(f"Resultado: {result['result']}")
    print(f"Exit code: {result['exit_code']}")
    print(f"Implementación: {result['implementation_version']}")

    return validation.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
'@

$TransitionalTests = @'
from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.native_ecosystem_models import (
    NativeEcosystemFinding,
)
from sgoda.governance.native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def _write(root: Path, code: str, payload: dict) -> None:
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
    assert result.version == "1.0.5"
    assert result.implementation_version == "2.0.0"


def test_empty_repository_is_approved(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.exit_code == 0
    assert result.repository_is_empty is True


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
    assert result.native_components == ("SPT-012",)


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


def test_findings_have_attribute_contract(
    tmp_path: Path,
) -> None:
    _write(tmp_path, "SPT-012", {})

    result = evaluate_native_ecosystem(tmp_path)

    assert isinstance(
        result.findings[0],
        NativeEcosystemFinding,
    )


def test_to_dict_serializes_findings(
    tmp_path: Path,
) -> None:
    _write(tmp_path, "SPT-012", {})

    payload = evaluate_native_ecosystem(
        tmp_path
    ).to_dict()

    assert isinstance(payload["findings"][0], dict)


def test_attribute_and_mapping_access_coexist(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved == result["approved"]
    assert result.exit_code == result["exit_code"]


def test_copy_preserves_contract(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(
        tmp_path
    ).copy()

    assert result["version"] == "1.0.3"
    assert result.version == "1.0.5"
    assert result.implementation_version == "2.0.0"
'@

$V2Tests = @'

import json
from pathlib import Path

from sgoda.governance.native_ecosystem_models import (
    NativeEcosystemFinding,
)
from sgoda.governance.native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def write_component(
    root: Path,
    code: str = "SPT-012",
    native=True,
    dependencies=None,
) -> None:
    target = root / "config" / "test"
    target.mkdir(parents=True, exist_ok=True)

    payload = {
        "increment_code": code,
        "mandatory_proprietary_dependencies": (
            [] if dependencies is None else dependencies
        ),
    }

    if native is not None:
        payload["native_ecosystem"] = native

    (target / f"{code}-component.json").write_text(
        json.dumps(payload),
        encoding="utf-8",
    )


def test_empty_repository_contract(tmp_path: Path) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.exit_code == 0
    assert result["version"] == "1.0.3"
    assert result.version == "1.0.5"
    assert result.implementation_version == "2.0.0"
    assert result.repository_is_empty is True
    assert result["criteria"]["empty_repository_allowed"] is True


def test_valid_native_component_all_criteria_true(
    tmp_path: Path,
) -> None:
    write_component(tmp_path)

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.repository_is_empty is False
    assert result["criteria"]["has_native_components"] is True
    assert all(result["criteria"].values())


def test_native_components_attribute_is_tuple(
    tmp_path: Path,
) -> None:
    write_component(tmp_path)

    result = evaluate_native_ecosystem(tmp_path)

    assert result.native_components == ("SPT-012",)
    assert result["native_components"] == ["SPT-012"]


def test_missing_native_flag_is_rejected(
    tmp_path: Path,
) -> None:
    write_component(tmp_path, native=None)

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert result.exit_code == 2
    assert result["criteria"]["has_native_components"] is False
    assert any(
        finding.rule_code == "SGD114E-R002"
        for finding in result.findings
    )


def test_false_native_flag_is_rejected(
    tmp_path: Path,
) -> None:
    write_component(tmp_path, native=False)

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False


def test_legacy_component_is_ignored(
    tmp_path: Path,
) -> None:
    write_component(
        tmp_path,
        code="SPT-006A",
        native=None,
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.component_count == 0


def test_proprietary_dependency_alias(
    tmp_path: Path,
) -> None:
    write_component(
        tmp_path,
        dependencies=["PaidVendorOnly"],
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.proprietary_dependency_count == 1
    assert (
        result["mandatory_proprietary_dependency_count"]
        == 1
    )


def test_invalid_json_is_rejected(
    tmp_path: Path,
) -> None:
    target = tmp_path / "config"
    target.mkdir()
    (target / "bad-component.json").write_text(
        "{invalid",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert result.structural_error_count == 1


def test_findings_contract_and_serialization(
    tmp_path: Path,
) -> None:
    write_component(tmp_path, native=None)

    result = evaluate_native_ecosystem(tmp_path)
    payload = result.to_dict()

    assert isinstance(
        result.findings[0],
        NativeEcosystemFinding,
    )
    assert isinstance(payload["findings"][0], dict)


def test_copy_preserves_contract(
    tmp_path: Path,
) -> None:
    copied = evaluate_native_ecosystem(
        tmp_path
    ).copy()

    assert copied.approved is True
    assert copied.exit_code == 0
    assert copied["version"] == "1.0.3"
    assert copied.version == "1.0.5"
    assert copied.implementation_version == "2.0.0"

'@

$ComponentJson = @'
{
  "increment_code": "SGD-114E-v2.0.0",
  "name": "Definitive Native Ecosystem Validator",
  "version": "2.0.0",
  "status": "implemented",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "mapping_contract_version": "1.0.3",
  "attribute_contract_version": "1.0.5",
  "historical_tests_modified": false,
  "transitional_test_corrected": true
}
'@

$Documentation = @'
# SGD-114E v2.0.0 — Definitive Native Ecosystem Validator

La versión 2.0.0 consolida todos los correctivos previos.

## Contratos

- `result["version"]`: 1.0.3
- `result.version`: 1.0.5
- `result.implementation_version`: 2.0.0
- `result.exit_code`
- `result.component_count`
- `result.proprietary_dependency_count`
- `result.findings`
- `result.native_components`
- `result.to_dict()`

## Criterios

`empty_repository_allowed` es una política siempre verdadera.

`repository_is_empty` registra el estado real del repositorio.

Por tanto, un repositorio válido con componentes no falla por tener
`empty_repository_allowed=False`.
'@

Write-Utf8 $ModelsPath $Models
Write-Utf8 $ValidatorPath $Validator
Write-Utf8 $CliPath $Cli
Write-Utf8 $TransitionalPath $TransitionalTests
Write-Utf8 $V2TestPath $V2Tests
Write-Utf8 $ComponentPath $ComponentJson
Write-Utf8 $DocPath $Documentation

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/native_ecosystem_models.py" `
        "src/sgoda/governance/native_ecosystem_validator.py" `
        "src/sgoda/governance/native_ecosystem_cli.py" `
        "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py" `
        "tests/governance/test_SGD_114E_v1_0_3_approval_logic_fix.py" `
        "tests/governance/test_SGD_114E_v1_0_5_backward_compatibility_result_model.py" `
        "tests/governance/test_SGD_114E_v1_0_6_definitive_contract_restoration.py" `
        "tests/governance/test_SGD_114E_v2_0_0_definitive_native_ecosystem_validator.py"
}

Run "Ejecutando pruebas contractuales completas" {
    & $RunnerPath `
        -Component "SGD-114E-v2.0.0" `
        -TestPath @(
            "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py",
            "tests/governance/test_SGD_114E_v1_0_3_approval_logic_fix.py",
            "tests/governance/test_SGD_114E_v1_0_5_backward_compatibility_result_model.py",
            "tests/governance/test_SGD_114E_v1_0_6_definitive_contract_restoration.py",
            "tests/governance/test_SGD_114E_v2_0_0_definitive_native_ecosystem_validator.py"
        ) `
        -ReportPath "$SpecificXml" `
        -SummaryJson "$SpecificJson" `
        -SummaryMarkdown "$SpecificMd" `
        -Scope "specific"
}

$Specific = Get-Content `
    -LiteralPath $SpecificJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Specific.approved) {
    throw "Las pruebas contractuales no fueron aprobadas."
}

if (-not $SkipFullSuite) {
    Run "Ejecutando suite completa" {
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

    $Full = Get-Content `
        -LiteralPath $FullJson `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

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

$Self = Get-Content `
    -LiteralPath $SelfJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

$Spt = Get-Content `
    -LiteralPath $SptJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

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
    increment_code = "SGD-114E-v2.0.0"
    status = "implemented_tested_and_approved"
    prevalidated_before_delivery = $true
    mapping_contract_version = "1.0.3"
    attribute_contract_version = "1.0.5"
    implementation_version = "2.0.0"
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
    backup = $BackupDir
}

Write-Json $EvidencePath $EvidenceObject

Write-Utf8 $EvidenceMd @"
# SGD-114E v2.0.0 — Evidencia

- Prevalidado antes de entrega: Sí
- Pruebas contractuales: $($Specific.passed)/$($Specific.executed)
- Autoevaluación: $($Self.result)
- SPT-016A: $($Spt.result)
- Implementación: 2.0.0
"@

foreach ($File in @(
    $ModelsPath,
    $ValidatorPath,
    $CliPath,
    $RunnerPath,
    $HistoricalPath,
    $LogicPath,
    $CompatibilityPath,
    $TransitionalPath,
    $V2TestPath,
    $ComponentPath,
    $DocPath,
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $SelfJson,
    $SelfMd,
    $SptJson,
    $SptMd,
    $EvidencePath,
    $EvidenceMd
)) {
    Require-File $File
    Copy-Item `
        -LiteralPath $File `
        -Destination $ReleaseDir `
        -Force
}

if (-not $SkipFullSuite) {
    foreach ($File in @(
        $FullXml,
        $FullJson,
        $FullMd
    )) {
        Require-File $File
        Copy-Item `
            -LiteralPath $File `
            -Destination $ReleaseDir `
            -Force
    }
}

Write-Json `
    (Join-Path $ReleaseDir "manifest.json") `
    ([ordered]@{
        increment_code = "SGD-114E-v2.0.0"
        status = "implemented_tested_and_approved"
        files = @(
            Get-ChildItem `
                -LiteralPath $ReleaseDir `
                -File |
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
        -CommitMessage "fix(governance): implement definitive SGD-114E v2.0.0" `
        -EvidenceCommitMessage "chore(governance): publish SGD-114E v2.0.0 evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SGD-114E v2.0.0 implementado." -ForegroundColor Green
Write-Host "Definitive Native Ecosystem Validator: OPERATIVO." -ForegroundColor Green
Write-Host "empty_repository_allowed: POLÍTICA ESTABLE." -ForegroundColor Green
Write-Host "repository_is_empty: ESTADO SEPARADO." -ForegroundColor Green
Write-Host "Contratos históricos: RESTAURADOS." -ForegroundColor Green
Write-Host (
    "Pruebas contractuales: " +
    "$($Specific.passed)/$($Specific.executed) APROBADAS."
) -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host (
        "Suite completa: " +
        "$($Full.passed)/$($Full.executed) APROBADA."
    ) -ForegroundColor Green
}

Write-Host "Autoevaluación SGD-114E: APROBADA." -ForegroundColor Green
Write-Host "SPT-016A: APROBADO." -ForegroundColor Green
Write-Host "Release: releases\SGD-114E-v2.0.0" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
}
