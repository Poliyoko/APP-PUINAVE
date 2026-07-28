from pathlib import Path
from sgoda.pmo.closure.closure_orchestrator import Decision, Gate

def test_required_gate_blocks(tmp_path:Path):
    d=Decision(repository_root=str(tmp_path),gates=[Gate('X','Control',True,False,'ausente')])
    assert not d.approved
    assert d.verdict=='CIERRE_CONDICIONADO'

def test_all_required_gates_pass(tmp_path:Path):
    d=Decision(repository_root=str(tmp_path),gates=[Gate('X','Control',True,True,'ok')])
    assert d.approved
    assert d.verdict=='APROBADO_PARA_CIERRE'