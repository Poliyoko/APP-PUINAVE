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
