from pathlib import Path
from sgoda.pmo.audit.models import AuditResult,Finding,Severity,Status
from sgoda.pmo.audit.orchestrator import RepositoryAuditOrchestrator
from sgoda.pmo.audit.reporting import JsonReporter,MarkdownReporter,ClosureReporter

def test_critical_failure_blocks_closure():
    result=AuditResult(findings=[Finding("X","TEST","Bloqueo",Severity.CRITICAL,Status.FAIL)]).finalize()
    assert result.verdict=="NOT_APPROVED"

def test_orchestrator_runs(tmp_path: Path):
    for item in (".github","docs","knowledge","scripts","src","tests"):
        (tmp_path/item).mkdir()
    (tmp_path/"README.md").write_text("# test",encoding="utf-8")
    result=RepositoryAuditOrchestrator(tmp_path).run()
    assert result.findings

def test_reporters(tmp_path: Path):
    result=AuditResult().finalize()
    assert JsonReporter().write(result,tmp_path/"x.json").exists()
    assert MarkdownReporter().write(result,tmp_path/"x.md").exists()
    assert ClosureReporter().write(result,tmp_path/"act.md").exists()