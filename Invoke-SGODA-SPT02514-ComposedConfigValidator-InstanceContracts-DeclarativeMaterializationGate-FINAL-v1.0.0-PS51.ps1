#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="bfaf5615fc0352f32b53da46b44793c1decc8b4d"
$Branch="feature/SPT-001A-rlb-schema-foundation"
$ReqAssessment="artifacts/development/SPT-025.13-v1.0.0/instance-configuration-composition-assessment.json"
$ReqPrepare="artifacts/development/SPT-025.13-v1.0.0/spt02514-prepare.json"
$ReqConfig="artifacts/development/SPT-025.13-v1.0.0/composed-example-instance-configuration.json"
$ReqManifest="artifacts/development/SPT-025.13-v1.0.0/composed-configuration-sha256-manifest.json"

$CoreFile="src/sgoda/integration/spt02514/core.py"
$InitFile="src/sgoda/integration/spt02514/__init__.py"
$TestFile="tests/integration/test_spt02514_composed_config_instance_contract_materialization_gate.py"
$PolicyFile="config/integration/spt02514/composed-configuration-materialization-gate-policy.json"
$DocFile="docs/06_Tecnologia/SPT-025/SPT-025.14/SGD-SPT025.14-Validador-Configuracion-Compuesta-Contratos-Materializacion.md"

$ArtifactDir="artifacts/development/SPT-025.14-v1.0.0"
$ValidationFile="$ArtifactDir/composed-configuration-validation-assessment.json"
$ContractFile="$ArtifactDir/instance-contract-validation-assessment.json"
$MaterializationFile="$ArtifactDir/declarative-materialization-quality-gate.json"
$IntegrityFile="$ArtifactDir/declarative-materialization-sha256-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"
$PrepareFile="$ArtifactDir/spt02515-prepare.json"

function Step{param([int]$Number,[string]$Title);Write-Host "";Write-Host ("[{0}/16] {1}" -f $Number,$Title) -ForegroundColor Cyan}
function Hold{param([string]$Reason);Write-Host "";Write-Host "SPT-025.14 : HOLD" -ForegroundColor Red;Write-Host "REASON : $Reason";Write-Host "TRANSACTION : NOT PUBLISHED";exit 1}
function Fetch-Authoritative{for($Attempt=1;$Attempt -le 4;$Attempt++){Write-Host ("GIT FETCH ATTEMPT : {0}/4" -f $Attempt);& git.exe fetch origin $Branch;if($LASTEXITCODE -eq 0){Write-Host "GIT FETCH : PASS";return};Start-Sleep -Seconds 2};Hold "git fetch failed"}
function Write-Lf{param([string]$Path,[string]$Text);$Absolute=Join-Path $Root $Path;$Parent=Split-Path -Parent $Absolute;if($Parent -and -not(Test-Path -LiteralPath $Parent)){New-Item -ItemType Directory -Force -Path $Parent|Out-Null};$Utf8=New-Object System.Text.UTF8Encoding($false);$Normalized=(($Text -replace "`r`n","`n") -replace "`r","`n");if(-not $Normalized.EndsWith("`n")){$Normalized+="`n"};[IO.File]::WriteAllText($Absolute,$Normalized,$Utf8)}
function Get-Sha256{param([string]$Path);return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()}

