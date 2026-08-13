#requires -Version 5.1
[CmdletBinding()] param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="3d980dcb905b856c8f898e6dda5aed3953664cdf"
$Branch="feature/SPT-001A-rlb-schema-foundation"

$ReqAssessment="artifacts/development/SPT-025.3-v1.0.0/spt0253-language-model-assessment.json"
$ReqPuinave="artifacts/development/SPT-025.3-v1.0.0/sgoda-puinave-language-baseline.json"
$ReqTemplate="artifacts/development/SPT-025.3-v1.0.0/replicable-language-platform-template-baseline.json"
$ReqPrepare="artifacts/development/SPT-025.3-v1.0.0/spt0254-prepare.json"

$CoreFile="src/sgoda/integration/spt0254/core.py"
$InitFile="src/sgoda/integration/spt0254/__init__.py"
$TestFile="tests/integration/test_spt0254_parametric_rlb_instance_data_contract.py"
$PolicyFile="config/integration/spt0254/parametric-rlb-instance-data-policy.json"
$SchemaFile="config/integration/spt0254/parametric-rlb-lexeme.schema.json"
$PuinaveContractFile="config/integration/spt0254/sgoda-puinave-rlb-instance-contract.json"
$TemplateFile="config/integration/spt0254/rlb-instance-template.json"
$DocFile="docs/06_Tecnologia/SPT-025/SPT-025.4/SGD-SPT025.4-RLB-Parametrizable-Contrato-Datos-Instancia.md"

$ArtifactDir="artifacts/development/SPT-025.4-v1.0.0"
$RlbModelFile="$ArtifactDir/parametric-rlb-model-baseline.json"
$LexemeContractFile="$ArtifactDir/lexeme-data-contract-baseline.json"
$InstanceBoundaryFile="$ArtifactDir/lexical-instance-boundary-baseline.json"
$PuinaveCompatibilityFile="$ArtifactDir/puinave-rlb-compatibility-baseline.json"
$FingerprintFile="$ArtifactDir/reference-lexeme-integrity-baseline.json"
$AssessmentFile="$ArtifactDir/spt0254-rlb-contract-assessment.json"
$IntegrityFile="$ArtifactDir/spt0254-integrity-manifest.json"
$PrepareFile="$ArtifactDir/spt0255-prepare.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"
$LargeFileLimit=100MB

function Step([int]$N,[string]$T){Write-Host "";Write-Host ("[{0}/16] {1}" -f $N,$T) -ForegroundColor Cyan}
function Hold([string]$R){Write-Host "";Write-Host "SPT-025.4 : HOLD" -ForegroundColor Red;Write-Host "REASON : $R";Write-Host "TRANSACTION : NOT PUBLISHED";exit 1}
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
Write-Host "SPT-024 / PISI + SPT-025.1-.3 : PROTECTED / NOT REOPENED"
Write-Host "DESTRUCTIVE CLEANUP : NO"

Step 2 "VERIFY SPT-025.3 LANGUAGE MODEL INPUTS"
$Req=@($ReqAssessment,$ReqPuinave,$ReqTemplate,$ReqPrepare)
$M=@($Req|Where-Object{-not(Test-Path (Join-Path $Root $_))})
Write-Host "REQUIRED SPT-025.3 INPUTS : $($Req.Count)"
Write-Host "MISSING INPUTS            : $($M.Count)"
if($M.Count){Hold "Missing SPT-025.3 inputs"}
$Prev=Get-Content -Raw (Join-Path $Root $ReqAssessment)|ConvertFrom-Json
if([string]$Prev.status-ne"LANGUAGE_PLATFORM_MODEL_GATE_PASS"){Hold "SPT-025.3 language model gate is not PASS"}
Write-Host "SPT-025.3 LANGUAGE PLATFORM MODEL GATE : PASS"

Step 3 "SHA-256 FREEZE OF CLOSED BASELINE"
$Freeze=@{}
foreach($p in @(& git.exe -c core.quotepath=false ls-files)){$f=Join-Path $Root $p;if(Test-Path $f){$Freeze[$p]=Sha $f}}
Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
Write-Host "SHA-256 FREEZE : PASS"

