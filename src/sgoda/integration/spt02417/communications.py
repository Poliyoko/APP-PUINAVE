def assess_secure_communications(p):
    checks={"tls_required":bool(p.get("tls_required")),"certificate_governance":bool(p.get("certificate_governance")),"protocol_allowlist":bool(p.get("protocol_allowlist")),"plaintext_secret_prohibition":bool(p.get("plaintext_secret_prohibition")),"internal_transport_governance":bool(p.get("internal_transport_governance")),"external_transport_governance":bool(p.get("external_transport_governance"))}
    return {"valid":all(checks.values()),**checks,"tls_configuration_changed":False}
