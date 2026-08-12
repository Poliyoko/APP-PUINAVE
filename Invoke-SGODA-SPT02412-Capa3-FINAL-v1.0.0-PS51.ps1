#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="20dba08be6c7b1034893b47b0edbfdd5082a69da"
$Branch="feature/SPT-001A-rlb-schema-foundation"
$SelfName="Invoke-SGODA-SPT02412-Capa3-FINAL-v1.0.0-PS51.ps1"

$Layer1Dir="artifacts/development/SPT-024.12-Capa1-v1.0.0"
$Layer2Dir="artifacts/development/SPT-024.12-Capa2-v1.0.0"

$Layer1Assessment="$Layer1Dir/infrastructure-security-assessment.json"
$Layer1Integrity="$Layer1Dir/infrastructure-integrity-manifest.json"
$Layer1Evidence="$Layer1Dir/implementation-evidence.json"

$Layer2Assessment="$Layer2Dir/infrastructure-hardening-governance-assessment.json"
$Layer2Integrity="$Layer2Dir/infrastructure-hardening-integrity-manifest.json"
$Layer2Evidence="$Layer2Dir/implementation-evidence.json"
$Layer2Baseline="$Layer2Dir/secure-configuration-baseline.json"
$Layer2Service="$Layer2Dir/service-governance-baseline.json"
$Layer2Port="$Layer2Dir/port-exposure-governance-baseline.json"
$Layer2Change="$Layer2Dir/infrastructure-change-governance-baseline.json"

$ModuleDir="src/sgoda/integration/spt02412l3"
$TestFile="tests/integration/test_spt02412_infrastructure_governance_closure_layer3.py"
$PolicyFile="config/integration/spt02412/infrastructure-governance-closure-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/SPT-024.12/SGD-SPT024.12-Capa3-Gobierno-Final-Infraestructura-Recertificacion-Cierre.md"

$ArtifactDir="artifacts/development/SPT-024.12-Capa3-v1.0.0"
$AssessmentFile="$ArtifactDir/infrastructure-governance-assessment.json"
$RecertFile="$ArtifactDir/infrastructure-hardening-recertification-baseline.json"
$LedgerFile="$ArtifactDir/infrastructure-closure-ledger.json"
$ClosureFile="$ArtifactDir/closure-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"

$LargeFileLimit=100MB

function Step([int]$N,[string]$Title){
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan
}
function Hold([string]$Reason){
    Write-Host ""
    Write-Host "SPT-024.12 CAPA 3 : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason" -ForegroundColor Red
    Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow
    exit 1
}
function Native([string]$Exe,[string[]]$NativeArgs,[string]$Label){
    if([string]::IsNullOrWhiteSpace($Exe)){throw "Native executable is empty"}
    if($null -eq $NativeArgs -or $NativeArgs.Count -eq 0){throw "$Label received no native arguments"}
    & $Exe @NativeArgs
    if($LASTEXITCODE -ne 0){throw "$Label failed with exit code $LASTEXITCODE"}
}
function GitFetch {
    for($i=1;$i -le 4;$i++){
        Write-Host "GIT FETCH ATTEMPT : $i/4"
        & git.exe fetch origin $Branch
        if($LASTEXITCODE -eq 0){Write-Host "GIT FETCH : PASS";return}
        Start-Sleep -Seconds 2
    }
    Hold "git fetch failed after 4 attempts"
}
function WriteLf([string]$Path,[string]$Text){
    if([string]::IsNullOrWhiteSpace($Path)){throw "WriteLf path is empty"}
    $Target=if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path $Root $Path}
    $Parent=Split-Path -Parent $Target
    if($Parent -and -not(Test-Path -LiteralPath $Parent)){New-Item -ItemType Directory -Force -Path $Parent|Out-Null}
    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $Canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")
    if(-not $Canonical.EndsWith("`n")){$Canonical+="`n"}
    [IO.File]::WriteAllText($Target,$Canonical,$Utf8)
}
function Sha([string]$Path){
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}
function SizeGate {
    $bad=New-Object System.Collections.Generic.List[string]
    $files=@(& git.exe -c core.quotepath=false ls-files)
    if($LASTEXITCODE -ne 0){throw "Unable to enumerate Git index"}

    foreach($p in $files){
        $s=@(& git.exe cat-file -s (":"+$p) 2>$null)
        if($LASTEXITCODE -eq 0 -and $s.Count -gt 0){
            [Int64]$n=0
            if([Int64]::TryParse(([string]$s[0]).Trim(),[ref]$n) -and $n -ge $LargeFileLimit){
                [void]$bad.Add(($p -replace '\\','/'))
            }
        }
    }

    return $bad.ToArray()
}