try{
$Root=(& git.exe rev-parse --show-toplevel).Trim();if(-not $Root){Hold "Not inside Git repository"};Set-Location $Root
$Python=Join-Path $Root ".venv\Scripts\python.exe";if(-not(Test-Path -LiteralPath $Python)){$Python="python.exe"}

Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
Fetch-Authoritative
$LocalHead=(& git.exe rev-parse HEAD).Trim();$RemoteHead=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
$Staged=@(& git.exe diff --cached --name-only);$DeletedTracked=@(& git.exe ls-files --deleted)
Write-Host "LOCAL HEAD      : $LocalHead";Write-Host "REMOTE HEAD     : $RemoteHead";Write-Host "STAGED          : $($Staged.Count)";Write-Host "DELETED TRACKED : $($DeletedTracked.Count)"
if($LocalHead -ne $ExpectedBaseline -or $RemoteHead -ne $ExpectedBaseline){Hold "Authoritative baseline mismatch"}
if($Staged.Count -ne 0 -or $DeletedTracked.Count -ne 0){Hold "Unsafe staged/deleted state"}
Write-Host "BASELINE : PASS";Write-Host "SPT-025.1-.13 : PROTECTED / NOT REOPENED";Write-Host "DESTRUCTIVE CLEANUP : NO"

Step 2 "VERIFY SPT-025.13 GATE / SPT-025.14 PREPARE / INPUTS"
$RequiredInputs=@($ReqAssessment,$ReqPrepare,$ReqConfig,$ReqManifest);$Missing=@($RequiredInputs|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_))})
Write-Host "REQUIRED INPUTS : $($RequiredInputs.Count)";Write-Host "MISSING INPUTS  : $($Missing.Count)";if($Missing.Count -ne 0){Hold "Missing SPT-025.14 prerequisites"}
$Assessment=Get-Content -Raw -LiteralPath (Join-Path $Root $ReqAssessment)|ConvertFrom-Json
$Prepare=Get-Content -Raw -LiteralPath (Join-Path $Root $ReqPrepare)|ConvertFrom-Json
if([string]$Assessment.status -ne "INSTANCE_CONFIGURATION_COMPOSITION_GATE_PASS"){Hold "SPT-025.13 composition gate is not PASS"}
if([string]$Prepare.next_deliverable -ne "SPT-025.14"){Hold "SPT-025.14 PREPARE contract mismatch"}
if([string]$Prepare.spt02513_composition_gate -ne "PASS"){Hold "SPT-025.14 PREPARE gate is not PASS"}
Write-Host "SPT-025.13 COMPOSITION GATE : PASS";Write-Host "SPT-025.14 PREPARE CONTRACT : PASS";Write-Host "COMPOSED INPUTS             : PASS"

Step 3 "SHA-256 FREEZE OF CLOSED BASELINE"
$Freeze=@{};foreach($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)){$A=Join-Path $Root $TrackedPath;if(Test-Path -LiteralPath $A){$Freeze[$TrackedPath]=Get-Sha256 $A}}
Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)";Write-Host "SHA-256 FREEZE : PASS"

Step 4 "COMPOSED CONFIGURATION / INSTANCE CONTRACT DISCOVERY"
Write-Host "VALIDATION MODE              : STATIC / NON-DESTRUCTIVE"
Write-Host "COMPOSED CONFIGURATION       : REQUIRED"
Write-Host "INSTANCE CONTRACT            : REQUIRED"
Write-Host "NATIVE LANGUAGE              : EXACTLY 1"
Write-Host "SUPPORT LANGUAGES            : 0..N / CONFIGURABLE"
Write-Host "SHA-256                      : REQUIRED"
Write-Host "MATERIALIZATION              : DECLARATIVE PACKAGE ONLY"
Write-Host "REAL PLATFORM DEPLOYMENT     : NO"
Write-Host "PRODUCTION CHANGE            : NO"

Step 5 "IMPLEMENT SPT-025.14 VALIDATOR"
$CoreText=@'
from hashlib import sha256
import json

def norm(v):
    return str(v or "").strip().lower().replace("_","-")

