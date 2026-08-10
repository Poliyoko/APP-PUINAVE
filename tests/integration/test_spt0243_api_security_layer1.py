import asyncio
from pathlib import Path

from sgoda.integration.spt0243 import (
    ApiSecurityAuditor,
    ApiSecurityGatewayMiddleware,
    GatewaySecurityPolicy,
    ProductionApiScope,
    Spt0243ApiSecurityService,
)


def write(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def operational_fixture(root: Path):
    write(
        root / "src" / "sgoda" / "api" / "routes.py",
        """
from fastapi import APIRouter
router = APIRouter()

@router.get("/health")
def health():
    return {"status": "ok"}

@router.get("/audit/repository")
def audit_repository():
    return {"status": "ok"}
""",
    )


def test_scope_excludes_tests(tmp_path):
    write(tmp_path / "tests" / "test_api.py", "debug=True\n")
    operational_fixture(tmp_path)
    files = ProductionApiScope(tmp_path).files()
    assert all("tests" not in path.parts for path in files)


def test_scope_excludes_releases(tmp_path):
    write(tmp_path / "releases" / "v1" / "api.py", "debug=True\n")
    operational_fixture(tmp_path)
    files = ProductionApiScope(tmp_path).files()
    assert all("releases" not in path.parts for path in files)


def test_scope_excludes_builder_templates(tmp_path):
    write(tmp_path / "builder" / "src" / "templates" / "api.py", "debug=True\n")
    operational_fixture(tmp_path)
    files = ProductionApiScope(tmp_path).files()
    assert all("builder" not in path.parts for path in files)


def test_scope_includes_operational_api(tmp_path):
    operational_fixture(tmp_path)
    files = ProductionApiScope(tmp_path).files()
    assert any(path.name == "routes.py" for path in files)


def test_gateway_policy_protects_audit_repository():
    assert GatewaySecurityPolicy().protects("/audit/repository") is True


def test_gateway_policy_does_not_protect_health():
    assert GatewaySecurityPolicy().protects("/health") is False


def test_gateway_policy_has_request_limit():
    assert GatewaySecurityPolicy().max_request_bytes > 0


def test_gateway_policy_has_rate_limit():
    assert GatewaySecurityPolicy().rate_limit_requests > 0


def test_gateway_policy_has_trusted_hosts():
    assert "localhost" in GatewaySecurityPolicy().trusted_hosts


def test_gateway_policy_never_persists_token():
    assert GatewaySecurityPolicy().to_dict()["plaintext_token_persisted"] is False


def test_gateway_policy_protects_audit_subpaths():
    assert GatewaySecurityPolicy().protects("/audit/repository/detail") is True


def test_gateway_policy_protects_admin_subpaths():
    assert GatewaySecurityPolicy().protects("/admin/users") is True


def test_auditor_discovers_audit_route(tmp_path):
    operational_fixture(tmp_path)
    exposures = ApiSecurityAuditor(tmp_path).discover_exposures()
    assert any(item.path == "/audit/repository" for item in exposures)


def test_audit_route_is_gateway_authenticated(tmp_path):
    operational_fixture(tmp_path)
    exposures = ApiSecurityAuditor(tmp_path).discover_exposures()
    item = [x for x in exposures if x.path == "/audit/repository"][0]
    assert item.gateway_auth is True
    assert item.authenticated is True


def test_health_is_not_sensitive(tmp_path):
    operational_fixture(tmp_path)
    exposures = ApiSecurityAuditor(tmp_path).discover_exposures()
    item = [x for x in exposures if x.path == "/health"][0]
    assert item.sensitive is False


def test_tests_debug_does_not_fail_production_gate(tmp_path):
    operational_fixture(tmp_path)
    write(tmp_path / "tests" / "test_bad.py", "debug=True\n")
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-DEBUG"].passed is True


def test_tests_wildcard_cors_does_not_fail_production_gate(tmp_path):
    operational_fixture(tmp_path)
    write(tmp_path / "tests" / "test_bad.py", 'allow_origins = ["*"]\n')
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-CORS"].passed is True


def test_tests_plaintext_fixture_does_not_fail_production_gate(tmp_path):
    operational_fixture(tmp_path)
    write(tmp_path / "tests" / "test_bad.py", 'token = "abcdefghijkl"\n')
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-SECRETS"].passed is True


def test_operational_debug_fails(tmp_path):
    operational_fixture(tmp_path)
    write(tmp_path / "src" / "sgoda" / "api" / "main.py", "debug=True\n")
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-DEBUG"].passed is False


def test_operational_wildcard_cors_fails(tmp_path):
    operational_fixture(tmp_path)
    write(tmp_path / "src" / "sgoda" / "api" / "main.py", 'allow_origins = ["*"]\n')
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-CORS"].passed is False


def test_operational_plaintext_secret_fails(tmp_path):
    operational_fixture(tmp_path)
    write(tmp_path / "src" / "sgoda" / "api" / "main.py", 'token = "abcdefghijkl"\n')
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-SECRETS"].passed is False


def test_gateway_auth_makes_sensitive_route_pass(tmp_path):
    operational_fixture(tmp_path)
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-AUTH"].passed is True


def test_gateway_headers_control_passes(tmp_path):
    operational_fixture(tmp_path)
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-HEADERS"].passed is True


def test_gateway_request_size_control_passes(tmp_path):
    operational_fixture(tmp_path)
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-REQUEST-SIZE"].passed is True


def test_gateway_rate_limit_control_passes(tmp_path):
    operational_fixture(tmp_path)
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-RATE-LIMIT"].passed is True


def test_gateway_trusted_host_control_passes(tmp_path):
    operational_fixture(tmp_path)
    controls, _ = ApiSecurityAuditor(tmp_path).audit()
    assert {x.control_id: x for x in controls}["API-TRUSTED-HOST"].passed is True


def test_service_passes_operational_fixture(tmp_path):
    operational_fixture(tmp_path)
    result = Spt0243ApiSecurityService(tmp_path).evaluate()
    assert result["status"] == "API_SECURITY_GATE_PASS"


def test_service_never_exposes_secret_values(tmp_path):
    operational_fixture(tmp_path)
    result = Spt0243ApiSecurityService(tmp_path).evaluate()
    assert result["secret_values_exposed"] is False


def test_service_does_not_mutate_closed_components(tmp_path):
    operational_fixture(tmp_path)
    result = Spt0243ApiSecurityService(tmp_path).evaluate()
    assert result["closed_components_mutated"] is False


def test_service_points_to_spt0244(tmp_path):
    operational_fixture(tmp_path)
    assert Spt0243ApiSecurityService(tmp_path).evaluate()["next_component"] == "SPT-024.4"


async def _dummy_app(scope, receive, send):
    await send({"type": "http.response.start", "status": 200, "headers": []})
    await send({"type": "http.response.body", "body": b"ok"})


async def _run_gateway(path="/health", headers=None, policy=None):
    messages = []
    app = ApiSecurityGatewayMiddleware(_dummy_app, policy)
    scope = {
        "type": "http",
        "path": path,
        "headers": headers or [(b"host", b"localhost")],
        "client": ("127.0.0.1", 1234),
    }

    async def receive():
        return {"type": "http.request", "body": b"", "more_body": False}

    async def send(message):
        messages.append(message)

    await app(scope, receive, send)
    return messages


def test_gateway_denies_sensitive_route_without_configured_token(monkeypatch):
    monkeypatch.delenv("SGODA_API_GUARD_TOKEN", raising=False)
    messages = asyncio.run(_run_gateway("/audit/repository"))
    assert messages[0]["status"] == 503


def test_gateway_denies_wrong_token(monkeypatch):
    monkeypatch.setenv("SGODA_API_GUARD_TOKEN", "correct-value")
    headers = [
        (b"host", b"localhost"),
        (b"authorization", b"Bearer wrong-value"),
    ]
    messages = asyncio.run(_run_gateway("/audit/repository", headers=headers))
    assert messages[0]["status"] == 401


def test_gateway_allows_correct_token(monkeypatch):
    monkeypatch.setenv("SGODA_API_GUARD_TOKEN", "correct-value")
    headers = [
        (b"host", b"localhost"),
        (b"authorization", b"Bearer correct-value"),
    ]
    messages = asyncio.run(_run_gateway("/audit/repository", headers=headers))
    assert messages[0]["status"] == 200


def test_gateway_allows_health_without_token(monkeypatch):
    monkeypatch.delenv("SGODA_API_GUARD_TOKEN", raising=False)
    messages = asyncio.run(_run_gateway("/health"))
    assert messages[0]["status"] == 200


def test_gateway_rejects_untrusted_host():
    messages = asyncio.run(
        _run_gateway(
            "/health",
            headers=[(b"host", b"evil.invalid")],
        )
    )
    assert messages[0]["status"] == 400


def test_gateway_rejects_oversized_request():
    headers = [
        (b"host", b"localhost"),
        (b"content-length", str(3 * 1024 * 1024).encode("ascii")),
    ]
    messages = asyncio.run(_run_gateway("/health", headers=headers))
    assert messages[0]["status"] == 413


def test_gateway_adds_security_headers():
    messages = asyncio.run(_run_gateway("/health"))
    headers = dict(messages[0]["headers"])
    assert headers[b"x-content-type-options"] == b"nosniff"
    assert headers[b"x-frame-options"] == b"DENY"


def test_gateway_denies_disallowed_origin():
    policy = GatewaySecurityPolicy(
        allowed_origins=("https://allowed.invalid",),
    )
    headers = [
        (b"host", b"localhost"),
        (b"origin", b"https://evil.invalid"),
    ]
    messages = asyncio.run(_run_gateway("/health", headers=headers, policy=policy))
    assert messages[0]["status"] == 403


def test_gateway_allows_configured_origin():
    policy = GatewaySecurityPolicy(
        allowed_origins=("https://allowed.invalid",),
    )
    headers = [
        (b"host", b"localhost"),
        (b"origin", b"https://allowed.invalid"),
    ]
    messages = asyncio.run(_run_gateway("/health", headers=headers, policy=policy))
    assert messages[0]["status"] == 200


def test_gateway_rate_limit_blocks_after_limit():
    policy = GatewaySecurityPolicy(
        rate_limit_requests=1,
        rate_limit_window_seconds=60,
    )
    app = ApiSecurityGatewayMiddleware(_dummy_app, policy, clock=lambda: 1.0)
    scope = {
        "type": "http",
        "path": "/health",
        "headers": [(b"host", b"localhost")],
        "client": ("127.0.0.1", 1),
    }

    async def once():
        messages = []
        async def receive():
            return {"type": "http.request", "body": b"", "more_body": False}
        async def send(message):
            messages.append(message)
        await app(scope, receive, send)
        return messages

    first = asyncio.run(once())
    second = asyncio.run(once())
    assert first[0]["status"] == 200
    assert second[0]["status"] == 429
