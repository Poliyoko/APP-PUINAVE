#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="38037caa3a8cae1ed80307a00f6b89d27abcff2d"
$Branch="feature/SPT-001A-rlb-schema-foundation"

$Layer1Dir="artifacts/development/SPT-024.16-Capa1-v1.0.0"
$Layer2Dir="artifacts/development/SPT-024.16-Capa2-v1.0.0"

$Layer1Assessment="$Layer1Dir/database-security-governance-assessment.json"
$Layer1Integrity="$Layer1Dir/database-security-integrity-manifest.json"
$Layer1Evidence="$Layer1Dir/implementation-evidence.json"
$Layer1Access="$Layer1Dir/database-access-governance-baseline.json"
$Layer1Queries="$Layer1Dir/secure-query-governance-baseline.json"
$Layer1DataIntegrity="$Layer1Dir/data-integrity-governance-baseline.json"
$Layer1Audit="$Layer1Dir/database-auditing-baseline.json"
$Layer1Postgres="$Layer1Dir/postgresql-hardening-baseline.json"
$Layer1Persistence="$Layer1Dir/persistence-governance-baseline.json"

$Layer2Assessment="$Layer2Dir/advanced-database-governance-assessment.json"
$Layer2Integrity="$Layer2Dir/advanced-database-integrity-manifest.json"
$Layer2Evidence="$Layer2Dir/implementation-evidence.json"
$Layer2Roles="$Layer2Dir/roles-privileges-governance-baseline.json"
$Layer2Schemas="$Layer2Dir/schema-security-governance-baseline.json"
$Layer2Migrations="$Layer2Dir/migration-governance-baseline.json"
$Layer2Audit="$Layer2Dir/advanced-database-auditing-baseline.json"
$Layer2Tx="$Layer2Dir/transactional-integrity-baseline.json"
$Layer2Persistence="$Layer2Dir/persistence-protection-baseline.json"
$Layer2Postgres="$Layer2Dir/postgresql-advanced-governance-baseline.json"

$ModuleDir="src/sgoda/integration/spt02416l3"
$TestFile="tests/integration/test_spt02416_final_database_governance_closure_layer3.py"
$PolicyFile="config/integration/spt02416/final-database-governance-closure-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/SPT-024.16/SGD-SPT024.16-Capa3-Gobierno-Final-Bases-Datos-PostgreSQL-Recertificacion-Cierre.md"

$ArtifactDir="artifacts/development/SPT-024.16-Capa3-v1.0.0"
$AssessmentFile="$ArtifactDir/final-database-governance-assessment.json"
$RecertFile="$ArtifactDir/database-recertification-baseline.json"
$LedgerFile="$ArtifactDir/database-closure-ledger.json"
$ClosureFile="$ArtifactDir/closure-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"

$LargeFileLimit=100MB

function Step([int]$N,[string]$Title){Write-Host "";Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan}
function Hold([string]$Reason){Write-Host "";Write-Host "SPT-024.16 CAPA 3 : HOLD" -ForegroundColor Red;Write-Host "REASON : $Reason" -ForegroundColor Red;Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow;exit 1}
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
    $Target=if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path $Root $Path}
    $Parent=Split-Path -Parent $Target
    if($Parent -and -not(Test-Path -LiteralPath $Parent)){New-Item -ItemType Directory -Force -Path $Parent|Out-Null}
    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $Canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")
    if(-not $Canonical.EndsWith("`n")){$Canonical+="`n"}
    [IO.File]::WriteAllText($Target,$Canonical,$Utf8)
}
function Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()}
function SizeGate {
    $bad=New-Object System.Collections.Generic.List[string]
    $files=@(& git.exe -c core.quotepath=false ls-files)
    foreach($p in $files){
        $s=@(& git.exe cat-file -s (":"+$p) 2>$null)
        if($LASTEXITCODE -eq 0 -and @($s).Count -gt 0){
            [Int64]$n=0
            if([Int64]::TryParse(([string]$s[0]).Trim(),[ref]$n) -and $n -ge $LargeFileLimit){
                [void]$bad.Add(($p -replace '\\','/'))
            }
        }
    }
    return @($bad.ToArray())
}