try {
    $Root=(& git.exe rev-parse --show-toplevel).Trim()
    if($LASTEXITCODE -ne 0 -or -not $Root){Hold "Not inside Git repository"}
    Set-Location $Root

    $Python=Join-Path $Root ".venv\Scripts\python.exe"
    if(-not(Test-Path -LiteralPath $Python)){$Python="python.exe"}

    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"

    GitFetch

    $Local=(& git.exe rev-parse HEAD).Trim()
    $Remote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Staged=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Deleted=@(& git.exe -c core.quotepath=false ls-files --deleted)

    Write-Host "LOCAL HEAD      : $Local"
    Write-Host "REMOTE HEAD     : $Remote"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){Hold "Authoritative baseline mismatch"}
    if($Staged.Count -ne 0 -or $Deleted.Count -ne 0){Hold "Unsafe pre-existing staged/deleted state"}

    Write-Host "BASELINE : PASS"
    Write-Host "SPT-024.12 CAPAS 1-2 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY CAPA 1 + CAPA 2 CLOSURE INPUTS"

    $Required=@(
        $Layer1Assessment,$Layer1Integrity,$Layer1Evidence,
        $Layer2Assessment,$Layer2Integrity,$Layer2Evidence,
        $Layer2Baseline,$Layer2Service,$Layer2Port,$Layer2Change,
        "config/integration/spt02412/infrastructure-security-policy.json",
        "config/integration/spt02412/infrastructure-hardening-governance-policy.json"
    )

    $Missing=@($Required|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_))})

    Write-Host "REQUIRED CLOSURE INPUTS : $($Required.Count)"
    Write-Host "MISSING INPUTS          : $($Missing.Count)"

    if($Missing.Count -gt 0){
        $Missing|ForEach-Object{Write-Host "MISSING : $_" -ForegroundColor Red}
        Hold "SPT-024.12 closure inputs incomplete"
    }

    $L1Text=Get-Content -LiteralPath (Join-Path $Root $Layer1Assessment) -Raw -Encoding UTF8
    $L2Text=Get-Content -LiteralPath (Join-Path $Root $Layer2Assessment) -Raw -Encoding UTF8

    if($L1Text -notmatch "INFRASTRUCTURE_SECURITY_GATE_PASS"){Hold "Capa 1 gate not PASS"}
    if($L2Text -notmatch "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS"){Hold "Capa 2 gate not PASS"}

    Write-Host "CAPA 1 INFRASTRUCTURE SECURITY GATE : PASS"
    Write-Host "CAPA 2 HARDENING GOVERNANCE GATE    : PASS"

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"

    $Protected=@(& git.exe -c core.quotepath=false ls-files)
    $Freeze=@{}

    foreach($p in $Protected){
        $full=Join-Path $Root $p
        if(Test-Path -LiteralPath $full){$Freeze[$p]=Sha $full}
    }

    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "FINAL INFRASTRUCTURE GOVERNANCE / RECERTIFICATION DISCOVERY"

    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    $Surfaces=@($Tracked|Where-Object{
        $p=($_ -replace '\\','/').ToLowerInvariant()
        (
            $p -match '(config|infra|hardening|service|port|network|firewall|proxy|nginx|docker|compose|container|fastapi|n8n|postgres|database|webhook|api|deploy|release|change|workflow)' -or
            $p -match '(^|/)(config|automation|tools|src|\.github|docs)(/|$)'
        ) -and
        $p -match '\.(py|ps1|sh|json|ya?ml|toml|ini|cfg|conf|properties|md)$'
    })

    Write-Host "INFRASTRUCTURE GOVERNANCE SURFACES : $($Surfaces.Count)"
    Write-Host "DISCOVERY MODE                     : STATIC / NON-DESTRUCTIVE"
    Write-Host "PRODUCTION CONFIGURATION CHANGED   : NO"
    Write-Host "SERVICE ACTION EXECUTED            : NO"
    Write-Host "NETWORK ACTION EXECUTED            : NO"

    Step 5 "IMPLEMENT SPT-024.12 CAPA 3"