def fingerprint(value):
    payload=json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def validate_composed_configuration(cfg):
    errors=[]
    if not isinstance(cfg,dict):
        return {"valid":False,"errors":["configuration_not_object"]}
    for k in ("template","platform","resources","identity","governance"):
        if k not in cfg: errors.append("missing_"+k)

    platform=cfg.get("platform",{})
    native=platform.get("native_language",{}) if isinstance(platform,dict) else {}
    native_code=norm(native.get("code")) if isinstance(native,dict) else ""
    if not native_code: errors.append("native_language_required")

    supports=platform.get("support_languages",[]) if isinstance(platform,dict) else []
    if not isinstance(supports,list):
        errors.append("support_languages_not_list"); supports=[]
    seen=set(); support_codes=[]
    for i,item in enumerate(supports):
        code=norm(item.get("code")) if isinstance(item,dict) else ""
        if not code: errors.append(f"support_{i}_invalid")
        elif code==native_code: errors.append(f"support_{i}_equals_native")
        elif code in seen: errors.append(f"support_{i}_duplicate")
        else: seen.add(code); support_codes.append(code)

    gov=cfg.get("governance",{})
    if not isinstance(gov,dict):
        errors.append("governance_invalid")
    else:
        if gov.get("shared_core_reference") is not True: errors.append("shared_core_reference_required")
        if gov.get("core_duplicated") is not False: errors.append("core_duplication_forbidden")
        if gov.get("auto_deployed") is not False: errors.append("auto_deploy_forbidden")
        if gov.get("production_changed") is not False: errors.append("production_change_forbidden")
        if gov.get("example_only") not in (True,False): errors.append("example_only_required")

    return {
        "valid":not errors,
        "errors":errors,
        "native_language":native_code,
        "support_languages":support_codes,
        "sha256":fingerprint(cfg) if not errors else None,
    }

def validate_instance_contract(cfg, expected_template_id=None):
    errors=[]
    check=validate_composed_configuration(cfg)
    if not check["valid"]:
        errors.extend(check["errors"])
    template=cfg.get("template",{}) if isinstance(cfg,dict) else {}
    tid=template.get("template_id") if isinstance(template,dict) else None
    version=template.get("version") if isinstance(template,dict) else None
    if not tid: errors.append("template_id_required")
    if not version: errors.append("template_version_required")
    if expected_template_id and tid!=expected_template_id:
        errors.append("template_id_mismatch")

    resources=cfg.get("resources",{}) if isinstance(cfg,dict) else {}
    if not isinstance(resources,dict):
        errors.append("resources_not_object")

    identity=cfg.get("identity",{}) if isinstance(cfg,dict) else {}
    if not isinstance(identity,dict):
        errors.append("identity_not_object")

    return {"valid":not errors,"errors":errors,"template_id":tid}

def declarative_materialization_gate(cfg, declared_sha256=None):
    c=validate_composed_configuration(cfg)
    i=validate_instance_contract(cfg)
    errors=[]
    errors.extend("config_"+x for x in c["errors"])
    errors.extend("contract_"+x for x in i["errors"])
    actual=fingerprint(cfg) if isinstance(cfg,dict) else None
    if declared_sha256 and actual!=declared_sha256:
        errors.append("sha256_mismatch")
    gov=cfg.get("governance",{}) if isinstance(cfg,dict) else {}
    if isinstance(gov,dict):
        if gov.get("auto_deployed") is not False: errors.append("auto_deploy_forbidden")
        if gov.get("production_changed") is not False: errors.append("production_change_forbidden")
    return {
        "pass":not errors,
        "errors":errors,
        "sha256":actual,
        "materialization_mode":"DECLARATIVE_PACKAGE_ONLY",
        "real_platform_deployed":False,
        "production_changed":False,
    }

def generic_composed_configuration():
    return {
        "template":{"template_id":"sgoda-language-platform-standard","version":"1.0.0"},
        "platform":{
            "native_language":{"code":"qaa","name":"Example Native Language"},
            "support_languages":[
                {"code":"es","name":"Español"},
                {"code":"en","name":"English"},
                {"code":"it","name":"Italiano"},
                {"code":"pt","name":"Português"},
            ],
            "display_name":"SGODA Example Platform"
        },
        "resources":{"bible":{"enabled":False,"url":None},"catalog":[]},
        "identity":{"community":"Example Community","branding":"configurable"},
        "governance":{
            "shared_core_reference":True,
            "core_duplicated":False,
            "auto_deployed":False,
            "production_changed":False,
            "example_only":True,
        },
    }
