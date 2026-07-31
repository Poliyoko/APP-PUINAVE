from __future__ import annotations
from pathlib import Path
from typing import Any
from .archive import create_archive
from .exceptions import EvidenceValidationError
from .hasher import calculate_sha256, calculate_size
from .models import EvidenceRecord,EvidenceStatus,EvidenceType,IntegrityResult
from .registry import EvidenceRegistry
from .retention import RetentionDecisionEngine,RetentionManager
from .retention_policy import RetentionPolicyRepository
from .verifier import verify_archive_contents,verify_path

class EvidenceManager:
    def __init__(self,repository_root:Path,registry_path:Path|None=None)->None:
        self.repository_root=repository_root.resolve()
        self.sems_root=self.repository_root/"artifacts"/"pmo"/"SPB-006-SEMS"
        self.registry=EvidenceRegistry(registry_path or self.sems_root/"registry"/"evidence-registry.json")
        policy_path=self.repository_root/"config"/"evidence-retention-policies.json"
        self.retention=RetentionManager(
            self.registry,
            RetentionDecisionEngine(RetentionPolicyRepository(policy_path))
        )

    def register(self,source:Path,*,evidence_id:str|None=None,evidence_type:EvidenceType|None=None,
                 deliverable_id:str="",commit:str="",tag:str="",metadata:dict[str,Any]|None=None)->EvidenceRecord:
        source=source.resolve()
        if not source.exists(): raise EvidenceValidationError(f"No existe la ruta: {source}")
        selected=evidence_type or (EvidenceType.DIRECTORY if source.is_dir() else EvidenceType.FILE)
        record=EvidenceRecord.create(source,selected,calculate_sha256(source),calculate_size(source),
                                     evidence_id=evidence_id,deliverable_id=deliverable_id,
                                     commit=commit,tag=tag,metadata=metadata)
        return self.registry.add(record)

    def verify(self,evidence_id:str)->IntegrityResult:
        record=self.registry.get(evidence_id)
        source=Path(record.archive_path or record.source_path)
        result=verify_path(source,record.sha256)
        record.status=EvidenceStatus.VERIFIED if result.valid else EvidenceStatus.FAILED
        self.registry.update(record)
        return result

    def archive(self,evidence_id:str,destination:Path|None=None)->EvidenceRecord:
        record=self.registry.get(evidence_id)
        source=Path(record.source_path)
        destination=destination or self.sems_root/"archives"/f"{record.evidence_id}-{record.name}.zip"
        archive_path,archive_sha=create_archive(source,destination,metadata={
            "evidence_id":record.evidence_id,"deliverable_id":record.deliverable_id,
            "source_sha256":record.sha256,"commit":record.commit,"tag":record.tag})
        valid,errors=verify_archive_contents(archive_path)
        if not valid: raise EvidenceValidationError("ZIP invÃ¡lido: "+", ".join(errors))
        record.archive_path=archive_path.as_posix()
        record.sha256=archive_sha
        record.size_bytes=archive_path.stat().st_size
        record.status=EvidenceStatus.ARCHIVED
        return self.registry.update(record)

    def status(self)->dict[str,Any]:
        records=self.registry.list()
        by_status={}
        by_retention_action={}
        for record in records:
            by_status[record.status.value]=by_status.get(record.status.value,0)+1
            if record.retention_action:
                by_retention_action[record.retention_action]=by_retention_action.get(record.retention_action,0)+1
        return {
            "schema":"sgoda.sems.status/v2",
            "registry":self.registry.path.as_posix(),
            "records":len(records),
            "by_status":by_status,
            "by_retention_action":by_retention_action,
        }