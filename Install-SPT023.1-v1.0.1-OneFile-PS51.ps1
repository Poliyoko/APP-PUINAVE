<#
SPT-023.1 v1.0.1 - Detector Inteligente de Palabras
Windows PowerShell 5.1 / ASCII
#>
[CmdletBinding()]
param(
    [string]$SourcePath = "",
    [switch]$RunDetection,
    [switch]$PreparePublication
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Component = "SPT-023.1"
$Version = "1.0.1"
$Baseline = "SPT-022.1 CLOSED"
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")

function Step([string]$Text){ Write-Host ""; Write-Host "==> $Text" -ForegroundColor Cyan }
function Write-Utf8NoBom([string]$Path,[string]$Content){
    $Parent=Split-Path -Parent $Path
    if($Parent -and -not(Test-Path -LiteralPath $Parent)){New-Item -ItemType Directory -Path $Parent -Force|Out-Null}
    [IO.File]::WriteAllText($Path,$Content,(New-Object Text.UTF8Encoding($false)))
}
function Write-Json([string]$Path,[object]$Data){ Write-Utf8NoBom $Path (($Data|ConvertTo-Json -Depth 50)+"`r`n") }
function Test-Ps([string]$Path){$t=$null;$e=$null;[void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e);@($e)}
function Root(){
    $r=@(& git rev-parse --show-toplevel 2>$null)
    if($LASTEXITCODE -ne 0 -or $r.Count -eq 0){throw "Ejecute desde SGODA-PUINAVE."}
    [IO.Path]::GetFullPath(([string]$r[0]).Trim())
}

$ProjectRoot=Root
Set-Location -LiteralPath $ProjectRoot
$Src=Join-Path $ProjectRoot 'src'
$Pkg=Join-Path $Src 'sgoda\integration\spt0231'
$ApiRoot=Join-Path $Src 'sgoda\api'
$Tests=Join-Path $ProjectRoot 'tests\integration'
$Cfg=Join-Path $ProjectRoot 'config\integration\spt0231'
$Docs=Join-Path $ProjectRoot 'docs\06_Tecnologia\SPT-023.1'
$Runtime=Join-Path $ProjectRoot 'artifacts\runtime\spt0231'
$Run=Join-Path $ProjectRoot ("artifacts\development\SPT-023.1-v1.0.1\runs\"+$RunId)
foreach($d in @($Pkg,$ApiRoot,$Tests,$Cfg,$Docs,$Runtime,$Run)){New-Item -ItemType Directory -Path $d -Force|Out-Null}

Step 'Verificando linea base institucional'
$req=@(
 'tools\institutional\Publish-SGODA-WithMasterBook.ps1',
 'tools\institutional\Invoke-SGD002-AutoUpdate.ps1',
 'automation\n8n\workflows\spt022',
 'docs\06_Tecnologia\SPT-022',
 'docs\06_Tecnologia\SPT-022.1'
)
$missing=@($req|Where-Object{-not(Test-Path -LiteralPath (Join-Path $ProjectRoot $_))})
if($missing.Count){throw ('Linea base incompleta: '+($missing -join ', '))}
Write-Host "Baseline: $Baseline"

Step 'Generando detector inteligente'
$init=@'
from .detector import IntelligentWordDetector, normalize_puinave, lexical_hash
from .registry import WordRegistry
from .service import Spt0231Service
__all__ = ["IntelligentWordDetector", "normalize_puinave", "lexical_hash", "WordRegistry", "Spt0231Service"]
'@
Write-Utf8NoBom (Join-Path $Pkg '__init__.py') $init

$registry=@'
import json
from pathlib import Path
class WordRegistry:
    def __init__(self,path):
        self.path=Path(path); self.path.parent.mkdir(parents=True,exist_ok=True); self.words={}; self.hashes=set(); self._load()
    def _load(self):
        if not self.path.exists(): return
        data=json.loads(self.path.read_text(encoding="utf-8"))
        for x in data.get("words",[]):
            n=str(x.get("normalized_puinave","")).strip(); h=str(x.get("lexical_hash","")).strip()
            if n:self.words[n]=h
            if h:self.hashes.add(h)
    def contains(self,n,h=None): return n in self.words or (bool(h) and h in self.hashes)
    def add(self,n,h): self.words[n]=h; self.hashes.add(h)
    def save(self):
        payload={"schema":"spt0231.word-registry.v1","words":[{"normalized_puinave":n,"lexical_hash":h} for n,h in sorted(self.words.items())]}
        self.path.write_text(json.dumps(payload,ensure_ascii=False,indent=2,sort_keys=True)+"\n",encoding="utf-8")
'@
Write-Utf8NoBom (Join-Path $Pkg 'registry.py') $registry

$sources=@'
import csv,json
from pathlib import Path
KEYS=("puinave","palabra_puinave","palabra","native","word","termino")
def _word(row):
    low={str(k).strip().lower():v for k,v in row.items()}
    for k in KEYS:
        v=low.get(k)
        if v is not None and str(v).strip(): return str(v).strip()
    return ""
def load_records(path):
    path=Path(path); s=path.suffix.lower(); rows=[]
    if s==".json":
        data=json.loads(path.read_text(encoding="utf-8-sig"))
        if isinstance(data,dict): data=next((data[k] for k in ("words","palabras","records","data") if isinstance(data.get(k),list)),[data])
        rows=[x if isinstance(x,dict) else {"puinave":str(x)} for x in data]
    elif s==".csv":
        with path.open("r",encoding="utf-8-sig",newline="") as f: rows=list(csv.DictReader(f))
    elif s in (".xlsx",".xlsm"):
        try: import openpyxl
        except ImportError as e: raise RuntimeError("Excel requires openpyxl (free/open-source).") from e
        wb=openpyxl.load_workbook(str(path),read_only=True,data_only=True); ws=wb.active; it=ws.iter_rows(values_only=True)
        try: headers=[str(v).strip() if v is not None else f"column_{i+1}" for i,v in enumerate(next(it))]
        except StopIteration: return []
        rows=[{headers[i]:v for i,v in enumerate(vals) if i<len(headers)} for vals in it]
    else: raise ValueError("Unsupported source; use JSON, CSV, XLSX or XLSM.")
    out=[]
    for r in rows:
        d={str(k).strip():v for k,v in dict(r).items()}; d["_puinave"]=_word(d); out.append(d)
    return out
'@
Write-Utf8NoBom (Join-Path $Pkg 'sources.py') $sources

$detector=@'
import hashlib,unicodedata
from .sources import load_records

def normalize_puinave(value): return " ".join(unicodedata.normalize("NFC",str(value or "")).strip().split()).casefold()
def lexical_hash(n): return hashlib.sha256(("PUINAVE|"+n).encode("utf-8")).hexdigest()
class IntelligentWordDetector:
    def __init__(self,registry): self.registry=registry
    def detect_records(self,records,source):
        words=[]; seen=set(); c={"NEW":0,"EXISTING":0,"DUPLICATE":0,"INVALID":0}
        for i,r in enumerate(records,1):
            original=str(r.get("_puinave","") or "").strip(); n=normalize_puinave(original); h=lexical_hash(n) if n else ""
            if not n: status="INVALID"
            elif h in seen: status="DUPLICATE"
            elif self.registry.contains(n,h): status="EXISTING"
            else: status="NEW"; seen.add(h); self.registry.add(n,h)
            c[status]+=1
            words.append({"source_index":i,"puinave":original,"normalized_puinave":n,"lexical_hash":h,"status":status,"source":source,
              "category_status":"PENDING","image_status":"PENDING","audio_puinave_status":"PENDING_NATIVE_RECORDING",
              "audio_es_status":"PENDING","audio_en_status":"PENDING","audio_it_status":"PENDING","fld_status":"PENDING","oda_status":"PENDING",
              "validation_required":True,"metadata":{str(k):v for k,v in r.items() if k!="_puinave"}})
        self.registry.save()
        bh=hashlib.sha256("\n".join(sorted(x["lexical_hash"] for x in words if x["lexical_hash"])).encode("utf-8")).hexdigest()
        return {"source":source,"records_seen":len(records),"new_words":c["NEW"],"existing_words":c["EXISTING"],"duplicates":c["DUPLICATE"],"invalid":c["INVALID"],"batch_hash":bh,"words":words}
    def detect_file(self,path): return self.detect_records(load_records(path),str(path))
'@
Write-Utf8NoBom (Join-Path $Pkg 'detector.py') $detector

$events=@'
import json
from datetime import datetime,timezone
def build_events(batch):
    out=[]
    for w in batch["words"]:
        if w["status"]!="NEW": continue
        out.append({"event_type":"SPT0231.NEW_PUINAVE_WORD","occurred_at":datetime.now(timezone.utc).isoformat(),"component":"SPT-023.1","payload":{
          "puinave":w["puinave"],"normalized_puinave":w["normalized_puinave"],"lexical_hash":w["lexical_hash"],"source":w["source"],"source_index":w["source_index"],
          "next_stages":["SPT-023.2_SEMANTIC_ANALYSIS","SPT-023.3_CATEGORY_ASSIGNMENT","SPT-023.4_IMAGE_GENERATION","SPT-023.5_AUDIO_PUINAVE","SPT-023.5_AUDIO_ES","SPT-023.5_AUDIO_EN","SPT-023.5_AUDIO_IT","SPT-023.6_FLD_ODA"],"requires_human_validation":True}})
    return out
def append_events(path,events):
    path.parent.mkdir(parents=True,exist_ok=True); n=0
    with path.open("a",encoding="utf-8") as f:
        for e in events: f.write(json.dumps(e,ensure_ascii=False,sort_keys=True)+"\n"); n+=1
    return n
'@
Write-Utf8NoBom (Join-Path $Pkg 'events.py') $events

$service=@'
import json
from pathlib import Path
from .registry import WordRegistry
from .detector import IntelligentWordDetector
from .events import build_events,append_events
class Spt0231Service:
    def __init__(self,root):
        self.root=Path(root); self.runtime=self.root/"artifacts"/"runtime"/"spt0231"
    def detect_file(self,source):
        batch=IntelligentWordDetector(WordRegistry(self.runtime/"word-registry.json")).detect_file(Path(source))
        batch["events_written"]=append_events(self.runtime/"events.jsonl",build_events(batch))
        batch["pipeline_contract"]={"semantic":"SPT-023.2","category":"SPT-023.3","image":"SPT-023.4","audio_puinave":"SPT-023.5","audio_es":"SPT-023.5","audio_en":"SPT-023.5","audio_it":"SPT-023.5","fld_oda":"SPT-023.6"}
        self.runtime.mkdir(parents=True,exist_ok=True); (self.runtime/"last-detection.json").write_text(json.dumps(batch,ensure_ascii=False,indent=2,sort_keys=True)+"\n",encoding="utf-8")
        return batch
'@
Write-Utf8NoBom (Join-Path $Pkg 'service.py') $service

$cli=@'
import argparse,json
from pathlib import Path
from .service import Spt0231Service
def main():
    p=argparse.ArgumentParser(); p.add_argument("--project-root",required=True); p.add_argument("--source",required=True); a=p.parse_args()
    print(json.dumps(Spt0231Service(Path(a.project_root)).detect_file(Path(a.source)),ensure_ascii=False,indent=2,sort_keys=True)); return 0
if __name__=="__main__": raise SystemExit(main())
'@
Write-Utf8NoBom (Join-Path $Pkg 'cli.py') $cli

Step 'Generando API FastAPI SPT-023.1'
$ApiContent=@'
import os
from pathlib import Path
from fastapi import APIRouter,HTTPException
from pydantic import BaseModel
from sgoda.integration.spt0231.service import Spt0231Service
router=APIRouter(prefix="/api/spt0231",tags=["SPT-023.1"])
class DetectionRequest(BaseModel): source_path:str
@router.get("/health")
def health(): return {"component":"SPT-023.1","status":"OPERATIONAL","capability":"INTELLIGENT_PUINAVE_WORD_DETECTION"}
@router.post("/detect")
def detect(req:DetectionRequest):
    root=Path(os.environ.get("SGODA_PROJECT_ROOT",Path.cwd())).resolve(); source=Path(req.source_path); source=source if source.is_absolute() else (root/source).resolve()
    try:return Spt0231Service(root).detect_file(source)
    except Exception as e: raise HTTPException(status_code=400,detail=str(e)) from e
'@
if([string]::IsNullOrWhiteSpace([string]$ApiRoot)){throw 'ApiRoot no inicializado.'}
if(-not(Test-Path -LiteralPath $ApiRoot -PathType Container)){New-Item -ItemType Directory -Path $ApiRoot -Force|Out-Null}
if([string]::IsNullOrWhiteSpace([string]$ApiContent)){throw 'ApiContent no generado.'}
Write-Host 'API path/content variable separation: OK'
Write-Utf8NoBom (Join-Path $ApiRoot 'spt0231_routes.py') $ApiContent

$FastApiIntegrated=$false
$mainCandidates=@((Join-Path $Src 'sgoda\main.py'),(Join-Path $Src 'sgoda\api\main.py'),(Join-Path $Src 'main.py'))
foreach($m in $mainCandidates){
 if(Test-Path -LiteralPath $m){$txt=Get-Content -LiteralPath $m -Raw;if($txt -match 'FastAPI\s*\('){
   if($txt -notmatch 'spt0231_routes'){$txt='from sgoda.api.spt0231_routes import router as spt0231_router'+"`r`n"+$txt.TrimEnd()+"`r`n`r`napp.include_router(spt0231_router)`r`n";Write-Utf8NoBom $m $txt}
   $FastApiIntegrated=$true;break
 }}
}
Write-Host "FastAPI integration: $FastApiIntegrated"

Step 'Generando configuracion y comando operativo'
$config=[ordered]@{schema='spt0231.detector.config.v1';component='SPT-023.1';version='1.0.1';canonical_language='puinave';source_formats=@('json','csv','xlsx','xlsm');downstream_audio_languages=@('puinave','es','en','it');duplicate_policy='NORMALIZED_FORM_AND_SHA256';category_stage='SPT-023.3';image_stage='SPT-023.4';audio_stage='SPT-023.5';human_validation='REQUIRED_FOR_NEW_WORDS';paid_services=$false}
Write-Json (Join-Path $Cfg 'detector-config.json') $config
$wrapperPath=Join-Path $ProjectRoot 'tools\institutional\Invoke-SPT0231-WordDetection.ps1'
$wrapper=@'
[CmdletBinding()]param([Parameter(Mandatory=$true)][string]$SourcePath)
Set-StrictMode -Version Latest;$ErrorActionPreference="Stop"
$r=@(& git rev-parse --show-toplevel 2>$null);if($LASTEXITCODE -ne 0 -or $r.Count -eq 0){throw "No repository root."}
$root=([string]$r[0]).Trim();$source=$SourcePath;if(-not[IO.Path]::IsPathRooted($source)){$source=Join-Path $root $source};if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw "Source not found: $source"}
$env:PYTHONPATH=Join-Path $root "src";& python -m sgoda.integration.spt0231.cli --project-root $root --source $source;if($LASTEXITCODE -ne 0){throw "SPT-023.1 detection failed."}
'@
Write-Utf8NoBom $wrapperPath $wrapper

Step 'Generando pruebas SPT-023.1'
$testPath=Join-Path $Tests 'test_spt0231_detector.py'
$testsPy=@'
import json
from sgoda.integration.spt0231.detector import IntelligentWordDetector,normalize_puinave,lexical_hash
from sgoda.integration.spt0231.registry import WordRegistry
from sgoda.integration.spt0231.events import build_events
from sgoda.integration.spt0231.service import Spt0231Service

def test_normalize(): assert normalize_puinave("  AMDA  ")=="amda"
def test_hash_stable(): assert lexical_hash("amda")==lexical_hash("amda")
def test_new(tmp_path):
 d=IntelligentWordDetector(WordRegistry(tmp_path/"r.json")); b=d.detect_records([{"_puinave":"AMDA"}],"mem"); assert b["new_words"]==1 and b["words"][0]["status"]=="NEW"
def test_duplicate_same_batch(tmp_path):
 d=IntelligentWordDetector(WordRegistry(tmp_path/"r.json")); b=d.detect_records([{"_puinave":"AMDA"},{"_puinave":" amda "}],"mem"); assert b["new_words"]==1 and b["duplicates"]==1
def test_existing_next_batch(tmp_path):
 p=tmp_path/"r.json";IntelligentWordDetector(WordRegistry(p)).detect_records([{"_puinave":"AMDA"}],"a");b=IntelligentWordDetector(WordRegistry(p)).detect_records([{"_puinave":"AMDA"}],"b");assert b["existing_words"]==1
def test_invalid(tmp_path):
 b=IntelligentWordDetector(WordRegistry(tmp_path/"r.json")).detect_records([{"_puinave":""}],"m");assert b["invalid"]==1
def test_events_include_category_image_audio_it(tmp_path):
 b=IntelligentWordDetector(WordRegistry(tmp_path/"r.json")).detect_records([{"_puinave":"AMDA"}],"m");s=build_events(b)[0]["payload"]["next_stages"];assert "SPT-023.3_CATEGORY_ASSIGNMENT" in s and "SPT-023.4_IMAGE_GENERATION" in s and "SPT-023.5_AUDIO_IT" in s
def test_json_detection(tmp_path):
 p=tmp_path/"w.json";p.write_text(json.dumps([{"puinave":"AMDA"},{"puinave":"OTRA"}]),encoding="utf-8");r=Spt0231Service(tmp_path).detect_file(p);assert r["records_seen"]==2 and r["events_written"]==2
def test_registry_persists(tmp_path):
 p=tmp_path/"r.json";r=WordRegistry(p);r.add("amda",lexical_hash("amda"));r.save();assert WordRegistry(p).contains("amda",lexical_hash("amda"))
def test_pending_contract(tmp_path):
 w=IntelligentWordDetector(WordRegistry(tmp_path/"r.json")).detect_records([{"_puinave":"AMDA"}],"m")["words"][0];assert w["category_status"]=="PENDING" and w["image_status"]=="PENDING" and w["audio_es_status"]=="PENDING" and w["audio_en_status"]=="PENDING" and w["audio_it_status"]=="PENDING"
'@
Write-Utf8NoBom $testPath $testsPy

Step 'Generando documentacion institucional'
$arch=@"
# SPT-023.1 - Detector Inteligente de Palabras

## Objetivo
Detectar nuevas palabras Puinave incrementalmente, evitar reprocesamiento y emitir eventos hacia las siguientes capas SPT-023.

## Fuentes
JSON, CSV, XLSX, XLSM.

## Contrato
SPT0231.NEW_PUINAVE_WORD -> SPT-023.2 semantica -> SPT-023.3 categorias -> SPT-023.4 imagenes -> SPT-023.5 audio Puinave/ES/EN/IT -> SPT-023.6 FLD/ODA.

## Regla
SPT-023.1 detecta y registra; no inventa traducciones, categorias ni recursos multimedia.
"@
Write-Utf8NoBom (Join-Path $Docs 'SGD-SPT023.1-Arquitectura-Detector-Inteligente.md') $arch
$actPath=Join-Path $Docs 'ACT-023.1-Implementacion-Inicial.md'
Write-Utf8NoBom $actPath "# ACT-023.1`r`nStatus: IMPLEMENTED_PENDING_VALIDATION`r`n"

Step 'Validando sintaxis PowerShell generada'
$psErrors=@(Test-Ps $wrapperPath)
if($psErrors.Count){throw ("Errores PowerShell generados: "+$psErrors.Count)}
Write-Host 'Generated PowerShell syntax errors: 0'

Step 'Validando JSON'
try{Get-Content (Join-Path $Cfg 'detector-config.json') -Raw|ConvertFrom-Json|Out-Null}catch{throw 'Invalid detector-config.json'}
Write-Host 'Invalid JSON files: 0'

Step 'Compilando Python'
$env:PYTHONPATH=$Src
& python -m compileall -q src tests
$compile=$LASTEXITCODE
if($compile -ne 0){throw 'Python compileall fallo.'}
Write-Host 'Python compile exit code: 0'

Step 'Ejecutando pruebas SPT-023.1'
$spec=@(& python -m pytest -q $testPath 2>&1);$specExit=$LASTEXITCODE;$specText=$spec -join "`n";$spec|ForEach-Object{Write-Host $_};if($specExit -ne 0){throw 'Pruebas SPT-023.1 fallaron.'}
$m=[regex]::Match($specText,'(\d+)\s+passed');$specPassed=if($m.Success){[int]$m.Groups[1].Value}else{0};if($specPassed -lt 10){throw "Se esperaban 10 pruebas SPT-023.1."}

Step 'Ejecutando suite institucional completa'
$all=@(& python -m pytest -q 2>&1);$allExit=$LASTEXITCODE;$allText=$all -join "`n";$all|ForEach-Object{Write-Host $_};if($allExit -ne 0){throw 'Suite institucional fallo.'}
$m2=[regex]::Match($allText,'(\d+)\s+passed');$testsPassed=if($m2.Success){[int]$m2.Groups[1].Value}else{0};if($testsPassed -lt 828){throw ("Linea base esperada >=828, detectadas: "+$testsPassed)}

$detectionStatus='NOT_REQUESTED';$detectionOutput=''
if($RunDetection){
 Step 'Ejecutando deteccion'
 if([string]::IsNullOrWhiteSpace($SourcePath)){throw '-RunDetection requiere -SourcePath.'}
 $s=$SourcePath;if(-not[IO.Path]::IsPathRooted($s)){$s=Join-Path $ProjectRoot $s}
 $o=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wrapperPath -SourcePath $s 2>&1);if($LASTEXITCODE -ne 0){$o|ForEach-Object{Write-Host $_};throw 'Deteccion fallo.'}
 $detectionOutput=Join-Path $Run 'detection-output.json';Write-Utf8NoBom $detectionOutput (($o -join "`r`n")+"`r`n");$detectionStatus='EXECUTED'
}

