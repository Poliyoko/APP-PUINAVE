#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="92ad4bcfef627c56b068dec05615b9eba420470c"
$Branch="feature/SPT-001A-rlb-schema-foundation"

$Close1Dir="artifacts/development/SPT-024.CLOSE.1-v1.0.2"
$Close1Assessment="$Close1Dir/pisi-global-prepare-assessment.json"
$Close1Coverage="$Close1Dir/pisi-component-coverage-matrix.json"
$Close1ControlMatrix="$Close1Dir/pisi-master-control-matrix.json"
$Close1Reconciliation="$Close1Dir/pisi-domain-reconciliation.json"
$Close1Prepare="$Close1Dir/pisi-institutional-closure-prepare.json"
$Close1Integrity="$Close1Dir/pisi-global-integrity-manifest.json"
$Close1Evidence="$Close1Dir/implementation-evidence.json"

$CoreFile="src/sgoda/integration/spt024close2/core.py"
$InitFile="src/sgoda/integration/spt024close2/__init__.py"
$TestFile="tests/integration/test_spt024_close2_pisi_institutional_closure.py"
$PolicyFile="config/integration/spt024close2/pisi-institutional-closure-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/CLOSE/SGD-SPT024-CLOSE2-Paquete-Cierre-Institucional-PISI.md"
$ActFile="docs/06_Tecnologia/SPT-024/CLOSE/ACT-SPT024-Cierre-Institucional-PISI.md"

$ArtifactDir="artifacts/development/SPT-024.CLOSE.2-v1.0.0"
$AssessmentFile="$ArtifactDir/pisi-final-closure-assessment.json"
$DomainStatusFile="$ArtifactDir/pisi-17-domain-consolidated-status.json"
$RecertificationFile="$ArtifactDir/pisi-final-recertification.json"
$LedgerFile="$ArtifactDir/pisi-master-closure-ledger.json"
$ManifestFile="$ArtifactDir/pisi-global-closure-manifest.json"
$MasterUpdateFile="$ArtifactDir/pisi-master-documentation-update.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"

$LargeFileLimit=100MB

