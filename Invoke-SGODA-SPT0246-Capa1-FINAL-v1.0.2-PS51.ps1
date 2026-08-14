#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "96f5d4a7f901cb294320fc85cee9a4aea93ccc7c"
$ExpectedOutsideScope = 56
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$SelfName = "Invoke-SGODA-SPT0246-Capa1-FINAL-v1.0.2-PS51.ps1"
$InputPackage = "SPT0246-Baseline-Input.zip"
$RuntimeFile = "artifacts/runtime/sgd002-auto/state.json"

$ModuleDir = "src/sgoda/integration/spt0246"
$TestFile = "tests/integration/test_spt0246_flutter_client_security_layer1.py"
$PolicyFile = "config/integration/spt0246/flutter-client-security-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-024/SPT-024.6/SGD-SPT024.6-Capa1-Flutter-Comunicaciones-Almacenamiento.md"
$ArtifactDir = "artifacts/development/SPT-024.6-Capa1-v1.0.0"
$AssessmentFile = "$ArtifactDir/client-security-assessment.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"

function Stop-Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host " SPT-024.6 CAPA 1 : HOLD" -ForegroundColor Red
    Write-Host " REASON           : $Reason" -ForegroundColor Red
    Write-Host " TRANSACTION      : NOT PUBLISHED" -ForegroundColor Red
    Write-Host "============================================================================" -ForegroundColor Red
    exit 1
}
function Step([int]$N,[string]$Text) {
    Write-Host ""
    Write-Host ("[{0}/14] {1}" -f $N,$Text) -ForegroundColor Cyan
}
function Native {
    param([string]$Exe,[string[]]$Args=@(),[string]$Label="Native command")
    & $Exe @Args
    if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE." }
}
function PythonExe {
    foreach ($p in @(".venv\Scripts\python.exe","venv\Scripts\python.exe")) {
        if (Test-Path -LiteralPath $p) { return (Resolve-Path $p).Path }
    }
    $cmd = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { return $cmd.Source }
    throw "Python executable not found."
}
function Norm([string]$P) {
    if ($null -eq $P) { return "" }
    return ($P.Trim('"') -replace '\\','/')
}
function Write-Lf([string]$Path,[string]$Text) {
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $u = New-Object System.Text.UTF8Encoding($false)
    $t = (($Text -replace "`r`n","`n") -replace "`r","`n")
    if (-not $t.EndsWith("`n")) { $t += "`n" }
    [IO.File]::WriteAllText((Join-Path $PWD $Path),$t,$u)
}
function IsTx([string]$P) {
    $p = Norm $P
    if ($p -eq $SelfName -or $p -eq $InputPackage -or $p -eq $TestFile -or $p -eq $PolicyFile -or $p -eq $DocFile) { return $true }
    if ($p.StartsWith("src/sgoda/integration/spt0246/")) { return $true }
    if ($p.StartsWith((Norm $ArtifactDir)+"/")) { return $true }
    return $false
}
function IsPublish([string]$P) {
    $p = Norm $P
    if ($p -eq $InputPackage) { return $false }
    return (IsTx $p)
}
function StatusRecords {
    $r=@()
    $lines=@(& git.exe -c core.quotepath=false status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect worktree." }
    foreach($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) { continue }
        $xy=$line.Substring(0,2); $p=$line.Substring(3)
        if($p -match ' -> '){$p=($p -split ' -> ')[-1]}
        $r += [pscustomobject]@{XY=$xy;Path=(Norm $p)}
    }
    return @($r)
}
function Finger([string]$P) {
    $n=$P -replace '/', [IO.Path]::DirectorySeparatorChar
    if(-not(Test-Path -LiteralPath $n)){return "MISSING"}
    $i=Get-Item -LiteralPath $n -Force
    if($i.PSIsContainer){return "DIRECTORY"}
    return (Get-FileHash -LiteralPath $n -Algorithm SHA256).Hash.ToUpperInvariant()
}
function Snapshot {
    $s=@{}
    foreach($r in @(StatusRecords)){
        $p=Norm $r.Path
        if($p -eq $RuntimeFile -or (IsTx $p)){continue}
        $s[$p]=[ordered]@{status=[string]$r.XY;sha256=(Finger $p)}
    }
    return $s
}
function Assert-Snapshot([hashtable]$Before,[string]$Label) {
    $now=@{}
    foreach($r in @(StatusRecords)){
        $p=Norm $r.Path
        if($p -eq $RuntimeFile -or (IsTx $p)){continue}
        $now[$p]=[ordered]@{status=[string]$r.XY;sha256=(Finger $p)}
    }
    $bad=@()
    foreach($p in @($Before.Keys+$now.Keys|Sort-Object -Unique)){
        if(-not $Before.ContainsKey($p)){$bad+="NEW OUTSIDE-SCOPE ITEM: $p";continue}
        if(-not $now.ContainsKey($p)){$bad+="PREEXISTING ITEM DISAPPEARED: $p";continue}
        if($Before[$p].status -ne $now[$p].status){$bad+="STATUS CHANGED: $p";continue}
        if($Before[$p].sha256 -ne $now[$p].sha256){$bad+="CONTENT CHANGED: $p"}
    }
    if($bad.Count){
        $bad|ForEach-Object{Write-Host $_ -ForegroundColor Red}
        Stop-Hold "$Label failed."
    }
    Write-Host "PREEXISTING OUTSIDE-SCOPE ITEMS : $($Before.Count)"
    Write-Host "PREEXISTING WORKTREE ITEMS       : PRESERVED"
}

