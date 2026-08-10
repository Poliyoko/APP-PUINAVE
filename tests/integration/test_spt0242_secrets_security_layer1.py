import json
from pathlib import Path

import pytest

from sgoda.integration.spt0242 import (
    GitSecretGate,
    SecretCandidateClassifier,
    SecretManagementPolicy,
    SecureConfigurationAuditor,
    SecureStoragePlanner,
    Spt0242SecretsSecurityService,
)
from sgoda.integration.spt0242.rotation import RotationPolicyEngine


def write(path: Path, content: str = "x\n"):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def candidate(
    path="src/config.py",
    detector="ASSIGNED_SECRET",
    fingerprint="ABCDEF1234567890ABCDEF12",
    line=1,
):
    return {
        "path": path,
        "detector": detector,
        "fingerprint": fingerprint,
        "line": line,
    }


def test_default_policy_disallows_paid_api():
    assert SecretManagementPolicy.default().paid_api_allowed is False


def test_default_policy_requires_git_gate():
    assert SecretManagementPolicy.default().require_git_gate is True


def test_policy_loads_json(tmp_path):
    path = write(tmp_path / "p.json", json.dumps({"rotation_days_high": 7}))
    assert SecretManagementPolicy.from_json(path).rotation_days_high == 7


def test_example_candidate_is_false_positive():
    assessment = SecretCandidateClassifier.classify_one(
        candidate(path="tests/fixture_secret.py")
    )
    assert assessment.classification == "LIKELY_FALSE_POSITIVE"


def test_sample_candidate_is_false_positive():
    assessment = SecretCandidateClassifier.classify_one(
        candidate(path="config/sample_token.json")
    )
    assert assessment.classification == "LIKELY_FALSE_POSITIVE"


def test_docs_candidate_requires_review():
    assessment = SecretCandidateClassifier.classify_one(
        candidate(path="docs/secret-guide.md")
    )
    assert assessment.classification == "REVIEW_REQUIRED"


def test_private_key_candidate_is_critical():
    assessment = SecretCandidateClassifier.classify_one(
        candidate(detector="PRIVATE_KEY_MARKER")
    )
    assert assessment.severity == "CRITICAL"


def test_assigned_secret_is_error():
    assessment = SecretCandidateClassifier.classify_one(candidate())
    assert assessment.severity == "ERROR"


def test_real_secret_requires_rotation():
    assessment = SecretCandidateClassifier.classify_one(candidate())
    assert assessment.requires_rotation is True


def test_real_secret_requires_git_removal():
    assessment = SecretCandidateClassifier.classify_one(candidate())
    assert assessment.requires_removal_from_git is True


def test_classifier_preserves_only_metadata():
    assessment = SecretCandidateClassifier.classify_one(candidate())
    serialized = json.dumps(assessment.to_dict())
    assert "secret-value" not in serialized


def test_gitignore_control_passes_for_env(tmp_path):
    write(tmp_path / ".gitignore", ".env\n")
    control = SecureConfigurationAuditor(tmp_path).audit_gitignore()
    assert control.passed is True


def test_gitignore_control_fails_without_env(tmp_path):
    write(tmp_path / ".gitignore", "__pycache__/\n")
    control = SecureConfigurationAuditor(tmp_path).audit_gitignore()
    assert control.passed is False


def test_gitignore_control_fails_when_missing(tmp_path):
    control = SecureConfigurationAuditor(tmp_path).audit_gitignore()
    assert control.passed is False


def test_tracked_env_is_blocking(tmp_path):
    control = SecureConfigurationAuditor(tmp_path).audit_tracked_sensitive_files(
        [".env"]
    )
    assert control.passed is False


def test_tracked_private_key_is_blocking(tmp_path):
    control = SecureConfigurationAuditor(tmp_path).audit_tracked_sensitive_files(
        ["certs/prod.key"]
    )
    assert control.passed is False


def test_safe_tracked_file_passes(tmp_path):
    control = SecureConfigurationAuditor(tmp_path).audit_tracked_sensitive_files(
        ["config/settings.example"]
    )
    assert control.passed is True


def test_secret_policy_control_passes_default(tmp_path):
    assert SecureConfigurationAuditor(
        tmp_path
    ).audit_repository_secret_policy().passed is True


