import json
from pathlib import Path
import pytest
from sgoda.extensions import ExtensionManager, ExtensionRegistryError, TemplateUpdateError, TemplateUpdater

def make_template(root,version,marker):
    source=root/f'rb-{version}'; render=source/'template'; render.mkdir(parents=True)
    (render/'README.md').write_text(marker,encoding='utf-8')
    (source/'sgoda.template.json').write_text(json.dumps({'schema_version':'1.0','type':'template','name':'rollback-template','version':version,'builder_requires':'>=1.10.0,<2.0.0','render_root':'template','variables':{},'files':['template/README.md']}),encoding='utf-8')
    return source

def test_registry_failure_rolls_back(tmp_path,monkeypatch):
    ws=tmp_path/'project'; v1=make_template(tmp_path,'1.0.0','old'); v2=make_template(tmp_path,'1.1.0','new')
    ExtensionManager(ws).install(v1,expected_type='template'); updater=TemplateUpdater(ws)
    monkeypatch.setattr(updater.registry,'update_record',lambda record: (_ for _ in ()).throw(ExtensionRegistryError('simulado')))
    with pytest.raises(TemplateUpdateError): updater.update('rollback-template',v2)
    rec=ExtensionManager(ws).info('template','rollback-template'); assert rec.version=='1.0.0'
    assert (Path(rec.installed_path)/'template'/'README.md').read_text(encoding='utf-8')=='old'
