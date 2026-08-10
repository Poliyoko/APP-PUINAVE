import json
from pathlib import Path

from sgoda.integration.spt0241 import (
    AssetClassifier,
    AttackSurfaceModel,
    SecurityAsset,
    SecurityBaseline,
    SecurityFinding,
    SecurityInventoryPolicy,
    SecuritySurfaceScanner,
    SecretMetadataScanner,
    Spt0241SecurityInventoryService,
)


def write(path: Path, content: str = "x\n"):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def test_default_policy_disallows_paid_api():
    assert SecurityInventoryPolicy.default().paid_api_allowed is False


def test_policy_loads_json(tmp_path):
    path = write(tmp_path / "policy.json", json.dumps({"fail_on_blocking": False}))
    assert SecurityInventoryPolicy.from_json(path).fail_on_blocking is False


def test_asset_serializes():
    asset = SecurityAsset("A", "x.py", "PYTHON", "MEDIUM", "INTERNAL", False)
    assert asset.to_dict()["asset_id"] == "A"


def test_error_finding_is_blocking():
    finding = SecurityFinding("X", "ERROR", "A", "x")
    assert finding.blocking is True


def test_warning_finding_is_not_blocking():
    finding = SecurityFinding("X", "WARNING", "A", "x")
    assert finding.blocking is False


def test_empty_baseline_is_conformant():
    assert SecurityBaseline().conformant is True


def test_baseline_with_error_not_conformant():
    baseline = SecurityBaseline(
        findings=[SecurityFinding("X", "ERROR", "A", "x")]
    )
    assert baseline.conformant is False


def test_classifier_python(tmp_path):
    path = write(tmp_path / "src" / "x.py")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.asset_type == "PYTHON"


def test_classifier_powershell(tmp_path):
    path = write(tmp_path / "tool.ps1")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.asset_type == "POWERSHELL"


def test_classifier_lexical_data(tmp_path):
    path = write(tmp_path / "diccionario.xlsx")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.data_classification == "INSTITUTIONAL_DATA"


def test_classifier_audio(tmp_path):
    path = write(tmp_path / "audio.wav")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.asset_type == "AUDIO"


def test_classifier_image(tmp_path):
    path = write(tmp_path / "image.png")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.asset_type == "IMAGE"


def test_classifier_detects_api_surface(tmp_path):
    path = write(tmp_path / "src" / "fastapi_router.py")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.exposed_surface is True


def test_classifier_marks_security_path_high(tmp_path):
    path = write(tmp_path / "src" / "security" / "gate.py")
    asset = AssetClassifier().classify(path, root=tmp_path)
    assert asset.criticality == "HIGH"


def test_scanner_excludes_git(tmp_path):
    write(tmp_path / ".git" / "config")
    write(tmp_path / "src" / "x.py")
    files = SecuritySurfaceScanner(tmp_path).files()
    assert all(".git" not in path.parts for path in files)


def test_scanner_sha256(tmp_path):
    path = write(tmp_path / "x.txt", "abc")
    assert len(SecuritySurfaceScanner.sha256(path)) == 64


def test_inventory_returns_assets(tmp_path):
    write(tmp_path / "src" / "x.py")
    assert len(SecuritySurfaceScanner(tmp_path).inventory()) == 1


def test_sensitive_extension_is_blocking(tmp_path):
    write(tmp_path / "private.key", "not-a-real-key")
    scanner = SecuritySurfaceScanner(tmp_path)
    findings = scanner.detect_findings(scanner.inventory())
    assert any(f.code == "SENSITIVE_FILE_PRESENT" and f.blocking for f in findings)


def test_secret_like_filename_is_warning(tmp_path):
    write(tmp_path / "token_notes.txt")
    scanner = SecuritySurfaceScanner(tmp_path)
    findings = scanner.detect_findings(scanner.inventory())
    assert any(f.code == "SECRET_LIKE_FILENAME" for f in findings)


def test_exposed_surface_is_info(tmp_path):
    write(tmp_path / "api" / "router.py")
    scanner = SecuritySurfaceScanner(tmp_path)
    findings = scanner.detect_findings(scanner.inventory())
    assert any(f.code == "EXPOSED_SURFACE_IDENTIFIED" for f in findings)


def test_secret_scanner_detects_assigned_secret_without_value(tmp_path):
    path = write(tmp_path / "config.py", 'api_key = "1234567890ABCDEF"\n')
    result = SecretMetadataScanner().scan(root=tmp_path, paths=[path])
    assert len(result) == 1
    assert "1234567890ABCDEF" not in json.dumps(result[0].to_dict())


def test_secret_scanner_detects_private_key_marker(tmp_path):
    path = write(tmp_path / "x.txt", "-----BEGIN PRIVATE KEY-----\n")
    result = SecretMetadataScanner().scan(root=tmp_path, paths=[path])
    assert result[0].detector == "PRIVATE_KEY_MARKER"


def test_secret_scanner_skips_binary_extension(tmp_path):
    path = write(tmp_path / "x.png", 'token="1234567890"\n')
    assert SecretMetadataScanner().scan(root=tmp_path, paths=[path]) == []


def test_secret_fingerprint_is_stable(tmp_path):
    path = write(tmp_path / "config.py", 'secret = "abcdefghijkl"\n')
    scanner = SecretMetadataScanner()
    one = scanner.scan(root=tmp_path, paths=[path])[0]
    two = scanner.scan(root=tmp_path, paths=[path])[0]
    assert one.fingerprint == two.fingerprint


def test_attack_surface_counts_assets():
    assets = [
        SecurityAsset("A", "api.py", "PYTHON", "HIGH", "INTERNAL", True),
        SecurityAsset("B", "x.md", "DOCUMENTATION", "LOW", "INTERNAL", False),
    ]
    model = AttackSurfaceModel.build(assets)
    assert model["asset_count"] == 2
    assert model["exposed_surface_count"] == 1


def test_attack_surface_groups_types():
    assets = [
        SecurityAsset("A", "a.py", "PYTHON", "MEDIUM", "INTERNAL", False),
        SecurityAsset("B", "b.py", "PYTHON", "MEDIUM", "INTERNAL", False),
    ]
    assert AttackSurfaceModel.build(assets)["asset_types"]["PYTHON"] == 2


def test_service_establishes_baseline(tmp_path):
    write(tmp_path / "src" / "x.py")
    result = Spt0241SecurityInventoryService(tmp_path).evaluate()
    assert result["status"] == "SECURITY_BASELINE_ESTABLISHED"


def test_service_is_read_only(tmp_path):
    path = write(tmp_path / "src" / "x.py", "VALUE = 1\n")
    before = SecuritySurfaceScanner.sha256(path)
    Spt0241SecurityInventoryService(tmp_path).evaluate()
    after = SecuritySurfaceScanner.sha256(path)
    assert before == after


def test_service_does_not_expose_secret_values(tmp_path):
    write(tmp_path / "config.py", 'password = "abcdefghijkl"\n')
    result = Spt0241SecurityInventoryService(tmp_path).evaluate()
    assert result["secret_values_exposed"] is False


def test_service_points_to_spt0242(tmp_path):
    write(tmp_path / "src" / "x.py")
    assert Spt0241SecurityInventoryService(tmp_path).evaluate()["next_component"] == "SPT-024.2"