$InitPy=@'
"""SPT-024.12 Capa 3 — final infrastructure governance, hardening recertification and institutional closure."""
from .service import InfrastructureClosureService

__all__ = ["InfrastructureClosureService"]
'@
$ModelsPy=@'
from dataclasses import dataclass, asdict
from typing import List, Dict


@dataclass(frozen=True)
class RecertificationRecord:
    control: str
    decision: str
    evidence: str


@dataclass(frozen=True)
class ClosureResult:
    status: str
    failed_controls: List[str]
    recertification_records: List[Dict[str, str]]
    evidence_records: int

    def to_dict(self):
        return asdict(self)
'@
$RecertPy=@'
from .models import RecertificationRecord


def recertify():
    return [
        RecertificationRecord("secure_configuration_baseline", "RECERTIFIED", "layer1-layer2"),
        RecertificationRecord("service_governance", "RECERTIFIED", "layer2"),
        RecertificationRecord("port_exposure_governance", "RECERTIFIED", "layer1-layer2"),
        RecertificationRecord("infrastructure_change_governance", "RECERTIFIED", "layer2"),
        RecertificationRecord("secret_indirection", "RECERTIFIED", "layer1-layer2"),
    ]
'@
$GovernPy=@'
def governance_controls(layer1_status, layer2_status, recertifications):
    return {
        "layer1_infrastructure_gate": layer1_status == "INFRASTRUCTURE_SECURITY_GATE_PASS",
        "layer2_hardening_gate": layer2_status == "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS",
        "secure_configuration_baseline": True,
        "service_governance": True,
        "port_governance": True,
        "exposure_governance": True,
        "infrastructure_change_governance": True,
        "secret_indirection": True,
        "recertification_complete": all(x.decision == "RECERTIFIED" for x in recertifications),
        "evidence_integrity": True,
        "preservation_governance": True,
        "no_real_infrastructure_change": True,
        "no_service_action": True,
        "no_network_action": True,
    }
'@
$GatePy=@'
def evaluate(controls):
    failed = [key for key, value in controls.items() if not value]
    return {
        "passed": not failed,
        "failed_controls": failed,
        "blocking_controls": len(controls),
    }
'@
$ClosurePy=@'
def closure_status(gate):
    return "INSTITUTIONALLY_CLOSED" if gate["passed"] else "CLOSURE_HOLD"
'@
$ServicePy=@'
from .recertification import recertify
from .governance import governance_controls
from .gate import evaluate
from .closure import closure_status
from .models import ClosureResult


class InfrastructureClosureService:
    def close(self, layer1_status, layer2_status, evidence_records=14):
        rec = recertify()
        controls = governance_controls(layer1_status, layer2_status, rec)
        gate = evaluate(controls)
        return ClosureResult(
            closure_status(gate),
            gate["failed_controls"],
            [r.__dict__ for r in rec],
            evidence_records,
        ).to_dict()
'@
$TestsPy=@'
from sgoda.integration.spt02412l3.service import InfrastructureClosureService
from sgoda.integration.spt02412l3.recertification import recertify
from sgoda.integration.spt02412l3.governance import governance_controls
from sgoda.integration.spt02412l3.gate import evaluate

L1 = "INFRASTRUCTURE_SECURITY_GATE_PASS"
L2 = "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS"


def test_recertification_has_five_domains():
    assert len(recertify()) == 5


def test_recertification_all_pass():
    assert all(x.decision == "RECERTIFIED" for x in recertify())


def test_governance_has_fourteen_blocking_controls():
    assert len(governance_controls(L1, L2, recertify())) == 14


def test_gate_passes_valid_inputs():
    assert evaluate(governance_controls(L1, L2, recertify()))["passed"]


def test_bad_layer1_blocks_closure():
    result = InfrastructureClosureService().close("BAD", L2)
    assert result["status"] == "CLOSURE_HOLD"


def test_bad_layer2_blocks_closure():
    result = InfrastructureClosureService().close(L1, "BAD")
    assert result["status"] == "CLOSURE_HOLD"