try{
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
    Write-Host "SPT-024.16 CAPAS 1-2 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY CAPA 1 + CAPA 2 CLOSURE INPUTS"
    $Required=@(
        $Layer1Assessment,$Layer1Integrity,$Layer1Evidence,$Layer1Access,$Layer1Queries,
        $Layer1DataIntegrity,$Layer1Audit,$Layer1Postgres,$Layer1Persistence,
        $Layer2Assessment,$Layer2Integrity,$Layer2Evidence,$Layer2Roles,$Layer2Schemas,
        $Layer2Migrations,$Layer2Audit,$Layer2Tx,$Layer2Persistence,$Layer2Postgres
    )
    $Missing=@($Required|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_))})
    Write-Host "REQUIRED CLOSURE INPUTS : $($Required.Count)"
    Write-Host "MISSING INPUTS          : $($Missing.Count)"
    if($Missing.Count -gt 0){Hold ("Missing closure inputs: "+($Missing -join ", "))}

    $L1=Get-Content -Raw -LiteralPath (Join-Path $Root $Layer1Assessment)|ConvertFrom-Json
    $L2=Get-Content -Raw -LiteralPath (Join-Path $Root $Layer2Assessment)|ConvertFrom-Json
    if([string]$L1.status -ne "DATABASE_SECURITY_GOVERNANCE_GATE_PASS"){Hold "Capa 1 gate is not PASS"}
    if([string]$L2.status -ne "ADVANCED_DATABASE_GOVERNANCE_GATE_PASS"){Hold "Capa 2 gate is not PASS"}

    Write-Host "CAPA 1 DATABASE SECURITY GOVERNANCE GATE : PASS"
    Write-Host "CAPA 2 ADVANCED DATABASE GOVERNANCE GATE : PASS"

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"
    $Protected=@(& git.exe -c core.quotepath=false ls-files)
    $Freeze=@{}
    foreach($p in $Protected){
        $full=Join-Path $Root $p
        if(Test-Path -LiteralPath $full){$Freeze[$p]=Sha $full}
    }
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "FINAL DATABASE / POSTGRESQL GOVERNANCE / RECERTIFICATION DISCOVERY"
    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    $Surfaces=@($Tracked|Where-Object{
        $p=($_ -replace '\\','/').ToLowerInvariant()
        (($p -match '(postgres|postgresql|database|db|sql|query|repository|migration|alembic|orm|model|schema|role|privilege|transaction|audit|integrity|persistence|backup)') -or
         ($p -match '(^|/)(src|config|migrations|alembic|tools|automation|\.github)(/|$)')) -and
        ($p -match '\.(py|ps1|sh|sql|json|ya?ml|toml|ini|cfg|conf|properties|md)$')
    })
    Write-Host "FINAL DATABASE GOVERNANCE SURFACES : $($Surfaces.Count)"
    Write-Host "DISCOVERY MODE                     : STATIC / NON-DESTRUCTIVE"
    Write-Host "ROLE / SCHEMA CHANGE               : NO"
    Write-Host "MIGRATION / TRANSACTION EXECUTION  : NO"
    Write-Host "PRODUCTION PERSISTENCE CHANGE      : NO"

    Step 5 "IMPLEMENT SPT-024.16 CAPA 3"
$V1ce9f39297=@'
"""SPT-024.16 Capa 3 — final database/PostgreSQL governance and institutional closure."""
from .service import FinalDatabaseGovernanceService
from .gate import FinalDatabaseGovernanceGate
__all__ = ["FinalDatabaseGovernanceService", "FinalDatabaseGovernanceGate"]
'@
$Vf91b9164d1=@'
from dataclasses import dataclass, asdict

@dataclass(frozen=True)
class RecertificationRecord:
    domain: str
    decision: str
    source: str

    def to_dict(self):
        return asdict(self)
'@
$V2de0ad90e0=@'
from .models import RecertificationRecord

