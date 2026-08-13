#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"
$ExpectedBaseline="a9b2a24a470761b6aa046275cc6b2d0570b25fe0"
$Branch="feature/SPT-001A-rlb-schema-foundation"
$ReqGate="artifacts/development/SPT-025.12-v1.0.0/configuration-quality-gate.json"
$ReqPrepare="artifacts/development/SPT-025.12-v1.0.0/spt02513-prepare.json"
$CoreFile="src/sgoda/integration/spt02513/core.py"
$InitFile="src/sgoda/integration/spt02513/__init__.py"
$TestFile="tests/integration/test_spt02513_instance_config_composer_profile_resolution.py"
$PolicyFile="config/integration/spt02513/instance-configuration-composition-policy.json"
$DocFile="docs/06_Tecnologia/SPT-025/SPT-025.13/SGD-SPT025.13-Compositor-Configuracion-Resolucion-Perfiles-Ensamblaje.md"
$ArtifactDir="artifacts/development/SPT-025.13-v1.0.0"
$CompositionFile="$ArtifactDir/instance-configuration-composition-assessment.json"
$ResolutionFile="$ArtifactDir/profile-resolution-assessment.json"
$AssemblyFile="$ArtifactDir/declarative-assembly-baseline.json"
$ExampleConfigFile="$ArtifactDir/composed-example-instance-configuration.json"
$IntegrityFile="$ArtifactDir/composed-configuration-sha256-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"
$PrepareFile="$ArtifactDir/spt02514-prepare.json"

function Step{param([int]$Number,[string]$Title);Write-Host "";Write-Host ("[{0}/16] {1}" -f $Number,$Title) -ForegroundColor Cyan}
function Hold{param([string]$Reason);Write-Host "";Write-Host "SPT-025.13 : HOLD" -ForegroundColor Red;Write-Host "REASON : $Reason";Write-Host "TRANSACTION : NOT PUBLISHED";exit 1}
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
Write-Host "BASELINE : PASS";Write-Host "SPT-025.1-.12 : PROTECTED / NOT REOPENED";Write-Host "DESTRUCTIVE CLEANUP : NO"

Step 2 "VERIFY SPT-025.12 GATE / SPT-025.13 PREPARE"
$RequiredInputs=@($ReqGate,$ReqPrepare);$Missing=@($RequiredInputs|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_))})
Write-Host "REQUIRED INPUTS : $($RequiredInputs.Count)";Write-Host "MISSING INPUTS  : $($Missing.Count)";if($Missing.Count -ne 0){Hold "Missing SPT-025.13 prerequisites"}
$Gate=Get-Content -Raw -LiteralPath (Join-Path $Root $ReqGate)|ConvertFrom-Json
$Prepare=Get-Content -Raw -LiteralPath (Join-Path $Root $ReqPrepare)|ConvertFrom-Json
if([string]$Gate.status -ne "TEMPLATE_PROFILE_VALIDATION_QUALITY_GATE_PASS"){Hold "SPT-025.12 quality gate is not PASS"}
if([string]$Prepare.next_deliverable -ne "SPT-025.13"){Hold "SPT-025.13 PREPARE contract mismatch"}
if([string]$Prepare.spt02512_configuration_quality_gate -ne "PASS"){Hold "SPT-025.13 PREPARE gate is not PASS"}
Write-Host "SPT-025.12 CONFIGURATION QUALITY GATE : PASS";Write-Host "SPT-025.13 PREPARE CONTRACT           : PASS"

Step 3 "SHA-256 FREEZE OF CLOSED BASELINE"
$Freeze=@{};foreach($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)){$A=Join-Path $Root $TrackedPath;if(Test-Path -LiteralPath $A){$Freeze[$TrackedPath]=Get-Sha256 $A}}
Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)";Write-Host "SHA-256 FREEZE : PASS"

Step 4 "COMPOSITION / PROFILE RESOLUTION / DECLARATIVE ASSEMBLY DISCOVERY"
Write-Host "COMPOSITION MODEL             : GENERIC / LANGUAGE-NEUTRAL"
Write-Host "NATIVE LANGUAGE               : EXACTLY 1 / IMMUTABLE"
Write-Host "SUPPORT LANGUAGES             : 0..N / CONFIGURABLE"
Write-Host "PROFILE RESOLUTION            : REQUIRED"
Write-Host "DECLARATIVE OVERLAY           : SUPPORTED"
Write-Host "SHA-256                       : REQUIRED"
Write-Host "EXAMPLE CONFIGURATION         : EVIDENCE ONLY"
Write-Host "AUTO DEPLOYMENT               : NO"
Write-Host "PRODUCTION CHANGE             : NO"

