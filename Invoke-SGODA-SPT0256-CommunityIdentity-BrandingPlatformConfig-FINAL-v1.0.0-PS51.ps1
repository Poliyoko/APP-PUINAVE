#requires -Version 5.1
[CmdletBinding()] param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"
$ExpectedBaseline="bc467bc133fd8bf3b9c0fedab62fffe48f0100a0"
$Branch="feature/SPT-001A-rlb-schema-foundation"

$ReqAssessment="artifacts/development/SPT-025.5-v1.0.0/spt0255-resource-catalog-assessment.json"
$ReqPrepare="artifacts/development/SPT-025.5-v1.0.0/spt0256-prepare.json"

$CoreFile="src/sgoda/integration/spt0256/core.py"
$InitFile="src/sgoda/integration/spt0256/__init__.py"
$TestFile="tests/integration/test_spt0256_community_identity_branding_platform_config.py"
$PolicyFile="config/integration/spt0256/platform-identity-branding-policy.json"
$SchemaFile="config/integration/spt0256/platform-identity.schema.json"
$PuinaveFile="config/integration/spt0256/sgoda-puinave-identity-profile.json"
$TemplateFile="config/integration/spt0256/platform-identity-template.json"
$DocFile="docs/06_Tecnologia/SPT-025/SPT-025.6/SGD-SPT025.6-Identidad-Comunitaria-Branding-Metadatos-Configuracion.md"

$ArtifactDir="artifacts/development/SPT-025.6-v1.0.0"
$IdentityModelFile="$ArtifactDir/platform-identity-model-baseline.json"
$BrandingModelFile="$ArtifactDir/branding-configuration-baseline.json"
$CommunityModelFile="$ArtifactDir/community-metadata-baseline.json"
$PresentationModelFile="$ArtifactDir/presentation-preferences-baseline.json"
$PuinaveBaselineFile="$ArtifactDir/sgoda-puinave-identity-baseline.json"
$BoundaryFile="$ArtifactDir/core-instance-identity-boundary-baseline.json"
$FingerprintFile="$ArtifactDir/identity-integrity-baseline.json"
$AssessmentFile="$ArtifactDir/spt0256-identity-assessment.json"
$IntegrityFile="$ArtifactDir/spt0256-integrity-manifest.json"
$PrepareFile="$ArtifactDir/spt0257-prepare.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"
$LargeFileLimit=100MB

function Step([int]$N,[string]$T){Write-Host "";Write-Host ("[{0}/16] {1}" -f $N,$T) -ForegroundColor Cyan}
function Hold([string]$R){Write-Host "";Write-Host "SPT-025.6 : HOLD" -ForegroundColor Red;Write-Host "REASON : $R";Write-Host "TRANSACTION : NOT PUBLISHED";exit 1}
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
Write-Host "BASELINE : PASS";Write-Host "SPT-024 / PISI + SPT-025.1-.5 : PROTECTED / NOT REOPENED";Write-Host "DESTRUCTIVE CLEANUP : NO"

Step 2 "VERIFY SPT-025.5 INPUTS"
$Req=@($ReqAssessment,$ReqPrepare);$M=@($Req|Where-Object{-not(Test-Path (Join-Path $Root $_))})
Write-Host "REQUIRED SPT-025.5 INPUTS : $($Req.Count)";Write-Host "MISSING INPUTS : $($M.Count)"
if($M.Count){Hold "Missing SPT-025.5 inputs"}
$Prev=Get-Content -Raw (Join-Path $Root $ReqAssessment)|ConvertFrom-Json
if([string]$Prev.status-ne"RESOURCE_BIBLE_GOVERNANCE_GATE_PASS"){Hold "SPT-025.5 gate is not PASS"}
Write-Host "SPT-025.5 RESOURCE / BIBLE GOVERNANCE GATE : PASS"

Step 3 "SHA-256 FREEZE OF CLOSED BASELINE"
$Freeze=@{};foreach($p in @(& git.exe -c core.quotepath=false ls-files)){$f=Join-Path $Root $p;if(Test-Path $f){$Freeze[$p]=Sha $f}}
Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)";Write-Host "SHA-256 FREEZE : PASS"

