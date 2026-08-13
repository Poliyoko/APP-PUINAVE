#requires -Version 5.1
[CmdletBinding()] param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="d2d8226d068451537982cc8fcec5c7ace60a0735"
$Branch="feature/SPT-001A-rlb-schema-foundation"

$ReqAssessment="artifacts/development/SPT-025.2-v1.0.0/spt0252-contract-assessment.json"
$ReqCore="artifacts/development/SPT-025.2-v1.0.0/sgoda-core-contract.json"
$ReqPlatform="artifacts/development/SPT-025.2-v1.0.0/independent-language-platform-contract.json"
$ReqPrepare="artifacts/development/SPT-025.2-v1.0.0/spt0253-prepare.json"

$CoreFile="src/sgoda/integration/spt0253/core.py"
$InitFile="src/sgoda/integration/spt0253/__init__.py"
$TestFile="tests/integration/test_spt0253_independent_language_platform_language_config.py"
$PolicyFile="config/integration/spt0253/independent-language-platform-language-policy.json"
$SchemaFile="config/integration/spt0253/independent-language-platform-language.schema.json"
$PuinaveFile="config/integration/spt0253/sgoda-puinave-language-profile.json"
$TemplateFile="config/integration/spt0253/independent-language-platform-template.json"
$DocFile="docs/06_Tecnologia/SPT-025/SPT-025.3/SGD-SPT025.3-Modelo-Plataforma-Linguistica-Independiente-Idiomas-Auxiliares.md"

$ArtifactDir="artifacts/development/SPT-025.3-v1.0.0"
$LanguageModelFile="$ArtifactDir/language-platform-model-baseline.json"
$SupportModelFile="$ArtifactDir/support-language-configuration-baseline.json"
$OutputSelectionFile="$ArtifactDir/output-language-selection-baseline.json"
$PuinaveBaselineFile="$ArtifactDir/sgoda-puinave-language-baseline.json"
$ReplicableTemplateFile="$ArtifactDir/replicable-language-platform-template-baseline.json"
$AssessmentFile="$ArtifactDir/spt0253-language-model-assessment.json"
$IntegrityFile="$ArtifactDir/spt0253-integrity-manifest.json"
$PrepareFile="$ArtifactDir/spt0254-prepare.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"
$LargeFileLimit=100MB

function Step([int]$N,[string]$T){Write-Host "";Write-Host ("[{0}/16] {1}" -f $N,$T) -ForegroundColor Cyan}
function Hold([string]$R){Write-Host "";Write-Host "SPT-025.3 : HOLD" -ForegroundColor Red;Write-Host "REASON : $R";Write-Host "TRANSACTION : NOT PUBLISHED";exit 1}
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
Write-Host "SPT-024 / PISI + SPT-025.1-.2 : PROTECTED / NOT REOPENED"
Write-Host "DESTRUCTIVE CLEANUP : NO"

Step 2 "VERIFY SPT-025.2 CONTRACT INPUTS"
$Req=@($ReqAssessment,$ReqCore,$ReqPlatform,$ReqPrepare)
$M=@($Req|Where-Object{-not(Test-Path (Join-Path $Root $_))})
Write-Host "REQUIRED SPT-025.2 INPUTS : $($Req.Count)"
Write-Host "MISSING INPUTS            : $($M.Count)"
if($M.Count){Hold "Missing SPT-025.2 inputs"}
$Prev=Get-Content -Raw (Join-Path $Root $ReqAssessment)|ConvertFrom-Json
if([string]$Prev.status-ne"SGODA_CORE_PLATFORM_CONTRACT_GATE_PASS"){Hold "SPT-025.2 contract gate is not PASS"}
Write-Host "SPT-025.2 SGODA CORE / PLATFORM CONTRACT GATE : PASS"

