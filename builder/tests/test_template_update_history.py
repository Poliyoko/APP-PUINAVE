import json
from pathlib import Path
from sgoda.cli.main import main
from sgoda.operations import HistoryStore

def make_template(root,version):
    source=root/f'h-{version}'; render=source/'template'; render.mkdir(parents=True)
    (render/'README.md').write_text(version,encoding='utf-8')
    (source/'sgoda.template.json').write_text(json.dumps({'schema_version':'1.0','type':'template','name':'history-template','version':version,'builder_requires':'>=1.11.0,<2.0.0','render_root':'template','variables':{},'files':['template/README.md']}),encoding='utf-8'); return source

def test_events(tmp_path,capsys):
    ws=tmp_path/'project'; assert main(['init',str(ws),'--project-name','Versions'])==0; capsys.readouterr()
    v1=make_template(tmp_path,'1.0.0'); v2=make_template(tmp_path,'1.1.0')
    assert main(['template','install',str(v1),'--workspace',str(ws)])==0; capsys.readouterr()
    assert main(['template','update','history-template',str(v2),'--workspace',str(ws)])==0; capsys.readouterr()
    assert main(['template','update','history-template',str(v1),'--workspace',str(ws)])==1; capsys.readouterr()
    types=[e.event_type for e in HistoryStore(ws).read_all()]; assert 'template_updated' in types; assert 'template_update_failed' in types
