param(
    [string]$ProjectRoot = "",
    [string]$ExpectedBaseline = "1ea0206b46f42dae287741d76ffe943a8fc46496"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$CommitMessage = "feat(spt-023.6): implement intelligent orchestrator layer 1"
$ExpectedTargetedTests = 20
$ExpectedFullSuiteMinimum = 1030
$CommitCreated = $false
$CreatedFiles = New-Object System.Collections.ArrayList
$MasterBookOriginal = $null
$MasterBookTouched = $false
$MasterBookPath = $null

function Invoke-Git {
    param([string[]]$Arguments)
    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Output = @(& git @Arguments 2>&1)
        $Code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }
    if ($Code -ne 0) {
        throw ("git " + ($Arguments -join " ") + " failed with exit code " + $Code + ": " + ($Output -join " "))
    }
    return @($Output | ForEach-Object { [string]$_ })
}

function Git-One {
    param([string[]]$Arguments)
    $Result = @(Invoke-Git -Arguments $Arguments)
    if ($Result.Count -eq 0) {
        throw ("git " + ($Arguments -join " ") + " returned no output.")
    }
    return ([string]$Result[0]).Trim()
}

function Write-Utf8Lf {
    param([string]$Path,[string]$Content,[switch]$TrackCreated)
    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    $Text = $Content.Replace("`r`n","`n").Replace("`r","`n").TrimEnd([char[]]@("`r","`n")) + "`n"
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        (New-Object System.Text.UTF8Encoding($false))
    )
    if ($TrackCreated) { [void]$CreatedFiles.Add($Path) }
}

function Get-HashMap {
    param([string]$Root,[string[]]$Paths)
    $Map = @{}
    foreach ($Rel in $Paths) {
        $Full = Join-Path $Root $Rel
        if (Test-Path -LiteralPath $Full -PathType Leaf) {
            $Map[$Rel] = (Get-FileHash -LiteralPath $Full -Algorithm SHA256).Hash
        }
    }
    return $Map
}

function Compare-HashMaps {
    param($Before,$After)
    $Changed = @()
    foreach ($Key in @($Before.Keys + $After.Keys | Sort-Object -Unique)) {
        if (-not $Before.ContainsKey($Key) -or -not $After.ContainsKey($Key) -or $Before[$Key] -ne $After[$Key]) {
            $Changed += $Key
        }
    }
    return @($Changed)
}

function Test-PowerShellSyntax {
    param([string]$Path)
    $Tokens = $null
    $Errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $Path,[ref]$Tokens,[ref]$Errors
    )
    if ($Errors.Count -ne 0) {
        throw ("PowerShell syntax validation failed: " + (($Errors | ForEach-Object { $_.Message }) -join " | "))
    }
}

function Emit-FinalBanner {
    param([string]$Commit,[int]$Targeted,[int]$FullSuite)
    Write-Output ""
    Write-Output "======================================================================"
    Write-Output " SPT-023.6 CAPA 1 : INSTITUTIONALLY CLOSED"
    Write-Output " COMMIT           : $Commit"
    Write-Output " TARGETED TESTS   : $Targeted PASSED"
    Write-Output " FULL SUITE       : $FullSuite PASSED"
    Write-Output " SPT-023.1-.5     : PRESERVED"
    Write-Output " PMO/AUDITOR      : REUSED"
    Write-Output " N8N/FASTAPI      : INTEGRATION CONTRACT READY"
    Write-Output " SGD-002          : UPDATED"
    Write-Output " LOCAL/REMOTE     : IDENTICAL"
    Write-Output " AHEAD            : 0"
    Write-Output " BEHIND           : 0"
    Write-Output " STAGING          : CLEAN"
    Write-Output " DELETED TRACKED  : 0"
    Write-Output " ERRORS PENDING   : 0"
    Write-Output " NEXT             : SPT-023.6 CAPA 2"
    Write-Output "======================================================================"
    Write-Output "FINAL_CLOSURE_EXIT_CODE=0"
}

function Rollback-PreCommit {
    if ($CommitCreated) { return }

    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & git reset -q HEAD -- 2>$null | Out-Null }
    finally { $ErrorActionPreference = $Previous }

    if ($MasterBookTouched -and $null -ne $MasterBookOriginal -and $null -ne $MasterBookPath) {
        [System.IO.File]::WriteAllText(
            $MasterBookPath,
            $MasterBookOriginal,
            (New-Object System.Text.UTF8Encoding($false))
        )
    }

    foreach ($Path in @($CreatedFiles) | Sort-Object Length -Descending) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        }
    }
}

function Fail {
    param([string]$Message)
    Rollback-PreCommit
    Write-Output ""
    Write-Output "======================================================================"
    Write-Output " SPT-023.6 CAPA 1 : HOLD"
    Write-Output (" REASON           : " + $Message)
    if ($CommitCreated) {
        Write-Output " LOCAL COMMIT     : PRESERVED FOR SAME-FILE RESUME"
    }
    else {
        Write-Output " TRANSACTION      : ROLLED BACK BEFORE COMMIT"
    }
    Write-Output " ERRORS PENDING   : 1"
    Write-Output "======================================================================"
    exit 20
}