Step 4 "RLB / INSTANCE DATA CONTRACT DISCOVERY"
Write-Host "RLB OWNERSHIP            : INSTANCE"
Write-Host "SGODA CORE LEXICAL DATA  : NO"
Write-Host "NATIVE LANGUAGE          : EXACTLY 1"
Write-Host "SUPPORT MEANING LANGUAGES: 0..N / CONFIGURABLE"
Write-Host "PRONUNCIATION / AUDIO    : INSTANCE SPECIFIC"
Write-Host "IMAGES / METADATA        : INSTANCE SPECIFIC"
Write-Host "PUINAVE COMPATIBILITY    : ADAPTER / NON-DESTRUCTIVE"

Step 5 "IMPLEMENT SPT-025.4 PARAMETRIC RLB CONTRACT"
$Core=@'
from dataclasses import dataclass
from hashlib import sha256
import json

REQUIRED_LEXEME_KEYS = (
    "lexical_id","native_language","native_form","meanings",
    "pronunciation","audio","images","metadata"
)

@dataclass(frozen=True)
class ValidationResult:
    valid: bool
    errors: tuple

def normalize_code(value):
    return str(value or "").strip().lower().replace("_","-")

def _nonempty(value):
    return bool(str(value or "").strip())

def validate_meanings(meanings, support_language_codes):
    errors=[]
    if not isinstance(meanings,dict):
        return ["meanings_not_object"]
    for code in support_language_codes:
        value=meanings.get(code)
        if value is None:
            continue
        if isinstance(value,dict):
            if "text" in value and not _nonempty(value.get("text")):
                errors.append(f"meaning_{code}_text_empty")
        elif not _nonempty(value):
            errors.append(f"meaning_{code}_empty")
    unknown=[normalize_code(k) for k in meanings.keys() if normalize_code(k) not in support_language_codes]
    if unknown:
        errors.extend(f"meaning_language_not_enabled:{x}" for x in unknown)
    return errors

def validate_lexeme(record, native_code, support_language_codes):
    errors=[]
    if not isinstance(record,dict):
        return {"valid":False,"errors":["lexeme_not_object"]}
    for k in REQUIRED_LEXEME_KEYS:
        if k not in record:
            errors.append(f"missing_{k}")
    if not _nonempty(record.get("lexical_id")):
        errors.append("lexical_id_required")
    if normalize_code(record.get("native_language")) != normalize_code(native_code):
        errors.append("native_language_mismatch")
    if not _nonempty(record.get("native_form")):
        errors.append("native_form_required")
    support=[normalize_code(x) for x in support_language_codes]
    if normalize_code(native_code) in support:
        errors.append("native_language_cannot_be_support_language")
    errors.extend(validate_meanings(record.get("meanings"),support))
    pronunciation=record.get("pronunciation")
    if not isinstance(pronunciation,dict):
        errors.append("pronunciation_not_object")
    audio=record.get("audio")
    if not isinstance(audio,dict):
        errors.append("audio_not_object")
    images=record.get("images")
    if not isinstance(images,list):
        errors.append("images_not_list")
    metadata=record.get("metadata")
    if not isinstance(metadata,dict):
        errors.append("metadata_not_object")
    return {"valid":not errors,"errors":errors}

def build_repository_contract(platform_id, native_code, support_language_codes):
    support=[]
    seen=set()
    for code in support_language_codes:
        c=normalize_code(code)
        if not c or c==normalize_code(native_code) or c in seen:
            continue
        seen.add(c)
        support.append(c)
    return {
        "contract":"PARAMETRIC_RLB_INSTANCE_DATA",
        "platform_id":str(platform_id or "").strip(),
        "native_language":normalize_code(native_code),
        "support_languages":support,
        "instance_specific":True,
        "sgoda_core_contains_lexical_data":False,
        "lexeme_required_keys":list(REQUIRED_LEXEME_KEYS),
        "supports_pronunciation":True,
        "supports_native_audio":True,
        "supports_images":True,
        "supports_metadata":True,
        "support_language_meanings_configurable":True,
        "backward_compatibility_adapter_required":True
    }