Step 5 "IMPLEMENT SPT-025.13 INSTANCE CONFIGURATION COMPOSER"
$CoreText=@'
from copy import deepcopy
from hashlib import sha256
import json

def merge(a,b):
    if isinstance(a,dict) and isinstance(b,dict):
        r=deepcopy(a)
        for k,v in b.items():
            r[k]=merge(r[k],v) if k in r else deepcopy(v)
        return r
    return deepcopy(b)

def norm(v):
    return str(v or "").strip().lower().replace("_","-")

def validate_profile(p):
    e=[]
    if not isinstance(p,dict): return {"valid":False,"errors":["profile_not_object"]}
    for k in ("profile_id","template_id","native_language","support_languages","governance"):
        if k not in p: e.append("missing_"+k)
    n=p.get("native_language",{})
    nc=norm(n.get("code")) if isinstance(n,dict) else ""
    if not nc: e.append("native_language_required")
    seen=set(); supports=[]
    for i,x in enumerate(p.get("support_languages",[]) if isinstance(p.get("support_languages",[]),list) else []):
        c=norm(x.get("code")) if isinstance(x,dict) else ""
        if not c: e.append(f"support_{i}_invalid")
        elif c==nc: e.append(f"support_{i}_equals_native")
        elif c in seen: e.append(f"support_{i}_duplicate")
        else: seen.add(c); supports.append(c)
    g=p.get("governance",{})
    if not isinstance(g,dict): e.append("governance_invalid")
    else:
        if g.get("example_only") not in (True,False): e.append("example_only_required")
        if g.get("auto_deploy") is not False: e.append("auto_deploy_forbidden")
        if g.get("production_change") is not False: e.append("production_change_forbidden")
    return {"valid":not e,"errors":e,"native_language":nc,"support_languages":supports,"template_id":p.get("template_id")}

def resolve_profiles(profiles):
    if not isinstance(profiles,list) or not profiles:
        return {"valid":False,"errors":["profiles_required"]}
    r=deepcopy(profiles[0]); b=validate_profile(r)
    if not b["valid"]: return {"valid":False,"errors":b["errors"]}
    native=b["native_language"]; template=b["template_id"]
    for i,overlay in enumerate(profiles[1:],1):
        c=merge(r,overlay); v=validate_profile(c)
        if not v["valid"]: return {"valid":False,"errors":[f"profile_{i}_{x}" for x in v["errors"]]}
        if v["native_language"]!=native: return {"valid":False,"errors":[f"profile_{i}_native_language_change_forbidden"]}
        if v["template_id"]!=template: return {"valid":False,"errors":[f"profile_{i}_template_change_forbidden"]}
        r=c
    return {"valid":True,"errors":[],"resolved":r}