try {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = Git-One @("rev-parse","--show-toplevel")
    }

    Set-Location $ProjectRoot
    $Root = Git-One @("rev-parse","--show-toplevel")
    $Branch = Git-One @("branch","--show-current")

    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.MyCommand.Path)
    if ([string]::IsNullOrWhiteSpace($ScriptName)) {
        throw "Unable to resolve current master script file name."
    }

    $ScriptCandidate = Join-Path $Root $ScriptName
    if (-not (Test-Path -LiteralPath $ScriptCandidate -PathType Leaf)) {
        throw "Master script file is not present in the official repository root."
    }

    Test-PowerShellSyntax -Path $ScriptCandidate
    $ScriptRel = $ScriptName.Replace("\","/")

    Write-Output ""
    Write-Output "======================================================================"
    Write-Output " SGODA-PUINAVE - SPT-023.6 CAPA 1 - MASTER TRANSACTION"
    Write-Output " INTELLIGENT ORCHESTRATOR / REUSE / PMO / AUDITOR / SGD-002 / N8N / FASTAPI"
    Write-Output "======================================================================"

    Write-Host ""
    Write-Host "[1/12] AUTHORITATIVE BASELINE / RESUME CHECK" -ForegroundColor Yellow

    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & git fetch origin $Branch --no-tags
        $FetchCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }
    if ($FetchCode -ne 0) { throw "Unable to fetch official remote." }

    $Local = Git-One @("rev-parse","HEAD")
    $Remote = Git-One @("rev-parse","origin/$Branch")

    if ($Local -ne $ExpectedBaseline) {
        $Subject = Git-One @("log","-1","--pretty=%s")
        $Parent = Git-One @("rev-parse","HEAD^")

        if ($Subject -eq $CommitMessage -and $Parent -eq $ExpectedBaseline) {
            $EvidenceResume = Join-Path $Root "artifacts\development\SPT-023.6-Capa1-v1.0.0\implementation-evidence.json"
            if (-not (Test-Path -LiteralPath $EvidenceResume -PathType Leaf)) {
                throw "Resumable Capa 1 commit detected but evidence file is missing."
            }
            $DataResume = Get-Content -LiteralPath $EvidenceResume -Raw -Encoding UTF8 | ConvertFrom-Json

            if ($Local -eq $Remote) {
                $FinalStaged = @(Invoke-Git @("diff","--cached","--name-only")).Count
                $FinalDeleted = @(Invoke-Git @("ls-files","--deleted")).Count
                if ($FinalStaged -ne 0 -or $FinalDeleted -ne 0) {
                    throw "Published Capa 1 commit exists but repository safety is not clean."
                }
                Emit-FinalBanner -Commit $Local -Targeted ([int]$DataResume.targeted_tests_passed) -FullSuite ([int]$DataResume.institutional_tests_passed)
                exit 0
            }

            if ($Remote -eq $ExpectedBaseline) {
                $CommitCreated = $true
                Write-Host "RESUME MODE : LOCAL COMMIT EXISTS; PUSH PENDING" -ForegroundColor Yellow
                & git push origin $Branch
                if ($LASTEXITCODE -ne 0) { throw "Resume push failed." }
                & git fetch origin $Branch --no-tags
                if ($LASTEXITCODE -ne 0) { throw "Resume verification fetch failed." }
                $RemoteResume = Git-One @("rev-parse","origin/$Branch")
                if ($RemoteResume -ne $Local) {
                    throw "Resume verification failed: local/remote mismatch."
                }
                Emit-FinalBanner -Commit $Local -Targeted ([int]$DataResume.targeted_tests_passed) -FullSuite ([int]$DataResume.institutional_tests_passed)
                exit 0
            }
        }

        throw "HEAD is neither certified baseline nor a resumable SPT-023.6 Capa 1 commit."
    }

    if ($Remote -ne $ExpectedBaseline) {
        throw "Official remote moved away from certified baseline."
    }

    $StagedBefore = @(Invoke-Git @("diff","--cached","--name-only"))
    $DeletedBefore = @(Invoke-Git @("ls-files","--deleted"))

    Write-Host "LOCAL HEAD      : $Local"
    Write-Host "REMOTE HEAD     : $Remote"
    Write-Host "STAGED          : $($StagedBefore.Count)"
    Write-Host "DELETED TRACKED : $($DeletedBefore.Count)"

    if ($StagedBefore.Count -ne 0) { throw "Staging is not clean." }
    if ($DeletedBefore.Count -ne 0) { throw "Tracked deletions detected." }

    $VenvPython = Join-Path $Root ".venv\Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
        throw "Project .venv Python not found."
    }

    Write-Host "BASELINE : PASS" -ForegroundColor Green
    Write-Host "POWERSHELL SYNTAX : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[2/12] REUSE CONTRACT + SHA-256 FREEZE" -ForegroundColor Yellow

    $Tracked = @(Invoke-Git @("-c","core.quotepath=false","ls-files"))
    $Protected = @(
        $Tracked | Where-Object {
            $_ -match '(?i)SPT-023\.[12345]' -or
            $_ -match '(?i)spt023[12345]' -or
            $_ -match '(?i)pmo' -or
            $_ -match '(?i)audit' -or
            $_ -match '(?i)n8n' -or
            $_ -match '(?i)fastapi'
        }
    )

    $ProtectedBefore = Get-HashMap -Root $Root -Paths $Protected
    if ($ProtectedBefore.Count -lt 1) {
        throw "Unable to establish protected SHA-256 baseline."
    }

    Write-Host "PROTECTED FILES : $($ProtectedBefore.Count)"
    Write-Host "SHA-256 FREEZE  : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[3/12] TARGET COLLISION GATE" -ForegroundColor Yellow

    $Targets = @(
        "src\sgoda\integration\spt0236\__init__.py",
        "src\sgoda\integration\spt0236\models.py",
        "src\sgoda\integration\spt0236\contracts.py",
        "src\sgoda\integration\spt0236\planner.py",
        "src\sgoda\integration\spt0236\state.py",
        "src\sgoda\integration\spt0236\service.py",
        "tests\integration\test_spt0236_orchestrator_layer1.py",
        "docs\06_Tecnologia\SPT-023.6\SGD-SPT023.6-Capa1-Orquestador-Inteligente.md",
        "config\integration\spt0236\orchestrator-policy.json",
        "artifacts\development\SPT-023.6-Capa1-v1.0.0\implementation-evidence.json"
    )

    foreach ($Rel in $Targets) {
        if (Test-Path -LiteralPath (Join-Path $Root $Rel)) {
            throw "Target already exists before fresh SPT-023.6 Capa 1 transaction: $Rel"
        }
    }

    $MasterBookPath = Join-Path $Root "docs\00_Estado_Maestro\SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    if (-not (Test-Path -LiteralPath $MasterBookPath -PathType Leaf)) {
        throw "SGD-002 master book not found."
    }

    $MasterBookOriginal = [System.IO.File]::ReadAllText($MasterBookPath)
    $Marker = "<!-- SPT-023.6-CAPA1-V1.0.0 -->"
    if ($MasterBookOriginal.Contains($Marker)) {
        throw "SGD-002 already contains SPT-023.6 Capa 1 marker while HEAD is baseline."
    }

    Write-Host "TARGET COLLISIONS : 0" -ForegroundColor Green

    Write-Host ""
    Write-Host "[4/12] IMPLEMENT SPT-023.6 CAPA 1" -ForegroundColor Yellow

    $Files = @{}
    $Files["src\sgoda\integration\spt0236\__init__.py"] = @'