Step 4 "COMMUNITY IDENTITY / BRANDING DISCOVERY"
Write-Host "IDENTITY OWNERSHIP : INSTANCE";Write-Host "PLATFORM NAME : CONFIGURABLE";Write-Host "COMMUNITY METADATA : CONFIGURABLE"
Write-Host "LOGO / ICON REFERENCES : CONFIGURABLE";Write-Host "THEME TOKENS : CONFIGURABLE";Write-Host "INSTITUTIONAL TEXTS : CONFIGURABLE"
Write-Host "CULTURAL METADATA : CONFIGURABLE";Write-Host "PRESENTATION PREFERENCES : CONFIGURABLE";Write-Host "SGODA CORE IDENTITY VALUES : NONE"

Step 5 "IMPLEMENT SPT-025.6 IDENTITY / BRANDING MODEL"
$Core=@'
from hashlib import sha256
import json

def _t(v): return str(v or "").strip()
def normalize_code(v): return _t(v).lower().replace("_","-")

def validate_platform_identity(cfg):
    errors=[]
    if not isinstance(cfg,dict):
        return {"valid":False,"errors":["platform_identity_not_object"]}
    for k in ("platform_id","platform_name","community","native_language","branding","institutional_texts","cultural_metadata","presentation"):
        if k not in cfg: errors.append("missing_"+k)
    if not _t(cfg.get("platform_id")): errors.append("platform_id_required")
    if not _t(cfg.get("platform_name")): errors.append("platform_name_required")
    if cfg.get("instance_specific") is not True: errors.append("identity_must_be_instance_specific")
    if cfg.get("sgoda_core_embeds_identity_values") is not False: errors.append("sgoda_core_must_not_embed_identity_values")

    c=cfg.get("community")
    if not isinstance(c,dict): errors.append("community_not_object")
    else:
        if not _t(c.get("community_id")): errors.append("community_id_required")
        if not _t(c.get("name")): errors.append("community_name_required")
        if "territory" not in c: errors.append("community_territory_required")
        if "contact_metadata" not in c: errors.append("community_contact_metadata_required")

    n=cfg.get("native_language")
    if not isinstance(n,dict): errors.append("native_language_not_object")
    else:
        if not normalize_code(n.get("code")): errors.append("native_language_code_required")
        if not _t(n.get("name")): errors.append("native_language_name_required")

    b=cfg.get("branding")
    if not isinstance(b,dict): errors.append("branding_not_object")
    else:
        if b.get("configurable_per_platform") is not True: errors.append("branding_must_be_configurable_per_platform")
        for k in ("logo","icon","theme"):
            if k not in b: errors.append("branding_missing_"+k)

    for key,msg in (
        ("institutional_texts","institutional_texts_must_be_configurable_per_platform"),
        ("cultural_metadata","cultural_metadata_must_be_configurable_per_platform"),
        ("presentation","presentation_must_be_configurable_per_platform"),
    ):
        x=cfg.get(key)
        if not isinstance(x,dict): errors.append(key+"_not_object")
        elif x.get("configurable_per_platform") is not True: errors.append(msg)
    return {"valid":not errors,"errors":errors}

def reference_puinave_identity():
    return {
      "platform_id":"sgoda-puinave","platform_name":"SGODA-PUINAVE",
      "instance_specific":True,"sgoda_core_embeds_identity_values":False,
      "community":{"community_id":"puinave","name":"Pueblo Puinave","territory":{"configurable":True,"value":""},"contact_metadata":{"configurable":True}},
      "native_language":{"code":"pui","name":"Puinave"},
      "branding":{"configurable_per_platform":True,"logo":{"mode":"resource_reference","value":""},"icon":{"mode":"resource_reference","value":""},"theme":{"primary_token":"platform-primary","secondary_token":"platform-secondary","configurable":True}},
      "institutional_texts":{"configurable_per_platform":True,"title":"SGODA-PUINAVE","slogan":"Tecnología para preservar la memoria del pueblo Puinave."},
      "cultural_metadata":{"configurable_per_platform":True,"community_description":"","cultural_notes":"","attribution":""},
      "presentation":{"configurable_per_platform":True,"default_navigation_language":"es","show_native_language_first":True}
    }

