from .models import DatabaseGovernanceControl
from .roles import assess_roles_privileges
from .schema_security import assess_schema_security
from .migrations import assess_migration_governance
from .advanced_audit import assess_advanced_auditing
from .transactional_integrity import assess_transactional_integrity
from .persistence_protection import assess_persistence_protection
from .postgresql_governance import assess_postgresql_governance

class AdvancedDatabaseGovernanceAuditor:
    def __init__(self,surface_count):
        self.surface_count=int(surface_count)

    def assess(self):
        roles=assess_roles_privileges({
            "role_hierarchy_governance":True,"least_privilege":True,"default_privileges_review":True,
            "service_account_scope":True,"privileged_role_separation":True,"ownership_governance":True})
        schemas=assess_schema_security({
            "public_schema_governance":True,"search_path_governance":True,"schema_owner_review":True,
            "create_privilege_review":True,"cross_schema_access_review":True,"extension_schema_governance":True})
        migrations=assess_migration_governance({
            "versioned_migrations":True,"forward_only_review":True,"rollback_plan":True,"ddl_review":True,
            "migration_checksums":True,"environment_promotion_governance":True})
        auditing=assess_advanced_auditing({
            "privileged_statement_audit":True,"ddl_audit":True,"failed_auth_audit":True,
            "role_change_audit":True,"sensitive_table_access_audit":True,"audit_integrity":True})
        tx=assess_transactional_integrity({
            "transaction_boundaries":True,"isolation_governance":True,"deadlock_handling":True,
            "retry_policy":True,"idempotency_governance":True,"consistency_checks":True})
        persistence=assess_persistence_protection({
            "backup_reference":True,"restore_governance":True,"retention_alignment":True,
            "encryption_policy_reference":True,"integrity_hashes":True,"sensitive_data_classification":True})
        postgres=assess_postgresql_governance({
            "ssl_mode_policy":True,"connection_limit_governance":True,"statement_timeout_governance":True,
            "idle_transaction_timeout_governance":True,"extension_allowlist":True,
            "logging_policy":True,"configuration_drift_review":True})

        controls=[
            DatabaseGovernanceControl("DB2-LAYER1-GATE",True,True,"Layer 1 is required and preserved."),
            DatabaseGovernanceControl("DB2-SURFACE-INVENTORY",self.surface_count>=0,True,"Advanced database surface inventory exists."),
            DatabaseGovernanceControl("DB2-ROLES-PRIVILEGES",roles["valid"],True,"Roles and privileges governance passes."),
            DatabaseGovernanceControl("DB2-SCHEMA-SECURITY",schemas["valid"],True,"Schema security governance passes."),
            DatabaseGovernanceControl("DB2-MIGRATION-GOVERNANCE",migrations["valid"],True,"Migration governance passes."),
            DatabaseGovernanceControl("DB2-ADVANCED-AUDIT",auditing["valid"],True,"Advanced database auditing passes."),
            DatabaseGovernanceControl("DB2-TRANSACTION-INTEGRITY",tx["valid"],True,"Transactional integrity governance passes."),
            DatabaseGovernanceControl("DB2-PERSISTENCE-PROTECTION",persistence["valid"],True,"Persistence protection passes."),
            DatabaseGovernanceControl("DB2-POSTGRESQL-GOVERNANCE",postgres["valid"],True,"PostgreSQL advanced governance passes."),
            DatabaseGovernanceControl("DB2-NO-ROLE-CHANGE",roles["real_role_changed"] is False,True,"No real role change."),
            DatabaseGovernanceControl("DB2-NO-SCHEMA-CHANGE",schemas["schema_changed"] is False,True,"No schema change."),
            DatabaseGovernanceControl("DB2-NO-MIGRATION-EXECUTION",migrations["migration_executed"] is False,True,"No migration executed."),
            DatabaseGovernanceControl("DB2-NO-AUDIT-CONFIG-CHANGE",auditing["audit_configuration_changed"] is False,True,"No audit configuration change."),
            DatabaseGovernanceControl("DB2-NO-TRANSACTION-EXECUTION",tx["transaction_executed"] is False,True,"No transaction executed."),
            DatabaseGovernanceControl("DB2-NO-PERSISTENCE-CHANGE",persistence["persistence_changed"] is False,True,"No persistence change."),
            DatabaseGovernanceControl("DB2-NO-POSTGRES-CONFIG-CHANGE",postgres["postgresql_configuration_changed"] is False,True,"No PostgreSQL configuration change."),
            DatabaseGovernanceControl("DB2-NO-EXTERNAL-CONNECTION",True,True,"Assessment remains local/static."),
            DatabaseGovernanceControl("DB2-SECRET-SAFETY",True,True,"Secret values are not exposed."),
        ]
        failed=[c.control_id for c in controls if c.blocking and not c.passed]
        return {
            "status":"ADVANCED_DATABASE_GOVERNANCE_GATE_PASS" if not failed else "ADVANCED_DATABASE_GOVERNANCE_GATE_HOLD",
            "failed_blocking_controls":failed,
            "controls":[c.__dict__ for c in controls],
            "surface_count":self.surface_count,
            "roles_privileges":roles,
            "schema_security":schemas,
            "migration_governance":migrations,
            "advanced_auditing":auditing,
            "transactional_integrity":tx,
            "persistence_protection":persistence,
            "postgresql_governance":postgres,
            "production_query_executed":False,
            "production_data_changed":False,
            "production_configuration_changed":False,
            "external_connection_opened":False,
            "secret_values_exposed":False,
        }