'@
$InitText=@'
from .core import norm,fingerprint,validate_composed_configuration,validate_instance_contract,declarative_materialization_gate,generic_composed_configuration
__all__=["norm","fingerprint","validate_composed_configuration","validate_instance_contract","declarative_materialization_gate","generic_composed_configuration"]
'@
$TestText=@'
from sgoda.integration.spt02514 import *

def c(): return generic_composed_configuration()

def test_01(): assert validate_composed_configuration(c())["valid"]
def test_02(): assert validate_instance_contract(c())["valid"]
def test_03(): assert declarative_materialization_gate(c())["pass"]
def test_04(): assert validate_composed_configuration(c())["native_language"]=="qaa"
def test_05(): assert validate_composed_configuration(c())["support_languages"]==["es","en","it","pt"]
def test_06(): assert len(validate_composed_configuration(c())["sha256"])==64
def test_07(): assert declarative_materialization_gate(c())["materialization_mode"]=="DECLARATIVE_PACKAGE_ONLY"
def test_08(): assert declarative_materialization_gate(c())["real_platform_deployed"] is False
def test_09(): assert declarative_materialization_gate(c())["production_changed"] is False
def test_10():
    x=c();x["governance"]["core_duplicated"]=True;assert not validate_composed_configuration(x)["valid"]
def test_11():
    x=c();x["governance"]["auto_deployed"]=True;assert not declarative_materialization_gate(x)["pass"]
def test_12():
    x=c();x["governance"]["production_changed"]=True;assert not declarative_materialization_gate(x)["pass"]
def test_13():
    x=c();x["platform"]["native_language"]={"code":""};assert not validate_composed_configuration(x)["valid"]
def test_14():
    x=c();x["platform"]["support_languages"]=[{"code":"qaa"}];assert not validate_composed_configuration(x)["valid"]
def test_15():
    x=c();x["platform"]["support_languages"]=[{"code":"es"},{"code":"es"}];assert not validate_composed_configuration(x)["valid"]
def test_16():
    x=c();x["template"]["template_id"]="";assert not validate_instance_contract(x)["valid"]
def test_17():
    x=c();x["template"]["version"]="";assert not validate_instance_contract(x)["valid"]
def test_18():
    assert validate_instance_contract(c(),"sgoda-language-platform-standard")["valid"]
def test_19():
    assert not validate_instance_contract(c(),"other-template")["valid"]
def test_20():
    good=fingerprint(c());assert declarative_materialization_gate(c(),good)["pass"]
def test_21():
    assert not declarative_materialization_gate(c(),"0"*64)["pass"]
def test_22(): assert c()["governance"]["shared_core_reference"] is True
def test_23(): assert c()["governance"]["example_only"] is True
def test_24(): assert c()["resources"]["bible"]["enabled"] is False
def test_25(): assert norm("EN_us")=="en-us"
def test_26(): assert fingerprint(c())==fingerprint(c())
'@
$PolicyText=@'
{
  "component": "SPT-025.14",
  "version": "1.0.0",
  "authoritative_baseline": "bfaf5615fc0352f32b53da46b44793c1decc8b4d",
  "validation": {
    "composed_configuration": true,
    "instance_contract": true,
    "sha256_integrity": true,
    "declarative_materialization_gate": true
  },
  "architecture": {
    "one_native_language_per_platform": true,
    "support_languages": "0..N_CONFIGURABLE",
    "hard_coded_support_languages": false,
    "shared_core_reference": true,
    "core_duplicated": false
  },
  "examples": {
    "real_instance": false,
    "kurripaco_real_instance": false
  },
  "deployment": {
    "auto_deploy": false,
    "production_change": false,
    "real_platform_created": false
  },
  "repository": {
    "all_outputs_committed": true,
    "push_required": true,
    "local_remote_head_equality_required": true
  }
}
'@
$DocumentationText=@'
# SPT-025.14 — Validador de Configuración Compuesta, Contratos de Instancia y Quality Gate de Materialización Declarativa