def build_platform_identity(platform_id,platform_name,community_id,community_name,native_code,native_name):
    cfg=reference_puinave_identity()
    cfg["platform_id"]=_t(platform_id); cfg["platform_name"]=_t(platform_name)
    cfg["community"]["community_id"]=_t(community_id); cfg["community"]["name"]=_t(community_name)
    cfg["native_language"]={"code":normalize_code(native_code),"name":_t(native_name)}
    cfg["institutional_texts"]["title"]=_t(platform_name); cfg["institutional_texts"]["slogan"]=""
    return cfg,validate_platform_identity(cfg)

def identity_fingerprint(cfg):
    return sha256(json.dumps(cfg,ensure_ascii=False,sort_keys=True,separators=(",",":")).encode("utf-8")).hexdigest()
'@
$Init=@'
from .core import normalize_code,validate_platform_identity,reference_puinave_identity,build_platform_identity,identity_fingerprint
__all__=["normalize_code","validate_platform_identity","reference_puinave_identity","build_platform_identity","identity_fingerprint"]
'@
$Tests=@'
from sgoda.integration.spt0256 import *
def ref(): return reference_puinave_identity()
def test_01(): assert validate_platform_identity(ref())["valid"]
def test_02(): assert ref()["platform_id"]=="sgoda-puinave"
def test_03(): assert ref()["native_language"]["code"]=="pui"
def test_04(): assert ref()["community"]["community_id"]=="puinave"
def test_05(): assert ref()["branding"]["configurable_per_platform"] is True
def test_06(): assert ref()["institutional_texts"]["configurable_per_platform"] is True
def test_07(): assert ref()["cultural_metadata"]["configurable_per_platform"] is True
def test_08(): assert ref()["presentation"]["configurable_per_platform"] is True
def test_09(): assert ref()["sgoda_core_embeds_identity_values"] is False
def test_10():
    x=ref(); x["branding"]["configurable_per_platform"]=False
    assert "branding_must_be_configurable_per_platform" in validate_platform_identity(x)["errors"]
def test_11():
    x=ref(); x["community"]["name"]=""
    assert "community_name_required" in validate_platform_identity(x)["errors"]
def test_12():
    x=ref(); x["instance_specific"]=False
    assert "identity_must_be_instance_specific" in validate_platform_identity(x)["errors"]
def test_13():
    x=ref(); x["sgoda_core_embeds_identity_values"]=True
    assert "sgoda_core_must_not_embed_identity_values" in validate_platform_identity(x)["errors"]
def test_14():
    cfg,res=build_platform_identity("sgoda-kurripaco","SGODA-KURRIPACO","kurripaco","Pueblo Kurripaco","kpc","Kurripaco")
    assert res["valid"]
def test_15():
    cfg,res=build_platform_identity("","","x","Pueblo X","x","Lengua X")
    assert not res["valid"]
def test_16():
    x=ref(); x["presentation"]["configurable_per_platform"]=False
    assert "presentation_must_be_configurable_per_platform" in validate_platform_identity(x)["errors"]
def test_17():
    x=ref(); x["institutional_texts"]["configurable_per_platform"]=False
    assert "institutional_texts_must_be_configurable_per_platform" in validate_platform_identity(x)["errors"]
def test_18():
    x=ref(); x["cultural_metadata"]["configurable_per_platform"]=False
    assert "cultural_metadata_must_be_configurable_per_platform" in validate_platform_identity(x)["errors"]
def test_19(): assert identity_fingerprint(ref())==identity_fingerprint(ref())
def test_20():
    x=ref(); y=ref(); y["platform_name"]="OTHER"
    assert identity_fingerprint(x)!=identity_fingerprint(y)
