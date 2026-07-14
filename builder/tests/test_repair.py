import json
from sgoda.cli.main import main
from sgoda.lifecycle.repair import ProjectRepairer

def init(tmp_path): assert main(["init",str(tmp_path),"--project-name","Repair"])==0

def test_repairs_missing_files_and_directories(tmp_path):
    init(tmp_path); (tmp_path/'README.md').unlink(); shutil_target=tmp_path/'data/metadata/catalog.json';shutil_target.unlink();
    report=ProjectRepairer(tmp_path).repair(); assert report.status=='REPAIRED';assert (tmp_path/'README.md').is_file();assert shutil_target.is_file()

def test_preserves_existing_file(tmp_path):
    init(tmp_path);p=tmp_path/'README.md';p.write_text('custom',encoding='utf-8');ProjectRepairer(tmp_path).repair();assert p.read_text(encoding='utf-8')=='custom'

def test_dry_run_does_not_modify(tmp_path):
    init(tmp_path);p=tmp_path/'README.md';p.unlink();r=ProjectRepairer(tmp_path).repair(dry_run=True);assert r.status=='PLANNED';assert not p.exists()

def test_invalid_manifest_is_backed_up_and_repaired(tmp_path):
    init(tmp_path);p=tmp_path/'sgoda.project.json';p.write_text('{bad',encoding='utf-8');r=ProjectRepairer(tmp_path).repair();assert r.backup_path and r.backup_path.is_file();assert json.loads(p.read_text(encoding='utf-8'))['schema_version']=='1.3'

def test_cli_fix_json(tmp_path,capsys):
    init(tmp_path);(tmp_path/'README.md').unlink();capsys.readouterr();assert main(['doctor',str(tmp_path),'--fix','--format','json'])==0;payload=json.loads(capsys.readouterr().out);assert payload['status']=='REPAIRED'