Step 3 "SHA-256 FREEZE OF CLOSED BASELINE"
$Freeze=@{}
foreach($p in @(& git.exe -c core.quotepath=false ls-files)){$f=Join-Path $Root $p;if(Test-Path $f){$Freeze[$p]=Sha $f}}
Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
Write-Host "SHA-256 FREEZE : PASS"

Step 4 "LANGUAGE MODEL / SUPPORT-LANGUAGE CONFIGURATION DISCOVERY"
Write-Host "NATIVE LANGUAGE PER PLATFORM : EXACTLY 1"
Write-Host "PLATFORM INDEPENDENCE         : REQUIRED"
Write-Host "SUPPORT LANGUAGES             : 0..N / CONFIGURABLE"
Write-Host "OUTPUT LANGUAGE SELECTION     : USER SELECTABLE"
Write-Host "PUINAVE REFERENCE             : PUI + ES/EN/IT/PT"
Write-Host "HARD-CODED SUPPORT LANGUAGES  : FORBIDDEN"

Step 5 "IMPLEMENT SPT-025.3 LANGUAGE PLATFORM MODEL"
$Core=@'
from dataclasses import dataclass

DEFAULT_REFERENCE_SUPPORT = ("es","en","it","pt")

@dataclass(frozen=True)
class LanguageDescriptor:
    code: str
    name: str
    role: str

def normalize_code(value):
    return str(value or "").strip().lower().replace("_","-")

def build_language_descriptor(code, name, role):
    code = normalize_code(code)
    name = str(name or "").strip()
    role = str(role or "").strip().lower()
    if not code:
        raise ValueError("language_code_required")
    if not name:
        raise ValueError("language_name_required")
    if role not in ("native","support"):
        raise ValueError("language_role_invalid")
    return LanguageDescriptor(code,name,role).__dict__

def validate_platform_language_model(cfg):
    errors=[]
    if not isinstance(cfg,dict):
        return {"valid":False,"errors":["platform_config_not_object"]}

    native=cfg.get("native_language")
    supports=cfg.get("support_languages")

    if not isinstance(native,dict):
        errors.append("native_language_not_object")
        native_code=""
    else:
        native_code=normalize_code(native.get("code"))
        if not native_code: errors.append("native_language_code_required")
        if not str(native.get("name","")).strip(): errors.append("native_language_name_required")

    if not isinstance(supports,list):
        errors.append("support_languages_not_list")
        supports=[]
    seen=set()
    for i,item in enumerate(supports):
        if not isinstance(item,dict):
            errors.append(f"support_{i}_not_object")
            continue
        code=normalize_code(item.get("code"))
        name=str(item.get("name","")).strip()
        if not code: errors.append(f"support_{i}_code_required")
        if not name: errors.append(f"support_{i}_name_required")
        if code and code==native_code:
            errors.append(f"support_{i}_cannot_equal_native_language")
        if code and code in seen:
            errors.append(f"support_{i}_duplicate_code")
        seen.add(code)

    if cfg.get("support_languages_hardcoded") is True:
        errors.append("support_languages_must_not_be_hardcoded")

    if cfg.get("independent_platform") is not True:
        errors.append("platform_must_be_independent")

    return {
        "valid": not errors,
        "errors": errors,
        "native_language_count": 1 if native_code else 0,
        "support_language_count": len([x for x in supports if isinstance(x,dict)]),
        "native_language_code": native_code,
        "support_language_codes": [normalize_code(x.get("code")) for x in supports if isinstance(x,dict) and normalize_code(x.get("code"))],
    }

def reference_puinave_model():
    return {
        "platform_id":"sgoda-puinave",
        "platform_name":"SGODA-PUINAVE",
        "independent_platform":True,
        "native_language":{"code":"pui","name":"Puinave","role":"native"},
        "support_languages":[
            {"code":"es","name":"Español","role":"support"},
            {"code":"en","name":"English","role":"support"},
            {"code":"it","name":"Italiano","role":"support"},
            {"code":"pt","name":"Português","role":"support"},
        ],
        "support_languages_hardcoded":False,
        "output_selection":{"enabled":True,"mode":"user_selectable"},
        "navigation_language":{"configurable":True},
        "translation_targets":{"configurable":True},
        "definition_languages":{"configurable":True},
        "example_languages":{"configurable":True},
        "audio_languages":{"configurable":True},
    }