def test_rotation_high_is_30_days():
    assessment = SecretCandidateClassifier.classify_one(
        candidate(detector="PRIVATE_KEY_MARKER")
    )
    plan = RotationPolicyEngine().plan(assessment)
    assert plan.maximum_age_days == 30


def test_rotation_medium_is_90_days():
    assessment = SecretCandidateClassifier.classify_one(candidate())
    plan = RotationPolicyEngine().plan(assessment)
    assert plan.maximum_age_days == 90


def test_false_positive_does_not_rotate():
    assessment = SecretCandidateClassifier.classify_one(
        candidate(path="tests/example_secret.py")
    )
    assert RotationPolicyEngine().plan(assessment).required is False


def test_environment_storage_is_secure():
    plan = SecureStoragePlanner().plan()
    assert plan.repository_storage_allowed is False
    assert plan.plaintext_allowed is False


def test_windows_credential_manager_is_supported():
    plan = SecureStoragePlanner().plan(
        preferred_backend="WINDOWS_CREDENTIAL_MANAGER"
    )
    assert plan.backend == "WINDOWS_CREDENTIAL_MANAGER"


def test_unapproved_storage_fails():
    with pytest.raises(ValueError):
        SecureStoragePlanner().plan(preferred_backend="PLAINTEXT_FILE")


def test_candidate_control_passes_without_real_secrets():
    assessments = SecretCandidateClassifier.classify_many(
        [candidate(path="tests/example_secret.py")]
    )
    assert GitSecretGate.candidate_control(assessments).passed is True


def test_candidate_control_fails_with_real_secret():
    assessments = SecretCandidateClassifier.classify_many([candidate()])
    assert GitSecretGate.candidate_control(assessments).passed is False


def test_git_gate_passes_all_controls(tmp_path):
    write(tmp_path / ".gitignore", ".env\n")
    assessments = SecretCandidateClassifier.classify_many(
        [candidate(path="tests/example_secret.py")]
    )
    auditor = SecureConfigurationAuditor(tmp_path)
    controls = [
        auditor.audit_gitignore(),
        auditor.audit_tracked_sensitive_files(["src/x.py"]),
        auditor.audit_repository_secret_policy(),
        GitSecretGate.candidate_control(assessments),
    ]
    assert GitSecretGate.certify(
        controls=controls,
        assessments=assessments,
    ).passed is True


def test_git_gate_blocks_real_secret(tmp_path):
    write(tmp_path / ".gitignore", ".env\n")
    assessments = SecretCandidateClassifier.classify_many([candidate()])
    auditor = SecureConfigurationAuditor(tmp_path)
    controls = [
        auditor.audit_gitignore(),
        auditor.audit_tracked_sensitive_files(["src/x.py"]),
        auditor.audit_repository_secret_policy(),
        GitSecretGate.candidate_control(assessments),
    ]
    assert GitSecretGate.certify(
        controls=controls,
        assessments=assessments,
    ).passed is False


def test_service_loads_candidates(tmp_path):
    path = write(
        tmp_path / "baseline.json",
        json.dumps({"secret_candidates": [candidate()]}),
    )
    assert len(
        Spt0242SecretsSecurityService.load_spt0241_candidates(path)
    ) == 1


def test_service_never_exposes_values(tmp_path):
    write(tmp_path / ".gitignore", ".env\n")
    result = Spt0242SecretsSecurityService(tmp_path).evaluate(
        secret_candidates=[candidate(path="tests/example_secret.py")],
        tracked_paths=["src/x.py"],
    )
    assert result["secret_values_exposed"] is False


def test_service_preserves_closed_components(tmp_path):
    write(tmp_path / ".gitignore", ".env\n")
    result = Spt0242SecretsSecurityService(tmp_path).evaluate(
        secret_candidates=[],
        tracked_paths=["src/x.py"],
    )
    assert result["closed_components_mutated"] is False


def test_service_points_to_spt0243(tmp_path):
    write(tmp_path / ".gitignore", ".env\n")
    result = Spt0242SecretsSecurityService(tmp_path).evaluate(
        secret_candidates=[],
        tracked_paths=["src/x.py"],
    )
    assert result["next_component"] == "SPT-024.3"