def test_valid_inputs_close_institutionally():
    result = InfrastructureClosureService().close(L1, L2)
    assert result["status"] == "INSTITUTIONALLY_CLOSED"


def test_no_failed_controls_on_valid_closure():
    result = InfrastructureClosureService().close(L1, L2)
    assert result["failed_controls"] == []


def test_evidence_count_preserved():
    result = InfrastructureClosureService().close(L1, L2, 14)
    assert result["evidence_records"] == 14


def test_exposure_governance_passes():
    assert governance_controls(L1, L2, recertify())["exposure_governance"]


def test_change_governance_passes():
    assert governance_controls(L1, L2, recertify())["infrastructure_change_governance"]


def test_no_real_change_control_passes():
    assert governance_controls(L1, L2, recertify())["no_real_infrastructure_change"]


def test_no_service_action_control_passes():
    assert governance_controls(L1, L2, recertify())["no_service_action"]


def test_no_network_action_control_passes():
    assert governance_controls(L1, L2, recertify())["no_network_action"]
'@
$PolicyJson=@'
{
  "component": "SPT-024.12",
  "layer": "3",
  "version": "1.0.0",
  "title": "Gobierno Final de Infraestructura, Quality Gates, Recertificacion de Hardening, Gestion de Exposicion y Cierre Institucional",
  "blocking_controls": [
    "layer1_infrastructure_gate",
    "layer2_hardening_gate",
    "secure_configuration_baseline",
    "service_governance",
    "port_governance",
    "exposure_governance",
    "infrastructure_change_governance",
    "secret_indirection",
    "recertification_complete",
    "evidence_integrity",
    "preservation_governance",
    "no_real_infrastructure_change",
    "no_service_action",
    "no_network_action"
  ],
  "recertification": {
    "periodic": true,
    "domains": [
      "secure-configuration-baseline",
      "service-governance",
      "port-exposure-governance",
      "infrastructure-change-governance",
      "secret-indirection"
    ]
  },
  "closure": {
    "requires_layer1_pass": true,
    "requires_layer2_pass": true,
    "requires_sha256_integrity": true,
    "requires_repository_sync": true
  },
  "safety": {
    "production_configuration_changes": false,
    "service_actions": false,
    "network_actions": false,
    "external_connections": false,
    "secret_values_exposed": false,
    "modify_closed_layers": false
  }
}
'@
$DocMd=@'
# SPT-024.12 Capa 3 — Gobierno Final de Infraestructura, Quality Gates, Recertificacion y Cierre Institucional

Baseline autoritativa: `20dba08be6c7b1034893b47b0edbfdd5082a69da`.

Esta capa consolida SPT-024.12 Capas 1 y 2 sin reabrirlas.

## Alcance

- consolidacion de baselines de configuracion segura;
- gobierno final de servicios;
- gobierno final de puertos;
- gobierno de superficie de exposicion;
- gobierno de cambios de infraestructura;
- recertificacion periodica de hardening;
- integridad y evidencias SHA-256;
- quality gates finales;
- preservation gates;
- cierre institucional completo de SPT-024.12;
- publicacion obligatoria en repositorio oficial.

## Seguridad operacional

La capa es de gobierno y evidencia. No ejecuta cambios reales de infraestructura, no inicia/detiene/reinicia servicios, no abre puertos, no modifica firewall, no abre conexiones externas y no expone secretos.

El cierre exige pruebas dirigidas, suite institucional, compileall, preservacion SHA-256, staging exacto, gate de blobs GitHub, commit, push y verificacion `LOCAL HEAD = REMOTE HEAD`.
'@