Step 'Actualizando Libro Maestro SGD-002'
$masterStatus='NOT_AVAILABLE';$updater=Join-Path $ProjectRoot 'tools\institutional\Invoke-SGD002-AutoUpdate.ps1'
if(Test-Path -LiteralPath $updater){$u=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $updater -ProjectRoot $ProjectRoot -ForceUpdate 2>&1);$ux=$LASTEXITCODE;$ut=$u -join "`n";$u|ForEach-Object{Write-Host $_};if($ux -ne 0){throw 'Actualizacion SGD-002 fallo.'};if($ut -match 'SGD-002 AUTO-UPDATED'){$masterStatus='UPDATED'}elseif($ut -match 'fingerprint unchanged'){$masterStatus='UNCHANGED_ALREADY_CURRENT'}elseif($ut -match 'another execution is active'){$masterStatus='BUSY_NON_BLOCKING'}else{$masterStatus='EXIT_0'}}

$prepareStatus='NOT_REQUESTED'
if($PreparePublication){
 Step 'Ejecutando PREPARE institucional'
 $pub=Join-Path $ProjectRoot 'tools\institutional\Publish-SGODA-WithMasterBook.ps1';$p=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $pub -PrepareOnly 2>&1);$px=$LASTEXITCODE;$pt=$p -join "`n";$p|ForEach-Object{Write-Host $_};if($px -ne 0){throw 'PREPARE fallo.'};if($pt -match 'READY_FOR_PUBLICATION' -or $pt -match 'Institutional status:\s*PREPARED'){$prepareStatus='READY_FOR_PUBLICATION'}else{throw 'PREPARE no confirmado.'}
}

