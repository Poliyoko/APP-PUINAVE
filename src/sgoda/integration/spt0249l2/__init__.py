"""SPT-024.9 Capa 2 â€” privilege governance, service identities, access lifecycle and PAM."""
from .service import PrivilegeGovernanceService
from .gate import PrivilegeGovernanceGate

__all__ = ["PrivilegeGovernanceService", "PrivilegeGovernanceGate"]