try {
    Step 1 "AUTHORITATIVE BASELINE / RESUME / WORKTREE SAFETY"
    if(-not(Test-Path ".git")){Stop-Hold "Execute from official repository root."}
    Native "git.exe" @("fetch","origin",$Branch) "git fetch"
    $LH=(& git.exe rev-parse HEAD).Trim()
    $RH=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $St=@(& git.exe diff --cached --name-only)
    $Del=@(& git.exe -c core.quotepath=false ls-files --deleted)
    Write-Host "LOCAL HEAD      : $LH"
    Write-Host "REMOTE HEAD     : $RH"
    Write-Host "STAGED          : $($St.Count)"
    Write-Host "DELETED TRACKED : $($Del.Count)"
    if($LH -ne $ExpectedBaseline){Stop-Hold "Local baseline mismatch. Expected $ExpectedBaseline; found $LH."}
    if($RH -ne $ExpectedBaseline){Stop-Hold "Remote baseline mismatch. Expected $ExpectedBaseline; found $RH."}
    if($St.Count){Stop-Hold "Pre-existing staged changes detected."}
    if($Del.Count){Stop-Hold "Tracked deletions detected."}
    if(Test-Path $RuntimeFile){Write-Host "RUNTIME PRESERVED : $RuntimeFile"}
    Write-Host "BASELINE : PASS"
    Write-Host "POWERSHELL 5.1 CONTRACT : ACTIVE"

    Step 2 "RECOVERY / RESUME DETECTION"
    $existing=@($ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir)|Where-Object{Test-Path -LiteralPath $_}
    Write-Host "PREEXISTING SPT-024.6 TARGETS : $($existing.Count)"
    Write-Host "DESTRUCTIVE CLEANUP            : NO"
    Write-Host "REGENERATION SCOPE             : SPT-024.6 ONLY"

    Step 3 "SHA-256 FREEZE / 56 OUTSIDE-SCOPE ITEMS"
    $Snap=Snapshot
    Write-Host "PREEXISTING OUTSIDE-SCOPE ITEMS : $($Snap.Count)"
    Write-Host "EXPECTED HISTORICAL ITEMS       : $ExpectedOutsideScope"
    Write-Host "INPUT ZIP EXCLUDED FROM COUNT   : $InputPackage"
    if($Snap.Count -ne $ExpectedOutsideScope){
        Stop-Hold "Expected exactly $ExpectedOutsideScope historical outside-scope items; found $($Snap.Count). Nothing modified."
    }
    Write-Host "SNAPSHOT SHA-256 : ESTABLISHED"
    Write-Host "SPT-023.1-.7 + SPT-024.1-.5 : PRESERVATION ACTIVE"

    Step 4 "FLUTTER / CLIENT PRODUCTION-SCOPE DISCOVERY"
    $tracked=@(& git.exe -c core.quotepath=false ls-files)
    if($LASTEXITCODE -ne 0){throw "Unable to enumerate tracked files."}
    $fc=@($tracked|Where-Object{$_ -match '\.dart$' -or $_ -match '(^|/)(android|ios|lib|flutter|mobile|client)(/|$)' -or $_ -match '(^|/)pubspec\.ya?ml$'})
    Write-Host "TRACKED FLUTTER/CLIENT CANDIDATES : $($fc.Count)"
    Write-Host "STATIC ANALYSIS ONLY              : YES"
    Write-Host "FLUTTER APP EXECUTED BY GATE      : NO"
    Write-Host "EXTERNAL CONNECTION OPENED        : NO"

    Step 5 "IMPLEMENT SPT-024.6 SECURITY LAYER"

    $init=@'
"""SPT-024.6 Flutter/client security."""
from .audit import ClientSecurityAuditor
from .gate import ClientSecurityGate
from .service import ClientSecurityService
__all__ = ["ClientSecurityAuditor","ClientSecurityGate","ClientSecurityService"]
'@
    $models=@'
from dataclasses import dataclass, field
from typing import Any, Dict

@dataclass(frozen=True)
class ClientSurface:
    path: str
    kind: str
    production_scope: bool
    metadata: Dict[str, Any] = field(default_factory=dict)

@dataclass(frozen=True)
class ClientSecurityControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str
'@
    $audit=@'
from __future__ import annotations
import re
from pathlib import Path
from typing import Iterable, List, Tuple
from .models import ClientSecurityControl, ClientSurface

class ClientSecurityAuditor:
    EXCLUDED_PARTS = {".git",".venv","venv","__pycache__",".pytest_cache","artifacts","releases","docs","tests","test","build",".dart_tool",".idea",".vscode"}
    TEXT_SUFFIXES = {".dart",".yaml",".yml",".xml",".plist",".gradle",".kts",".properties",".xcconfig",".json"}
    SECRET_PATTERNS = [
        re.compile(r"""(?ix)\b(api[_-]?key|secret|token|password|passwd|client[_-]?secret)\b\s*[:=]\s*["'][^"'\s][^"']{5,}["']"""),
        re.compile(r"(?i)\bAKIA[0-9A-Z]{16}\b"),
    ]
    HTTP_PATTERN = re.compile(r"""(?i)\bhttp://(?!localhost\b|127\.0\.0\.1\b|10\.0\.2\.2\b)[^\s"'<>]+""")
    TLS_BYPASS = [
        re.compile(r"badCertificateCallback\s*=\s*\([^)]*\)\s*=>\s*true",re.I),
        re.compile(r"onBadCertificate\s*:\s*\([^)]*\)\s*=>\s*true",re.I),
        re.compile(r"SecurityContext\s*\(\s*withTrustedRoots\s*:\s*false",re.I),
    ]
    INSECURE_STORAGE=[re.compile(r"\bSharedPreferences\b"),re.compile(r"\bgetSharedPreferences\b"),re.compile(r"\bNSUserDefaults\b")]
    SECURE_STORAGE=[re.compile(r"\bFlutterSecureStorage\b"),re.compile(r"\bflutter_secure_storage\b"),re.compile(r"\bKeychain\b",re.I),re.compile(r"\bEncryptedSharedPreferences\b")]
    SENSITIVE_STORAGE=re.compile(r"(?i)\b(token|secret|password|credential|refresh[_-]?token|access[_-]?token)\b")
    LOGS=[re.compile(r"\bprint\s*\("),re.compile(r"\bdebugPrint\s*\("),re.compile(r"\blog\w*\s*\(",re.I)]
    SENSITIVE=re.compile(r"(?i)\b(token|secret|password|credential|authorization|bearer)\b")
    WEBVIEW=re.compile(r"\b(WebView|InAppWebView|webview_flutter)\b",re.I)
    JS_UNRESTRICTED=re.compile(r"javascriptMode\s*:\s*JavascriptMode\.unrestricted",re.I)

    def __init__(self,root:Path): self.root=Path(root).resolve()

    def _prod(self,p:Path)->bool:
        try: rel=p.relative_to(self.root)
        except ValueError: return False
        parts={x.lower() for x in rel.parts}
        if parts & self.EXCLUDED_PARTS: return False
        s=rel.as_posix().lower()
        if s.startswith(("builder/","templates/","examples/","example/")): return False
        return p.suffix.lower() in self.TEXT_SUFFIXES and (
            p.suffix.lower()==".dart" or "/android/" in f"/{s}" or "/ios/" in f"/{s}" or
            "/lib/" in f"/{s}" or s.endswith("pubspec.yaml") or s.endswith("pubspec.yml")
        )

    def _files(self)->Iterable[Path]:
        for p in self.root.rglob("*"):
            if p.is_file() and self._prod(p): yield p

    @staticmethod
    def _read(p:Path)->str:
        try: return p.read_text(encoding="utf-8",errors="replace")
        except OSError: return ""

    def discover_surfaces(self)->List[ClientSurface]:
        out=[]
        for p in self._files():
            t=self._read(p); rel=p.relative_to(self.root).as_posix()
            out.append(ClientSurface(rel,"DART_SOURCE" if p.suffix.lower()==".dart" else "CLIENT_CONFIG",True,{
                "https_marker":"https://" in t.lower(),
                "http_marker":bool(self.HTTP_PATTERN.search(t)),
                "secure_storage_marker":any(x.search(t) for x in self.SECURE_STORAGE),
                "webview_marker":bool(self.WEBVIEW.search(t)),
            }))
        return out

    def audit(self)->Tuple[List[ClientSecurityControl],List[ClientSurface]]:
        surfaces=self.discover_surfaces()
        secrets=[]; http=[]; tls=[]; storage=[]; logs=[]; web=[]; backup=[]; perms=[]
        for s in surfaces:
            t=self._read(self.root/s.path)
            if any(x.search(t) for x in self.SECRET_PATTERNS): secrets.append(s.path)
            if self.HTTP_PATTERN.search(t): http.append(s.path)
            if any(x.search(t) for x in self.TLS_BYPASS): tls.append(s.path)
            if self.SENSITIVE_STORAGE.search(t):
                if any(x.search(t) for x in self.INSECURE_STORAGE) and not any(x.search(t) for x in self.SECURE_STORAGE):
                    storage.append(s.path)
            for line in t.splitlines():
                if self.SENSITIVE.search(line) and any(x.search(line) for x in self.LOGS):
                    logs.append(s.path); break
            if self.WEBVIEW.search(t) and self.JS_UNRESTRICTED.search(t): web.append(s.path)
            if s.path.lower().endswith("androidmanifest.xml"):
                if re.search(r"""android:allowBackup\s*=\s*["']true["']""",t,re.I): backup.append(s.path)
                if any(x in t for x in ["READ_SMS","SEND_SMS","READ_CONTACTS","WRITE_CONTACTS","RECORD_AUDIO","CAMERA","ACCESS_FINE_LOCATION","MANAGE_EXTERNAL_STORAGE","QUERY_ALL_PACKAGES"]):
                    perms.append(s.path)
        def c(cid,name,hits,blocking,ok):
            return ClientSecurityControl(cid,name,not hits,blocking,ok if not hits else f"Potential issue detected in {len(set(hits))} production client file(s).")
        controls=[
            c("CLI-SECRETS","No embedded client secrets",secrets,True,"No embedded secret-like assignment detected."),
            c("CLI-TLS","HTTPS/TLS communications",http,True,"No insecure external HTTP endpoint detected."),
            c("CLI-CERT","Certificate validation",tls,True,"No certificate-validation bypass detected."),
            c("CLI-STORAGE","Secure local storage",storage,True,"No insecure sensitive local storage marker detected."),
            c("CLI-LOGGING","Sensitive logging",logs,True,"No sensitive logging pattern detected."),
            c("CLI-WEBVIEW","WebView safety",web,True,"No unrestricted WebView JavaScript marker detected."),
            c("CLI-BACKUP","Mobile backup safety",backup,True,"No android:allowBackup=true marker detected."),
            ClientSecurityControl("CLI-PERMISSIONS","Mobile permission review",True,False,f"Sensitive permission declarations found in {len(set(perms))} manifest(s); advisory review."),
            ClientSecurityControl("CLI-DEPS","Dependency inventory",True,False,"Dependency manifests included in static discovery."),
            ClientSecurityControl("CLI-ENDPOINTS","Endpoint auditability",True,False,"Endpoint declarations included in TLS scope."),
        ]
        return controls,surfaces
'@
    $gate=@'
class ClientSecurityGate:
    REQUIRED_BLOCKING_CONTROLS=frozenset({"CLI-SECRETS","CLI-TLS","CLI-CERT","CLI-STORAGE","CLI-LOGGING","CLI-WEBVIEW","CLI-BACKUP"})
    @classmethod
    def evaluate(cls,controls):
        by={c.control_id:c for c in controls}
        missing=sorted(cls.REQUIRED_BLOCKING_CONTROLS-set(by))
        if missing: return False,["MISSING:"+x for x in missing]
        failed=sorted(x for x in cls.REQUIRED_BLOCKING_CONTROLS if not by[x].passed)
        return not failed,failed
'@
    $service=@'
from pathlib import Path
from .audit import ClientSecurityAuditor
from .gate import ClientSecurityGate

class ClientSecurityService:
    def __init__(self,root:Path): self.root=Path(root)
    def assess(self):
        controls,surfaces=ClientSecurityAuditor(self.root).audit()
        passed,failed=ClientSecurityGate.evaluate(controls)
        return {
            "status":"CLIENT_SECURITY_GATE_PASS" if passed else "CLIENT_SECURITY_GATE_HOLD",
            "failed_control_ids":failed,
            "controls":[c.__dict__ for c in controls],
            "surfaces":[s.__dict__ for s in surfaces],
            "external_connection_opened":False,
            "flutter_app_executed_by_gate":False,
            "secret_values_exposed":False,
        }
'@
    $tests=@'
import json
from pathlib import Path
from sgoda.integration.spt0246.audit import ClientSecurityAuditor
from sgoda.integration.spt0246.gate import ClientSecurityGate
from sgoda.integration.spt0246.service import ClientSecurityService

def w(p:Path,t:str):
    p.parent.mkdir(parents=True,exist_ok=True); p.write_text(t,encoding="utf-8")
def byid(root):
    c,_=ClientSecurityAuditor(root).audit(); return {x.control_id:x for x in c}
def test_gate_contract(): assert len(ClientSecurityGate.REQUIRED_BLOCKING_CONTROLS)==7
def test_empty_contract(tmp_path):
    c,_=ClientSecurityAuditor(tmp_path).audit(); assert ClientSecurityGate.evaluate(c)==(True,[])
def test_https_allowed(tmp_path):
    w(tmp_path/"lib"/"a.dart",'const endpoint="https://example.invalid";'); assert byid(tmp_path)["CLI-TLS"].passed
def test_external_http_blocked(tmp_path):
    w(tmp_path/"lib"/"a.dart",'const endpoint="http://example.invalid";'); assert not byid(tmp_path)["CLI-TLS"].passed
def test_local_http_allowed(tmp_path):
    w(tmp_path/"lib"/"a.dart",'const endpoint="http://localhost:8000";'); assert byid(tmp_path)["CLI-TLS"].passed
def test_embedded_secret_blocked(tmp_path):
    w(tmp_path/"lib"/"a.dart",'const apiKey="EXAMPLE_NOT_REAL_SECRET_12345";'); assert not byid(tmp_path)["CLI-SECRETS"].passed
def test_environment_indirection_allowed(tmp_path):
    w(tmp_path/"lib"/"a.dart",'const apiKey=String.fromEnvironment("API_KEY");'); assert byid(tmp_path)["CLI-SECRETS"].passed
def test_bad_certificate_blocked(tmp_path):
    w(tmp_path/"lib"/"a.dart",'client.badCertificateCallback = (cert,host,port) => true;'); assert not byid(tmp_path)["CLI-CERT"].passed
def test_secure_storage_allowed(tmp_path):
    w(tmp_path/"lib"/"a.dart",'import "package:flutter_secure_storage/flutter_secure_storage.dart"; final storage=FlutterSecureStorage(); final token=runtimeToken;'); assert byid(tmp_path)["CLI-STORAGE"].passed
def test_shared_preferences_blocked(tmp_path):
    w(tmp_path/"lib"/"a.dart",'final prefs=await SharedPreferences.getInstance(); await prefs.setString("access_token",runtimeToken);'); assert not byid(tmp_path)["CLI-STORAGE"].passed
def test_sensitive_print_blocked(tmp_path):
    w(tmp_path/"lib"/"a.dart",'print("token=$token");'); assert not byid(tmp_path)["CLI-LOGGING"].passed
def test_normal_print_allowed(tmp_path):
    w(tmp_path/"lib"/"a.dart",'print("application started");'); assert byid(tmp_path)["CLI-LOGGING"].passed
def test_unrestricted_webview_blocked(tmp_path):
    w(tmp_path/"lib"/"a.dart",'WebView(javascriptMode: JavascriptMode.unrestricted)'); assert not byid(tmp_path)["CLI-WEBVIEW"].passed
def test_backup_true_blocked(tmp_path):
    w(tmp_path/"android"/"app"/"src"/"main"/"AndroidManifest.xml",'<application android:allowBackup="true"></application>'); assert not byid(tmp_path)["CLI-BACKUP"].passed
def test_backup_false_allowed(tmp_path):
    w(tmp_path/"android"/"app"/"src"/"main"/"AndroidManifest.xml",'<application android:allowBackup="false"></application>'); assert byid(tmp_path)["CLI-BACKUP"].passed
def test_tests_excluded(tmp_path):
    w(tmp_path/"tests"/"bad.dart",'const endpoint="http://example.invalid";'); c,s=ClientSecurityAuditor(tmp_path).audit(); assert not s and {x.control_id:x for x in c}["CLI-TLS"].passed
def test_service_is_static(tmp_path):
    w(tmp_path/"lib"/"a.dart",'const endpoint="https://example.invalid";'); r=ClientSecurityService(tmp_path).assess(); assert not r["external_connection_opened"] and not r["flutter_app_executed_by_gate"] and not r["secret_values_exposed"]
def test_surface_metadata_has_no_contents(tmp_path):
    w(tmp_path/"lib"/"a.dart",'const endpoint="https://example.invalid";'); _,s=ClientSecurityAuditor(tmp_path).audit(); assert "const endpoint" not in json.dumps([x.__dict__ for x in s])
'@
    $policy=@'
{
  "component":"SPT-024.6",
  "version":"1.0.0",
  "mode":"static-non-executing",
  "blocking_controls":["CLI-SECRETS","CLI-TLS","CLI-CERT","CLI-STORAGE","CLI-LOGGING","CLI-WEBVIEW","CLI-BACKUP"],
  "advisory_controls":["CLI-PERMISSIONS","CLI-DEPS","CLI-ENDPOINTS"],
  "safety":{"open_external_connections":false,"execute_flutter_application":false,"print_secret_values":false,"persist_secret_values":false,"modify_closed_components":false}
}
'@
    $doc=@'
# SPT-024.6 Capa 1 — Seguridad del Cliente Flutter, Comunicaciones y Almacenamiento Local

Línea base autoritativa: `96f5d4a7f901cb294320fc85cee9a4aea93ccc7c`.

La capa realiza análisis estático no ejecutable de superficies Flutter/Dart y configuración móvil. No ejecuta Flutter, no abre conexiones externas, no imprime secretos y no modifica SPT-023.1–SPT-023.7 ni SPT-024.1–SPT-024.5.

Controles bloqueantes: CLI-SECRETS, CLI-TLS, CLI-CERT, CLI-STORAGE, CLI-LOGGING, CLI-WEBVIEW y CLI-BACKUP.

La publicación exige Security Gate PASS, pruebas dirigidas PASS, suite institucional PASS, compileall PASS, preservación SHA-256 de los 56 elementos históricos fuera de alcance, staging exacto y verificación remota final.
'@

    Write-Lf "$ModuleDir/__init__.py" $init
    Write-Lf "$ModuleDir/models.py" $models
    Write-Lf "$ModuleDir/audit.py" $audit
    Write-Lf "$ModuleDir/gate.py" $gate
    Write-Lf "$ModuleDir/service.py" $service
    Write-Lf $TestFile $tests
    Write-Lf $PolicyFile $policy
    Write-Lf $DocFile $doc
    @("$ModuleDir/__init__.py","$ModuleDir/models.py","$ModuleDir/audit.py","$ModuleDir/gate.py","$ModuleDir/service.py",$TestFile,$PolicyFile,$DocFile)|ForEach-Object{Write-Host "CREATED/VALIDATED : $_"}

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
    $Py=PythonExe
    $env:PYTHONPATH=(Join-Path $PWD "src")
    Native $Py @("-c","import sgoda.integration.spt0246; from sgoda.integration.spt0246.gate import ClientSecurityGate; assert len(ClientSecurityGate.REQUIRED_BLOCKING_CONTROLS)==7; print('SPT0246_IMPORT=PASS'); print('BLOCKING_CONTROLS=7')") "SPT-024.6 import"
    Native $Py @("-m","pytest",$TestFile,"-q") "SPT-024.6 targeted tests"
    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
    Native $Py @("-m","pytest","-q") "Institutional pytest suite"
    Write-Host "FULL SUITE : PASS"
    Native $Py @("-m","compileall","-q","src") "compileall"
    Write-Host "COMPILEALL : PASS"

    Step 8 "CLIENT SECURITY REGRESSION TESTS"
    foreach($sel in @("external_http","embedded_secret","bad_certificate","shared_preferences","sensitive_print","unrestricted_webview","backup_true","service_is_static")){
        Native $Py @("-m","pytest",$TestFile,"-q","-k",$sel) ("Regression "+$sel)
    }
    Write-Host "SECURITY REGRESSIONS : PASS"

    Step 9 "FLUTTER / COMMUNICATION / STORAGE ASSESSMENT"
    New-Item -ItemType Directory -Force -Path $ArtifactDir|Out-Null
    $probe=Join-Path $env:TEMP ("sgoda-spt0246-"+[Guid]::NewGuid().ToString("N")+".py")
    $pc=@'
import json
from pathlib import Path
from sgoda.integration.spt0246.service import ClientSecurityService
r=ClientSecurityService(Path.cwd()).assess()
safe={"status":r["status"],"failed_control_ids":r["failed_control_ids"],"controls":r["controls"],"surfaces":r["surfaces"],"external_connection_opened":False,"flutter_app_executed_by_gate":False,"secret_values_exposed":False}
p=Path.cwd()/"artifacts"/"development"/"SPT-024.6-Capa1-v1.0.0"/"client-security-assessment.json"
p.parent.mkdir(parents=True,exist_ok=True); p.write_text(json.dumps(safe,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print("CLIENT_SECURITY_STATUS="+r["status"]); print("CLIENT_SURFACES=%d"%len(r["surfaces"])); print("BLOCKING_CONTROLS=7"); print("FAILED_BLOCKING_CONTROLS=%d"%len(r["failed_control_ids"])); print("FAILED_CONTROL_IDS="+",".join(r["failed_control_ids"])); print("EXTERNAL_CONNECTION_OPENED=NO"); print("FLUTTER_APP_EXECUTED_BY_GATE=NO"); print("SECRET_VALUES_EXPOSED=NO"); print("SAFE_ASSESSMENT_REPORT="+str(p))
if r["status"]!="CLIENT_SECURITY_GATE_PASS": raise SystemExit(20)
'@
    try{Write-Lf $probe $pc; Native $Py @($probe) "Production client security assessment"}finally{Remove-Item $probe -Force -ErrorAction SilentlyContinue}
    Write-Host "CLIENT SECURITY GATE : PASS"

    Step 10 "CLOSED-COMPONENT + WORKTREE PRESERVATION"
    Assert-Snapshot $Snap "Preservation gate"
    $changed=@(& git.exe -c core.quotepath=false diff --name-only $ExpectedBaseline --)
    foreach($x in $changed){
        $p=Norm $x
        if((IsTx $p) -or $Snap.ContainsKey($p) -or $p -eq $RuntimeFile){continue}
        Stop-Hold "New tracked change outside SPT-024.6: $p"
    }
    Write-Host "SPT-023.1-.7 + SPT-024.1-.5 : PRESERVED"
    Write-Host "56 HISTORICAL OUTSIDE-SCOPE ITEMS : PRESERVED"

    Step 11 "EVIDENCE"
    $ev=[ordered]@{component="SPT-024.6";layer="Capa 1";version="1.0.0";generated_utc=[DateTime]::UtcNow.ToString("o");authoritative_baseline=$ExpectedBaseline;branch=$Branch;preexisting_outside_scope_items=$Snap.Count;input_package_present=(Test-Path $InputPackage);gates=[ordered]@{targeted_tests="PASS";institutional_suite="PASS";compileall="PASS";client_security="PASS";blocking_controls=7;external_connection_opened=$false;flutter_app_executed_by_gate=$false;secret_values_exposed=$false;closed_components_preserved=$true;historical_outside_scope_preserved=$true};publication="PENDING_CONTROLLED_COMMIT"}
    Write-Lf $EvidenceFile ($ev|ConvertTo-Json -Depth 10)
    Write-Host "EVIDENCE : CREATED (UTF-8 NO BOM / LF)"

    Step 12 "EXACT CONTROLLED STAGING"
    $canon=@($SelfName,$TestFile,$PolicyFile,$DocFile,$AssessmentFile,$EvidenceFile)
    $canon+=@(Get-ChildItem $ModuleDir -File -Recurse|ForEach-Object{$_.FullName.Substring($PWD.Path.Length+1)})
    $u=New-Object System.Text.UTF8Encoding($false)
    foreach($rel in ($canon|Select-Object -Unique)){
        $abs=Join-Path $PWD $rel
        if(Test-Path $abs -PathType Leaf){
            $b=[IO.File]::ReadAllBytes($abs); $nul=$false
            foreach($z in $b){if($z -eq 0){$nul=$true;break}}
            if(-not $nul){$t=[IO.File]::ReadAllText($abs,[Text.Encoding]::UTF8);$t=($t -replace "`r`n","`n") -replace "`r","`n";[IO.File]::WriteAllText($abs,$t,$u)}
        }
    }
    Write-Host "TRANSACTION LINE ENDINGS : CANONICAL LF"
    Write-Host "GIT SAFECRLF POLICY      : TRANSACTION-LOCAL OVERRIDE ONLY"
    foreach($t in @($SelfName,$ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir)){
        if(Test-Path $t){Native "git.exe" @("-c","core.safecrlf=false","add","--",$t) ("git add "+$t)}
    }
    $sn=@(& git.exe diff --cached --name-only)
    if(-not $sn.Count){Stop-Hold "Controlled staging is empty."}
    $unexpected=@($sn|Where-Object{-not(IsPublish $_)})
    Write-Host "STAGED     : $($sn.Count)"
    Write-Host "UNEXPECTED : $($unexpected.Count)"
    if($unexpected.Count){& git.exe reset; $unexpected|ForEach-Object{Write-Host "UNEXPECTED STAGED : $_" -ForegroundColor Red}; Stop-Hold "Unexpected staged path."}
    Write-Host "STAGING QUALITY : PASS"
    Assert-Snapshot $Snap "Post-staging preservation"

    Step 13 "FINAL REMOTE GATE + COMMIT + PUSH"
    Native "git.exe" @("fetch","origin",$Branch) "final fetch"
    $lb=(& git.exe rev-parse HEAD).Trim(); $rb=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    if($lb -ne $ExpectedBaseline -or $rb -ne $ExpectedBaseline){& git.exe reset;Stop-Hold "Authoritative baseline changed before publication."}
    Assert-Snapshot $Snap "Pre-commit preservation"
    Write-Host "REMOTE GATE : PASS"
    Native "git.exe" @("commit","-m","feat(spt-024.6): establish Flutter client security layer 1") "git commit"
    $New=(& git.exe rev-parse HEAD).Trim();Write-Host "NEW COMMIT : $New"
    Native "git.exe" @("push","origin",$Branch) "git push"

    Step 14 "AUTHORITATIVE REMOTE VERIFICATION"
    Native "git.exe" @("fetch","origin",$Branch) "verification fetch"
    $FL=(& git.exe rev-parse HEAD).Trim();$FR=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $cnt=((& git.exe rev-list --left-right --count (("origin/"+$Branch)+"...HEAD")).Trim() -split '\s+')
    $FS=@(& git.exe diff --cached --name-only);$FD=@(& git.exe -c core.quotepath=false ls-files --deleted)
    Write-Host "LOCAL HEAD      : $FL";Write-Host "REMOTE HEAD     : $FR";Write-Host "BEHIND          : $($cnt[0])";Write-Host "AHEAD           : $($cnt[1])";Write-Host "STAGED          : $($FS.Count)";Write-Host "DELETED TRACKED : $($FD.Count)"
    if($FL -ne $FR -or $cnt[0] -ne "0" -or $cnt[1] -ne "0" -or $FS.Count -or $FD.Count){Stop-Hold "Final repository synchronization gate failed."}
    Assert-Snapshot $Snap "Post-publication preservation"

    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Green
    Write-Host " SPT-024.6 CAPA 1 : SECURITY CERTIFIED" -ForegroundColor Green
    Write-Host " CLIENT_SECURITY_GATE=PASS" -ForegroundColor Green
    Write-Host " HISTORICAL_OUTSIDE_SCOPE_56=PRESERVED" -ForegroundColor Green
    Write-Host " CLOSED_COMPONENTS=PRESERVED" -ForegroundColor Green
    Write-Host " FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green
    exit 0
}
catch { Stop-Hold $_.Exception.Message }