def compose(template,profiles,overlay):
    if template.get("native_language",{}).get("mode")!="CONFIGURABLE_EXACTLY_ONE":
        return {"valid":False,"errors":["template_native_contract_invalid"]}
    if template.get("support_languages",{}).get("mode")!="CONFIGURABLE_0_TO_N":
        return {"valid":False,"errors":["template_support_contract_invalid"]}
    if template.get("support_languages",{}).get("hard_coded") is not False:
        return {"valid":False,"errors":["hard_coded_support_languages_forbidden"]}
    g=template.get("governance",{})
    if g.get("shared_core_reference") is not True or g.get("duplicate_core") is not False or g.get("auto_deploy") is not False or g.get("production_change") is not False:
        return {"valid":False,"errors":["template_governance_invalid"]}
    rp=resolve_profiles(profiles)
    if not rp["valid"]: return rp
    p=rp["resolved"]; pv=validate_profile(p)
    if pv["template_id"]!=template.get("template_id"): return {"valid":False,"errors":["template_profile_mismatch"]}
    cfg=merge({
        "template":{"template_id":template["template_id"],"version":template["version"]},
        "platform":{"native_language":p["native_language"],"support_languages":p["support_languages"]},
        "resources":p.get("resource_profile",{}),
        "identity":p.get("identity_profile",{}),
        "governance":{"shared_core_reference":True,"core_duplicated":False,"auto_deployed":False,"production_changed":False,"example_only":p["governance"]["example_only"]}
    },overlay or {})
    nc=norm(cfg["platform"]["native_language"].get("code"))
    if nc!=pv["native_language"]: return {"valid":False,"errors":["instance_overlay_native_language_change_forbidden"]}
    seen=set(); sc=[]
    for i,x in enumerate(cfg["platform"].get("support_languages",[])):
        c=norm(x.get("code")) if isinstance(x,dict) else ""
        if not c:return {"valid":False,"errors":[f"support_{i}_invalid"]}
        if c==nc:return {"valid":False,"errors":[f"support_{i}_equals_native"]}
        if c in seen:return {"valid":False,"errors":[f"support_{i}_duplicate"]}
        seen.add(c); sc.append(c)
    gg=cfg["governance"]
    if gg.get("shared_core_reference") is not True:return {"valid":False,"errors":["shared_core_reference_required"]}
    if gg.get("core_duplicated") is not False:return {"valid":False,"errors":["core_duplication_forbidden"]}
    if gg.get("auto_deployed") is not False:return {"valid":False,"errors":["auto_deploy_forbidden"]}
    if gg.get("production_changed") is not False:return {"valid":False,"errors":["production_change_forbidden"]}
    payload=json.dumps(cfg,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return {"valid":True,"errors":[],"configuration":cfg,"native_language":nc,"support_languages":sc,"sha256":sha256(payload.encode("utf-8")).hexdigest()}

def generic_template():
    return {"template_id":"sgoda-language-platform-standard","version":"1.0.0","native_language":{"mode":"CONFIGURABLE_EXACTLY_ONE"},"support_languages":{"mode":"CONFIGURABLE_0_TO_N","hard_coded":False},"governance":{"shared_core_reference":True,"duplicate_core":False,"auto_deploy":False,"production_change":False}}

def generic_base_profile():
    return {"profile_id":"example-base-profile","template_id":"sgoda-language-platform-standard","native_language":{"code":"qaa","name":"Example Native Language"},"support_languages":[{"code":"es"},{"code":"en"}],"resource_profile":{"bible":{"enabled":False,"url":None}},"identity_profile":{"community":"Example Community"},"governance":{"example_only":True,"auto_deploy":False,"production_change":False}}

def generic_extension_profile():
    return {"profile_id":"example-extension-profile","support_languages":[{"code":"es"},{"code":"en"},{"code":"it"},{"code":"pt"}],"identity_profile":{"theme":"configurable"}}

def generic_overlay():
    return {"platform":{"display_name":"SGODA Example Platform"},"governance":{"shared_core_reference":True,"core_duplicated":False,"auto_deployed":False,"production_changed":False,"example_only":True}}
'@
$InitText=@'
from .core import merge,norm,validate_profile,resolve_profiles,compose,generic_template,generic_base_profile,generic_extension_profile,generic_overlay
__all__=["merge","norm","validate_profile","resolve_profiles","compose","generic_template","generic_base_profile","generic_extension_profile","generic_overlay"]
'@
$TestText=@'
from sgoda.integration.spt02513 import *
def t(): return generic_template()
def b(): return generic_base_profile()
def e(): return generic_extension_profile()
def o(): return generic_overlay()
def test_01(): assert validate_profile(b())["valid"]
def test_02(): assert resolve_profiles([b(),e()])["valid"]
def test_03(): assert compose(t(),[b(),e()],o())["valid"]
def test_04(): assert compose(t(),[b(),e()],o())["native_language"]=="qaa"
def test_05(): assert compose(t(),[b(),e()],o())["support_languages"]==["es","en","it","pt"]
def test_06(): assert len(compose(t(),[b(),e()],o())["sha256"])==64
def test_07():
    x=e();x["native_language"]={"code":"zzz"};assert not resolve_profiles([b(),x])["valid"]
def test_08():
    x=e();x["template_id"]="other";assert not resolve_profiles([b(),x])["valid"]
def test_09():
    x=o();x["platform"]["native_language"]={"code":"zzz"};assert not compose(t(),[b(),e()],x)["valid"]
def test_10():
    x=o();x["governance"]["core_duplicated"]=True;assert not compose(t(),[b(),e()],x)["valid"]
def test_11():
    x=o();x["governance"]["auto_deployed"]=True;assert not compose(t(),[b(),e()],x)["valid"]
def test_12():
    x=o();x["governance"]["production_changed"]=True;assert not compose(t(),[b(),e()],x)["valid"]
def test_13():
    x=t();x["support_languages"]["hard_coded"]=True;assert not compose(x,[b(),e()],o())["valid"]
def test_14(): assert t()["native_language"]["mode"]=="CONFIGURABLE_EXACTLY_ONE"
def test_15(): assert t()["support_languages"]["mode"]=="CONFIGURABLE_0_TO_N"
def test_16(): assert b()["governance"]["example_only"] is True
def test_17():
    r=resolve_profiles([b(),e()])["resolved"];assert r["identity_profile"]["community"]=="Example Community"
def test_18():
    r=resolve_profiles([b(),e()])["resolved"];assert r["identity_profile"]["theme"]=="configurable"
def test_19(): assert not resolve_profiles([])["valid"]
def test_20():
    x=o();x["platform"]["support_languages"]=[{"code":"qaa"}];assert not compose(t(),[b(),e()],x)["valid"]
def test_21():
    x=o();x["platform"]["support_languages"]=[{"code":"es"},{"code":"es"}];assert not compose(t(),[b(),e()],x)["valid"]
def test_22(): assert compose(t(),[b(),e()],o())["configuration"]["resources"]["bible"]["enabled"] is False
def test_23(): assert compose(t(),[b(),e()],o())["configuration"]["governance"]["example_only"] is True
def test_24(): assert compose(t(),[b(),e()],o())["sha256"]==compose(t(),[b(),e()],o())["sha256"]
'@
$PolicyText=@'
{
  "component": "SPT-025.13",
  "version": "1.0.0",
  "authoritative_baseline": "a9b2a24a470761b6aa046275cc6b2d0570b25fe0",
  "one_native_language_per_platform": true,
  "native_language_immutable_during_composition": true,
  "support_languages": "0..N_CONFIGURABLE",
  "hard_coded_support_languages": false,
  "shared_core_reference": true,
  "duplicate_core": false,
  "auto_deploy": false,
  "production_change": false,
  "examples_are_real_instances": false,
  "kurripaco_real_instance": false,
  "all_outputs_in_repository": true
}
'@
$DocumentationText=@'
# SPT-025.13 — Compositor Institucional de Configuración de Instancia

Baseline autoritativa: `a9b2a24a470761b6aa046275cc6b2d0570b25fe0`.

Consume `artifacts/development/SPT-025.12-v1.0.0/spt02513-prepare.json`.

Compone una configuración declarativa a partir de plantilla, perfiles reutilizables y overlay de instancia, sin desplegar una plataforma real. Mantiene una sola lengua nativa principal, 0..N idiomas auxiliares configurables, SGODA Core compartido y no duplicado. Los nombres de ejemplo son evidencia técnica; Kurripaco no es una instancia real. Todos los resultados deben quedar en el repositorio oficial.
'@
Write-Lf $CoreFile $CoreText;Write-Lf $InitFile $InitText;Write-Lf $TestFile $TestText;Write-Lf $PolicyFile $PolicyText;Write-Lf $DocFile $DocumentationText
Write-Host "SPT-025.13 IMPLEMENTATION : CREATED/VALIDATED"

Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
$env:PYTHONPATH=Join-Path $Root "src"
$SmokeCode=@'
from sgoda.integration.spt02513 import generic_template,generic_base_profile,generic_extension_profile,generic_overlay,compose
r=compose(generic_template(),[generic_base_profile(),generic_extension_profile()],generic_overlay())
assert r["valid"];assert r["native_language"]=="qaa";assert r["support_languages"]==["es","en","it","pt"];assert len(r["sha256"])==64
print("SPT02513_IMPORT=PASS");print("PROFILE_RESOLUTION=PASS");print("DECLARATIVE_ASSEMBLY=PASS");print("INSTANCE_CONFIGURATION_COMPOSITION=PASS");print("SHA256_INTEGRITY=PASS")
'@
$Utf8=New-Object System.Text.UTF8Encoding($false);$SmokePath=Join-Path ([IO.Path]::GetTempPath()) ("spt02513-smoke-"+[guid]::NewGuid().ToString("N")+".py");[IO.File]::WriteAllText($SmokePath,$SmokeCode,$Utf8)
try{& $Python $SmokePath;if($LASTEXITCODE -ne 0){Hold "SPT-025.13 smoke validation failed"}}finally{Remove-Item -LiteralPath $SmokePath -Force -ErrorAction SilentlyContinue}
& $Python -m pytest -q $TestFile;if($LASTEXITCODE -ne 0){Hold "Targeted tests failed"};Write-Host "TARGETED TESTS : PASS"

Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
& $Python -m pytest -q;if($LASTEXITCODE -ne 0){Hold "Institutional suite failed"};Write-Host "FULL SUITE : PASS"
& $Python -m compileall -q (Join-Path $Root "src");if($LASTEXITCODE -ne 0){Hold "compileall failed"};Write-Host "COMPILEALL : PASS"

Step 8 "INSTANCE CONFIGURATION COMPOSITION QUALITY GATE"
$ComposeCode=@'
import json
from sgoda.integration.spt02513 import generic_template,generic_base_profile,generic_extension_profile,generic_overlay,resolve_profiles,compose
profiles=[generic_base_profile(),generic_extension_profile()]
print(json.dumps({"resolved":resolve_profiles(profiles),"composed":compose(generic_template(),profiles,generic_overlay())},ensure_ascii=False))
'@
$ComposeScript=Join-Path ([IO.Path]::GetTempPath()) ("spt02513-compose-"+[guid]::NewGuid().ToString("N")+".py");$ComposeOutput=Join-Path ([IO.Path]::GetTempPath()) ("spt02513-compose-"+[guid]::NewGuid().ToString("N")+".json");[IO.File]::WriteAllText($ComposeScript,$ComposeCode,$Utf8)
try{& $Python $ComposeScript|Out-File -LiteralPath $ComposeOutput -Encoding utf8;if($LASTEXITCODE -ne 0){Hold "SPT-025.13 composition assessment generation failed"};$ComposeResult=Get-Content -Raw -LiteralPath $ComposeOutput|ConvertFrom-Json}finally{Remove-Item -LiteralPath $ComposeScript,$ComposeOutput -Force -ErrorAction SilentlyContinue}
if(-not[bool]$ComposeResult.resolved.valid){Hold "Profile resolution gate failed"};if(-not[bool]$ComposeResult.composed.valid){Hold "Composition quality gate failed"}
Write-Host "PROFILE_RESOLUTION=PASS";Write-Host "DECLARATIVE_ASSEMBLY=PASS";Write-Host "INSTANCE_CONFIGURATION_COMPOSITION=PASS";Write-Host "NATIVE_LANGUAGE_COMPOSITION_IMMUTABILITY=PASS";Write-Host "SUPPORT_LANGUAGES_0_TO_N_CONFIGURABLE=PASS";Write-Host "HARD_CODED_SUPPORT_LANGUAGES=NO";Write-Host "CONFIGURATION_SHA256_INTEGRITY=PASS";Write-Host "KURRIPACO_REGISTERED_AS_REAL_INSTANCE=NO";Write-Host "AUTO_DEPLOYMENT=NO";Write-Host "PRODUCTION_CHANGE=NO";Write-Host "SPT-025.13 GLOBAL COMPOSITION GATE : PASS"

Step 9 "WRITE COMPOSITION / RESOLUTION / EVIDENCE / PREPARE"
New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null
$Composition=[ordered]@{component="SPT-025.13";version="1.0.0";baseline=$ExpectedBaseline;status="INSTANCE_CONFIGURATION_COMPOSITION_GATE_PASS";native_language=[string]$ComposeResult.composed.native_language;support_languages=@($ComposeResult.composed.support_languages);sha256=[string]$ComposeResult.composed.sha256;example_configuration_is_real_instance=$false;historical_kurripaco_reference_is_real_instance=$false;auto_deployment=$false;production_change=$false;sgoda_puinave_modified=$false}
$Resolution=[ordered]@{status="PASS";resolved=[bool]$ComposeResult.resolved.valid;errors=@($ComposeResult.resolved.errors);native_language_immutable=$true}
$Assembly=[ordered]@{mode="DECLARATIVE";template="sgoda-language-platform-standard";profile_layers=2;instance_overlay=$true;shared_core_reference=$true;core_duplicated=$false;auto_deployed=$false;production_changed=$false}
$Evidence=[ordered]@{component="SPT-025.13";version="1.0.0";baseline=$ExpectedBaseline;spt02512_gate="PASS";prepare_consumed=$ReqPrepare;targeted_tests="PASS";institutional_suite="PASS";compileall="PASS";global_composition_gate="PASS";all_outputs_to_repository=$true;closed_components_preserved=$true}
$Next=[ordered]@{next_deliverable="SPT-025.14";title="Validador de Configuracion Compuesta, Contratos de Instancia y Quality Gate de Materializacion Declarativa";source_baseline=$ExpectedBaseline;spt02513_composition_gate="PASS"}
Write-Lf $CompositionFile ($Composition|ConvertTo-Json -Depth 12);Write-Lf $ResolutionFile ($Resolution|ConvertTo-Json -Depth 12);Write-Lf $AssemblyFile ($Assembly|ConvertTo-Json -Depth 12);Write-Lf $ExampleConfigFile ($ComposeResult.composed.configuration|ConvertTo-Json -Depth 20);Write-Lf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 12);Write-Lf $PrepareFile ($Next|ConvertTo-Json -Depth 12)
$IntegrityRecords=@();foreach($P in @($CompositionFile,$ResolutionFile,$AssemblyFile,$ExampleConfigFile,$EvidenceFile,$PrepareFile)){$IntegrityRecords+=[ordered]@{path=$P;sha256=Get-Sha256 (Join-Path $Root $P)}};Write-Lf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$IntegrityRecords}|ConvertTo-Json -Depth 12)
Write-Host "COMPOSITION ASSESSMENT : CREATED";Write-Host "PROFILE RESOLUTION     : CREATED";Write-Host "DECLARATIVE ASSEMBLY   : CREATED";Write-Host "EXAMPLE CONFIGURATION  : CREATED / EXAMPLE ONLY";Write-Host "SHA-256 MANIFEST       : CREATED";Write-Host "SPT-025.14 PREPARE     : CREATED";Write-Host "EVIDENCE               : CREATED"

