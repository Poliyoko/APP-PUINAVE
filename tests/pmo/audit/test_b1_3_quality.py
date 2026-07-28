from pathlib import Path

from sgoda.pmo.audit.checks.quality import RepositoryQualityCheck
from sgoda.pmo.audit.context import AuditContext
from sgoda.pmo.audit.models import AuditResult, Finding, Severity, Status


def test_explicit_blocking_flag_controls_verdict():
    result = AuditResult(
        findings=[
            Finding(
                "X",
                "QUALITY",
                "Control",
                Severity.MEDIUM,
                Status.FAIL,
                blocking=True,
            )
        ]
    ).finalize()
    assert result.verdict == "NOT_APPROVED"


def test_quality_check_detects_mojibake_and_backup(tmp_path: Path):
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "bad.py").write_text(
        'title = "Auditor\u00c3\u00ada"', encoding="utf-8"
    )
    (tmp_path / "old.bak").write_text("backup", encoding="utf-8")

    findings, inventory = RepositoryQualityCheck().run(
        AuditContext.create(tmp_path)
    )

    by_code = {finding.code: finding for finding in findings}
    assert by_code["AIR-QLT-002"].status == Status.FAIL
    assert by_code["AIR-QLT-003"].status == Status.WARN
    assert inventory["mojibake"] == ["src/bad.py"]
    assert inventory["backup_or_temporary_files"] == ["old.bak"]


def test_quality_check_passes_clean_utf8_tree(tmp_path: Path):
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "ok.py").write_text(
        'title = "Auditoría"', encoding="utf-8"
    )
    findings, _ = RepositoryQualityCheck().run(AuditContext.create(tmp_path))
    by_code = {finding.code: finding for finding in findings}
    assert by_code["AIR-QLT-001"].status == Status.PASS
    assert by_code["AIR-QLT-002"].status == Status.PASS