"""SPT-023.6 — Orquestador Inteligente — Capa 1."""

from .contracts import PIPELINE, validate_pipeline_contract
from .planner import build_orchestration_plan
from .service import Spt0236Layer1Service
from .state import OrchestrationStateStore

__all__ = [
    "PIPELINE",
    "OrchestrationStateStore",
    "Spt0236Layer1Service",
    "build_orchestration_plan",
    "validate_pipeline_contract",
]
'@
    $Files["src\sgoda\integration\spt0236\models.py"] = @'
from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass(frozen=True)
class OrchestrationStep:
    step_id: str
    component: str
    action: str
    required_input_status: str | None
    success_status: str
    critical: bool
    metadata: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class OrchestrationPlan:
    orchestration_id: str
    lexical_id: str
    current_status: str
    steps: tuple[OrchestrationStep, ...]
    next_component: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "component": "SPT-023.6",
            "layer": "1",
            "orchestration_id": self.orchestration_id,
            "lexical_id": self.lexical_id,
            "current_status": self.current_status,
            "steps": [step.to_dict() for step in self.steps],
            "next_component": self.next_component,
        }
'@
    $Files["src\sgoda\integration\spt0236\contracts.py"] = @'
from __future__ import annotations

from .models import OrchestrationStep


PIPELINE = (
    OrchestrationStep(
        step_id="STEP-01",
        component="SPT-023.1",
        action="DETECT_NEW_WORD",
        required_input_status=None,
        success_status="WORD_DETECTED",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-02",
        component="SPT-023.2",
        action="SEMANTIC_ANALYSIS",
        required_input_status="WORD_DETECTED",
        success_status="SEMANTICALLY_VALIDATED",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-03",
        component="SPT-023.3",
        action="CATEGORY_ASSIGNMENT",
        required_input_status="SEMANTICALLY_VALIDATED",
        success_status="CATEGORY_READY",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-04",
        component="SPT-023.4",
        action="MULTIMEDIA_GENERATION",
        required_input_status="CATEGORY_READY",
        success_status="READY_FOR_FLD_ODA",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-05",
        component="SPT-023.5",
        action="BUILD_AND_PUBLISH_FLD_ODA",
        required_input_status="READY_FOR_FLD_ODA",
        success_status="PUBLISHED_FLD_ODA",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-06",
        component="PMO_DIGITAL",
        action="REGISTER_PROJECT_STATE",
        required_input_status="PUBLISHED_FLD_ODA",
        success_status="PMO_REGISTERED",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-07",
        component="AUDITOR_INSTITUCIONAL",
        action="RUN_INSTITUTIONAL_AUDIT",
        required_input_status="PMO_REGISTERED",
        success_status="AUDIT_APPROVED",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-08",
        component="SGD-002",
        action="UPDATE_MASTER_BOOK",
        required_input_status="AUDIT_APPROVED",
        success_status="MASTER_BOOK_UPDATED",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-09",
        component="N8N",
        action="COORDINATE_WORKFLOW",
        required_input_status="MASTER_BOOK_UPDATED",
        success_status="WORKFLOW_COORDINATED",
        critical=False,
        metadata={"reuse": True, "optional_runtime": True},
    ),
    OrchestrationStep(
        step_id="STEP-10",
        component="FASTAPI",
        action="EXPOSE_ORCHESTRATION_STATE",
        required_input_status="WORKFLOW_COORDINATED",
        success_status="ORCHESTRATION_EXPOSED",
        critical=False,
        metadata={"reuse": True},
    ),
)