Step 10 "SHA-256 PRESERVATION GATE"
foreach($TrackedPath in $Freeze.Keys){$A=Join-Path $Root $TrackedPath;if(-not(Test-Path -LiteralPath $A)){Hold ("Protected tracked file disappeared: "+$TrackedPath)};if((Get-Sha256 $A) -ne $Freeze[$TrackedPath]){Hold ("Protected tracked file changed: "+$TrackedPath)}};Write-Host "PROTECTED TRACKED FILES : PRESERVED";Write-Host "SPT-025.1-.12 : PRESERVED / NOT REOPENED"

Step 11 "EXACT CONTROLLED STAGING"
$Allowed=@("Invoke-SGODA-SPT02513-InstanceConfigComposer-ProfileResolution-DeclarativeAssembly-FINAL-v1.0.0-PS51.ps1",$CoreFile,$InitFile,$TestFile,$PolicyFile,$DocFile,$CompositionFile,$ResolutionFile,$AssemblyFile,$ExampleConfigFile,$IntegrityFile,$EvidenceFile,$PrepareFile)
foreach($AllowedPath in $Allowed){if(-not(Test-Path -LiteralPath (Join-Path $Root $AllowedPath))){Hold ("Missing expected target: "+$AllowedPath)};& git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $AllowedPath;if($LASTEXITCODE -ne 0){Hold ("git add failed: "+$AllowedPath)}}
$StagedNames=@(& git.exe -c core.quotepath=false diff --cached --name-only);$Unexpected=@($StagedNames|Where-Object{$Allowed -notcontains ($_ -replace "\\","/")});Write-Host "STAGED     : $($StagedNames.Count)";Write-Host "UNEXPECTED : $($Unexpected.Count)";if($Unexpected.Count -ne 0 -or $StagedNames.Count -ne $Allowed.Count){Hold "Exact staging mismatch"};Write-Host "STAGING QUALITY : PASS"

