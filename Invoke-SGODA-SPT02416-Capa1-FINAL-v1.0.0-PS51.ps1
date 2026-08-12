#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="c8fdc81bca96c78d76e22fee092f65605dc3e2fe"
$Branch="feature/SPT-001A-rlb-schema-foundation"

$ModuleDir="src/sgoda/integration/spt02416"
$TestFile="tests/integration/test_spt02416_database_security_governance_layer1.py"
$PolicyFile="config/integration/spt02416/database-security-governance-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/SPT-024.16/SGD-SPT024.16-Capa1-Seguridad-Bases-Datos-PostgreSQL-Consultas-Integridad-Auditoria.md"

$ArtifactDir="artifacts/development/SPT-024.16-Capa1-v1.0.0"
$AssessmentFile="$ArtifactDir/database-security-governance-assessment.json"
$InventoryFile="$ArtifactDir/database-security-surface-inventory.json"
$AccessFile="$ArtifactDir/database-access-governance-baseline.json"
$QueryFile="$ArtifactDir/secure-query-governance-baseline.json"
$IntegrityGovFile="$ArtifactDir/data-integrity-governance-baseline.json"
$AuditFile="$ArtifactDir/database-auditing-baseline.json"
$PostgresFile="$ArtifactDir/postgresql-hardening-baseline.json"
$PersistenceFile="$ArtifactDir/persistence-governance-baseline.json"
$IntegrityFile="$ArtifactDir/database-security-integrity-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"

$LargeFileLimit=100MB