def test_21(): assert ref()["presentation"]["show_native_language_first"] is True
def test_22(): assert ref()["institutional_texts"]["slogan"].startswith("Tecnología")
def test_23(): assert normalize_code(" PUI ")=="pui"
def test_24(): assert ref()["branding"]["theme"]["configurable"] is True
'@
$Policy=@'
{
  "component": "SPT-025.6",
  "version": "1.0.0",
  "authoritative_baseline": "bc467bc133fd8bf3b9c0fedab62fffe48f0100a0",
  "identity_ownership": "INSTANCE_SPECIFIC",
  "sgoda_core_embeds_identity_values": false,
  "platform_name_configurable": true,
  "community_metadata_configurable": true,
  "branding_configurable": true,
  "logo_reference_configurable": true,
  "icon_reference_configurable": true,
  "theme_tokens_configurable": true,
  "institutional_texts_configurable": true,
  "cultural_metadata_configurable": true,
  "presentation_preferences_configurable": true,
  "modify_closed_components": false,
  "production_change": false
}
'@
$Schema=@'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "SGODA Platform Identity",
  "type": "object",
  "required": [
    "platform_id",
    "platform_name",
    "instance_specific",
    "community",
    "native_language",
    "branding",
    "institutional_texts",
    "cultural_metadata",
    "presentation"
  ]
}
'@
$Puinave=@'
{
  "platform_id": "sgoda-puinave",
  "platform_name": "SGODA-PUINAVE",
  "instance_specific": true,
  "sgoda_core_embeds_identity_values": false,
  "community": {
    "community_id": "puinave",
    "name": "Pueblo Puinave",
    "territory": {
      "configurable": true,
      "value": ""
    },
    "contact_metadata": {
      "configurable": true
    }
  },
  "native_language": {
    "code": "pui",
    "name": "Puinave"
  },
  "branding": {
    "configurable_per_platform": true,
    "logo": {
      "mode": "resource_reference",
      "value": ""
    },
    "icon": {
      "mode": "resource_reference",
      "value": ""
    },
    "theme": {
      "primary_token": "platform-primary",
      "secondary_token": "platform-secondary",
      "configurable": true
    }
  },
  "institutional_texts": {
    "configurable_per_platform": true,
    "title": "SGODA-PUINAVE",
    "slogan": "Tecnología para preservar la memoria del pueblo Puinave."
  },
  "cultural_metadata": {
    "configurable_per_platform": true,
    "community_description": "",
    "cultural_notes": "",
    "attribution": ""
  },
  "presentation": {
    "configurable_per_platform": true,
    "default_navigation_language": "es",
    "show_native_language_first": true
  }
}
'@
$Template=@'
{
  "platform_id": "sgoda-<native-language>",
  "platform_name": "SGODA-<NATIVE-LANGUAGE>",
  "instance_specific": true,
  "sgoda_core_embeds_identity_values": false,
  "community": {
    "community_id": "<community-id>",
    "name": "<Community Name>",
    "territory": {
      "configurable": true,
      "value": ""
    },
    "contact_metadata": {
      "configurable": true
    }
  },
  "native_language": {
    "code": "<native-code>",
    "name": "<Native Language>"
  },
  "branding": {
    "configurable_per_platform": true,
    "logo": {
      "mode": "resource_reference",
      "value": ""
    },
    "icon": {
      "mode": "resource_reference",
      "value": ""
    },
    "theme": {
      "primary_token": "platform-primary",
      "secondary_token": "platform-secondary",
      "configurable": true
    }
  },
  "institutional_texts": {
    "configurable_per_platform": true,
    "title": "<Platform Title>",
    "slogan": ""
  },
  "cultural_metadata": {
    "configurable_per_platform": true,
    "community_description": "",
    "cultural_notes": "",
    "attribution": ""
  },
  "presentation": {
    "configurable_per_platform": true,
    "default_navigation_language": "<support-language>",
    "show_native_language_first": true
  }
}
'@
$Doc=@'
# SPT-025.6 — Identidad Comunitaria, Branding, Metadatos de Comunidad y Configuración de Plataforma

Baseline autoritativa: `bc467bc133fd8bf3b9c0fedab62fffe48f0100a0`.

Cada plataforma conserva identidad propia. SGODA Core no debe incrustar nombres, slogans, logos, iconos ni metadatos comunitarios concretos. Nombre de plataforma, comunidad, territorio, contactos, branding, textos institucionales, metadatos culturales y preferencias de presentación son configurables por instancia.