Step 'Generando evidencia institucional'
$evidencePath=Join-Path $Run 'implementation-evidence.json'
$e=[ordered]@{component=$Component;version=$Version;baseline=$Baseline;canonical_language='puinave';source_formats=@('json','csv','xlsx','xlsm');duplicate_policy='NORMALIZED_FORM_AND_SHA256';event_type='SPT0231.NEW_PUINAVE_WORD';downstream_audio_languages=@('puinave','es','en','it');category_stage='SPT-023.3';image_stage='SPT-023.4';audio_stage='SPT-023.5';api_path_content_collision_fix=$true;fastapi_integration=$FastApiIntegrated;generated_powershell_syntax_errors=0;invalid_json_files=0;python_compile_exit_code=0;specific_tests_passed=$specPassed;institutional_tests_passed=$testsPassed;detection_status=$detectionStatus;detection_output=$detectionOutput;master_book_status=$masterStatus;prepare_status=$prepareStatus;paid_services=$false;technical_errors=0;institutional_status='IMPLEMENTED'}
Write-Json $evidencePath $e
$act=@"
# ACT-023.1 - Implementacion del Detector Inteligente de Palabras

Component: SPT-023.1
Version: 1.0.1
Baseline: $Baseline
Status: IMPLEMENTED
Specific tests: $specPassed
Institutional tests: $testsPassed
Master Book: $masterStatus
Technical errors: 0
"@
Write-Utf8NoBom $actPath $act