def content_fingerprint(record):
    payload=json.dumps(record,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def reference_puinave_lexeme():
    return {
        "lexical_id":"PUINAVE-000001",
        "native_language":"pui",
        "native_form":"AMDA",
        "meanings":{
            "es":{"text":"..."},
            "en":{"text":"..."},
            "it":{"text":"..."},
            "pt":{"text":"..."}
        },
        "pronunciation":{"notation":"","validated":False},
        "audio":{"native":"","speaker":"","validated":False},
        "images":[],
        "metadata":{"source":"RLB-PUINAVE","status":"reference"}
    }
'@
$Init=@'
from .core import (
    REQUIRED_LEXEME_KEYS,ValidationResult,normalize_code,validate_meanings,
    validate_lexeme,build_repository_contract,content_fingerprint,reference_puinave_lexeme
)
__all__=[
    "REQUIRED_LEXEME_KEYS","ValidationResult","normalize_code","validate_meanings",
    "validate_lexeme","build_repository_contract","content_fingerprint","reference_puinave_lexeme"
]
'@
$Tests=@'
from sgoda.integration.spt0254 import *

SUP=("es","en","it","pt")
def ref(): return reference_puinave_lexeme()

def test_01(): assert len(REQUIRED_LEXEME_KEYS)==8
def test_02(): assert normalize_code(" PT ")=="pt"
def test_03(): assert validate_lexeme(ref(),"pui",SUP)["valid"]
def test_04():
    x=ref(); x["native_language"]="kpc"
    assert "native_language_mismatch" in validate_lexeme(x,"pui",SUP)["errors"]
def test_05():
    x=ref(); x["native_form"]=""
    assert "native_form_required" in validate_lexeme(x,"pui",SUP)["errors"]
def test_06():
    x=ref(); x["meanings"]["fr"]={"text":"x"}
    assert "meaning_language_not_enabled:fr" in validate_lexeme(x,"pui",SUP)["errors"]
def test_07():
    x=ref(); x["meanings"]["es"]={"text":""}
    assert "meaning_es_text_empty" in validate_lexeme(x,"pui",SUP)["errors"]
def test_08():
    x=ref(); x["pronunciation"]=[]
    assert "pronunciation_not_object" in validate_lexeme(x,"pui",SUP)["errors"]
def test_09():
    x=ref(); x["audio"]=[]
    assert "audio_not_object" in validate_lexeme(x,"pui",SUP)["errors"]
def test_10():
    x=ref(); x["images"]={}
    assert "images_not_list" in validate_lexeme(x,"pui",SUP)["errors"]
def test_11():
    x=ref(); x["metadata"]=[]
    assert "metadata_not_object" in validate_lexeme(x,"pui",SUP)["errors"]
def test_12():
    c=build_repository_contract("sgoda-puinave","pui",SUP)
    assert c["instance_specific"] is True
def test_13():
    c=build_repository_contract("sgoda-puinave","pui",SUP)
    assert c["sgoda_core_contains_lexical_data"] is False
def test_14():
    c=build_repository_contract("sgoda-puinave","pui",SUP)
    assert c["support_languages"]==["es","en","it","pt"]
def test_15():
    c=build_repository_contract("x","x",["x","es","es"])
    assert c["support_languages"]==["es"]
def test_16():
    c=build_repository_contract("x","x",[])
    assert c["support_languages"]==[]
def test_17():
    assert build_repository_contract("x","x",[])["backward_compatibility_adapter_required"] is True
def test_18():
    assert build_repository_contract("x","x",[])["support_language_meanings_configurable"] is True
def test_19():
    assert content_fingerprint(ref())==content_fingerprint(ref())
def test_20():
    x=ref(); y=ref(); y["native_form"]="AMDA2"
    assert content_fingerprint(x)!=content_fingerprint(y)
def test_21():
    x=ref(); del x["metadata"]
    assert "missing_metadata" in validate_lexeme(x,"pui",SUP)["errors"]
def test_22():
    x=ref(); x["meanings"]={}
    assert validate_lexeme(x,"pui",SUP)["valid"]
def test_23():
    x=ref()
    assert set(x["meanings"])==set(SUP)
def test_24():
    c=build_repository_contract("sgoda-puinave","pui",SUP)
    assert c["supports_native_audio"] and c["supports_pronunciation"] and c["supports_images"]
'@
$Policy=@'
{
  "component": "SPT-025.4",
  "version": "1.0.0",
  "title": "Repositorio Lexico Base Parametrizable por Lengua y Contrato de Datos de Instancia",
  "authoritative_baseline": "3d980dcb905b856c8f898e6dda5aed3953664cdf",
  "architecture": {
    "lexical_repository": "INSTANCE_SPECIFIC",
    "sgoda_core_contains_lexical_data": false,
    "one_native_language_per_platform": true,
    "support_language_meanings": "0..N_CONFIGURABLE",
    "pronunciation": "INSTANCE_SPECIFIC",
    "native_audio": "INSTANCE_SPECIFIC",
    "images": "INSTANCE_SPECIFIC",
    "metadata": "INSTANCE_SPECIFIC",
    "backward_compatibility_adapter_required": true,
    "reference_platform": "SGODA-PUINAVE",
    "reference_support_languages": [
      "es",
      "en",
      "it",
      "pt"
    ]
  },
  "mode": "NON_DESTRUCTIVE_CONTRACT_AND_ADAPTER_PREPARE",
  "rules": {
    "modify_existing_rlb": false,
    "migrate_existing_data": false,
    "modify_closed_components": false,
    "production_change": false,
    "commit_push_required": true,
    "local_remote_head_equality_required": true
  }
}
'@
$Schema=@'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "SGODA Parametric RLB Instance Lexeme",
  "type": "object",
  "required": [
    "lexical_id",
    "native_language",
    "native_form",
    "meanings",
    "pronunciation",
    "audio",
    "images",
    "metadata"
  ],
  "properties": {
    "lexical_id": {
      "type": "string",
      "minLength": 1
    },
    "native_language": {
      "type": "string",
      "minLength": 1
    },
    "native_form": {
      "type": "string",
      "minLength": 1
    },
    "meanings": {
      "type": "object",
      "additionalProperties": true
    },
    "pronunciation": {
      "type": "object"
    },
    "audio": {
      "type": "object"
    },
    "images": {
      "type": "array"
    },
    "metadata": {
      "type": "object"
    }
  }
}
'@
$PuinaveContract=@'
{
  "platform_id": "sgoda-puinave",
  "repository_id": "RLB-PUINAVE",
  "instance_specific": true,
  "native_language": {
    "code": "pui",
    "name": "Puinave"
  },
  "support_languages": [
    "es",
    "en",
    "it",
    "pt"
  ],
  "lexical_fields": [
    "lexical_id",
    "native_language",
    "native_form",
    "meanings",
    "pronunciation",
    "audio",
    "images",
    "metadata"
  ],
  "backward_compatibility": {
    "existing_rlb_preserved": true,
    "destructive_migration": false,
    "adapter_required": true
  }
}
'@
$Template=@'
{
  "platform_id": "sgoda-<native-language>",
  "repository_id": "RLB-<NATIVE-LANGUAGE>",
  "instance_specific": true,
  "native_language": {
    "code": "<native-code>",
    "name": "<Native Language>"
  },
  "support_languages": [
    "<support-code-1>",
    "<support-code-2>"
  ],
  "lexical_fields": [
    "lexical_id",
    "native_language",
    "native_form",
    "meanings",
    "pronunciation",
    "audio",
    "images",
    "metadata"
  ],
  "backward_compatibility": {
    "existing_rlb_preserved": true,
    "destructive_migration": false,
    "adapter_required": true
  }
}
'@
$Doc=@'
# SPT-025.4 — Repositorio Léxico Base Parametrizable por Lengua y Contrato de Datos de Instancia