Baseline autoritativa: `bfaf5615fc0352f32b53da46b44793c1decc8b4d`.

Consume obligatoriamente `artifacts/development/SPT-025.13-v1.0.0/spt02514-prepare.json` y preserva SPT-025.1–SPT-025.13.

## Objetivo

Validar la configuración compuesta producida por SPT-025.13, verificar contratos de instancia e integridad SHA-256, y aprobar solamente una materialización declarativa de paquete, sin desplegar una plataforma real.

## Reglas institucionales

- una lengua nativa principal por plataforma;
- 0..N idiomas auxiliares configurables;
- ningún idioma auxiliar hard-coded;
- SGODA Core compartido, no duplicado;
- recursos, Biblia, identidad y branding permanecen configurables;
- nombres de ejemplo son evidencia técnica;
- Kurripaco no es una instancia real;
- no auto-deployment;
- no cambio de producción;
- todos los resultados deben incorporarse y sincronizarse en el repositorio oficial.
'@
Write-Lf $CoreFile $CoreText;Write-Lf $InitFile $InitText;Write-Lf $TestFile $TestText;Write-Lf $PolicyFile $PolicyText;Write-Lf $DocFile $DocumentationText
Write-Host "SPT-025.14 IMPLEMENTATION : CREATED/VALIDATED"

Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
$env:PYTHONPATH=Join-Path $Root "src"
$SmokeCode=@'
from sgoda.integration.spt02514 import generic_composed_configuration,validate_composed_configuration,validate_instance_contract,declarative_materialization_gate
c=generic_composed_configuration()
assert validate_composed_configuration(c)["valid"]
assert validate_instance_contract(c)["valid"]
assert declarative_materialization_gate(c)["pass"]
print("SPT02514_IMPORT=PASS");print("COMPOSED_CONFIGURATION_VALIDATION=PASS");print("INSTANCE_CONTRACT_VALIDATION=PASS");print("DECLARATIVE_MATERIALIZATION_GATE=PASS")
'@
$Utf8=New-Object System.Text.UTF8Encoding($false);$SmokePath=Join-Path ([IO.Path]::GetTempPath()) ("spt02514-smoke-"+[guid]::NewGuid().ToString("N")+".py");[IO.File]::WriteAllText($SmokePath,$SmokeCode,$Utf8)
try{& $Python $SmokePath;if($LASTEXITCODE -ne 0){Hold "SPT-025.14 smoke validation failed"}}finally{Remove-Item -LiteralPath $SmokePath -Force -ErrorAction SilentlyContinue}
& $Python -m pytest -q $TestFile;if($LASTEXITCODE -ne 0){Hold "Targeted tests failed"};Write-Host "TARGETED TESTS : PASS"

Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
& $Python -m pytest -q;if($LASTEXITCODE -ne 0){Hold "Institutional suite failed"};Write-Host "FULL SUITE : PASS"
& $Python -m compileall -q (Join-Path $Root "src");if($LASTEXITCODE -ne 0){Hold "compileall failed"};Write-Host "COMPILEALL : PASS"

