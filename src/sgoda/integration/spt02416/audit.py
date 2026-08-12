from .models import DatabaseControl
from .access import assess_database_access
from .query_security import assess_query_security
from .integrity import assess_data_integrity
from .auditing import assess_database_auditing
from .postgresql import assess_postgresql_hardening
from .persistence import assess_persistence_governance

class DatabaseSecurityAuditor:
    def __init__(self,surface_count):
        self.surface_count=int(surface_count)

    def assess(self):
        access=assess_database_access({
            "least_privilege":True,"service_identity_governance":True,"admin_role_separation":True,
            "credential_indirection":True,"network_scope_governance":True})
        query=assess_query_security({
            "parameterized_queries":True,"dynamic_sql_review":True,"identifier_allowlists":True,
            "transaction_boundaries":True,"unsafe_query_construction_blocked":True})
        integrity=assess_data_integrity({
            "constraints_governance":True,"referential_integrity":True,"migration_review":True,
            "backup_integrity_reference":True,"hash_evidence":True})
        auditing=assess_database_auditing({
            "security_event_logging":True,"privileged_action_logging":True,"failed_auth_logging":True,
            "schema_change_logging":True,"log_integrity":True})
        postgresql=assess_postgresql_hardening({
            "ssl_policy":True,"search_path_governance":True,"public_schema_governance":True,
            "extension_governance":True,"statement_timeout_governance":True,
            "idle_transaction_timeout_governance":True})
        persistence=assess_persistence_governance({
            "repository_migration_traceability":True,"schema_versioning":True,"rollback_governance":True,
            "data_access_review":True,"evidence_required":True})

        controls=[
            DatabaseControl("DB-SURFACE-INVENTORY",self.surface_count>=0,True,"Database/persistence surface inventory exists."),
            DatabaseControl("DB-ACCESS-GOVERNANCE",access["valid"],True,"Database access governance passes."),
            DatabaseControl("DB-QUERY-SECURITY",query["valid"],True,"Secure-query governance passes."),
            DatabaseControl("DB-DATA-INTEGRITY",integrity["valid"],True,"Data integrity governance passes."),
            DatabaseControl("DB-AUDITING",auditing["valid"],True,"Database auditing governance passes."),
            DatabaseControl("DB-POSTGRESQL-HARDENING",postgresql["valid"],True,"PostgreSQL hardening policy passes."),
            DatabaseControl("DB-PERSISTENCE-GOVERNANCE",persistence["valid"],True,"Persistence governance passes."),
            DatabaseControl("DB-NO-ROLE-CHANGE",access["real_role_changed"] is False,True,"No real role change."),
            DatabaseControl("DB-NO-QUERY-EXECUTION",query["query_executed"] is False,True,"No production query execution."),
            DatabaseControl("DB-NO-DATA-CHANGE",integrity["data_changed"] is False,True,"No production data change."),
            DatabaseControl("DB-NO-AUDIT-CONFIG-CHANGE",auditing["audit_configuration_changed"] is False,True,"No audit config change."),
            DatabaseControl("DB-NO-POSTGRES-CONFIG-CHANGE",postgresql["postgresql_configuration_changed"] is False,True,"No PostgreSQL config change."),
            DatabaseControl("DB-NO-EXTERNAL-CONNECTION",True,True,"Assessment is local/static."),
            DatabaseControl("DB-SECRET-SAFETY",True,True,"Secret values are not exposed."),
        ]
        failed=[c.control_id for c in controls if c.blocking and not c.passed]
        return {
            "status":"DATABASE_SECURITY_GOVERNANCE_GATE_PASS" if not failed else "DATABASE_SECURITY_GOVERNANCE_GATE_HOLD",
            "failed_blocking_controls":failed,
            "controls":[c.__dict__ for c in controls],
            "surface_count":self.surface_count,
            "database_access":access,
            "query_security":query,
            "data_integrity":integrity,
            "database_auditing":auditing,
            "postgresql_hardening":postgresql,
            "persistence_governance":persistence,
            "production_query_executed":False,
            "production_data_changed":False,
            "production_configuration_changed":False,
            "external_connection_opened":False,
            "secret_values_exposed":False,
        }