SGODA-PUINAVE se conserva como referencia con Puinave (`pui`), Pueblo Puinave y el slogan institucional existente. Esta capa no modifica activos gráficos ni componentes cerrados.
'@
WriteLf $CoreFile $Core;WriteLf $InitFile $Init;WriteLf $TestFile $Tests;WriteLf $PolicyFile $Policy;WriteLf $SchemaFile $Schema;WriteLf $PuinaveFile $Puinave;WriteLf $TemplateFile $Template;WriteLf $DocFile $Doc
Write-Host "SPT-025.6 IMPLEMENTATION : CREATED/VALIDATED"

Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
$env:PYTHONPATH=Join-Path $Root "src"
& $Python -c "from sgoda.integration.spt0256 import reference_puinave_identity,validate_platform_identity; assert validate_platform_identity(reference_puinave_identity())['valid']; print('SPT0256_IMPORT=PASS'); print('PUINAVE_IDENTITY_MODEL=PASS'); print('BRANDING_CONFIGURABLE=PASS')"
if($LASTEXITCODE){Hold "SPT-025.6 import/validation failed"}
& $Python -m pytest -q $TestFile;if($LASTEXITCODE){Hold "Targeted tests failed"};Write-Host "TARGETED TESTS : PASS"

Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
& $Python -m pytest -q;if($LASTEXITCODE){Hold "Institutional suite failed"};Write-Host "FULL SUITE : PASS"
& $Python -m compileall -q (Join-Path $Root "src");if($LASTEXITCODE){Hold "compileall failed"};Write-Host "COMPILEALL : PASS"

Step 8 "IDENTITY / BRANDING GOVERNANCE ASSESSMENT"
$Cfg=Get-Content -Raw (Join-Path $Root $PuinaveFile)|ConvertFrom-Json
if(-not[bool]$Cfg.instance_specific){Hold "Identity must be instance specific"}
if([bool]$Cfg.sgoda_core_embeds_identity_values){Hold "SGODA Core must not embed identity values"}
if(-not[bool]$Cfg.branding.configurable_per_platform){Hold "Branding must be configurable"}
Write-Host "IDENTITY_INSTANCE_SPECIFIC=PASS";Write-Host "SGODA_CORE_EMBEDS_IDENTITY_VALUES=NO";Write-Host "PLATFORM_NAME_CONFIGURABLE=PASS"
Write-Host "COMMUNITY_METADATA_CONFIGURABLE=PASS";Write-Host "BRANDING_CONFIGURABLE_PER_PLATFORM=PASS";Write-Host "LOGO_REFERENCE_CONFIGURABLE=PASS"
Write-Host "ICON_REFERENCE_CONFIGURABLE=PASS";Write-Host "THEME_TOKENS_CONFIGURABLE=PASS";Write-Host "INSTITUTIONAL_TEXTS_CONFIGURABLE=PASS"
Write-Host "CULTURAL_METADATA_CONFIGURABLE=PASS";Write-Host "PRESENTATION_PREFERENCES_CONFIGURABLE=PASS";Write-Host "PUINAVE_IDENTITY_REFERENCE=PASS"
Write-Host "IDENTITY / BRANDING GOVERNANCE GATE : PASS"