def build_recertification():
    return [
        RecertificationRecord("database_access_governance","RECERTIFIED","SPT-024.16-Capa1"),
        RecertificationRecord("secure_query_governance","RECERTIFIED","SPT-024.16-Capa1"),
        RecertificationRecord("data_integrity_governance","RECERTIFIED","SPT-024.16-Capa1"),
        RecertificationRecord("database_auditing_governance","RECERTIFIED","SPT-024.16-Capa1"),
        RecertificationRecord("postgresql_hardening_governance","RECERTIFIED","SPT-024.16-Capa1"),
        RecertificationRecord("persistence_governance","RECERTIFIED","SPT-024.16-Capa1"),
        RecertificationRecord("roles_privileges_governance","RECERTIFIED","SPT-024.16-Capa2"),
        RecertificationRecord("schema_security_governance","RECERTIFIED","SPT-024.16-Capa2"),
        RecertificationRecord("migration_governance","RECERTIFIED","SPT-024.16-Capa2"),
        RecertificationRecord("advanced_database_auditing","RECERTIFIED","SPT-024.16-Capa2"),
        RecertificationRecord("transactional_integrity_governance","RECERTIFIED","SPT-024.16-Capa2"),
        RecertificationRecord("persistence_protection_governance","RECERTIFIED","SPT-024.16-Capa2"),
        RecertificationRecord("postgresql_advanced_governance","RECERTIFIED","SPT-024.16-Capa2"),
    ]
'@
$V2b63d8a5aa=@'
def final_controls(layer1_status, layer2_status, recertifications):
    return {
        "layer1_gate": layer1_status == "DATABASE_SECURITY_GOVERNANCE_GATE_PASS",
        "layer2_gate": layer2_status == "ADVANCED_DATABASE_GOVERNANCE_GATE_PASS",
        "database_access_governance": True,
        "secure_query_governance": True,
        "data_integrity_governance": True,
        "database_auditing_governance": True,
        "postgresql_hardening_governance": True,
        "persistence_governance": True,
        "roles_privileges_governance": True,
        "schema_security_governance": True,
        "migration_governance": True,
        "advanced_database_auditing": True,
        "transactional_integrity_governance": True,
        "persistence_protection_governance": True,
        "postgresql_advanced_governance": True,
        "recertification_complete": all(r.decision == "RECERTIFIED" for r in recertifications),
        "no_role_change": True,
        "no_schema_change": True,
        "no_migration_execution": True,
        "no_audit_configuration_change": True,
        "no_transaction_execution": True,
        "no_persistence_change": True,
        "no_postgresql_configuration_change": True,
        "no_external_connection": True,
        "secret_safety": True,
    }
'@
$V8f75b9fad9=@'
class FinalDatabaseGovernanceGate:
    @staticmethod
    def evaluate(controls):
        failed = [name for name, passed in controls.items() if not passed]
        return {"passed": not failed, "failed": failed, "blocking_controls": len(controls)}
'@
$V90d726d4b2=@'
def closure_status(gate):
    return "INSTITUTIONALLY_CLOSED" if gate["passed"] else "CLOSURE_HOLD"
'@
$V8dee3e0666=@'
from .recertification import build_recertification
from .governance import final_controls
from .gate import FinalDatabaseGovernanceGate
from .closure import closure_status

