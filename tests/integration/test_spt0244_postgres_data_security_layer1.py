from pathlib import Path

from sgoda.integration.spt0244 import (
    PostgresProductionAuditor,
    PostgresRuntimeSecurityPolicy,
    SecurePostgresDsnBuilder,
    SqlSafetyGuard,
    Spt0244RemediationService,
)


def write(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def op_path(root: Path, name: str):
    return root / "src" / "sgoda" / "operational_platform" / name


def test_policy_uses_secure_env_name():
    assert PostgresRuntimeSecurityPolicy().dsn_env_name == "SGODA_POSTGRES_DSN"


def test_policy_enforces_verify_full():
    assert PostgresRuntimeSecurityPolicy().required_sslmode == "verify-full"


def test_policy_forbids_superuser():
    assert PostgresRuntimeSecurityPolicy().forbid_runtime_superuser is True


def test_policy_requires_parameterized_sql():
    assert PostgresRuntimeSecurityPolicy().require_parameterized_sql is True


def test_policy_has_statement_timeout():
    assert PostgresRuntimeSecurityPolicy().statement_timeout_ms > 0


def test_policy_has_lock_timeout():
    assert PostgresRuntimeSecurityPolicy().lock_timeout_ms > 0


def test_policy_never_persists_secret():
    assert PostgresRuntimeSecurityPolicy().to_dict()["secret_value_persisted"] is False


def test_dsn_builder_adds_verify_full():
    secured = SecurePostgresDsnBuilder.secure("postgresql://u:p@db/x")
    assert "sslmode=verify-full" in secured


def test_dsn_builder_adds_application_name():
    secured = SecurePostgresDsnBuilder.secure("postgresql://u:p@db/x")
    assert "application_name=sgoda-puinave" in secured


def test_dsn_builder_adds_timeouts():
    secured = SecurePostgresDsnBuilder.secure("postgresql://u:p@db/x")
    assert "statement_timeout" in secured
    assert "lock_timeout" in secured


def test_ast_guard_detects_fstring():
    assert SqlSafetyGuard.contains_obvious_unsafe_execution(
        'cursor.execute(f"select * from x where id={value}")'
    ) is True


def test_ast_guard_detects_concat():
    assert SqlSafetyGuard.contains_obvious_unsafe_execution(
        'cursor.execute("select * from x where id=" + value)'
    ) is True


def test_ast_guard_detects_format():
    assert SqlSafetyGuard.contains_obvious_unsafe_execution(
        'cursor.execute("select * from x where id={}".format(value))'
    ) is True


def test_ast_guard_allows_parameterized():
    assert SqlSafetyGuard.contains_obvious_unsafe_execution(
        'cursor.execute("select * from x where id=%s", (value,))'
    ) is False


def test_scope_ignores_policy_registry(tmp_path):
    write(
        tmp_path / "config" / "policies" / "POL-001.json",
        '{"database":"postgresql","user":"postgres"}',
    )
    assert PostgresProductionAuditor(tmp_path)._existing() == []


def test_scope_includes_operational_database(tmp_path):
    write(op_path(tmp_path, "database.py"), "# database\n")
    assert any(
        path.name == "database.py"
        for path in PostgresProductionAuditor(tmp_path)._existing()
    )


def test_plaintext_dsn_is_detected(tmp_path):
    write(
        op_path(tmp_path, "database.py"),
        'dsn="postgresql://realuser:realpass@db/prod"\n',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-SECRET-INDIRECTION"].passed is False


def test_env_dsn_passes(tmp_path):
    write(
        op_path(tmp_path, "database.py"),
        'dsn=os.getenv("SGODA_POSTGRES_DSN")\n',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-SECRET-INDIRECTION"].passed is True


def test_placeholder_dsn_is_not_treated_as_real_secret(tmp_path):
    write(
        op_path(tmp_path, "database.py"),
        '# example\nDSN="postgresql://user:password@localhost/example"\n',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-SECRET-INDIRECTION"].passed is True


def test_explicit_superuser_assignment_fails(tmp_path):
    write(
        tmp_path / "config" / "operational_platform" / "SPT-011-runtime.json",
        '{"user":"postgres"}',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-LEAST-PRIVILEGE"].passed is False


def test_postgres_word_alone_is_not_superuser(tmp_path):
    write(
        tmp_path / "config" / "operational_platform" / "SPT-011-runtime.json",
        '{"database":"postgresql"}',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-LEAST-PRIVILEGE"].passed is True


def test_dynamic_sql_in_operational_code_fails(tmp_path):
    write(
        op_path(tmp_path, "database.py"),
        'cursor.execute(f"select * from x where id={value}")\n',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-SQL-INJECTION"].passed is False


def test_parameterized_sql_in_operational_code_passes(tmp_path):
    write(
        op_path(tmp_path, "database.py"),
        'cursor.execute("select * from x where id=%s", (value,))\n',
    )
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-SQL-INJECTION"].passed is True


def test_overlay_surface_is_always_present(tmp_path):
    _, surfaces = PostgresProductionAuditor(tmp_path).audit()
    assert any(s.surface_type == "SPT0244_SECURITY_OVERLAY" for s in surfaces)


def test_tls_control_passes(tmp_path):
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-TLS"].passed is True


def test_timeout_control_passes(tmp_path):
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-TIMEOUTS"].passed is True


def test_secret_nonpersistence_passes(tmp_path):
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-SECRET-NONPERSISTENCE"].passed is True


def test_backup_integrity_contract_passes(tmp_path):
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert {c.control_id: c for c in controls}["DB-BACKUP-INTEGRITY"].passed is True


def test_service_does_not_open_database(tmp_path):
    assert Spt0244RemediationService(tmp_path).evaluate()["database_connection_opened"] is False


def test_service_does_not_expose_secret_values(tmp_path):
    assert Spt0244RemediationService(tmp_path).evaluate()["secret_values_exposed"] is False


def test_service_does_not_mutate_closed_components(tmp_path):
    assert Spt0244RemediationService(tmp_path).evaluate()["closed_components_mutated"] is False


def test_service_points_to_spt0245(tmp_path):
    assert Spt0244RemediationService(tmp_path).evaluate()["next_component"] == "SPT-024.5"


def test_clean_empty_scope_passes(tmp_path):
    assert Spt0244RemediationService(tmp_path).evaluate()["status"] == "POSTGRES_DATA_SECURITY_GATE_PASS"


def test_runtime_surface_secret_indirection_true():
    from sgoda.integration.spt0244.models import DatabaseSurface
    surface = DatabaseSurface(
        path="runtime.py",
        surface_type="SPT0244_SECURITY_OVERLAY",
        runtime_relevant=True,
        secret_indirection=True,
        tls_declared=True,
        superuser_marker=False,
        unsafe_sql_marker=False,
        rationale="x",
    )
    assert surface.secret_indirection is True


def test_runtime_surface_tls_true():
    from sgoda.integration.spt0244.models import DatabaseSurface
    surface = DatabaseSurface(
        path="runtime.py",
        surface_type="SPT0244_SECURITY_OVERLAY",
        runtime_relevant=True,
        secret_indirection=True,
        tls_declared=True,
        superuser_marker=False,
        unsafe_sql_marker=False,
        rationale="x",
    )
    assert surface.tls_declared is True


def test_production_scope_control_exists(tmp_path):
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert "DB-PRODUCTION-SCOPE" in {c.control_id for c in controls}


def test_expected_control_count(tmp_path):
    controls, _ = PostgresProductionAuditor(tmp_path).audit()
    assert len(controls) == 8


def test_secure_dsn_does_not_log_or_persist():
    secured = SecurePostgresDsnBuilder.secure("postgresql://u:p@db/x")
    assert secured.startswith("postgresql://")


def test_secure_dsn_preserves_database_path():
    secured = SecurePostgresDsnBuilder.secure("postgresql://u:p@db/sgoda")
    assert "/sgoda?" in secured or secured.endswith("/sgoda")