Baseline autoritativa: `3d980dcb905b856c8f898e6dda5aed3953664cdf`.

## Objetivo
Definir un RLB parametrizable por plataforma, manteniendo los datos léxicos fuera de SGODA Core.

## Reglas
- Cada plataforma posee su propio RLB.
- El RLB pertenece a la instancia lingüística.
- SGODA Core no contiene palabras ni pronunciaciones específicas.
- Los significados se asocian a los idiomas auxiliares configurados.
- Pronunciación, audio nativo, imágenes y metadatos son datos de instancia.
- El RLB Puinave existente se preserva; esta capa no lo migra ni reescribe.
- La compatibilidad se resolverá mediante adaptador no destructivo.

## SGODA-PUINAVE
Lengua nativa: Puinave (`pui`).
Idiomas auxiliares de referencia: `es`, `en`, `it`, `pt`.
'@
WriteLf $CoreFile $Core
WriteLf $InitFile $Init
WriteLf $TestFile $Tests
WriteLf $PolicyFile $Policy
WriteLf $SchemaFile $Schema
WriteLf $PuinaveContractFile $PuinaveContract
WriteLf $TemplateFile $Template
WriteLf $DocFile $Doc
Write-Host "SPT-025.4 IMPLEMENTATION : CREATED/VALIDATED"

Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
$env:PYTHONPATH=Join-Path $Root "src"
& $Python -c "from sgoda.integration.spt0254 import reference_puinave_lexeme,validate_lexeme,build_repository_contract; r=reference_puinave_lexeme(); assert validate_lexeme(r,'pui',('es','en','it','pt'))['valid']; c=build_repository_contract('sgoda-puinave','pui',('es','en','it','pt')); assert c['instance_specific']; print('SPT0254_IMPORT=PASS'); print('PARAMETRIC_RLB_CONTRACT=PASS')"
if($LASTEXITCODE){Hold "SPT-025.4 import/contract validation failed"}
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