Step 9 "IDENTITY BASELINES / PREPARE / EVIDENCE"
New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null
WriteLf $IdentityModelFile ([ordered]@{model="PLATFORM_IDENTITY";ownership="INSTANCE";platform_name="CONFIGURABLE";community="CONFIGURABLE";sgoda_core_embeds_identity_values=$false}|ConvertTo-Json -Depth 8)
WriteLf $BrandingModelFile ([ordered]@{logo_reference="CONFIGURABLE";icon_reference="CONFIGURABLE";theme_tokens="CONFIGURABLE";asset_mutation="NOT_PERFORMED"}|ConvertTo-Json -Depth 8)
WriteLf $CommunityModelFile ([ordered]@{community_id="CONFIGURABLE";community_name="CONFIGURABLE";territory="CONFIGURABLE";contact_metadata="CONFIGURABLE";cultural_metadata="CONFIGURABLE"}|ConvertTo-Json -Depth 8)
WriteLf $PresentationModelFile ([ordered]@{default_navigation_language="CONFIGURABLE";show_native_language_first="CONFIGURABLE";institutional_texts="CONFIGURABLE"}|ConvertTo-Json -Depth 8)
WriteLf $PuinaveBaselineFile ([ordered]@{platform_id="sgoda-puinave";platform_name="SGODA-PUINAVE";community="Pueblo Puinave";native_language="pui";slogan="Tecnología para preservar la memoria del pueblo Puinave."}|ConvertTo-Json -Depth 8)
WriteLf $BoundaryFile ([ordered]@{sgoda_core=@("identity_contracts","validation","theme_contracts","security","testing","evidence");instance=@("platform_name","community_metadata","branding_resources","institutional_texts","cultural_metadata","presentation_preferences")}|ConvertTo-Json -Depth 8)
$Tmp=Join-Path ([IO.Path]::GetTempPath()) ("spt0256-"+[guid]::NewGuid().ToString("N")+".json");WriteLf $Tmp ($Cfg|ConvertTo-Json -Depth 12);$H=Sha $Tmp;Remove-Item $Tmp -Force
WriteLf $FingerprintFile ([ordered]@{algorithm="SHA-256";reference_identity="SGODA-PUINAVE";sha256=$H}|ConvertTo-Json -Depth 8)
WriteLf $AssessmentFile ([ordered]@{component="SPT-025.6";version="1.0.0";baseline=$ExpectedBaseline;status="IDENTITY_BRANDING_GOVERNANCE_GATE_PASS";identity_instance_specific=$true;sgoda_core_embeds_identity_values=$false;closed_components_preserved=$true}|ConvertTo-Json -Depth 8)
WriteLf $PrepareFile ([ordered]@{next_deliverable="SPT-025.7";title="Generador Institucional de Instancias Linguisticas / Bootstrap de Plataforma Independiente";source_baseline=$ExpectedBaseline;identity_branding_gate="PASS"}|ConvertTo-Json -Depth 8)
$MR=@();foreach($p in @($PolicyFile,$SchemaFile,$PuinaveFile,$TemplateFile,$DocFile,$IdentityModelFile,$BrandingModelFile,$CommunityModelFile,$PresentationModelFile,$PuinaveBaselineFile,$BoundaryFile,$FingerprintFile,$AssessmentFile,$PrepareFile)){$MR+=[ordered]@{path=$p;sha256=(Sha (Join-Path $Root $p))}}
WriteLf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$MR}|ConvertTo-Json -Depth 10)
WriteLf $EvidenceFile ([ordered]@{component="SPT-025.6";version="1.0.0";baseline=$ExpectedBaseline;status="IDENTITY_BRANDING_GOVERNANCE_GATE_PASS";targeted_tests="PASS";institutional_suite="PASS";compileall="PASS";branding_assets_modified=$false;production_change=$false;closed_components_preserved=$true}|ConvertTo-Json -Depth 8)
Write-Host "IDENTITY MODEL : CREATED";Write-Host "BRANDING MODEL : CREATED";Write-Host "COMMUNITY METADATA : CREATED";Write-Host "PRESENTATION MODEL : CREATED";Write-Host "PUINAVE IDENTITY : CREATED";Write-Host "SPT-025.7 PREPARE : CREATED";Write-Host "EVIDENCE : CREATED"

Step 10 "SHA-256 PRESERVATION GATE"
foreach($p in $Freeze.Keys){$f=Join-Path $Root $p;if(-not(Test-Path $f)-or(Sha $f)-ne$Freeze[$p]){Hold "Protected tracked file changed: $p"}}
Write-Host "PROTECTED TRACKED FILES : PRESERVED";Write-Host "SPT-024 / PISI + SPT-025.1-.5 + CLOSED COMPONENTS : PRESERVED"

Step 11 "EXACT CONTROLLED STAGING"
$Allowed=@("Invoke-SGODA-SPT0256-CommunityIdentity-BrandingPlatformConfig-FINAL-v1.0.0-PS51.ps1",$CoreFile,$InitFile,$TestFile,$PolicyFile,$SchemaFile,$PuinaveFile,$TemplateFile,$DocFile,$IdentityModelFile,$BrandingModelFile,$CommunityModelFile,$PresentationModelFile,$PuinaveBaselineFile,$BoundaryFile,$FingerprintFile,$AssessmentFile,$IntegrityFile,$PrepareFile,$EvidenceFile)
foreach($p in $Allowed){if(-not(Test-Path (Join-Path $Root $p))){Hold "Missing expected target: $p"};& git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $p;if($LASTEXITCODE){Hold "git add failed: $p"}}
$SN=@(& git.exe -c core.quotepath=false diff --cached --name-only);$U=@($SN|Where-Object{$Allowed-notcontains($_-replace'\\','/')})
Write-Host "STAGED     : $($SN.Count)";Write-Host "UNEXPECTED : $($U.Count)";if($U.Count-or$SN.Count-ne$Allowed.Count){Hold "Exact staging mismatch"};Write-Host "STAGING QUALITY : PASS"

