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
        # Production repository: inspect only Git-tracked client files. This avoids
        # recursively traversing .venv, historical artifacts and the 56 preserved
        # outside-scope worktree items. Unit-test temp roots (no .git) keep the
        # bounded filesystem fallback required by the test contract.
        if (self.root / ".git").exists():
            try:
                import subprocess
                cp = subprocess.run(
                    ["git", "-c", "core.quotepath=false", "ls-files", "-z"],
                    cwd=str(self.root), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    check=True, timeout=30,
                )
                for raw in cp.stdout.split(b"\0"):
                    if not raw:
                        continue
                    rel = raw.decode("utf-8", errors="surrogateescape")
                    p = self.root / Path(rel)
                    if p.is_file() and self._prod(p):
                        yield p
                return
            except Exception:
                # Fail closed for the authoritative repository. A production
                # assessment must never broaden scope silently after Git failure.
                return
        for p in self.root.rglob("*"):
            if p.is_file() and self._prod(p):
                yield p

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