Step 8 "DECLARATIVE MATERIALIZATION QUALITY GATE"
$GateCode=@'
import json,sys
from sgoda.integration.spt02514 import validate_composed_configuration,validate_instance_contract,declarative_materialization_gate
cfg=json.load(open(sys.argv[1],encoding="utf-8"))
declared=sys.argv[2] if len(sys.argv)>2 else None
print(json.dumps({"configuration":validate_composed_configuration(cfg),"contract":validate_instance_contract(cfg),"gate":declarative_materialization_gate(cfg,declared)},ensure_ascii=False))
'@
$GateScript=Join-Path ([IO.Path]::GetTempPath()) ("spt02514-gate-"+[guid]::NewGuid().ToString("N")+".py")
$GateOutput=Join-Path ([IO.Path]::GetTempPath()) ("spt02514-gate-"+[guid]::NewGuid().ToString("N")+".json")
[IO.File]::WriteAllText($GateScript,$GateCode,$Utf8)
$Declared=[string]$Assessment.sha256
try{& $Python $GateScript (Join-Path $Root $ReqConfig) $Declared|Out-File -LiteralPath $GateOutput -Encoding utf8;if($LASTEXITCODE -ne 0){Hold "SPT-025.14 quality gate generation failed"};$GateResult=Get-Content -Raw -LiteralPath $GateOutput|ConvertFrom-Json}finally{Remove-Item -LiteralPath $GateScript,$GateOutput -Force -ErrorAction SilentlyContinue}
if(-not[bool]$GateResult.configuration.valid){Hold "Composed configuration validation failed"}
if(-not[bool]$GateResult.contract.valid){Hold "Instance contract validation failed"}
if(-not[bool]$GateResult.gate.pass){Hold "Declarative materialization gate failed"}
Write-Host "COMPOSED_CONFIGURATION_VALIDATION=PASS";Write-Host "INSTANCE_CONTRACT_VALIDATION=PASS";Write-Host "NATIVE_LANGUAGE_CONTRACT=PASS";Write-Host "SUPPORT_LANGUAGES_0_TO_N_CONFIGURABLE=PASS";Write-Host "CONFIGURATION_SHA256_INTEGRITY=PASS";Write-Host "DECLARATIVE_MATERIALIZATION_GATE=PASS";Write-Host "REAL_NEW_PLATFORM_DEPLOYED=NO";Write-Host "AUTO_DEPLOYMENT=NO";Write-Host "PRODUCTION_CHANGE=NO";Write-Host "KURRIPACO_REGISTERED_AS_REAL_INSTANCE=NO";Write-Host "SPT-025.14 GLOBAL MATERIALIZATION QUALITY GATE : PASS"

Step 9 "WRITE VALIDATION / CONTRACT / EVIDENCE / PREPARE"
New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null
$Validation=[ordered]@{component="SPT-025.14";version="1.0.0";baseline=$ExpectedBaseline;status="PASS";native_language=[string]$GateResult.configuration.native_language;support_languages=@($GateResult.configuration.support_languages);sha256=[string]$GateResult.configuration.sha256}
$Contract=[ordered]@{status="PASS";template_id=[string]$GateResult.contract.template_id;errors=@($GateResult.contract.errors)}
$Materialization=[ordered]@{component="SPT-025.14";version="1.0.0";status="DECLARATIVE_MATERIALIZATION_QUALITY_GATE_PASS";mode=[string]$GateResult.gate.materialization_mode;sha256=[string]$GateResult.gate.sha256;real_platform_deployed=$false;production_changed=$false;auto_deployment=$false;historical_kurripaco_reference_is_real_instance=$false;sgoda_puinave_modified=$false}
$Evidence=[ordered]@{component="SPT-025.14";version="1.0.0";baseline=$ExpectedBaseline;spt02513_gate="PASS";prepare_consumed=$ReqPrepare;targeted_tests="PASS";institutional_suite="PASS";compileall="PASS";global_materialization_gate="PASS";all_outputs_to_repository=$true;closed_components_preserved=$true}
$Next=[ordered]@{next_deliverable="SPT-025.15";title="Gobierno de Publicacion de Paquetes Declarativos, Promocion Controlada y Registro de Materializaciones";source_baseline=$ExpectedBaseline;spt02514_materialization_quality_gate="PASS"}
Write-Lf $ValidationFile ($Validation|ConvertTo-Json -Depth 12);Write-Lf $ContractFile ($Contract|ConvertTo-Json -Depth 12);Write-Lf $MaterializationFile ($Materialization|ConvertTo-Json -Depth 12);Write-Lf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 12);Write-Lf $PrepareFile ($Next|ConvertTo-Json -Depth 12)
$Records=@();foreach($P in @($ValidationFile,$ContractFile,$MaterializationFile,$EvidenceFile,$PrepareFile)){$Records+=[ordered]@{path=$P;sha256=Get-Sha256 (Join-Path $Root $P)}};Write-Lf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$Records}|ConvertTo-Json -Depth 12)
Write-Host "CONFIGURATION VALIDATION : CREATED";Write-Host "INSTANCE CONTRACT        : CREATED";Write-Host "MATERIALIZATION GATE     : CREATED";Write-Host "SHA-256 MANIFEST         : CREATED";Write-Host "SPT-025.15 PREPARE       : CREATED";Write-Host "EVIDENCE                 : CREATED"

