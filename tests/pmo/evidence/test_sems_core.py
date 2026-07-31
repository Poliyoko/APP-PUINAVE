from pathlib import Path
import pytest
from sgoda.pmo.evidence.archive import create_archive
from sgoda.pmo.evidence.exceptions import EvidenceConflictError
from sgoda.pmo.evidence.hasher import calculate_sha256
from sgoda.pmo.evidence.manager import EvidenceManager
from sgoda.pmo.evidence.manifest import build_manifest
from sgoda.pmo.evidence.models import EvidenceStatus
from sgoda.pmo.evidence.verifier import verify_archive_contents

def test_manifest_and_hash(tmp_path:Path)->None:
    source=tmp_path/"source"; source.mkdir(); (source/"Ã±.txt").write_text("Puinave",encoding="utf-8")
    manifest=build_manifest(source)
    assert manifest["file_count"]==1 and len(calculate_sha256(source))==64

def test_archive_integrity(tmp_path:Path)->None:
    source=tmp_path/"source"; source.mkdir(); (source/"a.txt").write_text("A",encoding="utf-8")
    archive,sha=create_archive(source,tmp_path/"evidence.zip")
    valid,errors=verify_archive_contents(archive)
    assert len(sha)==64 and valid and errors==[]

def test_manager_lifecycle(tmp_path:Path)->None:
    repo=tmp_path/"repo"; repo.mkdir(); sample=repo/"evidence.txt"; sample.write_text("SGODA",encoding="utf-8")
    manager=EvidenceManager(repo)
    record=manager.register(sample,evidence_id="EVD-SPB006-001",deliverable_id="SPB-006.1")
    assert record.status is EvidenceStatus.REGISTERED
    assert manager.verify(record.evidence_id).valid
    archived=manager.archive(record.evidence_id)
    assert archived.status is EvidenceStatus.ARCHIVED and Path(archived.archive_path).exists()

def test_duplicate_rejected(tmp_path:Path)->None:
    repo=tmp_path/"repo"; repo.mkdir(); sample=repo/"e.txt"; sample.write_text("x",encoding="utf-8")
    manager=EvidenceManager(repo); manager.register(sample,evidence_id="EVD-1")
    with pytest.raises(EvidenceConflictError): manager.register(sample,evidence_id="EVD-1")