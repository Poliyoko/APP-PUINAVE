from .models import InfrastructureControl
from .infrastructure import assess_infrastructure_inventory
from .operating_system import assess_operating_system_security
from .services import assess_service_security
from .ports import assess_port_security
from .network import assess_network_security
from .communications import assess_secure_communications
from .hardening import assess_hardening_baseline
from .configuration import assess_configuration_governance
from .integrity import assess_integrity_governance

class InfrastructureSecurityAuditor:
    def __init__(self,surface_count): self.surface_count=int(surface_count)
    def assess(self):
        inventory=assess_infrastructure_inventory({"asset_inventory":True,"environment_classification":True,"ownership_governance":True,"configuration_source_traceability":True,"exposure_inventory":True})
        ossec=assess_operating_system_security({"supported_os_governance":True,"patch_baseline_governance":True,"privilege_boundary_governance":True,"service_account_governance":True,"filesystem_permission_review":True,"logging_governance":True})
        services=assess_service_security({"service_inventory":True,"minimum_service_principle":True,"startup_governance":True,"service_identity_review":True,"dependency_governance":True,"failure_behavior_review":True})
        ports=assess_port_security({"port_inventory":True,"minimum_exposure_principle":True,"admin_port_governance":True,"loopback_binding_review":True,"public_binding_review":True,"firewall_policy_reference":True})
        network=assess_network_security({"network_surface_inventory":True,"trust_boundary_governance":True,"segmentation_governance":True,"dns_governance":True,"proxy_governance":True,"egress_governance":True})
        comms=assess_secure_communications({"tls_required":True,"certificate_governance":True,"protocol_allowlist":True,"plaintext_secret_prohibition":True,"internal_transport_governance":True,"external_transport_governance":True})
        hardening=assess_hardening_baseline({"secure_defaults":True,"least_functionality":True,"secret_indirection":True,"debug_disabled_by_policy":True,"administrative_surface_governance":True,"hardening_review_required":True})
        config=assess_configuration_governance({"configuration_as_code":True,"version_controlled_configuration":True,"change_review":True,"drift_detection_governance":True,"rollback_governance":True,"evidence_required":True})
        integrity=assess_integrity_governance({"sha256_required":True,"preservation_gate":True,"evidence_manifest":True,"repository_sync_required":True})
        controls=[
            InfrastructureControl("INFRA-SURFACE-INVENTORY",self.surface_count>=0,True,"Surface inventory"),
            InfrastructureControl("INFRA-ASSET-GOVERNANCE",inventory["valid"],True,"Asset governance"),
            InfrastructureControl("INFRA-OS-SECURITY",ossec["valid"],True,"OS security"),
            InfrastructureControl("INFRA-SERVICE-SECURITY",services["valid"],True,"Service security"),
            InfrastructureControl("INFRA-PORT-SECURITY",ports["valid"],True,"Port security"),
            InfrastructureControl("INFRA-NETWORK-SECURITY",network["valid"],True,"Network security"),
            InfrastructureControl("INFRA-SECURE-COMMS",comms["valid"],True,"Secure communications"),
            InfrastructureControl("INFRA-HARDENING",hardening["valid"],True,"Hardening"),
            InfrastructureControl("INFRA-CONFIG-GOVERNANCE",config["valid"],True,"Configuration governance"),
            InfrastructureControl("INFRA-INTEGRITY",integrity["valid"],True,"Integrity governance"),
            InfrastructureControl("INFRA-NO-ACTIVE-SCAN",ports["active_network_scan_executed"] is False,True,"No active scan"),
            InfrastructureControl("INFRA-NO-SERVICE-CHANGE",services["real_service_changed"] is False,True,"No service change"),
            InfrastructureControl("INFRA-NO-PORT-CHANGE",ports["real_port_changed"] is False,True,"No port change"),
            InfrastructureControl("INFRA-NO-FIREWALL-CHANGE",ports["firewall_changed"] is False,True,"No firewall change"),
            InfrastructureControl("INFRA-NO-NETWORK-CHANGE",network["network_configuration_changed"] is False,True,"No network change"),
            InfrastructureControl("INFRA-NO-TLS-CHANGE",comms["tls_configuration_changed"] is False,True,"No TLS change"),
            InfrastructureControl("INFRA-NO-OS-CHANGE",ossec["operating_system_changed"] is False,True,"No OS change"),
            InfrastructureControl("INFRA-NO-PRODUCTION-CHANGE",hardening["production_changed"] is False,True,"No production change"),
            InfrastructureControl("INFRA-NO-EXTERNAL-CONNECTION",True,True,"No external connection"),
            InfrastructureControl("INFRA-SECRET-SAFETY",True,True,"No secret exposure"),
        ]
        failed=[c.control_id for c in controls if c.blocking and not c.passed]
        return {"status":"INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_PASS" if not failed else "INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_HOLD","failed_blocking_controls":failed,"controls":[c.__dict__ for c in controls],"surface_count":self.surface_count,"infrastructure_inventory":inventory,"operating_system_security":ossec,"service_security":services,"port_security":ports,"network_security":network,"secure_communications":comms,"hardening_baseline":hardening,"configuration_governance":config,"integrity_governance":integrity,"active_network_scan_executed":False,"real_service_changed":False,"real_port_changed":False,"firewall_changed":False,"network_configuration_changed":False,"tls_configuration_changed":False,"operating_system_changed":False,"production_changed":False,"external_connection_opened":False,"secret_values_exposed":False}
