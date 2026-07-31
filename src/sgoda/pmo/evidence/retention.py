from __future__ import annotations
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from typing import Any
from .models import EvidenceRecord
from .retention_policy import RetentionPolicy, RetentionPolicyRepository

def parse_utc(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z","+00:00")).astimezone(timezone.utc)

@dataclass(frozen=True)
class RetentionDecision:
    evidence_id: str
    policy_id: str
    policy_version: str
    action: str
    permanent: bool
    retention_until_utc: str
    evaluated_at_utc: str
    reason: str
    legal_hold: bool

    def to_dict(self) -> dict[str,Any]:
        return asdict(self)

class RetentionDecisionEngine:
    def __init__(self, repository: RetentionPolicyRepository) -> None:
        self.repository=repository

    @staticmethod
    def _matches(record: EvidenceRecord, policy: RetentionPolicy) -> bool:
        match=policy.match or {}
        if "evidence_type" in match and record.evidence_type.value not in match["evidence_type"]:
            return False
        if "deliverable_prefix" in match and not any(
            record.deliverable_id.upper().startswith(prefix.upper())
            for prefix in match["deliverable_prefix"]
        ):
            return False
        if match.get("requires_tag") is True and not record.tag:
            return False
        if match.get("requires_commit") is True and not record.commit:
            return False
        name_suffixes=match.get("name_suffix")
        if name_suffixes and not any(record.name.lower().endswith(x.lower()) for x in name_suffixes):
            return False
        return True

    def select_policy(self, record: EvidenceRecord) -> RetentionPolicy:
        explicit=str(record.metadata.get("retention_policy","")).strip()
        if explicit:
            return self.repository.get(explicit)
        for policy in self.repository.load():
            if self._matches(record,policy):
                return policy
        return self.repository.get("RET-DEFAULT-REVIEW")

    def evaluate(self, record: EvidenceRecord, now: datetime|None=None) -> RetentionDecision:
        now=now or datetime.now(timezone.utc)
        policy=self.select_policy(record)
        if record.legal_hold or bool(record.metadata.get("legal_hold",False)):
            return RetentionDecision(
                record.evidence_id,policy.policy_id,policy.version,"keep",True,"",
                now.isoformat(),"legal-hold",True
            )
        if policy.permanent or policy.duration_days is None:
            until=""
            action="keep"
            reason="permanent-policy"
        else:
            base=parse_utc(record.registered_at_utc)
            expiry=base+timedelta(days=policy.duration_days)
            until=expiry.isoformat()
            expired=now>=expiry
            action=policy.action_on_expiry if expired else "keep"
            reason="expired" if expired else "within-retention-period"
        return RetentionDecision(
            record.evidence_id,policy.policy_id,policy.version,action,
            policy.permanent,until,now.isoformat(),reason,False
        )

class RetentionManager:
    def __init__(self, registry, engine: RetentionDecisionEngine) -> None:
        self.registry=registry
        self.engine=engine

    def evaluate_one(self, evidence_id: str, *, apply: bool=False) -> RetentionDecision:
        record=self.registry.get(evidence_id)
        decision=self.engine.evaluate(record)
        if apply:
            record.retention_policy=decision.policy_id
            record.retention_policy_version=decision.policy_version
            record.retention_until_utc=decision.retention_until_utc
            record.retention_action=decision.action
            record.retention_evaluated_at_utc=decision.evaluated_at_utc
            record.legal_hold=decision.legal_hold
            self.registry.update(record)
        return decision

    def evaluate_all(self, *, apply: bool=False) -> list[RetentionDecision]:
        return [self.evaluate_one(item.evidence_id,apply=apply) for item in self.registry.list()]

    @staticmethod
    def summary(decisions: list[RetentionDecision], *, applied: bool) -> dict[str,Any]:
        by_action: dict[str,int]={}
        by_policy: dict[str,int]={}
        for item in decisions:
            by_action[item.action]=by_action.get(item.action,0)+1
            by_policy[item.policy_id]=by_policy.get(item.policy_id,0)+1
        return {
            "schema":"sgoda.sems.retention-report/v1",
            "mode":"apply" if applied else "dry-run",
            "records":len(decisions),
            "by_action":by_action,
            "by_policy":by_policy,
            "decisions":[item.to_dict() for item in decisions],
        }