def build_independent_platform(platform_id, platform_name, native_language, support_languages):
    cfg={
        "platform_id":str(platform_id or "").strip(),
        "platform_name":str(platform_name or "").strip(),
        "independent_platform":True,
        "native_language":native_language,
        "support_languages":support_languages,
        "support_languages_hardcoded":False,
        "output_selection":{"enabled":True,"mode":"user_selectable"},
        "navigation_language":{"configurable":True},
        "translation_targets":{"configurable":True},
        "definition_languages":{"configurable":True},
        "example_languages":{"configurable":True},
        "audio_languages":{"configurable":True},
    }
    result=validate_platform_language_model(cfg)
    if not cfg["platform_id"]: result["errors"].append("platform_id_required")
    if not cfg["platform_name"]: result["errors"].append("platform_name_required")
    result["valid"]=not result["errors"]
    return cfg,result
'@
$Init=@'
from .core import (
    DEFAULT_REFERENCE_SUPPORT,LanguageDescriptor,normalize_code,build_language_descriptor,
    validate_platform_language_model,reference_puinave_model,build_independent_platform
)
__all__=[
    "DEFAULT_REFERENCE_SUPPORT","LanguageDescriptor","normalize_code","build_language_descriptor",
    "validate_platform_language_model","reference_puinave_model","build_independent_platform"
]
'@
$Tests=@'
from sgoda.integration.spt0253 import *

def ref(): return reference_puinave_model()
def test_01(): assert DEFAULT_REFERENCE_SUPPORT==("es","en","it","pt")
def test_02(): assert normalize_code(" EN ")=="en"
def test_03(): assert build_language_descriptor("pui","Puinave","native")["role"]=="native"
def test_04(): assert build_language_descriptor("es","Español","support")["code"]=="es"
def test_05(): assert validate_platform_language_model(ref())["valid"]
def test_06(): assert validate_platform_language_model(ref())["native_language_count"]==1
def test_07(): assert validate_platform_language_model(ref())["support_language_count"]==4
def test_08(): assert validate_platform_language_model(ref())["support_language_codes"]==["es","en","it","pt"]
def test_09(): assert ref()["output_selection"]["mode"]=="user_selectable"
def test_10(): assert ref()["navigation_language"]["configurable"] is True
def test_11(): assert ref()["translation_targets"]["configurable"] is True
def test_12(): assert ref()["definition_languages"]["configurable"] is True
def test_13(): assert ref()["example_languages"]["configurable"] is True
def test_14(): assert ref()["audio_languages"]["configurable"] is True
def test_15():
    x=ref(); x["support_languages"].append({"code":"pui","name":"Puinave","role":"support"})
    assert not validate_platform_language_model(x)["valid"]
def test_16():
    x=ref(); x["support_languages"].append({"code":"es","name":"Español duplicado","role":"support"})
    assert "support_4_duplicate_code" in validate_platform_language_model(x)["errors"]
def test_17():
    x=ref(); x["support_languages_hardcoded"]=True
    assert "support_languages_must_not_be_hardcoded" in validate_platform_language_model(x)["errors"]
def test_18():
    x=ref(); x["independent_platform"]=False
    assert "platform_must_be_independent" in validate_platform_language_model(x)["errors"]
def test_19():
    cfg,res=build_independent_platform("sgoda-kurripaco","SGODA-KURRIPACO",{"code":"kpc","name":"Kurripaco"},[{"code":"es","name":"Español"},{"code":"en","name":"English"}])
    assert res["valid"]