Step 'Resultado final'
Write-Host "Component: $Component"
Write-Host "Version: $Version"
Write-Host "Baseline: $Baseline"
Write-Host 'Institutional detector: IMPLEMENTED'
Write-Host 'Canonical language: Puinave'
Write-Host 'Source formats: JSON, CSV, XLSX, XLSM'
Write-Host 'Duplicate policy: NORMALIZED_FORM_AND_SHA256'
Write-Host 'Category stage: SPT-023.3'
Write-Host 'Image stage: SPT-023.4'
Write-Host 'Audio stage: SPT-023.5'
Write-Host 'Audio languages: Puinave, Espanol, Ingles, Italiano'
Write-Host 'Generated PowerShell syntax errors: 0'
Write-Host 'Invalid JSON files: 0'
Write-Host 'Python compile exit code: 0'
Write-Host "SPT-023.1 tests passed: $specPassed"
Write-Host "Institutional tests passed: $testsPassed"
Write-Host "Detection status: $detectionStatus"
Write-Host "Master Book status: $masterStatus"
Write-Host "Prepare status: $prepareStatus"
Write-Host 'Paid services: NO'
Write-Host 'API path/content collision fix: ENABLED'
Write-Host 'Technical errors: 0'
Write-Host "Evidence: $evidencePath"
Write-Host "Act: $actPath"
Write-Host ''
Write-Host 'SPT-023.1 v1.0.1: IMPLEMENTED WITH ZERO TECHNICAL ERRORS.'
Write-Host 'Next institutional stage: SPT-023.2.'