def validate_pipeline_contract() -> None:
    if len(PIPELINE) != 10:
        raise ValueError("SPT-023.6 pipeline must define exactly ten steps.")

    ids = [step.step_id for step in PIPELINE]
    if len(set(ids)) != len(ids):
        raise ValueError("Orchestration step ids must be unique.")

    previous_status = None
    for index, step in enumerate(PIPELINE):
        if index == 0:
            if step.required_input_status is not None:
                raise ValueError("First orchestration step cannot require prior status.")
        else:
            if step.required_input_status != previous_status:
                raise ValueError(
                    f"Pipeline status chain broken at {step.step_id}: "
                    f"{step.required_input_status!r} != {previous_status!r}"
                )
        previous_status = step.success_status
'@
    $Files["src\sgoda\integration\spt0236\planner.py"] = @'
from __future__ import annotations

import hashlib
import json
from typing import Any

from .contracts import PIPELINE, validate_pipeline_contract
from .models import OrchestrationPlan


def _orchestration_id(lexical_id: str) -> str:
    digest = hashlib.sha256(
        json.dumps(
            {"lexical_id": lexical_id, "pipeline": "SPT-023.6"},
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()[:20].upper()
    return f"ORCH-{digest}"


def build_orchestration_plan(
    *,
    lexical_id: str,
    current_status: str = "NEW",
) -> OrchestrationPlan:
    validate_pipeline_contract()

    lexical_id = str(lexical_id or "").strip()
    current_status = str(current_status or "").strip() or "NEW"

    if not lexical_id:
        raise ValueError("lexical_id is required.")

    return OrchestrationPlan(
        orchestration_id=_orchestration_id(lexical_id),
        lexical_id=lexical_id,
        current_status=current_status,
        steps=PIPELINE,
        next_component="SPT-023.6-CAPA-2",
    )
'@
    $Files["src\sgoda\integration\spt0236\state.py"] = @'
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


class OrchestrationStateStore:
    """Persistencia local, atómica e idempotente del estado del orquestador."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def load(self) -> dict[str, Any]:
        if not self.path.exists():
            return {
                "schema_version": "1.0.0",
                "component": "SPT-023.6",
                "runs": {},
            }

        data = json.loads(self.path.read_text(encoding="utf-8"))
        if str(data.get("schema_version")) != "1.0.0":
            raise ValueError("Unsupported orchestration state schema_version.")
        if not isinstance(data.get("runs"), dict):
            raise ValueError("Orchestration runs must be an object.")
        return data

    def save_run(self, run: dict[str, Any]) -> dict[str, Any]:
        orchestration_id = str(run.get("orchestration_id") or "").strip()
        if not orchestration_id:
            raise ValueError("orchestration_id is required.")

        data = self.load()
        runs = dict(data["runs"])
        runs[orchestration_id] = dict(run)
        data["runs"] = runs

        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_name(self.path.name + ".tmp")
        tmp.write_text(
            json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(tmp, self.path)
        return dict(run)

    def get(self, orchestration_id: str) -> dict[str, Any] | None:
        return self.load()["runs"].get(orchestration_id)
'@
    $Files["src\sgoda\integration\spt0236\service.py"] = @'
from __future__ import annotations

from typing import Any, Callable

from .planner import build_orchestration_plan
from .state import OrchestrationStateStore


StepHandler = Callable[[dict[str, Any]], dict[str, Any]]


class Spt0236Layer1Service:
    """Orquestador institucional reutilizando componentes ya existentes."""

    def __init__(self, state_store: OrchestrationStateStore) -> None:
        self.state_store = state_store

    def create_run(
        self,
        *,
        lexical_id: str,
        current_status: str = "NEW",
    ) -> dict[str, Any]:
        plan = build_orchestration_plan(
            lexical_id=lexical_id,
            current_status=current_status,
        ).to_dict()

        run = {
            "orchestration_id": plan["orchestration_id"],
            "lexical_id": lexical_id,
            "status": current_status,
            "current_step": None,
            "completed_steps": [],
            "failed_steps": [],
            "plan": plan,
            "runtime": {
                "n8n_required": False,
                "fastapi_required": False,
                "paid_api_used": False,
            },
        }
        return self.state_store.save_run(run)

    def execute_with_handlers(
        self,
        *,
        orchestration_id: str,
        handlers: dict[str, StepHandler],
    ) -> dict[str, Any]:
        run = self.state_store.get(orchestration_id)
        if run is None:
            raise ValueError("Orchestration run not found.")

        plan = dict(run["plan"])
        completed = list(run.get("completed_steps") or [])
        failed = list(run.get("failed_steps") or [])
        status = str(run.get("status") or "NEW")

        for step in plan["steps"]:
            step_id = step["step_id"]
            if step_id in completed:
                status = step["success_status"]
                continue

            required = step["required_input_status"]
            if required is not None and status != required:
                raise ValueError(
                    f"Step {step_id} requires status {required}, got {status}."
                )

            handler = handlers.get(step["component"])
            if handler is None:
                if step.get("critical", True):
                    raise ValueError(
                        f"Missing handler for critical component {step['component']}."
                    )
                completed.append(step_id)
                status = step["success_status"]
                continue

            run["current_step"] = step_id
            self.state_store.save_run(run)

            try:
                result = handler(
                    {
                        "orchestration_id": orchestration_id,
                        "lexical_id": run["lexical_id"],
                        "status": status,
                        "step": step,
                    }
                )
            except Exception:
                failed.append(step_id)
                run["failed_steps"] = failed
                run["status"] = status
                self.state_store.save_run(run)
                raise

            if str(result.get("status") or "") != step["success_status"]:
                failed.append(step_id)
                run["failed_steps"] = failed
                run["status"] = status
                self.state_store.save_run(run)
                raise ValueError(
                    f"Handler for {step['component']} returned invalid status."
                )

            completed.append(step_id)
            status = step["success_status"]
            run["completed_steps"] = completed
            run["status"] = status
            run["current_step"] = None
            self.state_store.save_run(run)

        run["status"] = status
        run["current_step"] = None
        run["completed_steps"] = completed
        run["failed_steps"] = failed
        run["orchestration_complete"] = len(completed) == len(plan["steps"])
        run["next_component"] = (
            "SPT-023.6-CAPA-2"
            if run["orchestration_complete"]
            else "SPT-023.6-CAPA-1"
        )
        return self.state_store.save_run(run)
'@
    $Files["tests\integration\test_spt0236_orchestrator_layer1.py"] = @'
import json

import pytest

from sgoda.integration.spt0236.contracts import PIPELINE, validate_pipeline_contract
from sgoda.integration.spt0236.planner import build_orchestration_plan
from sgoda.integration.spt0236.service import Spt0236Layer1Service
from sgoda.integration.spt0236.state import OrchestrationStateStore


def handler_for(status):
    def _handler(payload):
        return {
            "status": status,
            "payload": payload,
        }
    return _handler


def handlers():
    return {
        step.component: handler_for(step.success_status)
        for step in PIPELINE
    }


def test_pipeline_contract_has_ten_steps():
    validate_pipeline_contract()
    assert len(PIPELINE) == 10


def test_pipeline_starts_with_spt0231():
    assert PIPELINE[0].component == "SPT-023.1"


def test_pipeline_includes_spt0235():
    assert any(step.component == "SPT-023.5" for step in PIPELINE)


def test_pipeline_includes_pmo_auditor_sgd002_n8n_fastapi():
    components = {step.component for step in PIPELINE}
    assert {
        "PMO_DIGITAL",
        "AUDITOR_INSTITUCIONAL",
        "SGD-002",
        "N8N",
        "FASTAPI",
    }.issubset(components)


def test_plan_requires_lexical_id():
    with pytest.raises(ValueError):
        build_orchestration_plan(lexical_id="")


def test_orchestration_id_is_deterministic():
    one = build_orchestration_plan(lexical_id="LEX-001")
    two = build_orchestration_plan(lexical_id="LEX-001")
    assert one.orchestration_id == two.orchestration_id


def test_plan_points_to_layer2():
    plan = build_orchestration_plan(lexical_id="LEX-001")
    assert plan.next_component == "SPT-023.6-CAPA-2"


def test_state_store_roundtrip(tmp_path):
    store = OrchestrationStateStore(tmp_path / "state.json")
    run = {"orchestration_id": "ORCH-1", "status": "NEW"}
    store.save_run(run)
    assert store.get("ORCH-1")["status"] == "NEW"


def test_state_file_is_valid_json(tmp_path):
    path = tmp_path / "state.json"
    store = OrchestrationStateStore(path)
    store.save_run({"orchestration_id": "ORCH-1", "status": "NEW"})
    data = json.loads(path.read_text(encoding="utf-8"))
    assert data["component"] == "SPT-023.6"


def test_service_creates_run(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    assert run["lexical_id"] == "LEX-001"
    assert run["completed_steps"] == []


def test_service_executes_full_pipeline(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    result = service.execute_with_handlers(
        orchestration_id=run["orchestration_id"],
        handlers=handlers(),
    )
    assert result["orchestration_complete"] is True
    assert len(result["completed_steps"]) == 10


def test_service_rejects_missing_critical_handler(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    mapping = handlers()
    mapping.pop("SPT-023.2")
    with pytest.raises(ValueError):
        service.execute_with_handlers(
            orchestration_id=run["orchestration_id"],
            handlers=mapping,
        )


def test_optional_n8n_can_be_skipped(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    mapping = handlers()
    mapping.pop("N8N")
    result = service.execute_with_handlers(
        orchestration_id=run["orchestration_id"],
        handlers=mapping,
    )
    assert result["orchestration_complete"] is True


def test_optional_fastapi_can_be_skipped(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    mapping = handlers()
    mapping.pop("FASTAPI")
    result = service.execute_with_handlers(
        orchestration_id=run["orchestration_id"],
        handlers=mapping,
    )
    assert result["orchestration_complete"] is True


def test_failure_is_recorded(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    mapping = handlers()

    def broken(_payload):
        raise RuntimeError("boom")

    mapping["SPT-023.3"] = broken

    with pytest.raises(RuntimeError):
        service.execute_with_handlers(
            orchestration_id=run["orchestration_id"],
            handlers=mapping,
        )

    stored = service.state_store.get(run["orchestration_id"])
    assert "STEP-03" in stored["failed_steps"]


def test_completed_steps_are_idempotent(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    first = service.execute_with_handlers(
        orchestration_id=run["orchestration_id"],
        handlers=handlers(),
    )
    second = service.execute_with_handlers(
        orchestration_id=run["orchestration_id"],
        handlers=handlers(),
    )
    assert first["completed_steps"] == second["completed_steps"]


def test_paid_api_is_disabled(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    assert run["runtime"]["paid_api_used"] is False


def test_n8n_runtime_is_not_mandatory(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    assert run["runtime"]["n8n_required"] is False


def test_fastapi_runtime_is_not_mandatory(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    assert run["runtime"]["fastapi_required"] is False


def test_final_status_is_orchestration_exposed(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    result = service.execute_with_handlers(
        orchestration_id=run["orchestration_id"],
        handlers=handlers(),
    )
    assert result["status"] == "ORCHESTRATION_EXPOSED"
'@
    $Files["docs\06_Tecnologia\SPT-023.6\SGD-SPT023.6-Capa1-Orquestador-Inteligente.md"] = @'
# SPT-023.6 — Orquestador Inteligente — Capa 1

## Objetivo

Iniciar SPT-023.6 integrando y coordinando los componentes cerrados de
SPT-023.1 a SPT-023.5 con PMO Digital, Auditor Institucional, SGD-002, n8n y
FastAPI, sin reabrir ni duplicar la lógica ya implementada.

## Cadena institucional

La Capa 1 define un contrato secuencial de diez pasos:

1. SPT-023.1 — detección de palabra;
2. SPT-023.2 — análisis semántico;
3. SPT-023.3 — clasificación/categorías;
4. SPT-023.4 — multimedia;
5. SPT-023.5 — FLD/ODA;
6. PMO Digital — registro del estado;
7. Auditor Institucional — auditoría;
8. SGD-002 — actualización del Libro Maestro;
9. n8n — coordinación de workflow;
10. FastAPI — exposición del estado de orquestación.

## Principios

- todos los componentes previos se reutilizan;
- los pasos críticos requieren handler válido;
- n8n y FastAPI no son obligatorios para el motor de pruebas de Capa 1;
- el estado se persiste localmente en JSON atómico;
- la ejecución es reanudable e idempotente;
- no se utilizan APIs de pago.

## Siguiente desarrollo

SPT-023.6 Capa 2 deberá integrar adaptadores reales con FastAPI, n8n y los
servicios institucionales existentes, manteniendo desacoplamiento y pruebas
locales.
'@
    $Files["config\integration\spt0236\orchestrator-policy.json"] = @'
{
  "schema_version": "1.0.0",
  "component": "SPT-023.6",
  "layer": "1",
  "pipeline_steps": 10,
  "components": [
    "SPT-023.1",
    "SPT-023.2",
    "SPT-023.3",
    "SPT-023.4",
    "SPT-023.5",
    "PMO_DIGITAL",
    "AUDITOR_INSTITUCIONAL",
    "SGD-002",
    "N8N",
    "FASTAPI"
  ],
  "reuse_existing_components": true,
  "state_storage": "LOCAL_JSON_ATOMIC",
  "idempotent": true,
  "resume_supported": true,
  "n8n_runtime_required_for_layer1_tests": false,
  "fastapi_runtime_required_for_layer1_tests": false,
  "paid_api_allowed": false,
  "next_component": "SPT-023.6-CAPA-2"
}
'@

    foreach ($Rel in $Files.Keys) {
        $Full = Join-Path $Root $Rel
        Write-Utf8Lf -Path $Full -Content $Files[$Rel] -TrackCreated
        Write-Host ("CREATED : " + $Rel)
    }

    Write-Host ""
    Write-Host "[5/12] PYTHON PREVALIDATION + TARGETED TESTS" -ForegroundColor Yellow

    $env:PYTHONPATH = Join-Path $Root "src"

    $PyFiles = @(
        "src\sgoda\integration\spt0236\__init__.py",
        "src\sgoda\integration\spt0236\models.py",
        "src\sgoda\integration\spt0236\contracts.py",
        "src\sgoda\integration\spt0236\planner.py",
        "src\sgoda\integration\spt0236\state.py",
        "src\sgoda\integration\spt0236\service.py",
        "tests\integration\test_spt0236_orchestrator_layer1.py"
    ) | ForEach-Object { Join-Path $Root $_ }

    & $VenvPython -m py_compile @PyFiles
    if ($LASTEXITCODE -ne 0) {
        throw "Python syntax prevalidation failed."
    }

    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $TargetOutput = @(
            & $VenvPython -m pytest `
                "tests/integration/test_spt0236_orchestrator_layer1.py" `
                -q 2>&1
        )
        $TargetCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }

    $TargetOutput | ForEach-Object { Write-Host $_ }
    if ($TargetCode -ne 0) {
        throw "Targeted SPT-023.6 Capa 1 tests failed."
    }

    $TargetText = ($TargetOutput | ForEach-Object { [string]$_ }) -join "`n"
    $TargetMatch = [regex]::Match($TargetText, '(\d+)\s+passed')
    if (-not $TargetMatch.Success) {
        throw "Unable to certify targeted test count."
    }

    $TargetPassed = [int]$TargetMatch.Groups[1].Value
    if ($TargetPassed -lt $ExpectedTargetedTests) {
        throw "Targeted test count below expected $ExpectedTargetedTests."
    }

    Write-Host "TARGETED TESTS : $TargetPassed PASSED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[6/12] INSTITUTIONAL SUITE + COMPILEALL" -ForegroundColor Yellow

    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $SuiteOutput = @(& $VenvPython -m pytest -q 2>&1)
        $SuiteCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }

    $SuiteOutput | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }
    if ($SuiteCode -ne 0) {
        throw "Institutional pytest suite failed."
    }

    $SuiteText = ($SuiteOutput | ForEach-Object { [string]$_ }) -join "`n"
    $SuiteMatch = [regex]::Match($SuiteText, '(\d+)\s+passed')
    if (-not $SuiteMatch.Success) {
        throw "Unable to certify institutional test count."
    }

    $SuitePassed = [int]$SuiteMatch.Groups[1].Value
    if ($SuitePassed -lt $ExpectedFullSuiteMinimum) {
        throw "Institutional suite below expected minimum $ExpectedFullSuiteMinimum."
    }

    & $VenvPython -m compileall -q src
    if ($LASTEXITCODE -ne 0) {
        throw "Python compileall failed."
    }

    Write-Host "FULL SUITE : $SuitePassed PASSED" -ForegroundColor Green
    Write-Host "COMPILEALL : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[7/12] SHA-256 PRESERVATION GATE" -ForegroundColor Yellow

    $ProtectedAfter = Get-HashMap -Root $Root -Paths $Protected
    $ChangedProtected = @(Compare-HashMaps -Before $ProtectedBefore -After $ProtectedAfter)

    Write-Host "PROTECTED FILES CHANGED : $($ChangedProtected.Count)"
    if ($ChangedProtected.Count -ne 0) {
        throw ("Closed/reused component SHA-256 changed: " + ($ChangedProtected -join ", "))
    }

    Write-Host "CLOSED + REUSED COMPONENTS : PRESERVED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[8/12] EVIDENCE + SGD-002 UPDATE" -ForegroundColor Yellow

    $EvidencePath = Join-Path $Root "artifacts\development\SPT-023.6-Capa1-v1.0.0\implementation-evidence.json"
    $EvidenceDir = Split-Path -Parent $EvidencePath
    if (-not (Test-Path -LiteralPath $EvidenceDir)) {
        New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
    }

    $Generated = @()
    foreach ($Rel in $Files.Keys | Sort-Object) {
        $Full = Join-Path $Root $Rel
        $Generated += [ordered]@{
            path = $Rel.Replace("\","/")
            sha256 = (Get-FileHash -LiteralPath $Full -Algorithm SHA256).Hash
        }
    }

    $Evidence = [ordered]@{
        schema_version = "1.0.0"
        component = "SPT-023.6"
        layer = "1"
        title = "Orquestador Inteligente"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        certified_baseline = $ExpectedBaseline
        targeted_tests_passed = $TargetPassed
        institutional_tests_passed = $SuitePassed
        protected_files = $ProtectedBefore.Count
        protected_files_changed = $ChangedProtected.Count
        pipeline_steps = 10
        integrates_spt0231_to_spt0235 = $true
        integrates_pmo = $true
        integrates_auditor = $true
        integrates_sgd002 = $true
        n8n_contract = $true
        fastapi_contract = $true
        idempotent = $true
        resume_supported = $true
        paid_api_allowed = $false
        next_component = "SPT-023.6-CAPA-2"
        generated_files = $Generated
    }

    Write-Utf8Lf -Path $EvidencePath -Content ($Evidence | ConvertTo-Json -Depth 8) -TrackCreated

    $MasterAppend = @"

$Marker
## SPT-023.6 — Orquestador Inteligente — Capa 1

- Estado institucional: CLOSED.
- Línea base de entrada: `$ExpectedBaseline`.
- Pruebas específicas: `$TargetPassed` aprobadas.
- Suite institucional: `$SuitePassed` aprobadas.
- SPT-023.1 a SPT-023.5: integrados por contrato y preservados.
- PMO Digital: integrado por contrato.
- Auditor Institucional: integrado por contrato.
- SGD-002: integrado como paso institucional.
- n8n: contrato de coordinación habilitado; runtime no obligatorio para pruebas Capa 1.
- FastAPI: contrato de exposición habilitado; runtime no obligatorio para pruebas Capa 1.
- Estado de orquestación: persistencia local JSON atómica.
- Reanudación e idempotencia: implementadas.
- APIs de pago: deshabilitadas.
- Siguiente desarrollo: SPT-023.6 Capa 2 — adaptadores reales FastAPI/n8n/servicios institucionales.
"@

    $UpdatedMaster = $MasterBookOriginal.TrimEnd([char[]]@("`r","`n")) + "`n" + $MasterAppend.Replace("`r`n","`n").Replace("`r","`n").TrimStart([char[]]@("`r","`n"))

    [System.IO.File]::WriteAllText(
        $MasterBookPath,
        $UpdatedMaster,
        (New-Object System.Text.UTF8Encoding($false))
    )
    $MasterBookTouched = $true

    Write-Host "EVIDENCE : CREATED" -ForegroundColor Green
    Write-Host "SGD-002  : UPDATED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[9/12] EXACT CONTROLLED STAGING" -ForegroundColor Yellow

    $Allowed = @(
        $Files.Keys | ForEach-Object { $_.Replace("\","/") }
    )
    $Allowed += "artifacts/development/SPT-023.6-Capa1-v1.0.0/implementation-evidence.json"
    $Allowed += "docs/00_Estado_Maestro/SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    $Allowed += $ScriptRel
    $Allowed = @($Allowed | Sort-Object -Unique)

    & git reset -q HEAD --
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to guarantee clean index."
    }

    & git -c core.safecrlf=false add -- @Allowed
    if ($LASTEXITCODE -ne 0) {
        throw "Controlled staging failed."
    }

    $Actual = @(
        Invoke-Git @("-c","core.quotepath=false","diff","--cached","--name-only") |
        ForEach-Object { $_.Replace("\","/") } |
        Sort-Object -Unique
    )

    $Missing = @($Allowed | Where-Object { $Actual -notcontains $_ })
    $Unexpected = @($Actual | Where-Object { $Allowed -notcontains $_ })

    Write-Host "STAGED     : $($Actual.Count)"
    Write-Host "MISSING    : $($Missing.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if ($Missing.Count -ne 0 -or $Unexpected.Count -ne 0) {
        throw "Exact staging manifest mismatch."
    }

    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) {
        throw "git diff --cached --check failed."
    }

    Write-Host "STAGING QUALITY : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[10/12] FINAL REMOTE GATE" -ForegroundColor Yellow

    & git fetch origin $Branch --no-tags
    if ($LASTEXITCODE -ne 0) {
        throw "Final fetch failed."
    }

    $HeadBeforeCommit = Git-One @("rev-parse","HEAD")
    $RemoteBeforeCommit = Git-One @("rev-parse","origin/$Branch")

    if ($HeadBeforeCommit -ne $ExpectedBaseline -or $RemoteBeforeCommit -ne $ExpectedBaseline) {
        throw "Repository moved during SPT-023.6 Capa 1 transaction."
    }

    Write-Host "REMOTE GATE : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[11/12] COMMIT + PUSH" -ForegroundColor Yellow

    & git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) {
        throw "Commit failed."
    }

    $CommitCreated = $true
    $NewHead = Git-One @("rev-parse","HEAD")
    Write-Host "NEW COMMIT : $NewHead"

    & git push origin $Branch
    if ($LASTEXITCODE -ne 0) {
        throw "Push failed. Re-run this SAME file to resume."
    }

    Write-Host ""
    Write-Host "[12/12] AUTHORITATIVE REMOTE VERIFICATION" -ForegroundColor Yellow

    & git fetch origin $Branch --no-tags
    if ($LASTEXITCODE -ne 0) {
        throw "Verification fetch failed. Re-run this SAME file."
    }

    $LocalFinal = Git-One @("rev-parse","HEAD")
    $RemoteFinal = Git-One @("rev-parse","origin/$Branch")
    $AheadFinal = @(Invoke-Git @("rev-list","origin/$Branch..HEAD")).Count
    $BehindFinal = @(Invoke-Git @("rev-list","HEAD..origin/$Branch")).Count
    $StagedFinal = @(Invoke-Git @("diff","--cached","--name-only")).Count
    $DeletedFinal = @(Invoke-Git @("ls-files","--deleted")).Count

    Write-Host "LOCAL HEAD      : $LocalFinal"
    Write-Host "REMOTE HEAD     : $RemoteFinal"
    Write-Host "AHEAD           : $AheadFinal"
    Write-Host "BEHIND          : $BehindFinal"
    Write-Host "STAGED          : $StagedFinal"
    Write-Host "DELETED TRACKED : $DeletedFinal"

    if ($LocalFinal -ne $RemoteFinal) { throw "Local/remote mismatch after publication." }
    if ($AheadFinal -ne 0 -or $BehindFinal -ne 0) { throw "Repository divergence after publication." }
    if ($StagedFinal -ne 0) { throw "Staging is not clean after publication." }
    if ($DeletedFinal -ne 0) { throw "Tracked deletions detected after publication." }

    Emit-FinalBanner -Commit $LocalFinal -Targeted $TargetPassed -FullSuite $SuitePassed
    exit 0
}
catch {
    Fail $_.Exception.Message
}