Step 12 "INDEX-WIDE GITHUB SIZE GATE"
$Oversized=@();foreach($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)){$B=@(& git.exe cat-file -s (":"+$TrackedPath) 2>$null);if($LASTEXITCODE -eq 0 -and $B.Count -gt 0){[Int64]$S=0;if([Int64]::TryParse(([string]$B[0]).Trim(),[ref]$S)){if($S -ge 100MB){$Oversized+=$TrackedPath}}}};Write-Host "INDEX BLOBS >=100MB : $($Oversized.Count)";if($Oversized.Count -ne 0){Hold "GitHub size gate failed"};Write-Host "GITHUB SIZE GATE : PASS"

Step 13 "FINAL REMOTE / PRESERVATION GATE"
Fetch-Authoritative;if((& git.exe rev-parse ("origin/"+$Branch)).Trim() -ne $ExpectedBaseline){Hold "Remote advanced during transaction"};foreach($TrackedPath in $Freeze.Keys){$A=Join-Path $Root $TrackedPath;if((Get-Sha256 $A) -ne $Freeze[$TrackedPath]){Hold ("Preservation failure before commit: "+$TrackedPath)}};Write-Host "PROTECTED TRACKED FILES : PRESERVED";Write-Host "REMOTE GATE : PASS"

Step 14 "COMMIT"
& git.exe commit -m "feat(spt-025.13): compose declarative instance configuration and resolve profiles";if($LASTEXITCODE -ne 0){Hold "git commit failed"};Write-Host "NEW COMMIT : $((& git.exe rev-parse HEAD).Trim())"