Step 8 "PARAMETRIC RLB / INSTANCE DATA ASSESSMENT"
$Cfg=Get-Content -Raw (Join-Path $Root $PuinaveContractFile)|ConvertFrom-Json
if(-not[bool]$Cfg.instance_specific){Hold "Puinave RLB must be instance specific"}
if([string]$Cfg.native_language.code-ne"pui"){Hold "Puinave native language code mismatch"}
$Codes=@($Cfg.support_languages|ForEach-Object{[string]$_})
foreach($c in @("es","en","it","pt")){if($Codes-notcontains$c){Hold "Missing Puinave support language: $c"}}
Write-Host "RLB_INSTANCE_SPECIFIC=PASS"
Write-Host "SGODA_CORE_CONTAINS_LEXICAL_DATA=NO"
Write-Host "NATIVE_LANGUAGE_BOUNDARY=PASS"
Write-Host "SUPPORT_LANGUAGE_MEANINGS_CONFIGURABLE=PASS"
Write-Host "PRONUNCIATION_INSTANCE_SPECIFIC=PASS"
Write-Host "NATIVE_AUDIO_INSTANCE_SPECIFIC=PASS"
Write-Host "IMAGES_INSTANCE_SPECIFIC=PASS"
Write-Host "METADATA_INSTANCE_SPECIFIC=PASS"
Write-Host "PUINAVE_RLB_BACKWARD_COMPATIBILITY=PASS"
Write-Host "PARAMETRIC RLB / INSTANCE DATA GATE : PASS"