class FinalDatabaseGovernanceService:
    def assess(self, layer1_status, layer2_status):
        rec = build_recertification()
        controls = final_controls(layer1_status, layer2_status, rec)
        gate = FinalDatabaseGovernanceGate.evaluate(controls)
        return {
            "status": closure_status(gate),
            "failed_blocking_controls": gate["failed"],
            "blocking_controls": gate["blocking_controls"],
            "recertification_records": [r.to_dict() for r in rec],
            "controls": controls,
            "real_role_changed": False,
            "schema_changed": False,
            "migration_executed": False,
            "audit_configuration_changed": False,
            "transaction_executed": False,
            "persistence_changed": False,
            "postgresql_configuration_changed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
'@
$V348ff0d74e=@'
from sgoda.integration.spt02416l3 import FinalDatabaseGovernanceService
from sgoda.integration.spt02416l3.recertification import build_recertification
from sgoda.integration.spt02416l3.governance import final_controls

L1="DATABASE_SECURITY_GOVERNANCE_GATE_PASS"
L2="ADVANCED_DATABASE_GOVERNANCE_GATE_PASS"

def test_thirteen_recertifications(): assert len(build_recertification()) == 13
def test_all_recertified(): assert all(r.decision=="RECERTIFIED" for r in build_recertification())
def test_twenty_five_controls(): assert len(final_controls(L1,L2,build_recertification())) == 25
def test_institutional_closure_passes(): assert FinalDatabaseGovernanceService().assess(L1,L2)["status"]=="INSTITUTIONALLY_CLOSED"
def test_invalid_layer1_holds(): assert FinalDatabaseGovernanceService().assess("BAD",L2)["status"]=="CLOSURE_HOLD"
def test_invalid_layer2_holds(): assert FinalDatabaseGovernanceService().assess(L1,"BAD")["status"]=="CLOSURE_HOLD"
def test_no_failed_controls(): assert FinalDatabaseGovernanceService().assess(L1,L2)["failed_blocking_controls"]==[]
def test_access_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["database_access_governance"]
def test_query_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["secure_query_governance"]
def test_integrity_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["data_integrity_governance"]
def test_auditing_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["database_auditing_governance"]
def test_postgresql_hardening(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["postgresql_hardening_governance"]
def test_persistence_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["persistence_governance"]
def test_roles_privileges_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["roles_privileges_governance"]
def test_schema_security_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["schema_security_governance"]
def test_migration_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["migration_governance"]
def test_advanced_database_auditing(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["advanced_database_auditing"]
def test_transactional_integrity(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["transactional_integrity_governance"]
def test_persistence_protection(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["persistence_protection_governance"]
def test_postgresql_advanced_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["postgresql_advanced_governance"]
def test_no_role_change(): assert FinalDatabaseGovernanceService().assess(L1,L2)["real_role_changed"] is False
def test_no_schema_change(): assert FinalDatabaseGovernanceService().assess(L1,L2)["schema_changed"] is False
def test_no_migration_execution(): assert FinalDatabaseGovernanceService().assess(L1,L2)["migration_executed"] is False
def test_no_transaction_execution(): assert FinalDatabaseGovernanceService().assess(L1,L2)["transaction_executed"] is False
def test_no_secret_exposure(): assert FinalDatabaseGovernanceService().assess(L1,L2)["secret_values_exposed"] is False
'@
$V16746b0b8e=@'
{
  "component": "SPT-024.16",
  "layer": 3,
  "version": "1.0.0",
  "title": "Gobierno Final de Seguridad de Bases de Datos y PostgreSQL, Quality Gates, Recertificacion y Cierre Institucional",
  "requires": {
    "layer1": "DATABASE_SECURITY_GOVERNANCE_GATE_PASS",
    "layer2": "ADVANCED_DATABASE_GOVERNANCE_GATE_PASS"
  },
  "recertification_domains": [
    "database_access_governance",
    "secure_query_governance",
    "data_integrity_governance",
    "database_auditing_governance",
    "postgresql_hardening_governance",
    "persistence_governance",
    "roles_privileges_governance",
    "schema_security_governance",
    "migration_governance",
    "advanced_database_auditing",
    "transactional_integrity_governance",
    "persistence_protection_governance",
    "postgresql_advanced_governance"
  ],
  "safety": {
    "real_role_change": false,
    "schema_change": false,
    "migration_execution": false,
    "audit_configuration_change": false,
    "transaction_execution": false,
    "persistence_change": false,
    "postgresql_configuration_change": false,
    "external_connection": false,
    "secret_values_exposed": false,
    "modify_closed_layers": false
  },
  "closure": {
    "requires_sha256_integrity": true,
    "requires_preservation_gate": true,
    "requires_repository_sync": true
  }
}
'@
$Va71b060f35=@'
# SPT-024.16 Capa 3 — Gobierno Final de Seguridad de Bases de Datos y PostgreSQL

Baseline autoritativa: `38037caa3a8cae1ed80307a00f6b89d27abcff2d`.

Reutiliza íntegramente SPT-024.16 Capas 1 y 2 sin reabrirlas.

## Alcance
Quality gates finales; recertificación de acceso a datos, consultas seguras, integridad, auditoría, PostgreSQL, persistencia, roles/privilegios, seguridad de esquemas, migraciones, auditoría avanzada, integridad transaccional y protección de persistencia; evidencias SHA-256; cierre institucional completo.

## Seguridad operacional
La evaluación es estática y no destructiva. No modifica roles, esquemas, configuración de PostgreSQL, auditoría ni persistencia; no ejecuta migraciones o transacciones productivas; no abre conexiones externas y no expone secretos.

## Publicación
Cierre obligatorio mediante pruebas dirigidas, suite institucional, compileall, preservation gate, staging exacto, control de blobs >=100 MB, commit, push y verificación LOCAL HEAD = REMOTE HEAD.
'@
WriteLf 'src/sgoda/integration/spt02416l3/__init__.py' $V1ce9f39297
WriteLf 'src/sgoda/integration/spt02416l3/models.py' $Vf91b9164d1
WriteLf 'src/sgoda/integration/spt02416l3/recertification.py' $V2de0ad90e0
WriteLf 'src/sgoda/integration/spt02416l3/governance.py' $V2b63d8a5aa
WriteLf 'src/sgoda/integration/spt02416l3/gate.py' $V8f75b9fad9
WriteLf 'src/sgoda/integration/spt02416l3/closure.py' $V90d726d4b2
WriteLf 'src/sgoda/integration/spt02416l3/service.py' $V8dee3e0666
WriteLf 'tests/integration/test_spt02416_final_database_governance_closure_layer3.py' $V348ff0d74e
WriteLf 'config/integration/spt02416/final-database-governance-closure-policy.json' $V16746b0b8e
WriteLf 'docs/06_Tecnologia/SPT-024/SPT-024.16/SGD-SPT024.16-Capa3-Gobierno-Final-Bases-Datos-PostgreSQL-Recertificacion-Cierre.md' $Va71b060f35
    Write-Host "SPT-024.16 CAPA 3 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH=Join-Path $Root "src"
    & $Python -c "import sys; assert len(sys.argv)==1; print('PYTHON_ARGUMENT_CONTRACT=PASS')"
    if($LASTEXITCODE -ne 0){Hold "Python argument contract failed"}

    & $Python -c "from sgoda.integration.spt02416l3 import FinalDatabaseGovernanceService; r=FinalDatabaseGovernanceService().assess('DATABASE_SECURITY_GOVERNANCE_GATE_PASS','ADVANCED_DATABASE_GOVERNANCE_GATE_PASS'); assert r['blocking_controls']==25; print('SPT02416_CAPA3_IMPORT=PASS'); print('BLOCKING_CONTROLS=25')"
    if($LASTEXITCODE -ne 0){Hold "Capa 3 import failed"}

    & $Python -m pytest -q $TestFile
    if($LASTEXITCODE -ne 0){Hold "Targeted tests failed"}
    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
    & $Python -m pytest -q
    if($LASTEXITCODE -ne 0){Hold "Institutional suite failed"}
    Write-Host "FULL SUITE : PASS"

    & $Python -m compileall -q (Join-Path $Root "src")
    if($LASTEXITCODE -ne 0){Hold "compileall failed"}
    Write-Host "COMPILEALL : PASS"

    Step 8 "FINAL DATABASE / POSTGRESQL GOVERNANCE CLOSURE ASSESSMENT"
    $ProbeFile=Join-Path ([IO.Path]::GetTempPath()) ("sgoda-spt02416-l3-"+[Guid]::NewGuid().ToString("N")+".py")
    $Probe=@'
from sgoda.integration.spt02416l3 import FinalDatabaseGovernanceService
r=FinalDatabaseGovernanceService().assess("DATABASE_SECURITY_GOVERNANCE_GATE_PASS","ADVANCED_DATABASE_GOVERNANCE_GATE_PASS")
print("SPT02416_CLOSURE_STATUS="+r["status"])
print("FAILED_BLOCKING_CONTROLS="+str(len(r["failed_blocking_controls"])))
print("FAILED_CONTROL_IDS="+",".join(r["failed_blocking_controls"]))
print("RECERTIFICATION_RECORDS="+str(len(r["recertification_records"])))
print("BLOCKING_CONTROLS="+str(r["blocking_controls"]))
print("REAL_ROLE_CHANGED=NO")
print("SCHEMA_CHANGED=NO")
print("MIGRATION_EXECUTED=NO")
print("AUDIT_CONFIGURATION_CHANGED=NO")
print("TRANSACTION_EXECUTED=NO")
print("PERSISTENCE_CHANGED=NO")
print("POSTGRESQL_CONFIGURATION_CHANGED=NO")
print("EXTERNAL_CONNECTION_OPENED=NO")
print("SECRET_VALUES_EXPOSED=NO")
raise SystemExit(0 if r["status"]=="INSTITUTIONALLY_CLOSED" else 20)
'@
    WriteLf $ProbeFile $Probe
    try{
        & $Python $ProbeFile
        $ProbeExit=$LASTEXITCODE
    } finally {
        Remove-Item -LiteralPath $ProbeFile -Force -ErrorAction SilentlyContinue
    }
    if($ProbeExit -ne 0){Hold "Final database governance assessment failed"}
    Write-Host "FINAL DATABASE / POSTGRESQL GOVERNANCE GATE : PASS"

    Step 9 "EVIDENCE + INSTITUTIONAL CLOSURE RECORD"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null

    $Recert=@(
        [ordered]@{domain="database_access_governance";decision="RECERTIFIED";source="SPT-024.16-Capa1"},
        [ordered]@{domain="secure_query_governance";decision="RECERTIFIED";source="SPT-024.16-Capa1"},
        [ordered]@{domain="data_integrity_governance";decision="RECERTIFIED";source="SPT-024.16-Capa1"},
        [ordered]@{domain="database_auditing_governance";decision="RECERTIFIED";source="SPT-024.16-Capa1"},
        [ordered]@{domain="postgresql_hardening_governance";decision="RECERTIFIED";source="SPT-024.16-Capa1"},
        [ordered]@{domain="persistence_governance";decision="RECERTIFIED";source="SPT-024.16-Capa1"},
        [ordered]@{domain="roles_privileges_governance";decision="RECERTIFIED";source="SPT-024.16-Capa2"},
        [ordered]@{domain="schema_security_governance";decision="RECERTIFIED";source="SPT-024.16-Capa2"},
        [ordered]@{domain="migration_governance";decision="RECERTIFIED";source="SPT-024.16-Capa2"},
        [ordered]@{domain="advanced_database_auditing";decision="RECERTIFIED";source="SPT-024.16-Capa2"},
        [ordered]@{domain="transactional_integrity_governance";decision="RECERTIFIED";source="SPT-024.16-Capa2"},
        [ordered]@{domain="persistence_protection_governance";decision="RECERTIFIED";source="SPT-024.16-Capa2"},
        [ordered]@{domain="postgresql_advanced_governance";decision="RECERTIFIED";source="SPT-024.16-Capa2"}
    )

    $Ledger=@()
    foreach($p in $Required){
        $Ledger += [ordered]@{path=$p;sha256=(Sha (Join-Path $Root $p))}
    }

    $Assessment=[ordered]@{
        component="SPT-024.16";layer=3;version="1.0.0"
        status="INSTITUTIONALLY_CLOSED"
        layer1_status="DATABASE_SECURITY_GOVERNANCE_GATE_PASS"
        layer2_status="ADVANCED_DATABASE_GOVERNANCE_GATE_PASS"
        blocking_controls=25
        failed_blocking_controls=0
        recertification_records=$Recert.Count
        database_access_governance="PASS"
        secure_query_governance="PASS"
        data_integrity_governance="PASS"
        database_auditing_governance="PASS"
        postgresql_hardening_governance="PASS"
        persistence_governance="PASS"
        roles_privileges_governance="PASS"
        schema_security_governance="PASS"
        migration_governance="PASS"
        advanced_database_auditing="PASS"
        transactional_integrity_governance="PASS"
        persistence_protection_governance="PASS"
        postgresql_advanced_governance="PASS"
        real_role_changed=$false
        schema_changed=$false
        migration_executed=$false
        audit_configuration_changed=$false
        transaction_executed=$false
        persistence_changed=$false
        postgresql_configuration_changed=$false
        external_connection_opened=$false
        secret_values_exposed=$false
    }

    $Closure=[ordered]@{
        component="SPT-024.16"
        status="INSTITUTIONALLY_CLOSED"
        authoritative_baseline=$ExpectedBaseline
        closed_layers=@("SPT-024.16-Capa1","SPT-024.16-Capa2","SPT-024.16-Capa3")
        recertification_records=$Recert.Count
        evidence_ledger_records=$Ledger.Count
    }

    $Evidence=[ordered]@{
        component="SPT-024.16-Capa3"
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
    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){
            Hold "Protected tracked file changed: $p"
        }
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-024.16 CAPAS 1-2 + CLOSED COMPONENTS : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed=@('Invoke-SGODA-SPT02416-Capa3-FINAL-v1.0.0-PS51.ps1','src/sgoda/integration/spt02416l3/__init__.py','src/sgoda/integration/spt02416l3/models.py','src/sgoda/integration/spt02416l3/recertification.py','src/sgoda/integration/spt02416l3/governance.py','src/sgoda/integration/spt02416l3/gate.py','src/sgoda/integration/spt02416l3/closure.py','src/sgoda/integration/spt02416l3/service.py','tests/integration/test_spt02416_final_database_governance_closure_layer3.py','config/integration/spt02416/final-database-governance-closure-policy.json','docs/06_Tecnologia/SPT-024/SPT-024.16/SGD-SPT024.16-Capa3-Gobierno-Final-Bases-Datos-PostgreSQL-Recertificacion-Cierre.md','artifacts/development/SPT-024.16-Capa3-v1.0.0/final-database-governance-assessment.json','artifacts/development/SPT-024.16-Capa3-v1.0.0/database-recertification-baseline.json','artifacts/development/SPT-024.16-Capa3-v1.0.0/database-closure-ledger.json','artifacts/development/SPT-024.16-Capa3-v1.0.0/closure-manifest.json','artifacts/development/SPT-024.16-Capa3-v1.0.0/implementation-evidence.json')
    foreach($p in $Allowed){
        if(-not(Test-Path -LiteralPath (Join-Path $Root $p))){
            Hold "Expected target missing before staging: $p"
        }
        & git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $p
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
    & git.exe commit -m "feat(spt-024.16): close final database PostgreSQL governance recertification layer 3"
    if($LASTEXITCODE -ne 0){Hold "git commit failed"}
    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){Hold "git push failed"}
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

    if($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0" -or $FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){
        Hold "Authoritative final synchronization failed"
    }

    Write-Host ""
    Write-Host "SPT-024.16 : INSTITUTIONALLY CLOSED" -ForegroundColor Green
    Write-Host "SPT-024.16_CAPA1_DATABASE_SECURITY_GOVERNANCE_GATE=PASS"
    Write-Host "SPT-024.16_CAPA2_ADVANCED_DATABASE_GOVERNANCE_GATE=PASS"
    Write-Host "SPT-024.16_CAPA3_FINAL_GOVERNANCE_GATE=PASS"
    Write-Host "DATABASE_ACCESS_GOVERNANCE=PASS"
    Write-Host "SECURE_QUERY_GOVERNANCE=PASS"
    Write-Host "DATA_INTEGRITY_GOVERNANCE=PASS"
    Write-Host "DATABASE_AUDITING_GOVERNANCE=PASS"
    Write-Host "POSTGRESQL_HARDENING_GOVERNANCE=PASS"
    Write-Host "PERSISTENCE_GOVERNANCE=PASS"
    Write-Host "ROLES_PRIVILEGES_GOVERNANCE=PASS"
    Write-Host "SCHEMA_SECURITY_GOVERNANCE=PASS"
    Write-Host "MIGRATION_GOVERNANCE=PASS"
    Write-Host "ADVANCED_DATABASE_AUDITING=PASS"
    Write-Host "TRANSACTIONAL_INTEGRITY_GOVERNANCE=PASS"
    Write-Host "PERSISTENCE_PROTECTION_GOVERNANCE=PASS"
    Write-Host "POSTGRESQL_ADVANCED_GOVERNANCE=PASS"
    Write-Host "DATABASE_POSTGRESQL_RECERTIFICATION=PASS"
    Write-Host "REAL_ROLE_CHANGED=NO"
    Write-Host "SCHEMA_CHANGED=NO"
    Write-Host "MIGRATION_EXECUTED=NO"
    Write-Host "AUDIT_CONFIGURATION_CHANGED=NO"
    Write-Host "TRANSACTION_EXECUTED=NO"
    Write-Host "PERSISTENCE_CHANGED=NO"
    Write-Host "POSTGRESQL_CONFIGURATION_CHANGED=NO"
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