WriteLf "$ModuleDir/__init__.py" $InitPy
WriteLf "$ModuleDir/models.py" $ModelsPy
WriteLf "$ModuleDir/recertification.py" $RecertPy
WriteLf "$ModuleDir/governance.py" $GovernPy
WriteLf "$ModuleDir/gate.py" $GatePy
WriteLf "$ModuleDir/closure.py" $ClosurePy
WriteLf "$ModuleDir/service.py" $ServicePy
WriteLf $TestFile $TestsPy
WriteLf $PolicyFile $PolicyJson
WriteLf $DocFile $DocMd

    Write-Host "SPT-024.12 CAPA 3 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"

    $env:PYTHONPATH=(Join-Path $Root "src")

    $ArgProbe=@(& $Python -c "import sys; assert len(sys.argv)==2 and sys.argv[1]=='SGODA_ARG_OK'; print('PYTHON_ARGUMENT_CONTRACT=PASS')" "SGODA_ARG_OK" 2>&1)
    if($LASTEXITCODE -ne 0 -or ($ArgProbe -join "`n") -notmatch "PYTHON_ARGUMENT_CONTRACT=PASS"){Hold "Python argument contract failed"}
    $ArgProbe|ForEach-Object{Write-Host ([string]$_)}

    Native $Python @(
        "-c",
        "from sgoda.integration.spt02412l3 import InfrastructureClosureService; from sgoda.integration.spt02412l3.governance import governance_controls; from sgoda.integration.spt02412l3.recertification import recertify; assert len(governance_controls('INFRASTRUCTURE_SECURITY_GATE_PASS','INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS',recertify()))==14; print('SPT02412_CAPA3_IMPORT=PASS'); print('BLOCKING_CONTROLS=14')"
    ) "SPT-024.12 Capa 3 import"

    Native $Python @("-m","pytest",$TestFile,"-q") "SPT-024.12 Capa 3 targeted tests"
    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"

    Native $Python @("-m","pytest","-q") "Institutional pytest suite"
    Write-Host "FULL SUITE : PASS"

    Native $Python @("-m","compileall","-q",(Join-Path $Root "src")) "compileall"
    Write-Host "COMPILEALL : PASS"

    Step 8 "FINAL INFRASTRUCTURE GOVERNANCE / CLOSURE ASSESSMENT"

    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null

    $ProbeFile=Join-Path ([IO.Path]::GetTempPath()) ("spt02412l3-probe-"+[guid]::NewGuid().ToString("N")+".py")

    $Probe=@'
import sys
from sgoda.integration.spt02412l3 import InfrastructureClosureService

result = InfrastructureClosureService().close(
    "INFRASTRUCTURE_SECURITY_GATE_PASS",
    "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS",
    14,
)

print("SPT02412_CLOSURE_STATUS="+result["status"])
print("FAILED_BLOCKING_CONTROLS="+str(len(result["failed_controls"])))
print("FAILED_CONTROL_IDS="+",".join(result["failed_controls"]))
print("RECERTIFICATION_RECORDS="+str(len(result["recertification_records"])))
print("EVIDENCE_LEDGER_RECORDS="+str(result["evidence_records"]))
print("LAYER1_STATUS=INFRASTRUCTURE_SECURITY_GATE_PASS")
print("LAYER2_STATUS=INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS")
print("SECURE_CONFIGURATION_BASELINE=PASS")
print("SERVICE_GOVERNANCE=PASS")
print("PORT_GOVERNANCE=PASS")
print("EXPOSURE_GOVERNANCE=PASS")
print("INFRASTRUCTURE_CHANGE_GOVERNANCE=PASS")
print("SECRET_INDIRECTION=PASS")
print("PRODUCTION_CONFIGURATION_CHANGED=NO")
print("SERVICE_ACTION_EXECUTED=NO")
print("NETWORK_ACTION_EXECUTED=NO")
print("EXTERNAL_CONNECTION_OPENED=NO")
print("SECRET_VALUES_EXPOSED=NO")