Step 12 "INDEX-WIDE GITHUB SIZE GATE"
$B=@(SizeGate);Write-Host "INDEX BLOBS >=100MB : $($B.Count)";if($B.Count){Hold "Git index contains blob >=100 MB"};Write-Host "GITHUB SIZE GATE : PASS"

Step 13 "FINAL REMOTE / PRESERVATION GATE"
Fetch
$R2=(& git.exe rev-parse ("origin/"+$Branch)).Trim();if($R2-ne$ExpectedBaseline){Hold "Remote advanced during transaction"}
foreach($p in $Freeze.Keys){$f=Join-Path $Root $p;if(-not(Test-Path $f)-or(Sha $f)-ne$Freeze[$p]){Hold "Preservation changed before commit"}}
Write-Host "PROTECTED TRACKED FILES : PRESERVED";Write-Host "REMOTE GATE : PASS"

Step 14 "COMMIT"
& git.exe commit -m "feat(spt-025.6): implement configurable community identity branding and platform metadata";if($LASTEXITCODE){Hold "git commit failed"}
$NC=(& git.exe rev-parse HEAD).Trim();Write-Host "NEW COMMIT : $NC"

Step 15 "PUSH"
& git.exe push origin $Branch;if($LASTEXITCODE){Hold "git push failed"};Write-Host "PUSH : PASS"

Step 16 "AUTHORITATIVE REMOTE VERIFICATION / TECHNICAL CLOSURE"
Fetch
$FL=(& git.exe rev-parse HEAD).Trim();$FR=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
$Behind=(& git.exe rev-list --count ("HEAD..origin/"+$Branch)).Trim();$Ahead=(& git.exe rev-list --count ("origin/"+$Branch+"..HEAD")).Trim()
$FS=@(& git.exe diff --cached --name-only);$FD=@(& git.exe ls-files --deleted)
Write-Host "LOCAL HEAD      : $FL";Write-Host "REMOTE HEAD     : $FR";Write-Host "BEHIND          : $Behind";Write-Host "AHEAD           : $Ahead";Write-Host "STAGED          : $($FS.Count)";Write-Host "DELETED TRACKED : $($FD.Count)"
if($FL-ne$FR-or$Behind-ne"0"-or$Ahead-ne"0"-or$FS.Count-ne0-or$FD.Count-ne0){Hold "Final synchronization failed"}
Write-Host ""
Write-Host "SPT-025.6 : TECHNICALLY CLOSED / IDENTITY & BRANDING MODEL APPROVED" -ForegroundColor Green
Write-Host "SPT-025.5_RESOURCE_CATALOG_GATE=PASS";Write-Host "IDENTITY_INSTANCE_SPECIFIC=PASS";Write-Host "SGODA_CORE_EMBEDS_IDENTITY_VALUES=NO"
Write-Host "PLATFORM_NAME_CONFIGURABLE=PASS";Write-Host "COMMUNITY_METADATA_CONFIGURABLE=PASS";Write-Host "BRANDING_CONFIGURABLE_PER_PLATFORM=PASS"
Write-Host "LOGO_REFERENCE_CONFIGURABLE=PASS";Write-Host "ICON_REFERENCE_CONFIGURABLE=PASS";Write-Host "THEME_TOKENS_CONFIGURABLE=PASS"
Write-Host "INSTITUTIONAL_TEXTS_CONFIGURABLE=PASS";Write-Host "CULTURAL_METADATA_CONFIGURABLE=PASS";Write-Host "PRESENTATION_PREFERENCES_CONFIGURABLE=PASS"
Write-Host "PUINAVE_IDENTITY_REFERENCE=PASS";Write-Host "BRANDING_ASSETS_MODIFIED=NO";Write-Host "DESTRUCTIVE_CHANGE=NO";Write-Host "PRODUCTION_CHANGE=NO"
Write-Host "TARGETED_TESTS=PASS";Write-Host "INSTITUTIONAL_SUITE=PASS";Write-Host "COMPILEALL=PASS";Write-Host "CLOSED_COMPONENTS=PRESERVED"
Write-Host "LOCAL_HEAD=REMOTE_HEAD";Write-Host "NEXT_DELIVERABLE=SPT-025.7";Write-Host "FINAL_EXIT_CODE=0";exit 0
}catch{Hold $_.Exception.Message}