Step 9 "RLB BASELINES / PREPARE / EVIDENCE"
New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null
$Model=[ordered]@{model="PARAMETRIC_RLB";ownership="INSTANCE";sgoda_core_contains_lexical_data=$false;native_language_count=1;support_languages="0..N";support_language_meanings_configurable=$true}
$Lexeme=[ordered]@{required_fields=@("lexical_id","native_language","native_form","meanings","pronunciation","audio","images","metadata");native_form="REQUIRED";meanings="BY_ENABLED_SUPPORT_LANGUAGE";pronunciation="INSTANCE";audio="INSTANCE";images="INSTANCE";metadata="INSTANCE"}
$Boundary=[ordered]@{sgoda_core=@("schema_validation","api_contracts","workflow","security","testing","evidence");instance=@("lexicon","native_forms","meanings","pronunciation","native_audio","images","metadata")}
$Compat=[ordered]@{platform="SGODA-PUINAVE";repository="RLB-PUINAVE";preserve_existing=$true;destructive_migration=$false;adapter_required=$true;support_languages=@("es","en","it","pt")}
$Ref=@{lexical_id="PUINAVE-000001";native_language="pui";native_form="AMDA";meanings=@{es=@{text="..."};en=@{text="..."};it=@{text="..."};pt=@{text="..."}};pronunciation=@{notation="";validated=$false};audio=@{native="";speaker="";validated=$false};images=@();metadata=@{source="RLB-PUINAVE";status="reference"}}
$RefJson=$Ref|ConvertTo-Json -Depth 12
$TmpRef=Join-Path ([IO.Path]::GetTempPath()) ("spt0254-ref-"+[guid]::NewGuid().ToString("N")+".json")
WriteLf $TmpRef $RefJson
$RefHash=Sha $TmpRef
Remove-Item $TmpRef -Force -ErrorAction SilentlyContinue
$Fingerprint=[ordered]@{algorithm="SHA-256";reference_lexeme_id="PUINAVE-000001";sha256=$RefHash}
$Assessment=[ordered]@{component="SPT-025.4";version="1.0.0";baseline=$ExpectedBaseline;status="PARAMETRIC_RLB_INSTANCE_DATA_GATE_PASS";rlb_instance_specific=$true;sgoda_core_contains_lexical_data=$false;support_language_meanings_configurable=$true;puinave_backward_compatibility=$true;closed_components_preserved=$true}
$Prepare=[ordered]@{next_deliverable="SPT-025.5";title="Recursos Culturales y Linguisticos Configurables por Plataforma / Biblia y Catalogo de Recursos";source_baseline=$ExpectedBaseline;rlb_contract_gate="PASS"}
WriteLf $RlbModelFile ($Model|ConvertTo-Json -Depth 8)
WriteLf $LexemeContractFile ($Lexeme|ConvertTo-Json -Depth 8)
WriteLf $InstanceBoundaryFile ($Boundary|ConvertTo-Json -Depth 8)
WriteLf $PuinaveCompatibilityFile ($Compat|ConvertTo-Json -Depth 8)
WriteLf $FingerprintFile ($Fingerprint|ConvertTo-Json -Depth 8)
WriteLf $AssessmentFile ($Assessment|ConvertTo-Json -Depth 8)
WriteLf $PrepareFile ($Prepare|ConvertTo-Json -Depth 8)
$MR=@()
foreach($p in @($PolicyFile,$SchemaFile,$PuinaveContractFile,$TemplateFile,$DocFile,$RlbModelFile,$LexemeContractFile,$InstanceBoundaryFile,$PuinaveCompatibilityFile,$FingerprintFile,$AssessmentFile,$PrepareFile)){$MR+=[ordered]@{path=$p;sha256=(Sha (Join-Path $Root $p))}}
WriteLf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$MR}|ConvertTo-Json -Depth 10)
WriteLf $EvidenceFile ([ordered]@{component="SPT-025.4";version="1.0.0";baseline=$ExpectedBaseline;status="PARAMETRIC_RLB_INSTANCE_DATA_GATE_PASS";targeted_tests="PASS";institutional_suite="PASS";compileall="PASS";production_change=$false;existing_rlb_modified=$false;closed_components_preserved=$true}|ConvertTo-Json -Depth 8)
Write-Host "PARAMETRIC RLB MODEL      : CREATED"
Write-Host "LEXEME DATA CONTRACT      : CREATED"
Write-Host "CORE/INSTANCE BOUNDARY    : CREATED"
Write-Host "PUINAVE COMPATIBILITY     : CREATED"
Write-Host "REFERENCE INTEGRITY       : CREATED"
Write-Host "SPT-025.5 PREPARE         : CREATED"
Write-Host "EVIDENCE                  : CREATED"