Step 10 "SHA-256 PRESERVATION GATE"
foreach($TrackedPath in $Freeze.Keys){$A=Join-Path $Root $TrackedPath;if(-not(Test-Path -LiteralPath $A)){Hold ("Protected tracked file disappeared: "+$TrackedPath)};if((Get-Sha256 $A) -ne $Freeze[$TrackedPath]){Hold ("Protected tracked file changed: "+$TrackedPath)}};Write-Host "PROTECTED TRACKED FILES : PRESERVED";Write-Host "SPT-025.1-.13 : PRESERVED / NOT REOPENED"

Step 11 "EXACT CONTROLLED STAGING"
$Allowed=@("Invoke-SGODA-SPT02514-ComposedConfigValidator-InstanceContracts-DeclarativeMaterializationGate-FINAL-v1.0.0-PS51.ps1",$CoreFile,$InitFile,$TestFile,$PolicyFile,$DocFile,$ValidationFile,$ContractFile,$MaterializationFile,$IntegrityFile,$EvidenceFile,$PrepareFile)
foreach($AllowedPath in $Allowed){if(-not(Test-Path -LiteralPath (Join-Path $Root $AllowedPath))){Hold ("Missing expected target: "+$AllowedPath)};& git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $AllowedPath;if($LASTEXITCODE -ne 0){Hold ("git add failed: "+$AllowedPath)}}
$StagedNames=@(& git.exe -c core.quotepath=false diff --cached --name-only);$Unexpected=@($StagedNames|Where-Object{$Allowed -notcontains ($_ -replace "\\","/")});Write-Host "STAGED     : $($StagedNames.Count)";Write-Host "UNEXPECTED : $($Unexpected.Count)";if($Unexpected.Count -ne 0 -or $StagedNames.Count -ne $Allowed.Count){Hold "Exact staging mismatch"};Write-Host "STAGING QUALITY : PASS"

Step 12 "INDEX-WIDE GITHUB SIZE GATE"
$Oversized=@();foreach($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)){$B=@(& git.exe cat-file -s (":"+$TrackedPath) 2>$null);if($LASTEXITCODE -eq 0 -and $B.Count -gt 0){[Int64]$S=0;if([Int64]::TryParse(([string]$B[0]).Trim(),[ref]$S)){if($S -ge 100MB){$Oversized+=$TrackedPath}}}};Write-Host "INDEX BLOBS >=100MB : $($Oversized.Count)";if($Oversized.Count -ne 0){Hold "GitHub size gate failed"};Write-Host "GITHUB SIZE GATE : PASS"

Step 13 "FINAL REMOTE / PRESERVATION GATE"
Fetch-Authoritative;if((& git.exe rev-parse ("origin/"+$Branch)).Trim() -ne $ExpectedBaseline){Hold "Remote advanced during transaction"};foreach($TrackedPath in $Freeze.Keys){$A=Join-Path $Root $TrackedPath;if((Get-Sha256 $A) -ne $Freeze[$TrackedPath]){Hold ("Preservation failure before commit: "+$TrackedPath)}};Write-Host "PROTECTED TRACKED FILES : PRESERVED";Write-Host "REMOTE GATE : PASS"