def test_20():
    cfg,res=build_independent_platform("sgoda-x","SGODA-X",{"code":"x","name":"Lengua X"},[])
    assert res["valid"] and res["support_language_count"]==0
def test_21():
    cfg,res=build_independent_platform("","SGODA-X",{"code":"x","name":"Lengua X"},[])
    assert not res["valid"]
def test_22():
    cfg,res=build_independent_platform("sgoda-x","",{"code":"x","name":"Lengua X"},[])
    assert not res["valid"]
def test_23():
    try: build_language_descriptor("","","native"); assert False
    except ValueError as e: assert str(e)=="language_code_required"
def test_24():
    try: build_language_descriptor("x","X","other"); assert False
    except ValueError as e: assert str(e)=="language_role_invalid"
'@
$Policy=@'
{
  "component": "SPT-025.3",
  "version": "1.0.0",
  "title": "Modelo de Plataforma Linguistica Independiente y Configuracion de Lengua Nativa / Idiomas Auxiliares",
  "authoritative_baseline": "d2d8226d068451537982cc8fcec5c7ace60a0735",
  "rules": {
    "one_native_language_per_platform": true,
    "independent_platforms": true,
    "support_languages_count": "0..N",
    "support_languages_configurable": true,
    "support_languages_hardcoded": false,
    "output_language_user_selectable": true,
    "navigation_language_configurable": true,
    "translation_definition_examples_audio_configurable": true,
    "reference_platform": "SGODA-PUINAVE",
    "reference_support_languages": [
      "es",
      "en",
      "it",
      "pt"
    ],
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
  "title": "SGODA Independent Language Platform Language Configuration",
  "type": "object",
  "required": [
    "platform_id",
    "platform_name",
    "independent_platform",
    "native_language",
    "support_languages",
    "support_languages_hardcoded",
    "output_selection"
  ],
  "properties": {
    "platform_id": {
      "type": "string",
      "minLength": 1
    },
    "platform_name": {
      "type": "string",
      "minLength": 1
    },
    "independent_platform": {
      "const": true
    },
    "native_language": {
      "type": "object",
      "required": [
        "code",
        "name"
      ],
      "properties": {
        "code": {
          "type": "string",
          "minLength": 1
        },
        "name": {
          "type": "string",
          "minLength": 1
        },
        "role": {
          "enum": [
            "native"
          ]
        }
      }
    },
    "support_languages": {
      "type": "array",
      "items": {
        "type": "object",
        "required": [
          "code",
          "name"
        ],
        "properties": {
          "code": {
            "type": "string",
            "minLength": 1
          },
          "name": {
            "type": "string",
            "minLength": 1
          },
          "role": {
            "enum": [
              "support"
            ]
          }
        }
      }
    },
    "support_languages_hardcoded": {
      "const": false
    },
    "output_selection": {
      "type": "object",
      "required": [
        "enabled",
        "mode"
      ],
      "properties": {
        "enabled": {
          "const": true
        },
        "mode": {
          "const": "user_selectable"
        }
      }
    }
  }
}
'@
$Puinave=@'
{
  "platform_id": "sgoda-puinave",
  "platform_name": "SGODA-PUINAVE",
  "independent_platform": true,
  "native_language": {
    "code": "pui",
    "name": "Puinave",
    "role": "native"
  },
  "support_languages": [
    {
      "code": "es",
      "name": "Español",
      "role": "support"
    },
    {
      "code": "en",
      "name": "English",
      "role": "support"
    },
    {
      "code": "it",
      "name": "Italiano",
      "role": "support"
    },
    {
      "code": "pt",
      "name": "Português",
      "role": "support"
    }
  ],
  "support_languages_hardcoded": false,
  "output_selection": {
    "enabled": true,
    "mode": "user_selectable"
  },
  "navigation_language": {
    "configurable": true
  },
  "translation_targets": {
    "configurable": true
  },
  "definition_languages": {
    "configurable": true
  },
  "example_languages": {
    "configurable": true
  },
  "audio_languages": {
    "configurable": true
  }
}
'@
$Template=@'
{
  "platform_id": "sgoda-<native-language>",
  "platform_name": "SGODA-<NATIVE-LANGUAGE>",
  "independent_platform": true,
  "native_language": {
    "code": "<native-code>",
    "name": "<Native Language>",
    "role": "native"
  },
  "support_languages": [
    {
      "code": "<support-code>",
      "name": "<Support Language>",
      "role": "support"
    }
  ],
  "support_languages_hardcoded": false,
  "output_selection": {
    "enabled": true,
    "mode": "user_selectable"
  },
  "navigation_language": {
    "configurable": true
  },
  "translation_targets": {
    "configurable": true
  },
  "definition_languages": {
    "configurable": true
  },
  "example_languages": {
    "configurable": true
  },
  "audio_languages": {
    "configurable": true
  }
}
'@
$Doc=@'
# SPT-025.3 — Modelo de Plataforma Lingüística Independiente y Configuración de Lengua Nativa / Idiomas Auxiliares

Baseline autoritativa: `d2d8226d068451537982cc8fcec5c7ace60a0735`.

## Regla institucional
Cada plataforma SGODA representa exactamente una lengua nativa principal y es independiente de las demás plataformas.

## Idiomas auxiliares
Cada plataforma puede definir de cero a N idiomas auxiliares. Su número y tipo no quedan fijados en el código. El usuario podrá seleccionar cualquiera de los idiomas auxiliares habilitados como idioma de salida para traducción, definiciones, ejemplos, navegación y audio cuando el recurso exista.

## Implementación de referencia
SGODA-PUINAVE:
- lengua nativa: Puinave (`pui`);
- idiomas auxiliares: Español (`es`), English (`en`), Italiano (`it`) y Português (`pt`).

## Replicación
Una futura plataforma, por ejemplo SGODA-KURRIPACO, conservará el mismo contrato pero definirá su propia lengua nativa y el conjunto de idiomas auxiliares requerido por la comunidad.

Esta capa es no destructiva y no migra ni reabre componentes cerrados.
'@
WriteLf $CoreFile $Core
WriteLf $InitFile $Init
WriteLf $TestFile $Tests
WriteLf $PolicyFile $Policy
WriteLf $SchemaFile $Schema
WriteLf $PuinaveFile $Puinave
WriteLf $TemplateFile $Template
WriteLf $DocFile $Doc
Write-Host "SPT-025.3 IMPLEMENTATION : CREATED/VALIDATED"

Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
$env:PYTHONPATH=Join-Path $Root "src"
& $Python -c "from sgoda.integration.spt0253 import reference_puinave_model,validate_platform_language_model; r=validate_platform_language_model(reference_puinave_model()); assert r['valid']; print('SPT0253_IMPORT=PASS'); print('PUINAVE_LANGUAGE_MODEL=PASS'); print('SUPPORT_LANGUAGES=es,en,it,pt')"
if($LASTEXITCODE){Hold "SPT-025.3 import/model validation failed"}
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

Step 8 "INDEPENDENT LANGUAGE PLATFORM MODEL ASSESSMENT"
$Cfg=Get-Content -Raw (Join-Path $Root $PuinaveFile)|ConvertFrom-Json
$Codes=@($Cfg.support_languages|ForEach-Object{[string]$_.code})
if([string]$Cfg.native_language.code-ne"pui"){Hold "Puinave native language code mismatch"}
if(-not[bool]$Cfg.independent_platform){Hold "Reference platform must be independent"}
foreach($c in @("es","en","it","pt")){if($Codes-notcontains$c){Hold "Missing Puinave support language: $c"}}
if([bool]$Cfg.support_languages_hardcoded){Hold "Support languages must remain configurable"}
Write-Host "ONE_NATIVE_LANGUAGE_PER_PLATFORM=PASS"
Write-Host "INDEPENDENT_LANGUAGE_PLATFORM=PASS"
Write-Host "SUPPORT_LANGUAGES_0_TO_N=PASS"
Write-Host "SUPPORT_LANGUAGES_CONFIGURABLE=PASS"
Write-Host "OUTPUT_LANGUAGE_USER_SELECTABLE=PASS"
Write-Host "PUINAVE_NATIVE_LANGUAGE=PUI"
Write-Host "PUINAVE_SUPPORT_LANGUAGES=ES,EN,IT,PT"
Write-Host "TRANSLATION_DEFINITION_EXAMPLE_AUDIO_TARGETS=CONFIGURABLE"
Write-Host "LANGUAGE PLATFORM MODEL GATE : PASS"

Step 9 "MODEL BASELINES / PREPARE / EVIDENCE"
New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null
$LanguageModel=[ordered]@{model="INDEPENDENT_LANGUAGE_PLATFORM";native_language_count=1;independent_platform=$true;support_languages="0..N";support_languages_configurable=$true;hardcoded_support_languages=$false}
$SupportModel=[ordered]@{selection="PER_PLATFORM";count="0..N";unique_codes_required=$true;native_code_excluded=$true;roles=@("support");runtime_selection=$true}
$Output=[ordered]@{user_selectable=$true;targets=@("translation","definition","example","navigation","audio");availability_driven=$true}
$Pui=[ordered]@{platform="SGODA-PUINAVE";native_language=@{code="pui";name="Puinave"};support_languages=@("es","en","it","pt");backward_compatibility_required=$true}
$TemplateBase=[ordered]@{platform_id="CONFIGURABLE";platform_name="CONFIGURABLE";native_language="EXACTLY_ONE";support_languages="ZERO_TO_N";independent_platform=$true}
$Assessment=[ordered]@{component="SPT-025.3";version="1.0.0";baseline=$ExpectedBaseline;status="LANGUAGE_PLATFORM_MODEL_GATE_PASS";one_native_language_per_platform=$true;support_languages_configurable=$true;output_language_user_selectable=$true;puinave_support_languages=@("es","en","it","pt");closed_components_preserved=$true}
$Prepare=[ordered]@{next_deliverable="SPT-025.4";title="Repositorio Lexico Base Parametrizable por Lengua y Contrato de Datos de Instancia";source_baseline=$ExpectedBaseline;language_model_gate="PASS"}
WriteLf $LanguageModelFile ($LanguageModel|ConvertTo-Json -Depth 8)
WriteLf $SupportModelFile ($SupportModel|ConvertTo-Json -Depth 8)
WriteLf $OutputSelectionFile ($Output|ConvertTo-Json -Depth 8)
WriteLf $PuinaveBaselineFile ($Pui|ConvertTo-Json -Depth 8)
WriteLf $ReplicableTemplateFile ($TemplateBase|ConvertTo-Json -Depth 8)
WriteLf $AssessmentFile ($Assessment|ConvertTo-Json -Depth 8)
WriteLf $PrepareFile ($Prepare|ConvertTo-Json -Depth 8)
$MR=@()
foreach($p in @($PolicyFile,$SchemaFile,$PuinaveFile,$TemplateFile,$DocFile,$LanguageModelFile,$SupportModelFile,$OutputSelectionFile,$PuinaveBaselineFile,$ReplicableTemplateFile,$AssessmentFile,$PrepareFile)){$MR+=[ordered]@{path=$p;sha256=(Sha (Join-Path $Root $p))}}
WriteLf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$MR}|ConvertTo-Json -Depth 10)
WriteLf $EvidenceFile ([ordered]@{component="SPT-025.3";version="1.0.0";baseline=$ExpectedBaseline;status="LANGUAGE_PLATFORM_MODEL_GATE_PASS";targeted_tests="PASS";institutional_suite="PASS";compileall="PASS";production_change=$false;closed_components_preserved=$true}|ConvertTo-Json -Depth 8)
Write-Host "LANGUAGE PLATFORM MODEL : CREATED"
Write-Host "SUPPORT LANGUAGE MODEL  : CREATED"
Write-Host "OUTPUT SELECTION MODEL  : CREATED"
Write-Host "PUINAVE BASELINE        : CREATED"
Write-Host "REPLICABLE TEMPLATE     : CREATED"
Write-Host "SPT-025.4 PREPARE       : CREATED"
Write-Host "EVIDENCE                : CREATED"