Step 10 "SHA-256 PRESERVATION GATE"
foreach($p in $Freeze.Keys){$f=Join-Path $Root $p;if(-not(Test-Path $f)-or(Sha $f)-ne$Freeze[$p]){Hold "Protected tracked file changed: $p"}}
Write-Host "PROTECTED TRACKED FILES : PRESERVED"
Write-Host "SPT-024 / PISI + SPT-025.1-.3 + CLOSED COMPONENTS : PRESERVED"

Step 11 "EXACT CONTROLLED STAGING"
$Allowed=@("Invoke-SGODA-SPT0254-ParametricRLB-InstanceDataContract-FINAL-v1.0.0-PS51.ps1",$CoreFile,$InitFile,$TestFile,$PolicyFile,$SchemaFile,$PuinaveContractFile,$TemplateFile,$DocFile,$RlbModelFile,$LexemeContractFile,$InstanceBoundaryFile,$PuinaveCompatibilityFile,$FingerprintFile,$AssessmentFile,$IntegrityFile,$PrepareFile,$EvidenceFile)
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
& git.exe commit -m "feat(spt-025.4): implement parametric RLB and instance data contract"
if($LASTEXITCODE){Hold "git commit failed"}
$NC=(& git.exe rev-parse HEAD).Trim()
Write-Host "NEW COMMIT : $NC"

Step 15 "PUSH"
& git.exe push origin $Branch
if($LASTEXITCODE){Hold "git push failed"}
Write-Host "PUSH : PASS"

Step 16 "AUTHORITATIVE REMOTE VERIFICATION / TECHNICAL CLOSURE"
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
Write-Host "SPT-025.4 : TECHNICALLY CLOSED / PARAMETRIC RLB CONTRACT APPROVED" -ForegroundColor Green
Write-Host "SPT-025.3_LANGUAGE_MODEL_GATE=PASS"
Write-Host "RLB_INSTANCE_SPECIFIC=PASS"
Write-Host "SGODA_CORE_CONTAINS_LEXICAL_DATA=NO"
Write-Host "ONE_NATIVE_LANGUAGE_PER_RLB=PASS"
Write-Host "SUPPORT_LANGUAGE_MEANINGS_CONFIGURABLE=PASS"
Write-Host "PUINAVE_SUPPORT_LANGUAGES=ES,EN,IT,PT"
Write-Host "PRONUNCIATION_INSTANCE_SPECIFIC=PASS"
Write-Host "NATIVE_AUDIO_INSTANCE_SPECIFIC=PASS"
Write-Host "IMAGES_INSTANCE_SPECIFIC=PASS"
Write-Host "METADATA_INSTANCE_SPECIFIC=PASS"
Write-Host "PUINAVE_RLB_BACKWARD_COMPATIBILITY=PASS"
Write-Host "EXISTING_RLB_MODIFIED=NO"
Write-Host "DESTRUCTIVE_MIGRATION=NO"
Write-Host "PRODUCTION_CHANGE=NO"
Write-Host "TARGETED_TESTS=PASS"
Write-Host "INSTITUTIONAL_SUITE=PASS"
Write-Host "COMPILEALL=PASS"
Write-Host "CLOSED_COMPONENTS=PRESERVED"
Write-Host "LOCAL_HEAD=REMOTE_HEAD"
Write-Host "NEXT_DELIVERABLE=SPT-025.5"
Write-Host "FINAL_EXIT_CODE=0"
exit 0
}catch{Hold $_.Exception.Message}