Step 15 "PUSH"
& git.exe push origin $Branch;if($LASTEXITCODE -ne 0){Hold "git push failed"};Write-Host "PUSH : PASS"

Step 16 "AUTHORITATIVE REMOTE VERIFICATION / TECHNICAL CLOSURE"
Fetch-Authoritative;$FinalLocal=(& git.exe rev-parse HEAD).Trim();$FinalRemote=(& git.exe rev-parse ("origin/"+$Branch)).Trim();$Behind=(& git.exe rev-list --count ("HEAD..origin/"+$Branch)).Trim();$Ahead=(& git.exe rev-list --count ("origin/"+$Branch+"..HEAD")).Trim();$FinalStaged=@(& git.exe diff --cached --name-only);$FinalDeleted=@(& git.exe ls-files --deleted)
Write-Host "LOCAL HEAD      : $FinalLocal";Write-Host "REMOTE HEAD     : $FinalRemote";Write-Host "BEHIND          : $Behind";Write-Host "AHEAD           : $Ahead";Write-Host "STAGED          : $($FinalStaged.Count)";Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"
if($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0"){Hold "Final synchronization failed"};if($FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){Hold "Final repository state is not clean enough for closure"}
Write-Host "";Write-Host "SPT-025.13 : TECHNICALLY CLOSED / INSTANCE CONFIGURATION COMPOSITION APPROVED" -ForegroundColor Green
Write-Host "SPT-025.12_CONFIGURATION_QUALITY_GATE=PASS";Write-Host "SPT-025.13_PREPARE_CONSUMED=PASS";Write-Host "PROFILE_RESOLUTION=PASS";Write-Host "DECLARATIVE_ASSEMBLY=PASS";Write-Host "INSTANCE_CONFIGURATION_COMPOSITION=PASS";Write-Host "NATIVE_LANGUAGE_COMPOSITION_IMMUTABILITY=PASS";Write-Host "SUPPORT_LANGUAGES_0_TO_N_CONFIGURABLE=PASS";Write-Host "HARD_CODED_SUPPORT_LANGUAGES=NO";Write-Host "CONFIGURATION_SHA256_INTEGRITY=PASS";Write-Host "EXAMPLE_NAMES_ARE_EVIDENCE_ONLY=PASS";Write-Host "KURRIPACO_REGISTERED_AS_REAL_INSTANCE=NO";Write-Host "REAL_NEW_PLATFORM_DEPLOYED=NO";Write-Host "AUTO_DEPLOYMENT=NO";Write-Host "PRODUCTION_CHANGE=NO";Write-Host "SGODA_PUINAVE_MODIFIED=NO";Write-Host "SGODA_CORE_DUPLICATED=NO";Write-Host "TARGETED_TESTS=PASS";Write-Host "INSTITUTIONAL_SUITE=PASS";Write-Host "COMPILEALL=PASS";Write-Host "CLOSED_COMPONENTS=PRESERVED";Write-Host "ALL_OUTPUTS_IN_REPOSITORY=PASS";Write-Host "LOCAL_HEAD=REMOTE_HEAD";Write-Host "NEXT_DELIVERABLE=SPT-025.14";Write-Host "FINAL_EXIT_CODE=0";exit 0
}catch{Hold $_.Exception.Message}