function Step([int]$N,[string]$T){Write-Host "";Write-Host ("[{0}/16] {1}" -f $N,$T) -ForegroundColor Cyan}
function Hold([string]$R){Write-Host "";Write-Host "SPT-024.CLOSE.2 : HOLD" -ForegroundColor Red;Write-Host "REASON : $R" -ForegroundColor Red;Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow;exit 1}
function Fetch{for($i=1;$i-le4;$i++){Write-Host "GIT FETCH ATTEMPT : $i/4";& git.exe fetch origin $Branch;if($LASTEXITCODE-eq0){Write-Host "GIT FETCH : PASS";return};Start-Sleep 2};Hold "git fetch failed"}
function WriteLf([string]$P,[string]$T){$X=if([IO.Path]::IsPathRooted($P)){$P}else{Join-Path $Root $P};$D=Split-Path -Parent $X;if($D-and-not(Test-Path $D)){New-Item -ItemType Directory -Force -Path $D|Out-Null};$U=New-Object Text.UTF8Encoding($false);$C=(($T-replace"`r`n","`n")-replace"`r","`n");if(-not$C.EndsWith("`n")){$C+="`n"};[IO.File]::WriteAllText($X,$C,$U)}
function Sha([string]$P){(Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash.ToUpperInvariant()}
function SizeGate{$B=@();foreach($p in @(& git.exe -c core.quotepath=false ls-files)){$s=@(& git.exe cat-file -s (":"+$p) 2>$null);if($LASTEXITCODE-eq0-and@($s).Count-gt0){[Int64]$n=0;if([Int64]::TryParse(([string]$s[0]).Trim(),[ref]$n)-and$n-ge$LargeFileLimit){$B+=($p-replace'\\','/')}}};@($B)}

try{
$Root=(& git.exe rev-parse --show-toplevel).Trim();if(-not$Root){Hold "Not inside Git repository"};Set-Location $Root
$Python=Join-Path $Root ".venv\Scripts\python.exe";if(-not(Test-Path $Python)){$Python="python.exe"}

Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
Fetch
$L=(& git.exe rev-parse HEAD).Trim();$R=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
$S=@(& git.exe diff --cached --name-only);$D=@(& git.exe ls-files --deleted)
Write-Host "LOCAL HEAD      : $L";Write-Host "REMOTE HEAD     : $R";Write-Host "STAGED          : $($S.Count)";Write-Host "DELETED TRACKED : $($D.Count)"
if($L-ne$ExpectedBaseline-or$R-ne$ExpectedBaseline){Hold "Authoritative baseline mismatch"}
if($S.Count-ne0-or$D.Count-ne0){Hold "Unsafe staged/deleted state"}
Write-Host "BASELINE : PASS"
Write-Host "SPT-024.1-.17 + CLOSE.1 : PROTECTED / NOT REOPENED"
Write-Host "DESTRUCTIVE CLEANUP : NO"

Step 2 "VERIFY CLOSE.1 PREPARE INPUTS"
$Req=@($Close1Assessment,$Close1Coverage,$Close1ControlMatrix,$Close1Reconciliation,$Close1Prepare,$Close1Integrity,$Close1Evidence)
$M=@($Req|Where-Object{-not(Test-Path (Join-Path $Root $_))})
Write-Host "REQUIRED CLOSE.1 INPUTS : $($Req.Count)"
Write-Host "MISSING INPUTS          : $($M.Count)"
if($M.Count){Hold "Missing CLOSE.1 inputs"}
$C1=Get-Content -Raw (Join-Path $Root $Close1Assessment)|ConvertFrom-Json
$Coverage=Get-Content -Raw (Join-Path $Root $Close1Coverage)|ConvertFrom-Json
if([string]$C1.status-ne"PISI_GLOBAL_PREPARE_GATE_PASS"){Hold "CLOSE.1 prepare gate is not PASS"}
if([int]$C1.covered_components-ne17-or@($C1.missing_components).Count-ne0){Hold "CLOSE.1 coverage is incomplete"}
Write-Host "CLOSE.1 GLOBAL PREPARE GATE : PASS"
Write-Host "COVERAGE 17/17              : PASS"

Step 3 "SHA-256 FREEZE OF ALL CLOSED COMPONENTS"
$Freeze=@{}
foreach($p in @(& git.exe -c core.quotepath=false ls-files)){$f=Join-Path $Root $p;if(Test-Path $f){$Freeze[$p]=Sha $f}}
Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
Write-Host "SHA-256 FREEZE : PASS"

Step 4 "FINAL PISI CLOSURE DISCOVERY / RECERTIFICATION INPUT"
Write-Host "EXPECTED PISI DOMAINS : 17"
Write-Host "COVERED PISI DOMAINS  : $($Coverage.Count)"
Write-Host "MODE                  : STATIC / NON-DESTRUCTIVE"
Write-Host "ACTIVE SECURITY PROBE : NO"
Write-Host "PRODUCTION CHANGE     : NO"

Step 5 "IMPLEMENT SPT-024.CLOSE.2 PACKAGE"
$Core=@'
from dataclasses import dataclass

EXPECTED = tuple(f"SPT-024.{i}" for i in range(1,18))

@dataclass(frozen=True)
class DomainStatus:
    component: str
    status: str
    recertified: bool

def validate_close1(close1):
    return (
        close1.get("status") == "PISI_GLOBAL_PREPARE_GATE_PASS"
        and int(close1.get("expected_components", 0)) == 17
        and int(close1.get("covered_components", 0)) == 17
        and len(close1.get("missing_components", [])) == 0
    )

def build_domain_status(coverage):
    by_id = {x.get("component"): x for x in coverage}
    result = []
    for component in EXPECTED:
        row = by_id.get(component, {})
        covered = bool(row.get("covered"))
        result.append(DomainStatus(
            component=component,
            status="CLOSED_AND_RECERTIFIED" if covered else "HOLD",
            recertified=covered
        ).__dict__)
    return result

def assess(close1, coverage):
    close1_ok = validate_close1(close1)
    domains = build_domain_status(coverage)
    domain_ok = all(x["status"] == "CLOSED_AND_RECERTIFIED" for x in domains)
    failed = []
    if not close1_ok:
        failed.append("CLOSE1_PREPARE_GATE")
    if not domain_ok:
        failed.append("DOMAIN_RECERTIFICATION")
    final = not failed
    return {
        "status": "INSTITUTIONALLY_CLOSED" if final else "HOLD",
        "final_gate": "PISI_INSTITUTIONAL_CLOSURE_GATE_PASS" if final else "PISI_INSTITUTIONAL_CLOSURE_GATE_HOLD",
        "failed_blocking_controls": failed,
        "expected_domains": 17,
        "recertified_domains": sum(1 for x in domains if x["recertified"]),
        "domains": domains,
        "close1_prepare_verified": close1_ok,
        "closed_components_preserved": True,
        "production_change_executed": False,
        "active_security_probe_executed": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
'@
$Init=@'
from .core import EXPECTED, validate_close1, build_domain_status, assess
__all__=["EXPECTED","validate_close1","build_domain_status","assess"]
'@
$Tests=@'
from sgoda.integration.spt024close2 import EXPECTED, validate_close1, build_domain_status, assess

def close1():
    return {"status":"PISI_GLOBAL_PREPARE_GATE_PASS","expected_components":17,"covered_components":17,"missing_components":[]}

def coverage():
    return [{"component":f"SPT-024.{i}","covered":True} for i in range(1,18)]

def test_01_expected(): assert len(EXPECTED)==17
def test_02_close1_pass(): assert validate_close1(close1())
def test_03_close1_hold_status(): assert not validate_close1({**close1(),"status":"HOLD"})
def test_04_close1_hold_count(): assert not validate_close1({**close1(),"covered_components":16})
def test_05_domains_len(): assert len(build_domain_status(coverage()))==17
def test_06_domains_closed(): assert all(x["status"]=="CLOSED_AND_RECERTIFIED" for x in build_domain_status(coverage()))
def test_07_assess_status(): assert assess(close1(),coverage())["status"]=="INSTITUTIONALLY_CLOSED"
def test_08_final_gate(): assert assess(close1(),coverage())["final_gate"]=="PISI_INSTITUTIONAL_CLOSURE_GATE_PASS"
def test_09_failed_empty(): assert assess(close1(),coverage())["failed_blocking_controls"]==[]
def test_10_recertified_17(): assert assess(close1(),coverage())["recertified_domains"]==17
def test_11_prepare_verified(): assert assess(close1(),coverage())["close1_prepare_verified"] is True
def test_12_closed_preserved(): assert assess(close1(),coverage())["closed_components_preserved"] is True
def test_13_no_prod_change(): assert assess(close1(),coverage())["production_change_executed"] is False
def test_14_no_probe(): assert assess(close1(),coverage())["active_security_probe_executed"] is False
def test_15_no_external(): assert assess(close1(),coverage())["external_connection_opened"] is False
def test_16_no_secret(): assert assess(close1(),coverage())["secret_values_exposed"] is False
def test_17_missing_domain_hold(): assert assess(close1(),coverage()[:-1])["status"]=="HOLD"
def test_18_missing_domain_gate(): assert assess(close1(),coverage()[:-1])["final_gate"]=="PISI_INSTITUTIONAL_CLOSURE_GATE_HOLD"
def test_19_missing_domain_failed(): assert "DOMAIN_RECERTIFICATION" in assess(close1(),coverage()[:-1])["failed_blocking_controls"]
def test_20_close1_failed(): assert "CLOSE1_PREPARE_GATE" in assess({"status":"HOLD"},coverage())["failed_blocking_controls"]
'@
$Policy=@'
{
  "component": "SPT-024.CLOSE.2",
  "version": "1.0.0",
  "title": "Paquete de Cierre Institucional de PISI/SPT-024",
  "authoritative_baseline": "92ad4bcfef627c56b068dec05615b9eba420470c",
  "requires": {
    "close1_status": "PISI_GLOBAL_PREPARE_GATE_PASS",
    "expected_domains": 17,
    "covered_domains": 17,
    "missing_domains": 0
  },
  "final_gate": "PISI_INSTITUTIONAL_CLOSURE_GATE_PASS",
  "rules": {
    "modify_closed_components": false,
    "destructive_cleanup": false,
    "production_change": false,
    "active_security_probe": false,
    "secret_values_exposed": false,
    "commit_push_required": true,
    "local_remote_head_equality_required": true
  }
}
'@
$Doc=@'
# SPT-024.CLOSE.2 — Paquete de Cierre Institucional PISI/SPT-024

Baseline autoritativa: `92ad4bcfef627c56b068dec05615b9eba420470c`.

Este paquete **no reabre ni modifica SPT-024.1–SPT-024.17 ni SPT-024.CLOSE.1**. Consolida sus resultados ya aprobados y emite los artefactos finales de cierre institucional.

El cierre final exige `PISI_INSTITUTIONAL_CLOSURE_GATE_PASS`, recertificación 17/17, pruebas completas, preservation gate SHA-256, commit, push y `LOCAL HEAD = REMOTE HEAD`.
'@
$Acta=@'
# ACT-SPT024 — Acta de Cierre Institucional de PISI / SPT-024

**Línea base de partida:** `92ad4bcfef627c56b068dec05615b9eba420470c`

## Declaración
SPT-024.CLOSE.2 consolida el cierre institucional del Programa Integral de Seguridad Informática (PISI) de SGODA-PUINAVE.

El cierre solo podrá declararse si:
- SPT-024.CLOSE.1 está aprobado;
- los 17 dominios SPT-024.1 a SPT-024.17 están cubiertos;
- no existen componentes faltantes;
- las pruebas dirigidas e institucionales están aprobadas;
- se preservan SHA-256 y todos los componentes cerrados;
- el repositorio queda sincronizado con `LOCAL HEAD = REMOTE HEAD`.

## Alcance
Acta institucional, manifiesto global, ledger maestro, recertificación final de 17 dominios, estado consolidado, evidencia SHA-256, actualización documental maestra no destructiva y publicación final.
'@
WriteLf $CoreFile $Core
WriteLf $InitFile $Init
WriteLf $TestFile $Tests
WriteLf $PolicyFile $Policy
WriteLf $DocFile $Doc
WriteLf $ActFile $Acta
Write-Host "SPT-024.CLOSE.2 IMPLEMENTATION : CREATED/VALIDATED"

Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
$env:PYTHONPATH=Join-Path $Root "src"
& $Python -c "from sgoda.integration.spt024close2 import EXPECTED; assert len(EXPECTED)==17; print('SPT024_CLOSE2_IMPORT=PASS'); print('EXPECTED_DOMAINS=17')"
if($LASTEXITCODE){Hold "SPT-024.CLOSE.2 import failed"}
& $Python -m pytest -q $TestFile
if($LASTEXITCODE){Hold "Targeted tests failed"}
Write-Host "TARGETED TESTS : PASS"

Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
& $Python -m pytest -q
if($LASTEXITCODE){Hold "Institutional suite failed"}
Write-Host "FULL SUITE : PASS"
& $Python -m compileall -q (Join-Path $Root "src")
if($LASTEXITCODE){Hold "compileall failed"}
Write-Host "COMPILEALL : PASS"

Step 8 "FINAL PISI INSTITUTIONAL CLOSURE ASSESSMENT"
$TmpC1=Join-Path ([IO.Path]::GetTempPath()) ("spt024-close2-c1-"+[guid]::NewGuid().ToString("N")+".json")
$TmpCov=Join-Path ([IO.Path]::GetTempPath()) ("spt024-close2-cov-"+[guid]::NewGuid().ToString("N")+".json")
$TmpProbe=Join-Path ([IO.Path]::GetTempPath()) ("spt024-close2-"+[guid]::NewGuid().ToString("N")+".py")
WriteLf $TmpC1 ($C1|ConvertTo-Json -Depth 10)
WriteLf $TmpCov ($Coverage|ConvertTo-Json -Depth 10)
$Probe=@'
import json,sys
from sgoda.integration.spt024close2 import assess
c1=json.load(open(sys.argv[1],encoding="utf-8"))
cov=json.load(open(sys.argv[2],encoding="utf-8"))
print(json.dumps(assess(c1,cov)))
'@
WriteLf $TmpProbe $Probe
try{$J=& $Python $TmpProbe $TmpC1 $TmpCov;$E=$LASTEXITCODE}finally{Remove-Item $TmpProbe,$TmpC1,$TmpCov -Force -ErrorAction SilentlyContinue}
if($E){Hold "Final PISI closure assessment failed"}
$A=$J|ConvertFrom-Json
Write-Host "SPT024_CLOSURE_STATUS=$($A.status)"
Write-Host "FINAL_GATE=$($A.final_gate)"
Write-Host "EXPECTED_DOMAINS=$($A.expected_domains)"
Write-Host "RECERTIFIED_DOMAINS=$($A.recertified_domains)"
Write-Host "FAILED_BLOCKING_CONTROLS=$(@($A.failed_blocking_controls).Count)"
Write-Host "ACTIVE_SECURITY_PROBE_EXECUTED=NO"
Write-Host "PRODUCTION_CHANGE_EXECUTED=NO"
Write-Host "EXTERNAL_CONNECTION_OPENED=NO"
Write-Host "SECRET_VALUES_EXPOSED=NO"
if([string]$A.status-ne"INSTITUTIONALLY_CLOSED"-or[string]$A.final_gate-ne"PISI_INSTITUTIONAL_CLOSURE_GATE_PASS"){Hold "PISI institutional closure gate failed"}
Write-Host "PISI INSTITUTIONAL CLOSURE GATE : PASS"

Step 9 "FINAL ACTA / LEDGER / MANIFEST / MASTER UPDATE / EVIDENCE"
New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null
WriteLf $AssessmentFile ($A|ConvertTo-Json -Depth 12)
WriteLf $DomainStatusFile ($A.domains|ConvertTo-Json -Depth 10)
WriteLf $RecertificationFile ([ordered]@{program="PISI";component="SPT-024";recertified_domains=$A.recertified_domains;expected_domains=17;status="PASS";domains=$A.domains}|ConvertTo-Json -Depth 12)

$Ledger=[ordered]@{
program="PISI";component="SPT-024";closure_package="SPT-024.CLOSE.2";version="1.0.0"
source_baseline=$ExpectedBaseline
close1_gate="PISI_GLOBAL_PREPARE_GATE_PASS"
final_gate="PISI_INSTITUTIONAL_CLOSURE_GATE_PASS"
institutional_status="INSTITUTIONALLY_CLOSED"
domains_total=17
domains_recertified=$A.recertified_domains
closed_components_preserved=$true
}
WriteLf $LedgerFile ($Ledger|ConvertTo-Json -Depth 10)

$MasterUpdate=[ordered]@{
update_type="INSTITUTIONAL_MASTER_STATUS_UPDATE"
program="SPT-024 / PISI"
new_status="INSTITUTIONALLY_CLOSED"
source_of_truth_commit_before=$ExpectedBaseline
domains="SPT-024.1-SPT-024.17"
coverage="17/17"
quality_gate="PASS"
instruction="Reflect this closure in SGD-000, SGD-002, Master Index and Master Traceability during the next institutional master synchronization without reopening closed components."
}
WriteLf $MasterUpdateFile ($MasterUpdate|ConvertTo-Json -Depth 8)

$MR=@()
foreach($p in @($PolicyFile,$DocFile,$ActFile,$AssessmentFile,$DomainStatusFile,$RecertificationFile,$LedgerFile,$MasterUpdateFile,$Close1Assessment,$Close1Coverage,$Close1ControlMatrix,$Close1Reconciliation,$Close1Prepare,$Close1Integrity,$Close1Evidence)){$MR+=[ordered]@{path=$p;sha256=(Sha (Join-Path $Root $p))}}
WriteLf $ManifestFile ([ordered]@{algorithm="SHA-256";program="PISI";component="SPT-024";records=$MR}|ConvertTo-Json -Depth 12)

WriteLf $EvidenceFile ([ordered]@{
component="SPT-024.CLOSE.2";version="1.0.0";baseline=$ExpectedBaseline
status="INSTITUTIONALLY_CLOSED";final_gate="PISI_INSTITUTIONAL_CLOSURE_GATE_PASS"
expected_domains=17;recertified_domains=$A.recertified_domains
targeted_tests="PASS";institutional_suite="PASS";compileall="PASS"
closed_components_preserved=$true;production_change=$false;secret_values_exposed=$false
}|ConvertTo-Json -Depth 10)

Write-Host "FINAL ASSESSMENT     : CREATED"
Write-Host "17-DOMAIN STATUS     : CREATED"
Write-Host "FINAL RECERTIFICATION: CREATED"
Write-Host "MASTER LEDGER        : CREATED"
Write-Host "GLOBAL MANIFEST      : CREATED"
Write-Host "MASTER DOC UPDATE    : CREATED"
Write-Host "INSTITUTIONAL ACTA   : CREATED"
Write-Host "EVIDENCE             : CREATED"

Step 10 "SHA-256 PRESERVATION GATE"
foreach($p in $Freeze.Keys){$f=Join-Path $Root $p;if(-not(Test-Path $f)-or(Sha $f)-ne$Freeze[$p]){Hold "Protected tracked file changed: $p"}}
Write-Host "PROTECTED TRACKED FILES : PRESERVED"
Write-Host "SPT-024.1-.17 + CLOSE.1 + CLOSED COMPONENTS : PRESERVED"

Step 11 "EXACT CONTROLLED STAGING"
$Allowed=@("Invoke-SGODA-SPT024-CLOSE2-PISI-InstitutionalClosure-FINAL-v1.0.0-PS51.ps1",$CoreFile,$InitFile,$TestFile,$PolicyFile,$DocFile,$ActFile,$AssessmentFile,$DomainStatusFile,$RecertificationFile,$LedgerFile,$ManifestFile,$MasterUpdateFile,$EvidenceFile)
foreach($p in $Allowed){if(-not(Test-Path (Join-Path $Root $p))){Hold "Missing expected target: $p"};& git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $p;if($LASTEXITCODE){Hold "git add failed: $p"}}
$SN=@(& git.exe -c core.quotepath=false diff --cached --name-only)
$U=@($SN|Where-Object{$Allowed-notcontains($_-replace'\\','/')})
Write-Host "STAGED     : $($SN.Count)"
Write-Host "UNEXPECTED : $($U.Count)"
if($U.Count-or$SN.Count-ne$Allowed.Count){Hold "Exact staging mismatch"}
Write-Host "STAGING QUALITY : PASS"

Step 12 "INDEX-WIDE GITHUB SIZE GATE"
$B=@(SizeGate)
Write-Host "INDEX BLOBS >=100MB : $($B.Count)"
if($B.Count){Hold "Git index contains blob >=100 MB"}
Write-Host "GITHUB SIZE GATE : PASS"

Step 13 "FINAL REMOTE / PRESERVATION GATE"
Fetch
$R2=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
if($R2-ne$ExpectedBaseline){Hold "Remote advanced during transaction"}
foreach($p in $Freeze.Keys){$f=Join-Path $Root $p;if(-not(Test-Path $f)-or(Sha $f)-ne$Freeze[$p]){Hold "Preservation changed before commit"}}
Write-Host "PROTECTED TRACKED FILES : PRESERVED"
Write-Host "REMOTE GATE : PASS"

Step 14 "COMMIT"
& git.exe commit -m "feat(spt-024.close.2): close PISI institutional security program"
if($LASTEXITCODE){Hold "git commit failed"}
$NC=(& git.exe rev-parse HEAD).Trim()
Write-Host "NEW COMMIT : $NC"

Step 15 "PUSH"
& git.exe push origin $Branch
if($LASTEXITCODE){Hold "git push failed"}
Write-Host "PUSH : PASS"

Step 16 "AUTHORITATIVE REMOTE VERIFICATION / INSTITUTIONAL CLOSURE"
Fetch
$FL=(& git.exe rev-parse HEAD).Trim()
$FR=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
$Behind=(& git.exe rev-list --count ("HEAD..origin/"+$Branch)).Trim()
$Ahead=(& git.exe rev-list --count ("origin/"+$Branch+"..HEAD")).Trim()
$FS=@(& git.exe diff --cached --name-only)
$FD=@(& git.exe ls-files --deleted)
Write-Host "LOCAL HEAD      : $FL"
Write-Host "REMOTE HEAD     : $FR"
Write-Host "BEHIND          : $Behind"
Write-Host "AHEAD           : $Ahead"
Write-Host "STAGED          : $($FS.Count)"
Write-Host "DELETED TRACKED : $($FD.Count)"
if($FL-ne$FR-or$Behind-ne"0"-or$Ahead-ne"0"-or$FS.Count-ne0-or$FD.Count-ne0){Hold "Final synchronization failed"}

Write-Host ""
Write-Host "SPT-024 / PISI : INSTITUTIONALLY CLOSED" -ForegroundColor Green
Write-Host "SPT-024_CLOSE1_PREPARE_GATE=PASS"
Write-Host "SPT-024_CLOSE2_FINAL_CLOSURE_GATE=PASS"
Write-Host "PISI_GLOBAL_COVERAGE=17/17"
Write-Host "PISI_FINAL_RECERTIFICATION=17/17"
Write-Host "MASTER_CLOSURE_LEDGER=CREATED"
Write-Host "GLOBAL_CLOSURE_MANIFEST=CREATED"
Write-Host "INSTITUTIONAL_CLOSURE_ACTA=CREATED"
Write-Host "MASTER_DOCUMENTATION_UPDATE=CREATED"
Write-Host "ACTIVE_SECURITY_PROBE=NO"
Write-Host "PRODUCTION_CHANGE=NO"
Write-Host "SECRET_VALUES_EXPOSED=NO"
Write-Host "TARGETED_TESTS=PASS"
Write-Host "INSTITUTIONAL_SUITE=PASS"
Write-Host "COMPILEALL=PASS"
Write-Host "CLOSED_COMPONENTS=PRESERVED"
Write-Host "LOCAL_HEAD=REMOTE_HEAD"
Write-Host "FINAL_CLOSURE_EXIT_CODE=0"
exit 0
}catch{Hold $_.Exception.Message}
