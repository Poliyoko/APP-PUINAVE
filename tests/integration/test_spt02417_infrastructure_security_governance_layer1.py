from sgoda.integration.spt02417 import InfrastructureSecurityService
from sgoda.integration.spt02417.gate import InfrastructureSecurityGate
def test_blocking_control_count(): assert len(InfrastructureSecurityGate.BLOCKING)==20
def test_gate_passes(): assert InfrastructureSecurityService().assess(10)["status"]=="INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_PASS"
def test_no_failed_controls(): assert InfrastructureSecurityService().assess(10)["failed_blocking_controls"]==[]
def test_inventory(): assert InfrastructureSecurityService().assess(1)["infrastructure_inventory"]["valid"]
def test_os(): assert InfrastructureSecurityService().assess(1)["operating_system_security"]["valid"]
def test_services(): assert InfrastructureSecurityService().assess(1)["service_security"]["valid"]
def test_ports(): assert InfrastructureSecurityService().assess(1)["port_security"]["valid"]
def test_network(): assert InfrastructureSecurityService().assess(1)["network_security"]["valid"]
def test_comms(): assert InfrastructureSecurityService().assess(1)["secure_communications"]["valid"]
def test_hardening(): assert InfrastructureSecurityService().assess(1)["hardening_baseline"]["valid"]
def test_config(): assert InfrastructureSecurityService().assess(1)["configuration_governance"]["valid"]
def test_integrity(): assert InfrastructureSecurityService().assess(1)["integrity_governance"]["valid"]
def test_no_active_scan(): assert InfrastructureSecurityService().assess(1)["active_network_scan_executed"] is False
def test_no_service_change(): assert InfrastructureSecurityService().assess(1)["real_service_changed"] is False
def test_no_port_change(): assert InfrastructureSecurityService().assess(1)["real_port_changed"] is False
def test_no_firewall_change(): assert InfrastructureSecurityService().assess(1)["firewall_changed"] is False
def test_no_network_change(): assert InfrastructureSecurityService().assess(1)["network_configuration_changed"] is False
def test_no_tls_change(): assert InfrastructureSecurityService().assess(1)["tls_configuration_changed"] is False
def test_no_os_change(): assert InfrastructureSecurityService().assess(1)["operating_system_changed"] is False
def test_no_production_change(): assert InfrastructureSecurityService().assess(1)["production_changed"] is False
def test_no_external_connection(): assert InfrastructureSecurityService().assess(1)["external_connection_opened"] is False
def test_no_secret_exposure(): assert InfrastructureSecurityService().assess(1)["secret_values_exposed"] is False