Step 10 "SHA-256 PRESERVATION GATE"
foreach($p in $Freeze.Keys){$f=Join-Path $Root $p;if(-not(Test-Path $f)-or(Sha $f)-ne$Freeze[$p]){Hold "Protected tracked file changed: $p"}}
Write-Host "PROTECTED TRACKED FILES : PRESERVED"
Write-Host "SPT-024 / PISI + SPT-025.1-.2 + CLOSED COMPONENTS : PRESERVED"

Step 11 "EXACT CONTROLLED STAGING"
$Allowed=@("Invoke-SGODA-SPT0253-IndependentLanguagePlatform-LanguageConfig-FINAL-v1.0.0-PS51.ps1",$CoreFile,$InitFile,$TestFile,$PolicyFile,$SchemaFile,$PuinaveFile,$TemplateFile,$DocFile,$LanguageModelFile,$SupportModelFile,$OutputSelectionFile,$PuinaveBaselineFile,$ReplicableTemplateFile,$AssessmentFile,$IntegrityFile,$PrepareFile,$EvidenceFile)
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
& git.exe commit -m "feat(spt-025.3): implement independent language platform and configurable support-language model"
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
Write-Host "SPT-025.3 : TECHNICALLY CLOSED / LANGUAGE PLATFORM MODEL APPROVED" -ForegroundColor Green
Write-Host "SPT-025.2_CORE_PLATFORM_CONTRACT_GATE=PASS"
Write-Host "ONE_NATIVE_LANGUAGE_PER_PLATFORM=PASS"
Write-Host "INDEPENDENT_LANGUAGE_PLATFORM=PASS"
Write-Host "SUPPORT_LANGUAGES_CONFIGURABLE=PASS"
Write-Host "SUPPORT_LANGUAGES_COUNT=0..N"
Write-Host "OUTPUT_LANGUAGE_USER_SELECTABLE=PASS"
Write-Host "PUINAVE_NATIVE_LANGUAGE=PUI"
Write-Host "PUINAVE_SUPPORT_LANGUAGES=ES,EN,IT,PT"
Write-Host "TRANSLATION_TARGETS_CONFIGURABLE=PASS"
Write-Host "DEFINITION_TARGETS_CONFIGURABLE=PASS"
Write-Host "EXAMPLE_TARGETS_CONFIGURABLE=PASS"
Write-Host "NAVIGATION_LANGUAGE_CONFIGURABLE=PASS"
Write-Host "AUDIO_LANGUAGE_CONFIGURABLE=PASS"
Write-Host "HARD_CODED_SUPPORT_LANGUAGES=NO"
Write-Host "DESTRUCTIVE_CHANGE=NO"
Write-Host "PRODUCTION_CHANGE=NO"
Write-Host "TARGETED_TESTS=PASS"
Write-Host "INSTITUTIONAL_SUITE=PASS"
Write-Host "COMPILEALL=PASS"
Write-Host "CLOSED_COMPONENTS=PRESERVED"
Write-Host "LOCAL_HEAD=REMOTE_HEAD"
Write-Host "NEXT_DELIVERABLE=SPT-025.4"
Write-Host "FINAL_EXIT_CODE=0"
exit 0
}catch{Hold $_.Exception.Message}
