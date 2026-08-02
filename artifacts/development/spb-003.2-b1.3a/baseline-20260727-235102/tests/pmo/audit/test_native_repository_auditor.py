from pathlib import Path
from sgoda.pmo.audit.native_repository_auditor import NativeRepositoryAuditor


def test_missing_repository_requirements_are_blocking(tmp_path: Path):
    report = NativeRepositoryAuditor(tmp_path).run()
    assert report.closure_ready is False
    assert report.blockers