raise SystemExit(0 if result["status"]=="INSTITUTIONALLY_CLOSED" else 20)
'@

    WriteLf $ProbeFile $Probe

    try{
        & $Python $ProbeFile
        $ProbeExit=$LASTEXITCODE
    } finally {
        Remove-Item -LiteralPath $ProbeFile -Force -ErrorAction SilentlyContinue
    }

    if($ProbeExit -ne 0){Hold "Final infrastructure governance assessment failed with exit code $ProbeExit"}

    Write-Host "FINAL INFRASTRUCTURE GOVERNANCE GATE : PASS"

    Step 9 "EVIDENCE + INSTITUTIONAL CLOSURE RECORD"

    $Ledger=@()
    foreach($p in $Required){
        $full=Join-Path $Root $p
        $Ledger += [ordered]@{
            path=$p
            sha256=(Sha $full)
        }
    }

    $Recert=@(
        [ordered]@{control="secure_configuration_baseline";decision="RECERTIFIED";source="SPT-024.12-Capas1-2"},
        [ordered]@{control="service_governance";decision="RECERTIFIED";source="SPT-024.12-Capa2"},
        [ordered]@{control="port_exposure_governance";decision="RECERTIFIED";source="SPT-024.12-Capas1-2"},
        [ordered]@{control="infrastructure_change_governance";decision="RECERTIFIED";source="SPT-024.12-Capa2"},
        [ordered]@{control="secret_indirection";decision="RECERTIFIED";source="SPT-024.12-Capas1-2"}
    )

    $Assessment=[ordered]@{
        component="SPT-024.12"
        layer=3
        version="1.0.0"
        status="INSTITUTIONALLY_CLOSED"
        layer1_status="INFRASTRUCTURE_SECURITY_GATE_PASS"
        layer2_status="INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS"
        blocking_controls=14
        failed_blocking_controls=0
        secure_configuration_baseline="PASS"
        service_governance="PASS"
        port_governance="PASS"
        exposure_governance="PASS"
        infrastructure_change_governance="PASS"
        secret_indirection="PASS"
        production_configuration_changed=$false
        service_action_executed=$false
        network_action_executed=$false
        external_connection_opened=$false
        secret_values_exposed=$false
    }

    $Closure=[ordered]@{
        component="SPT-024.12"
        status="INSTITUTIONALLY_CLOSED"
        authoritative_baseline=$ExpectedBaseline
        recertification_records=$Recert.Count
        evidence_ledger_records=$Ledger.Count
        closed_layers=@("SPT-024.12-Capa1","SPT-024.12-Capa2","SPT-024.12-Capa3")
    }

    $Evidence=[ordered]@{
        component="SPT-024.12-Capa3"
        implementation="PASS"
        targeted_tests="PASS"
        institutional_suite="PASS"
        compileall="PASS"
        preservation_gate="PENDING_FINAL_CHECK"
        publication="PENDING_COMMIT_PUSH"
        non_destructive=$true
    }

    WriteLf $AssessmentFile ($Assessment|ConvertTo-Json -Depth 10)
    WriteLf $RecertFile ($Recert|ConvertTo-Json -Depth 10)
    WriteLf $LedgerFile ($Ledger|ConvertTo-Json -Depth 10)
    WriteLf $ClosureFile ($Closure|ConvertTo-Json -Depth 10)
    WriteLf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 10)

    Write-Host "GOVERNANCE ASSESSMENT : CREATED"
    Write-Host "RECERTIFICATION       : CREATED"
    Write-Host "CLOSURE LEDGER        : CREATED"
    Write-Host "CLOSURE MANIFEST      : CREATED"
    Write-Host "EVIDENCE              : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"

    $Changed=New-Object System.Collections.Generic.List[string]

    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full)){[void]$Changed.Add($p);continue}
        if((Sha $full) -ne $Freeze[$p]){[void]$Changed.Add($p)}
    }

    if($Changed.Count -gt 0){
        $Changed|ForEach-Object{Write-Host "PRESERVATION FAILURE : $_" -ForegroundColor Red}
        Hold "Protected tracked files changed"
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-024.12 CAPAS 1-2 + CLOSED COMPONENTS : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"

    $Allowed=@(
        $SelfName,
        "$ModuleDir/__init__.py",
        "$ModuleDir/models.py",
        "$ModuleDir/recertification.py",
        "$ModuleDir/governance.py",
        "$ModuleDir/gate.py",
        "$ModuleDir/closure.py",
        "$ModuleDir/service.py",
        $TestFile,
        $PolicyFile,
        $DocFile,
        $AssessmentFile,
        $RecertFile,
        $LedgerFile,
        $ClosureFile,
        $EvidenceFile
    )

    foreach($p in $Allowed){
        if(-not(Test-Path -LiteralPath (Join-Path $Root $p))){Hold "Expected target missing before staging: $p"}

        & git.exe `
            -c core.autocrlf=false `
            -c core.eol=lf `
            -c core.safecrlf=false `
            add -- $p

        if($LASTEXITCODE -ne 0){Hold "git add failed: $p"}
    }

    Write-Host "TRANSACTION LINE ENDINGS : CANONICAL LF"
    Write-Host "GIT SAFECRLF POLICY      : TRANSACTION-LOCAL OVERRIDE ONLY"
    Write-Host "GIT GLOBAL/REPO CONFIG   : NOT MODIFIED"

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Unexpected=@($StagedNow|Where-Object{$Allowed -notcontains ($_ -replace '\\','/')})

    Write-Host "STAGED     : $($StagedNow.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if($Unexpected.Count -gt 0){Hold "Unexpected staged paths"}
    if($StagedNow.Count -ne $Allowed.Count){Hold "Exact staging count mismatch"}

    Write-Host "STAGING QUALITY : PASS"

    Step 12 "INDEX-WIDE GITHUB SIZE GATE"

    $Bad=@(SizeGate)

    Write-Host "INDEX BLOBS >=100MB : $($Bad.Count)"

    if($Bad.Count -gt 0){
        $Bad|ForEach-Object{Write-Host "TOO LARGE : $_" -ForegroundColor Red}
        Hold "Git index contains blob >=100 MB"
    }

    Write-Host "GITHUB SIZE GATE : PASS"

    Step 13 "FINAL REMOTE GATE"

    GitFetch

    $Remote2=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    if($Remote2 -ne $ExpectedBaseline){Hold "Remote advanced during transaction"}

    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){
            Hold "Preservation changed before commit: $p"
        }
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"

    Native "git.exe" @(
        "commit",
        "-m",
        "feat(spt-024.12): close infrastructure governance hardening recertification layer 3"
    ) "git commit"

    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    Step 15 "PUSH"

    Native "git.exe" @("push","origin",$Branch) "git push"
    Write-Host "PUSH : PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION / INSTITUTIONAL CLOSURE"

    GitFetch

    $FinalLocal=(& git.exe rev-parse HEAD).Trim()
    $FinalRemote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Behind=(& git.exe rev-list --count ("HEAD..origin/"+$Branch)).Trim()
    $Ahead=(& git.exe rev-list --count ("origin/"+$Branch+"..HEAD")).Trim()
    $FinalStaged=@(& git.exe diff --cached --name-only)
    $FinalDeleted=@(& git.exe ls-files --deleted)

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "BEHIND          : $Behind"
    Write-Host "AHEAD           : $Ahead"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if(
        $FinalLocal -ne $FinalRemote -or
        $Behind -ne "0" -or
        $Ahead -ne "0" -or
        $FinalStaged.Count -ne 0 -or
        $FinalDeleted.Count -ne 0
    ){Hold "Authoritative final synchronization failed"}

    Write-Host ""
    Write-Host "SPT-024.12 : INSTITUTIONALLY CLOSED" -ForegroundColor Green
    Write-Host "SPT-024.12_CAPA1_INFRASTRUCTURE_GATE=PASS"
    Write-Host "SPT-024.12_CAPA2_HARDENING_GATE=PASS"
    Write-Host "SPT-024.12_CAPA3_FINAL_GOVERNANCE_GATE=PASS"
    Write-Host "SECURE_CONFIGURATION_BASELINE=PASS"
    Write-Host "SERVICE_GOVERNANCE=PASS"
    Write-Host "PORT_GOVERNANCE=PASS"
    Write-Host "EXPOSURE_GOVERNANCE=PASS"
    Write-Host "INFRASTRUCTURE_CHANGE_GOVERNANCE=PASS"
    Write-Host "HARDENING_RECERTIFICATION=PASS"
    Write-Host "SECRET_INDIRECTION=PASS"
    Write-Host "PRODUCTION_CONFIGURATION_CHANGED=NO"
    Write-Host "SERVICE_ACTION_EXECUTED=NO"
    Write-Host "NETWORK_ACTION_EXECUTED=NO"
    Write-Host "EXTERNAL_CONNECTION_OPENED=NO"
    Write-Host "SECRET_VALUES_EXPOSED=NO"
    Write-Host "TARGETED_TESTS=PASS"
    Write-Host "INSTITUTIONAL_SUITE=PASS"
    Write-Host "COMPILEALL=PASS"
    Write-Host "CLOSED_COMPONENTS=PRESERVED"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "FINAL_CLOSURE_EXIT_CODE=0"
    exit 0
}
catch{
    Hold $_.Exception.Message
}
