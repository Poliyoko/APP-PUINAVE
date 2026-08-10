from pathlib import Path

from sgoda.integration.spt0247.audit import SupplyChainSecurityAuditor
from sgoda.integration.spt0247.gate import SupplyChainSecurityGate
from sgoda.integration.spt0247.service import SupplyChainSecurityService


def write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def controls(root, tracked):
    result = SupplyChainSecurityAuditor(root, tracked).assess()
    return {c["control_id"]: c for c in result["controls"]}


def test_gate_contract_has_eight_required_controls():
    assert len(SupplyChainSecurityGate.REQUIRED_BLOCKING_CONTROLS) == 8


def test_empty_scope_passes_non_applicable_controls(tmp_path):
    result = SupplyChainSecurityService(tmp_path, []).assess()
    assert result["status"] == "SUPPLY_CHAIN_SECURITY_GATE_PASS"


def test_write_all_permissions_are_blocking(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "permissions: write-all\njobs: {}\n")
    assert controls(tmp_path, [p])["SCM-WORKFLOW-PERMISSIONS"]["passed"] is False


def test_read_permissions_are_allowed(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "permissions: read-all\njobs: {}\n")
    assert controls(tmp_path, [p])["SCM-WORKFLOW-PERMISSIONS"]["passed"] is True


def test_mutable_main_action_is_blocking(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "steps:\n  - uses: owner/action@main\n")
    assert controls(tmp_path, [p])["SCM-ACTIONS-MUTABLE-BRANCH"]["passed"] is False


def test_version_tag_action_is_advisory_not_blocking(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "steps:\n  - uses: actions/checkout@v4\n")
    result = SupplyChainSecurityService(tmp_path, [p]).assess()
    assert result["status"] == "SUPPLY_CHAIN_SECURITY_GATE_PASS"
    by = {c["control_id"]: c for c in result["controls"]}
    assert by["SCM-ACTIONS-PINNING"]["passed"] is False
    assert by["SCM-ACTIONS-PINNING"]["blocking"] is False


def test_sha_pinned_action_passes_pinning_inventory(tmp_path):
    p = ".github/workflows/a.yml"
    sha = "0123456789abcdef0123456789abcdef01234567"
    write(tmp_path / p, f"steps:\n  - uses: actions/checkout@{sha}\n")
    assert controls(tmp_path, [p])["SCM-ACTIONS-PINNING"]["passed"] is True


def test_direct_secret_in_run_is_blocking(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "steps:\n  - run: echo ${{ secrets.API_TOKEN }}\n")
    assert controls(tmp_path, [p])["SCM-SECRET-USAGE"]["passed"] is False


def test_secret_in_env_not_direct_run_is_allowed(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "env:\n  API_TOKEN: ${{ secrets.API_TOKEN }}\nsteps:\n  - run: tool\n")
    assert controls(tmp_path, [p])["SCM-SECRET-USAGE"]["passed"] is True


def test_event_expression_in_run_is_blocking(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "steps:\n  - run: echo ${{ github.event.issue.title }}\n")
    assert controls(tmp_path, [p])["SCM-EXPRESSION-INJECTION"]["passed"] is False


def test_pipe_to_shell_is_blocking(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "steps:\n  - run: curl https://example.invalid/install.sh | bash\n")
    assert controls(tmp_path, [p])["SCM-SCRIPT-EXECUTION"]["passed"] is False


def test_run_without_dash_is_also_audited(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "run: echo ${{ secrets.API_TOKEN }}\n")
    assert controls(tmp_path, [p])["SCM-SECRET-USAGE"]["passed"] is False


def test_https_dependency_source_is_allowed(tmp_path):
    p = "requirements.txt"
    write(tmp_path / p, "package==1.0.0\n")
    assert controls(tmp_path, [p])["SCM-DEPENDENCY-INTEGRITY"]["passed"] is True


def test_insecure_http_dependency_source_is_blocking(tmp_path):
    p = "requirements.txt"
    write(tmp_path / p, "pkg @ http://example.invalid/pkg.whl\n")
    assert controls(tmp_path, [p])["SCM-DEPENDENCY-INTEGRITY"]["passed"] is False


def test_unpinned_vcs_dependency_is_blocking(tmp_path):
    p = "requirements.txt"
    write(tmp_path / p, "git+https://github.com/example/project.git\n")
    assert controls(tmp_path, [p])["SCM-DEPENDENCY-INTEGRITY"]["passed"] is False


def test_workflow_is_classified(tmp_path):
    p = ".github/workflows/a.yml"
    write(tmp_path / p, "jobs: {}\n")
    result = SupplyChainSecurityService(tmp_path, [p]).assess()
    assert any(s["surface_type"] == "CI_CD_WORKFLOW" for s in result["surfaces"])


def test_dependency_manifest_is_classified(tmp_path):
    p = "pyproject.toml"
    write(tmp_path / p, "[project]\nname='x'\n")
    result = SupplyChainSecurityService(tmp_path, [p]).assess()
    assert any(s["surface_type"] == "DEPENDENCY_MANIFEST" for s in result["surfaces"])


def test_gate_never_executes_workflow_or_release(tmp_path):
    result = SupplyChainSecurityService(tmp_path, []).assess()
    assert result["workflow_executed_by_gate"] is False
    assert result["package_installed_by_gate"] is False
    assert result["release_published_by_gate"] is False
    assert result["secret_values_exposed"] is False


def test_unknown_yaml_is_not_ci_workflow(tmp_path):
    p = "pic.yaml"
    write(tmp_path / p, "name: config\n")
    result = SupplyChainSecurityService(tmp_path, [p]).assess()
    assert not result["surfaces"]


def test_test_requirements_are_still_supply_chain_surface(tmp_path):
    p = "tests/requirements.txt"
    write(tmp_path / p, "package==1\n")
    result = SupplyChainSecurityService(tmp_path, [p]).assess()
    assert any(s["surface_type"] == "DEPENDENCY_MANIFEST" for s in result["surfaces"])