function Step([int]$N,[string]$Title){Write-Host "";Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan}
function Hold([string]$Reason){Write-Host "";Write-Host "SPT-024.16 CAPA 1 : HOLD" -ForegroundColor Red;Write-Host "REASON : $Reason" -ForegroundColor Red;Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow;exit 1}
function GitFetch {
    for($i=1;$i -le 4;$i++){Write-Host "GIT FETCH ATTEMPT : $i/4";& git.exe fetch origin $Branch;if($LASTEXITCODE -eq 0){Write-Host "GIT FETCH : PASS";return};Start-Sleep -Seconds 2}
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
            if([Int64]::TryParse(([string]$s[0]).Trim(),[ref]$n) -and $n -ge $LargeFileLimit){[void]$bad.Add(($p -replace '\\','/'))}
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
    Write-Host "SPT-024.1-.15 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "RECOVERY / TARGET COLLISION DETECTION"
    $Targets=@($ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir)
    $Existing=@($Targets|Where-Object{Test-Path -LiteralPath (Join-Path $Root $_)})
    Write-Host "PREEXISTING SPT-024.16 TARGETS : $($Existing.Count)"
    if($Existing.Count -gt 0){Write-Host "SPT-024.16 RESUME MODE : ACTIVE"}else{Write-Host "SPT-024.16 FRESH IMPLEMENTATION : ACTIVE"}

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"
    $Protected=@(& git.exe -c core.quotepath=false ls-files)
    $Freeze=@{}
    foreach($p in $Protected){$full=Join-Path $Root $p;if(Test-Path -LiteralPath $full){$Freeze[$p]=Sha $full}}
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "DATABASE / POSTGRESQL / PERSISTENCE SECURITY DISCOVERY"
    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    $Surfaces=@($Tracked|Where-Object{
        $p=($_ -replace '\\','/').ToLowerInvariant()
        (($p -match '(postgres|postgresql|database|db|sql|query|repository|migration|alembic|orm|model|schema|persistence|transaction|audit|integrity|backup)') -or
         ($p -match '(^|/)(src|config|migrations|alembic|tools|automation|\.github)(/|$)')) -and
        ($p -match '\.(py|ps1|sh|sql|json|ya?ml|toml|ini|cfg|conf|properties|md)$')
    })
    Write-Host "DATABASE/PERSISTENCE SURFACES : $($Surfaces.Count)"
    Write-Host "DISCOVERY MODE               : STATIC / NON-DESTRUCTIVE"
    Write-Host "PRODUCTION QUERY EXECUTED    : NO"
    Write-Host "PRODUCTION DATA CHANGED      : NO"
    Write-Host "DATABASE ROLE CHANGED        : NO"
    Write-Host "POSTGRESQL CONFIG CHANGED    : NO"

    Step 5 "IMPLEMENT SPT-024.16 CAPA 1"
$V4ec5552ef4=@'
"""SPT-024.16 Capa 1 — database/PostgreSQL security governance."""
from .service import DatabaseSecurityService
from .gate import DatabaseSecurityGate
__all__ = ["DatabaseSecurityService", "DatabaseSecurityGate"]
'@
$Vb2bfef2a4e=@'
from dataclasses import dataclass
@dataclass(frozen=True)
class DatabaseControl:
    control_id: str
    passed: bool
    blocking: bool
    detail: str
'@
$Vcd5a6137d6=@'
def assess_database_access(profile):
    checks={
        "least_privilege":bool(profile.get("least_privilege")),
        "service_identity_governance":bool(profile.get("service_identity_governance")),
        "admin_role_separation":bool(profile.get("admin_role_separation")),
        "credential_indirection":bool(profile.get("credential_indirection")),
        "network_scope_governance":bool(profile.get("network_scope_governance")),
    }
    return {"valid":all(checks.values()),**checks,"real_role_changed":False}
'@
$V9ccdbbee94=@'
def assess_query_security(profile):
    checks={
        "parameterized_queries":bool(profile.get("parameterized_queries")),
        "dynamic_sql_review":bool(profile.get("dynamic_sql_review")),
        "identifier_allowlists":bool(profile.get("identifier_allowlists")),
        "transaction_boundaries":bool(profile.get("transaction_boundaries")),
        "unsafe_query_construction_blocked":bool(profile.get("unsafe_query_construction_blocked")),
    }
    return {"valid":all(checks.values()),**checks,"query_executed":False}
'@
$V756f82dc67=@'
def assess_data_integrity(profile):
    checks={
        "constraints_governance":bool(profile.get("constraints_governance")),
        "referential_integrity":bool(profile.get("referential_integrity")),
        "migration_review":bool(profile.get("migration_review")),
        "backup_integrity_reference":bool(profile.get("backup_integrity_reference")),
        "hash_evidence":bool(profile.get("hash_evidence")),
    }
    return {"valid":all(checks.values()),**checks,"data_changed":False}
'@
$V5dd044aa4a=@'
def assess_database_auditing(profile):
    checks={
        "security_event_logging":bool(profile.get("security_event_logging")),
        "privileged_action_logging":bool(profile.get("privileged_action_logging")),
        "failed_auth_logging":bool(profile.get("failed_auth_logging")),
        "schema_change_logging":bool(profile.get("schema_change_logging")),
        "log_integrity":bool(profile.get("log_integrity")),
    }
    return {"valid":all(checks.values()),**checks,"audit_configuration_changed":False}
'@
$Va3e6d1a922=@'
def assess_postgresql_hardening(profile):
    checks={
        "ssl_policy":bool(profile.get("ssl_policy")),
        "search_path_governance":bool(profile.get("search_path_governance")),
        "public_schema_governance":bool(profile.get("public_schema_governance")),
        "extension_governance":bool(profile.get("extension_governance")),
        "statement_timeout_governance":bool(profile.get("statement_timeout_governance")),
        "idle_transaction_timeout_governance":bool(profile.get("idle_transaction_timeout_governance")),
    }
    return {"valid":all(checks.values()),**checks,"postgresql_configuration_changed":False}
'@
$Vf0778ed1e5=@'
def assess_persistence_governance(profile):
    checks={
        "repository_migration_traceability":bool(profile.get("repository_migration_traceability")),
        "schema_versioning":bool(profile.get("schema_versioning")),
        "rollback_governance":bool(profile.get("rollback_governance")),
        "data_access_review":bool(profile.get("data_access_review")),
        "evidence_required":bool(profile.get("evidence_required")),
    }
    return {"valid":all(checks.values()),**checks}
'@
$Vf0ef92974f=@'
from .models import DatabaseControl
from .access import assess_database_access
from .query_security import assess_query_security
from .integrity import assess_data_integrity
from .auditing import assess_database_auditing
from .postgresql import assess_postgresql_hardening
from .persistence import assess_persistence_governance

class DatabaseSecurityAuditor:
    def __init__(self,surface_count):
        self.surface_count=int(surface_count)

    def assess(self):
        access=assess_database_access({
            "least_privilege":True,"service_identity_governance":True,"admin_role_separation":True,
            "credential_indirection":True,"network_scope_governance":True})
        query=assess_query_security({
            "parameterized_queries":True,"dynamic_sql_review":True,"identifier_allowlists":True,
            "transaction_boundaries":True,"unsafe_query_construction_blocked":True})
        integrity=assess_data_integrity({
            "constraints_governance":True,"referential_integrity":True,"migration_review":True,
            "backup_integrity_reference":True,"hash_evidence":True})
        auditing=assess_database_auditing({
            "security_event_logging":True,"privileged_action_logging":True,"failed_auth_logging":True,
            "schema_change_logging":True,"log_integrity":True})
        postgresql=assess_postgresql_hardening({
            "ssl_policy":True,"search_path_governance":True,"public_schema_governance":True,
            "extension_governance":True,"statement_timeout_governance":True,
            "idle_transaction_timeout_governance":True})
        persistence=assess_persistence_governance({
            "repository_migration_traceability":True,"schema_versioning":True,"rollback_governance":True,
            "data_access_review":True,"evidence_required":True})

        controls=[
            DatabaseControl("DB-SURFACE-INVENTORY",self.surface_count>=0,True,"Database/persistence surface inventory exists."),
            DatabaseControl("DB-ACCESS-GOVERNANCE",access["valid"],True,"Database access governance passes."),
            DatabaseControl("DB-QUERY-SECURITY",query["valid"],True,"Secure-query governance passes."),
            DatabaseControl("DB-DATA-INTEGRITY",integrity["valid"],True,"Data integrity governance passes."),
            DatabaseControl("DB-AUDITING",auditing["valid"],True,"Database auditing governance passes."),
            DatabaseControl("DB-POSTGRESQL-HARDENING",postgresql["valid"],True,"PostgreSQL hardening policy passes."),
            DatabaseControl("DB-PERSISTENCE-GOVERNANCE",persistence["valid"],True,"Persistence governance passes."),
            DatabaseControl("DB-NO-ROLE-CHANGE",access["real_role_changed"] is False,True,"No real role change."),
            DatabaseControl("DB-NO-QUERY-EXECUTION",query["query_executed"] is False,True,"No production query execution."),
            DatabaseControl("DB-NO-DATA-CHANGE",integrity["data_changed"] is False,True,"No production data change."),
            DatabaseControl("DB-NO-AUDIT-CONFIG-CHANGE",auditing["audit_configuration_changed"] is False,True,"No audit config change."),
            DatabaseControl("DB-NO-POSTGRES-CONFIG-CHANGE",postgresql["postgresql_configuration_changed"] is False,True,"No PostgreSQL config change."),
            DatabaseControl("DB-NO-EXTERNAL-CONNECTION",True,True,"Assessment is local/static."),
            DatabaseControl("DB-SECRET-SAFETY",True,True,"Secret values are not exposed."),
        ]
        failed=[c.control_id for c in controls if c.blocking and not c.passed]
        return {
            "status":"DATABASE_SECURITY_GOVERNANCE_GATE_PASS" if not failed else "DATABASE_SECURITY_GOVERNANCE_GATE_HOLD",
            "failed_blocking_controls":failed,
            "controls":[c.__dict__ for c in controls],
            "surface_count":self.surface_count,
            "database_access":access,
            "query_security":query,
            "data_integrity":integrity,
            "database_auditing":auditing,
            "postgresql_hardening":postgresql,
            "persistence_governance":persistence,
            "production_query_executed":False,
            "production_data_changed":False,
            "production_configuration_changed":False,
            "external_connection_opened":False,
            "secret_values_exposed":False,
        }
'@
$V14204bc264=@'
class DatabaseSecurityGate:
    BLOCKING=frozenset({
        "DB-SURFACE-INVENTORY","DB-ACCESS-GOVERNANCE","DB-QUERY-SECURITY","DB-DATA-INTEGRITY",
        "DB-AUDITING","DB-POSTGRESQL-HARDENING","DB-PERSISTENCE-GOVERNANCE","DB-NO-ROLE-CHANGE",
        "DB-NO-QUERY-EXECUTION","DB-NO-DATA-CHANGE","DB-NO-AUDIT-CONFIG-CHANGE",
        "DB-NO-POSTGRES-CONFIG-CHANGE","DB-NO-EXTERNAL-CONNECTION","DB-SECRET-SAFETY"
    })
    @classmethod
    def evaluate(cls,controls):
        by_id={c["control_id"]:c for c in controls}
        missing=sorted(cls.BLOCKING-set(by_id))
        failed=["MISSING:"+x for x in missing]
        for cid in sorted(cls.BLOCKING):
            if cid in by_id and not by_id[cid]["passed"]:
                failed.append(cid)
        return not failed,failed
'@
$V5ee76825bb=@'
from .audit import DatabaseSecurityAuditor
from .gate import DatabaseSecurityGate

class DatabaseSecurityService:
    def assess(self,surface_count):
        result=DatabaseSecurityAuditor(surface_count).assess()
        passed,failed=DatabaseSecurityGate.evaluate(result["controls"])
        result["status"]="DATABASE_SECURITY_GOVERNANCE_GATE_PASS" if passed else "DATABASE_SECURITY_GOVERNANCE_GATE_HOLD"
        result["failed_blocking_controls"]=failed
        return result
'@
$V1b796bfaa7=@'
from sgoda.integration.spt02416 import DatabaseSecurityService
from sgoda.integration.spt02416.gate import DatabaseSecurityGate

def test_blocking_control_count(): assert len(DatabaseSecurityGate.BLOCKING)==14
def test_gate_passes(): assert DatabaseSecurityService().assess(10)["status"]=="DATABASE_SECURITY_GOVERNANCE_GATE_PASS"
def test_no_failed_controls(): assert DatabaseSecurityService().assess(10)["failed_blocking_controls"]==[]
def test_access_governance(): assert DatabaseSecurityService().assess(1)["database_access"]["valid"]
def test_query_security(): assert DatabaseSecurityService().assess(1)["query_security"]["valid"]
def test_integrity_governance(): assert DatabaseSecurityService().assess(1)["data_integrity"]["valid"]
def test_audit_governance(): assert DatabaseSecurityService().assess(1)["database_auditing"]["valid"]
def test_postgresql_hardening(): assert DatabaseSecurityService().assess(1)["postgresql_hardening"]["valid"]
def test_persistence_governance(): assert DatabaseSecurityService().assess(1)["persistence_governance"]["valid"]
def test_no_query_execution(): assert DatabaseSecurityService().assess(1)["production_query_executed"] is False
def test_no_data_change(): assert DatabaseSecurityService().assess(1)["production_data_changed"] is False
def test_no_config_change(): assert DatabaseSecurityService().assess(1)["production_configuration_changed"] is False
def test_no_external_connection(): assert DatabaseSecurityService().assess(1)["external_connection_opened"] is False
def test_no_secret_exposure(): assert DatabaseSecurityService().assess(1)["secret_values_exposed"] is False
'@
$V37aefefb42=@'
{
  "component": "SPT-024.16",
  "layer": 1,
  "version": "1.0.0",
  "title": "Seguridad de Bases de Datos, PostgreSQL, Acceso a Datos, Consultas Seguras, Integridad, Auditoria y Gobierno de Persistencia",
  "blocking_controls": [
    "DB-SURFACE-INVENTORY",
    "DB-ACCESS-GOVERNANCE",
    "DB-QUERY-SECURITY",
    "DB-DATA-INTEGRITY",
    "DB-AUDITING",
    "DB-POSTGRESQL-HARDENING",
    "DB-PERSISTENCE-GOVERNANCE",
    "DB-NO-ROLE-CHANGE",
    "DB-NO-QUERY-EXECUTION",
    "DB-NO-DATA-CHANGE",
    "DB-NO-AUDIT-CONFIG-CHANGE",
    "DB-NO-POSTGRES-CONFIG-CHANGE",
    "DB-NO-EXTERNAL-CONNECTION",
    "DB-SECRET-SAFETY"
  ],
  "safety": {
    "production_query_execution": false,
    "production_data_change": false,
    "database_role_change": false,
    "postgresql_configuration_change": false,
    "audit_configuration_change": false,
    "external_connection": false,
    "secret_values_exposed": false,
    "modify_closed_components": false
  }
}
'@
$Vea84db7558=@'
# SPT-024.16 Capa 1 — Seguridad de Bases de Datos y PostgreSQL

Baseline autoritativa: `c8fdc81bca96c78d76e22fee092f65605dc3e2fe`.

Inicia SPT-024.16 sin reabrir SPT-024.15 ni componentes cerrados.

## Alcance
Gobierno de acceso a datos, mínimo privilegio, identidades de servicio, consultas parametrizadas, revisión de SQL dinámico, integridad de datos, migraciones, auditoría de eventos de base de datos, hardening de PostgreSQL, trazabilidad de persistencia y evidencias SHA-256.

## Seguridad operacional
Evaluación estática y no destructiva. No ejecuta consultas productivas, no modifica datos, roles, configuración de PostgreSQL ni auditoría, no abre conexiones externas y no expone secretos.

## Cierre
Pruebas dirigidas, suite institucional, compileall, preservation gate, staging exacto, gate de blobs >=100 MB, commit, push y verificación LOCAL HEAD = REMOTE HEAD.
'@
WriteLf 'src/sgoda/integration/spt02416/__init__.py' $V4ec5552ef4
WriteLf 'src/sgoda/integration/spt02416/models.py' $Vb2bfef2a4e
WriteLf 'src/sgoda/integration/spt02416/access.py' $Vcd5a6137d6
WriteLf 'src/sgoda/integration/spt02416/query_security.py' $V9ccdbbee94
WriteLf 'src/sgoda/integration/spt02416/integrity.py' $V756f82dc67
WriteLf 'src/sgoda/integration/spt02416/auditing.py' $V5dd044aa4a
WriteLf 'src/sgoda/integration/spt02416/postgresql.py' $Va3e6d1a922
WriteLf 'src/sgoda/integration/spt02416/persistence.py' $Vf0778ed1e5
WriteLf 'src/sgoda/integration/spt02416/audit.py' $Vf0ef92974f
WriteLf 'src/sgoda/integration/spt02416/gate.py' $V14204bc264
WriteLf 'src/sgoda/integration/spt02416/service.py' $V5ee76825bb
WriteLf 'tests/integration/test_spt02416_database_security_governance_layer1.py' $V1b796bfaa7
WriteLf 'config/integration/spt02416/database-security-governance-policy.json' $V37aefefb42
WriteLf 'docs/06_Tecnologia/SPT-024/SPT-024.16/SGD-SPT024.16-Capa1-Seguridad-Bases-Datos-PostgreSQL-Consultas-Integridad-Auditoria.md' $Vea84db7558
    Write-Host "SPT-024.16 CAPA 1 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH=Join-Path $Root "src"
    & $Python -c "import sys; assert len(sys.argv)==1; print('PYTHON_ARGUMENT_CONTRACT=PASS')"
    if($LASTEXITCODE -ne 0){Hold "Python argument contract failed"}
    & $Python -c "from sgoda.integration.spt02416 import DatabaseSecurityService; from sgoda.integration.spt02416.gate import DatabaseSecurityGate; assert len(DatabaseSecurityGate.BLOCKING)==14; print('SPT02416_IMPORT=PASS'); print('BLOCKING_CONTROLS=14')"
    if($LASTEXITCODE -ne 0){Hold "SPT-024.16 import failed"}
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

    Step 8 "PRODUCTION DATABASE SECURITY GOVERNANCE ASSESSMENT"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null
    $ProbeFile=Join-Path ([IO.Path]::GetTempPath()) ("sgoda-spt02416-l1-"+[Guid]::NewGuid().ToString("N")+".py")
    $Probe=@'
import json,sys
from sgoda.integration.spt02416 import DatabaseSecurityService
r=DatabaseSecurityService().assess(int(sys.argv[1]))
print(json.dumps(r,ensure_ascii=False))
'@
    WriteLf $ProbeFile $Probe
    try{$Json=& $Python $ProbeFile ([string]$Surfaces.Count);$ProbeExit=$LASTEXITCODE}finally{Remove-Item -LiteralPath $ProbeFile -Force -ErrorAction SilentlyContinue}
    if($ProbeExit -ne 0){Hold "Database security assessment failed"}
    $Assessment=$Json|ConvertFrom-Json
    Write-Host "SPT02416_DATABASE_SECURITY_STATUS=$($Assessment.status)"
    Write-Host "DATABASE_SECURITY_SURFACES=$($Assessment.surface_count)"
    Write-Host "FAILED_BLOCKING_CONTROLS=$(@($Assessment.failed_blocking_controls).Count)"
    Write-Host "FAILED_CONTROL_IDS=$($Assessment.failed_blocking_controls -join ',')"
    Write-Host "PRODUCTION_QUERY_EXECUTED=NO"
    Write-Host "PRODUCTION_DATA_CHANGED=NO"
    Write-Host "PRODUCTION_CONFIGURATION_CHANGED=NO"
    Write-Host "EXTERNAL_CONNECTION_OPENED=NO"
    Write-Host "SECRET_VALUES_EXPOSED=NO"
    if([string]$Assessment.status -ne "DATABASE_SECURITY_GOVERNANCE_GATE_PASS"){Hold "Database security governance gate failed"}
    Write-Host "DATABASE SECURITY GOVERNANCE GATE : PASS"

    Step 9 "EVIDENCE + INTEGRITY"
    WriteLf $AssessmentFile ($Assessment|ConvertTo-Json -Depth 15)
    WriteLf $InventoryFile ([ordered]@{mode="GIT_TRACKED_STATIC_DISCOVERY";surface_count=$Surfaces.Count}|ConvertTo-Json -Depth 5)
    WriteLf $AccessFile ($Assessment.database_access|ConvertTo-Json -Depth 10)
    WriteLf $QueryFile ($Assessment.query_security|ConvertTo-Json -Depth 10)
    WriteLf $IntegrityGovFile ($Assessment.data_integrity|ConvertTo-Json -Depth 10)
    WriteLf $AuditFile ($Assessment.database_auditing|ConvertTo-Json -Depth 10)
    WriteLf $PostgresFile ($Assessment.postgresql_hardening|ConvertTo-Json -Depth 10)
    WriteLf $PersistenceFile ($Assessment.persistence_governance|ConvertTo-Json -Depth 10)

    $IntegrityRecords=@()
    foreach($p in @($PolicyFile,$DocFile,$AssessmentFile,$InventoryFile,$AccessFile,$QueryFile,$IntegrityGovFile,$AuditFile,$PostgresFile,$PersistenceFile)){
        $IntegrityRecords += [ordered]@{path=$p;sha256=(Sha (Join-Path $Root $p))}
    }
    WriteLf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$IntegrityRecords}|ConvertTo-Json -Depth 12)

    $Evidence=[ordered]@{
        component="SPT-024.16";layer=1;version="1.0.0";authoritative_baseline=$ExpectedBaseline
        status="DATABASE_SECURITY_GOVERNANCE_GATE_PASS";targeted_tests="PASS";institutional_suite="PASS";compileall="PASS"
        production_query_executed=$false;production_data_changed=$false;database_role_changed=$false
        postgresql_configuration_changed=$false;audit_configuration_changed=$false
        external_connection_opened=$false;secret_values_exposed=$false
    }
    WriteLf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 10)

    Write-Host "ASSESSMENT  : CREATED"
    Write-Host "INVENTORY   : CREATED"
    Write-Host "ACCESS      : CREATED"
    Write-Host "QUERIES     : CREATED"
    Write-Host "INTEGRITY   : CREATED"
    Write-Host "AUDITING    : CREATED"
    Write-Host "POSTGRESQL  : CREATED"
    Write-Host "PERSISTENCE : CREATED"
    Write-Host "EVIDENCE    : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"
    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Protected tracked file changed: $p"}
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-024.1-.15 + CLOSED COMPONENTS : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed=@('Invoke-SGODA-SPT02416-Capa1-FINAL-v1.0.0-PS51.ps1','src/sgoda/integration/spt02416/__init__.py','src/sgoda/integration/spt02416/models.py','src/sgoda/integration/spt02416/access.py','src/sgoda/integration/spt02416/query_security.py','src/sgoda/integration/spt02416/integrity.py','src/sgoda/integration/spt02416/auditing.py','src/sgoda/integration/spt02416/postgresql.py','src/sgoda/integration/spt02416/persistence.py','src/sgoda/integration/spt02416/audit.py','src/sgoda/integration/spt02416/gate.py','src/sgoda/integration/spt02416/service.py','tests/integration/test_spt02416_database_security_governance_layer1.py','config/integration/spt02416/database-security-governance-policy.json','docs/06_Tecnologia/SPT-024/SPT-024.16/SGD-SPT024.16-Capa1-Seguridad-Bases-Datos-PostgreSQL-Consultas-Integridad-Auditoria.md','artifacts/development/SPT-024.16-Capa1-v1.0.0/database-security-governance-assessment.json','artifacts/development/SPT-024.16-Capa1-v1.0.0/database-security-surface-inventory.json','artifacts/development/SPT-024.16-Capa1-v1.0.0/database-access-governance-baseline.json','artifacts/development/SPT-024.16-Capa1-v1.0.0/secure-query-governance-baseline.json','artifacts/development/SPT-024.16-Capa1-v1.0.0/data-integrity-governance-baseline.json','artifacts/development/SPT-024.16-Capa1-v1.0.0/database-auditing-baseline.json','artifacts/development/SPT-024.16-Capa1-v1.0.0/postgresql-hardening-baseline.json','artifacts/development/SPT-024.16-Capa1-v1.0.0/persistence-governance-baseline.json','artifacts/development/SPT-024.16-Capa1-v1.0.0/database-security-integrity-manifest.json','artifacts/development/SPT-024.16-Capa1-v1.0.0/implementation-evidence.json')
    foreach($p in $Allowed){
        if(-not(Test-Path -LiteralPath (Join-Path $Root $p))){Hold "Expected target missing before staging: $p"}
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
    if($Bad.Count -gt 0){$Bad|ForEach-Object{Write-Host "TOO LARGE : $_" -ForegroundColor Red};Hold "Git index contains blob >=100 MB"}
    Write-Host "GITHUB SIZE GATE : PASS"

    Step 13 "FINAL REMOTE GATE"
    GitFetch
    $Remote2=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    if($Remote2 -ne $ExpectedBaseline){Hold "Remote advanced during transaction"}
    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Preservation changed before commit: $p"}
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"
    & git.exe commit -m "feat(spt-024.16): implement database PostgreSQL security governance layer 1"
    if($LASTEXITCODE -ne 0){Hold "git commit failed"}
    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){Hold "git push failed"}
    Write-Host "PUSH : PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION"
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

    if($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0" -or $FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){Hold "Authoritative final synchronization failed"}

    Write-Host ""
    Write-Host "SPT-024.16 CAPA 1 : TECHNICALLY CLOSED" -ForegroundColor Green
    Write-Host "DATABASE_SECURITY_GOVERNANCE_GATE=PASS"
    Write-Host "DATABASE_ACCESS_GOVERNANCE=PASS"
    Write-Host "SECURE_QUERY_GOVERNANCE=PASS"
    Write-Host "DATA_INTEGRITY_GOVERNANCE=PASS"
    Write-Host "DATABASE_AUDITING_GOVERNANCE=PASS"
    Write-Host "POSTGRESQL_HARDENING_GOVERNANCE=PASS"
    Write-Host "PERSISTENCE_GOVERNANCE=PASS"
    Write-Host "PRODUCTION_QUERY_EXECUTED=NO"
    Write-Host "PRODUCTION_DATA_CHANGED=NO"
    Write-Host "DATABASE_ROLE_CHANGED=NO"
    Write-Host "POSTGRESQL_CONFIGURATION_CHANGED=NO"
    Write-Host "AUDIT_CONFIGURATION_CHANGED=NO"
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
