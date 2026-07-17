import json
from pathlib import Path
from sgoda.cli.main import main
from sgoda.extensions import ExtensionManager

def make_template(root,name,version,marker):
    source=root/f'{name}-{version}'; render=source/'template'; render.mkdir(parents=True)
    (render/'README.md').write_text(marker,encoding='utf-8')
    (source/'sgoda.template.json').write_text(json.dumps({'schema_version':'1.0','type':'template','name':name,'version':version,'builder_requires':'>=1.10.0,<2.0.0','render_root':'template','variables':{},'files':['template/README.md']}),encoding='utf-8')
    return source

def test_update_backup_and_version(tmp_path,capsys):
    ws=tmp_path/'project'; v1=make_template(tmp_path,'versioned-template','1.0.0','old'); v2=make_template(tmp_path,'versioned-template','1.1.0','new')
    assert main(['template','install',str(v1),'--workspace',str(ws)])==0; capsys.readouterr()
    assert main(['template','update','versioned-template',str(v2),'--workspace',str(ws)])==0
    assert '1.0.0 -> 1.1.0' in capsys.readouterr().out
    record=ExtensionManager(ws).info('template','versioned-template'); assert record.version=='1.1.0'
    assert 'new' in (Path(record.installed_path)/'template'/'README.md').read_text(encoding='utf-8')

def test_downgrade_block_and_allow(tmp_path,capsys):
    ws=tmp_path/'project'; v2=make_template(tmp_path,'down-template','2.0.0','new'); v1=make_template(tmp_path,'down-template','1.0.0','old')
    assert main(['template','install',str(v2),'--workspace',str(ws)])==0; capsys.readouterr()
    assert main(['template','update','down-template',str(v1),'--workspace',str(ws)])==1
    assert 'Downgrade bloqueado' in capsys.readouterr().out
    assert main(['template','update','down-template',str(v1),'--workspace',str(ws),'--allow-downgrade','--no-backup'])==0