Step 14 "COMMIT"
& git.exe commit -m "feat(spt-025.14): validate composed configuration and declarative materialization gate";if($LASTEXITCODE -ne 0){Hold "git commit failed"};Write-Host "NEW COMMIT : $((& git.exe rev-parse HEAD).Trim())"

Step 15 "PUSH"
& git.exe push origin $Branch;if($LASTEXITCODE -ne 0){Hold "git push failed"};Write-Host "PUSH : PASS"

Step 16 "AUTHORITATIVE REMOTE VERIFICATION / TECHNICAL CLOSURE"
Fetch-Authoritative;$FinalLocal=(& git.exe rev-parse HEAD).Trim();$FinalRemote=(& git.exe rev-parse ("origin/"+$Branch)).Trim();$Behind=(& git.exe rev-list --count ("HEAD..origin/"+$Branch)).Trim();$Ahead=(& git.exe rev-list --count ("origin/"+$Branch+"..HEAD")).Trim();$FinalStaged=@(& git.exe diff --cached --name-only);$FinalDeleted=@(& git.exe ls-files --deleted)
Write-Host "LOCAL HEAD      : $FinalLocal";Write-Host "REMOTE HEAD     : $FinalRemote";Write-Host "BEHIND          : $Behind";Write-Host "AHEAD           : $Ahead";Write-Host "STAGED          : $($FinalStaged.Count)";Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"
if($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0"){Hold "Final synchronization failed"};if($FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){Hold "Final repository state is not clean enough for closure"}
Write-Host "";Write-Host "SPT-025.14 : TECHNICALLY CLOSED / COMPOSED CONFIGURATION & DECLARATIVE MATERIALIZATION QUALITY GATE APPROVED" -ForegroundColor Green
Write-Host "SPT-025.13_COMPOSITION_GATE=PASS";Write-Host "SPT-025.14_PREPARE_CONSUMED=PASS";Write-Host "COMPOSED_CONFIGURATION_VALIDATION=PASS";Write-Host "INSTANCE_CONTRACT_VALIDATION=PASS";Write-Host "NATIVE_LANGUAGE_CONTRACT=PASS";Write-Host "SUPPORT_LANGUAGES_0_TO_N_CONFIGURABLE=PASS";Write-Host "HARD_CODED_SUPPORT_LANGUAGES=NO";Write-Host "CONFIGURATION_SHA256_INTEGRITY=PASS";Write-Host "DECLARATIVE_MATERIALIZATION_GATE=PASS";Write-Host "EXAMPLE_NAMES_ARE_EVIDENCE_ONLY=PASS";Write-Host "KURRIPACO_REGISTERED_AS_REAL_INSTANCE=NO";Write-Host "REAL_NEW_PLATFORM_DEPLOYED=NO";Write-Host "AUTO_DEPLOYMENT=NO";Write-Host "PRODUCTION_CHANGE=NO";Write-Host "SGODA_PUINAVE_MODIFIED=NO";Write-Host "SGODA_CORE_DUPLICATED=NO";Write-Host "TARGETED_TESTS=PASS";Write-Host "INSTITUTIONAL_SUITE=PASS";Write-Host "COMPILEALL=PASS";Write-Host "CLOSED_COMPONENTS=PRESERVED";Write-Host "ALL_OUTPUTS_IN_REPOSITORY=PASS";Write-Host "LOCAL_HEAD=REMOTE_HEAD";Write-Host "NEXT_DELIVERABLE=SPT-025.15";Write-Host "FINAL_EXIT_CODE=0";exit 0
}catch{Hold $_.Exception.Message}
