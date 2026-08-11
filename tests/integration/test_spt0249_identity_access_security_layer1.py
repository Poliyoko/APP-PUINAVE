from pathlib import Path

from sgoda.integration.spt0249.authn import validate_authentication_profile
from sgoda.integration.spt0249.least_privilege import validate_role_catalog
from sgoda.integration.spt0249.models import Identity
from sgoda.integration.spt0249.policy import RbacPolicy
from sgoda.integration.spt0249.service import IdentityAccessSecurityService


def test_reader_can_read():
    identity = Identity(
        identity_id="U1",
        identity_type="HUMAN",
        roles=frozenset({"LEXICAL_READER"}),
    )
    decision = RbacPolicy().decide(identity, "lexical", "read")
    assert decision.allowed is True


def test_reader_cannot_publish():
    identity = Identity(
        identity_id="U1",
        identity_type="HUMAN",
        roles=frozenset({"LEXICAL_READER"}),
    )
    decision = RbacPolicy().decide(identity, "publication", "publish")
    assert decision.allowed is False
    assert decision.reason == "DENY_BY_DEFAULT"


def test_unknown_role_is_denied():
    identity = Identity(
        identity_id="U2",
        identity_type="HUMAN",
        roles=frozenset({"UNKNOWN_ROLE"}),
    )
    decision = RbacPolicy().decide(identity, "lexical", "read")
    assert decision.allowed is False
    assert decision.reason == "UNKNOWN_ROLE"


def test_service_identity_can_execute_workflow():
    identity = Identity(
        identity_id="SVC1",
        identity_type="SERVICE",
        roles=frozenset({"SERVICE_WORKFLOW"}),
    )
    decision = RbacPolicy().decide(identity, "workflow", "execute")
    assert decision.allowed is True


def test_service_identity_cannot_use_human_role():
    identity = Identity(
        identity_id="SVC2",
        identity_type="SERVICE",
        roles=frozenset({"PUBLISHER"}),
    )
    decision = RbacPolicy().decide(identity, "publication", "publish")
    assert decision.allowed is False
    assert decision.reason == "SERVICE_ROLE_SCOPE_VIOLATION"


def test_human_identity_cannot_use_service_role():
    identity = Identity(
        identity_id="U3",
        identity_type="HUMAN",
        roles=frozenset({"SERVICE_WORKFLOW"}),
    )
    decision = RbacPolicy().decide(identity, "workflow", "execute")
    assert decision.allowed is False
    assert decision.reason == "HUMAN_ROLE_SCOPE_VIOLATION"


def test_separation_of_duties():
    publisher = Identity(
        identity_id="PUB",
        identity_type="HUMAN",
        roles=frozenset({"PUBLISHER"}),
    )
    security = Identity(
        identity_id="SEC",
        identity_type="HUMAN",
        roles=frozenset({"SECURITY_OPERATOR"}),
    )

    policy = RbacPolicy()

    assert policy.decide(publisher, "publication", "publish").allowed is True
    assert policy.decide(publisher, "incident", "escalate").allowed is False
    assert policy.decide(security, "incident", "escalate").allowed is True
    assert policy.decide(security, "publication", "publish").allowed is False


def test_role_catalog_has_no_wildcards():
    result = validate_role_catalog()
    assert result["wildcard_permissions"] == []
    assert result["least_privilege_pass"] is True


def test_human_authentication_requires_indirect_reference():
    secure = validate_authentication_profile({
        "identity_type": "HUMAN",
        "enabled": True,
        "credential_reference": "env:USER_CREDENTIAL",
        "factors": ["MFA"],
    })
    insecure = validate_authentication_profile({
        "identity_type": "HUMAN",
        "enabled": True,
        "credential_reference": "plaintext-value",
        "factors": ["MFA"],
    })

    assert secure["valid"] is True
    assert insecure["valid"] is False


def test_service_authentication_profile():
    result = validate_authentication_profile({
        "identity_type": "SERVICE",
        "enabled": True,
        "credential_reference": "secretref:WORKFLOW_TOKEN",
        "factors": ["WORKLOAD_IDENTITY"],
    })

    assert result["valid"] is True
    assert result["secret_values_exposed"] is False


def test_disabled_identity_is_denied():
    identity = Identity(
        identity_id="U4",
        identity_type="HUMAN",
        roles=frozenset({"LEXICAL_READER"}),
        enabled=False,
    )
    decision = RbacPolicy().decide(identity, "lexical", "read")

    assert decision.allowed is False
    assert decision.reason == "IDENTITY_DISABLED"


def test_full_gate_passes(tmp_path):
    result = IdentityAccessSecurityService(tmp_path, []).assess()

    assert result["status"] == "IDENTITY_ACCESS_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_gate_has_no_operational_side_effects(tmp_path):
    result = IdentityAccessSecurityService(tmp_path, []).assess()

    assert result["password_changed"] is False
    assert result["token_rotated"] is False
    assert result["os_permission_changed"] is False
    assert result["database_role_changed"] is False
    assert result["github_permission_changed"] is False
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
