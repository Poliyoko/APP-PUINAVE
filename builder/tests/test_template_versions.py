import json
from sgoda.cli.main import main

def make_template(root,version):
    source=root/f'v-{version}'; render=source/'template'; render.mkdir(parents=True)
    (render/'README.md').write_text(version,encoding='utf-8')
    (source/'sgoda.template.json').write_text(json.dumps({'schema_version':'1.0','type':'template','name':'versions-template','version':version,'builder_requires':'>=1.12.0,<2.0.0','render_root':'template','variables':{},'files':['template/README.md']}),encoding='utf-8'); return source

def test_versions_json(tmp_path,capsys):
    ws=tmp_path/'project'; v1=make_template(tmp_path,'1.0.0'); v2=make_template(tmp_path,'1.1.0')
    assert main(['template','install',str(v1),'--workspace',str(ws)])==0; capsys.readouterr()
    assert main(['template','update','versions-template',str(v2),'--workspace',str(ws)])==0; capsys.readouterr()
    assert main(['template','versions','versions-template','--workspace',str(ws),'--format','json'])==0
    payload=json.loads(capsys.readouterr().out); assert payload['count']==1; assert payload['backups'][0]['version']=='1.0.0'
